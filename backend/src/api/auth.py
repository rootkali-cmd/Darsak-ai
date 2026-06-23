import logging
import hashlib
import re
import asyncio
import time
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Request, Response
from src.utils.dependencies import get_current_user
from src.schemas.user import UserCreate, UserLogin, UserResponse, TokenResponse, TokenRefresh, UserUpdate, OnboardingUpdate
from src.core.security.auth import verify_password, create_access_token, create_refresh_token, decode_token
from src.core.security.sanitizer import sanitize_text, sanitize_email
from src.core.security.supabase_repo import SupabaseError
from src.services import user_service, subscription_plan_service, teacher_subscription_service
from src.infrastructure.audit_events import audit as audit_publisher, AuditEvent
from src.infrastructure.rate_limiter import rate_limiter

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/auth", tags=["Authentication"])

# In-memory token blacklist for refresh token rotation (race-safe with asyncio.Lock)
_token_blacklist: set[str] = set()
_blacklist_lock = asyncio.Lock()

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_WINDOW_SECONDS = 15 * 60  # 15 minutes
LOCKOUT_DURATION_SECONDS = 15 * 60  # 15 minutes


def _validate_password_policy(password: str) -> str | None:
    """Validate password policy. Returns error message in Arabic or None if valid."""
    if len(password) < 8:
        return "يجب أن تكون كلمة المرور 8 أحرف على الأقل"
    if not re.search(r"[A-Z]", password):
        return "يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل"
    if not re.search(r"[a-z]", password):
        return "يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل"
    if not re.search(r"[0-9]", password):
        return "يجب أن تحتوي كلمة المرور على رقم واحد على الأقل"
    return None


async def _is_token_blacklisted(token: str) -> bool:
    async with _blacklist_lock:
        return token in _token_blacklist


async def _blacklist_token(token: str) -> bool:
    async with _blacklist_lock:
        if token in _token_blacklist:
            return False
        _token_blacklist.add(token)
        return True


async def _check_bruteforce(email: str) -> bool:
    """Returns True if the account is locked due to too many failed attempts. Redis-backed."""
    ban_remaining = await rate_limiter.ban_check(f"auth_lockout:{email}", LOCKOUT_DURATION_SECONDS)
    return ban_remaining > 0


async def _record_failed_attempt(email: str) -> None:
    """Record a failed login attempt. Redis-backed with sliding window."""
    count = await rate_limiter.increment(f"auth_fail:{email}", LOCKOUT_WINDOW_SECONDS)
    if count >= MAX_FAILED_ATTEMPTS:
        await rate_limiter.set_ban(f"auth_lockout:{email}", LOCKOUT_DURATION_SECONDS)
        logger.warning("Account locked for email %s after %d failures", email, count)


async def _clear_failed_attempts(email: str) -> None:
    """Clear failed attempts on successful login. Ban keys expire naturally."""
    pass


def get_client_ip(request: Request) -> str:
    if request.client:
        return request.client.host
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return "unknown"


def _get_plan_storage_limit_gb(plan_name: str):
    name_lower = plan_name.lower()
    if "enterprise" in name_lower:
        return "غير محدود"
    if "pro" in name_lower:
        return 6
    return 2

def _get_plan_ai_limit_display(plan_name: str):
    name_lower = plan_name.lower()
    if "enterprise" in name_lower:
        return "غير محدود"
    if "pro" in name_lower:
        return 50
    return 10

def _user_response(user: dict) -> dict:
    return {
        "id": str(user.get("id", "")),
        "email": user.get("email", ""),
        "full_name": user.get("full_name", ""),
        "role": user.get("role", ""),
        "teacher_code": user.get("teacher_code"),
        "is_active": user.get("is_active", True),
        "created_at": str(user.get("created_at", "")),
        "onboarding_completed": user.get("onboarding_completed", False),
        "subjects": user.get("subjects") or [],
        "levels": user.get("levels") or [],
    }


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, request: Request):
    # Password policy enforcement
    pwd_error = _validate_password_policy(user_data.password)
    if pwd_error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=pwd_error)

    try:
        user = await user_service.create(
            email=sanitize_email(user_data.email),
            full_name=sanitize_text(user_data.full_name) or user_data.full_name,
            password=user_data.password,
            role=user_data.role.value if hasattr(user_data.role, 'value') else user_data.role,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except SupabaseError as e:
        logger.error("Registration DB error: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="تعذر إنشاء الحساب. تأكد من اتصال قاعدة البيانات وحاول مرة أخرى",
        )
    except Exception as e:
        logger.error("Unexpected registration error: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="حدث خطأ غير متوقع أثناء إنشاء الحساب. حاول مرة أخرى",
        )

    # Fire-and-forget audit (non-blocking)
    await audit_publisher.publish(AuditEvent(
        actor_type="system",
        action="user_registered",
        actor_id=user["id"],
        resource_type="user",
        resource_id=user["id"],
        ip_address=get_client_ip(request),
    ))

    # Auto-activate 30-day trial on Basic plan for new registered teachers
    if user.get("role") in ("teacher", None):
        try:
            plans = await subscription_plan_service.list_active()
            basic_plan = None
            for p in plans:
                if "basic" in p.get("name", "").lower():
                    basic_plan = p
                    break

            if basic_plan:
                import uuid
                from datetime import timedelta
                from datetime import timezone
                trial_code_id = f"trial-{uuid.uuid4().hex[:12]}"
                trial_expires = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
                await teacher_subscription_service.repo.insert({
                    "teacher_id": user["id"],
                    "plan_id": basic_plan["id"],
                    "code_id": trial_code_id,
                    "expires_at": trial_expires,
                    "is_active": True,
                })
                logger.info("Trial subscription activated for user %s on plan %s", user["id"], basic_plan["name"])
        except Exception as e:
            logger.warning("Failed to auto-activate trial for user %s: %s", user["id"], e)

    return _user_response(user)


@router.post("/login")
async def login(credentials: UserLogin, request: Request, response: Response):
    email = credentials.email.lower().strip()

    # Brute force protection
    if await _check_bruteforce(email):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="تم حظر الحساب مؤقتاً بسبب محاولات دخول كثيرة. حاول مرة أخرى بعد 15 دقيقة",
        )

    user = await user_service.get_by_email(email)
    if not user or not verify_password(credentials.password, user["hashed_password"]):
        await _record_failed_attempt(email)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="بيانات الدخول غير صحيحة")

    # Clear failed attempts on successful login
    await _clear_failed_attempts(email)

    if not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    await audit_publisher.publish(AuditEvent(
        actor_type=user.get("role", "teacher"),
        action="user_login",
        actor_id=user["id"],
        resource_type="user",
        resource_id=user["id"],
        ip_address=get_client_ip(request),
    ))

    access_token = create_access_token(user["id"], extra_claims={"name": user.get("full_name", "")})
    refresh_token = create_refresh_token(user["id"])

    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=1800,  # 30 minutes
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=604800,  # 7 days
        path="/",
    )

    return {"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer", "onboarding_completed": user.get("onboarding_completed", False)}


@router.post("/refresh")
async def refresh_token_endpoint(token_data: TokenRefresh, response: Response):
    # 1. Check blacklist atomically (race-safe with asyncio.Lock)
    if await _is_token_blacklisted(token_data.refresh_token):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token has already been used")

    # 2. Decode the token
    decoded = decode_token(token_data.refresh_token)
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    # 3. Atomic check-and-blacklist (prevent race condition)
    if not await _blacklist_token(token_data.refresh_token):
        # Another request already blacklisted this token
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token has already been used")

    # 4. Verify user still exists and is active
    user_id = decoded.get("sub")
    user = await user_service.get_by_id(user_id)
    if not user or not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    # 5. Issue new tokens
    new_access = create_access_token(user["id"])
    new_refresh = create_refresh_token(user["id"])

    response.set_cookie(
        key="access_token",
        value=new_access,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=1800,  # 30 minutes
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=new_refresh,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=604800,  # 7 days
        path="/",
    )

    return {"access_token": new_access, "refresh_token": new_refresh, "token_type": "bearer"}


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    result = _user_response(current_user)
    if current_user.get("role") in ("teacher", "admin", None):
        try:
            sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
            if sub:
                plan = await subscription_plan_service.get_by_id(sub["plan_id"])
                if plan:
                    plan_name = plan.get("name", "")
                    result["subscription"] = {
                        "plan_name": plan_name,
                        "expires_at": sub.get("expires_at", ""),
                        "activated_at": sub.get("activated_at", sub.get("created_at", "")),
                        "is_active": sub.get("is_active", True),
                        "max_students": await subscription_plan_service.get_plan_student_limit(plan_name),
                    }
                    result["plan_limits"] = {
                        "max_students": await subscription_plan_service.get_plan_student_limit(plan_name),
                        "ai_requests_per_month": await subscription_plan_service.get_plan_ai_limit(plan_name),
                        "storage_limit_gb": _get_plan_storage_limit_gb(plan_name),
                    }
                    result["plan_name"] = plan_name
                    result["storage_limit_gb"] = _get_plan_storage_limit_gb(plan_name)
                    result["ai_requests_per_month"] = _get_plan_ai_limit_display(plan_name)
                    expires = sub.get("expires_at")
                    if isinstance(expires, str):
                        expires_dt = datetime.fromisoformat(expires.replace("Z", "+00:00"))
                    else:
                        expires_dt = expires
                    result["is_expired"] = expires_dt < datetime.now(timezone.utc)
                    result["days_remaining"] = max(0, (expires_dt - datetime.now(timezone.utc)).days)
                    code_id = sub.get("code_id", "")
                    result["is_trial"] = sub.get("is_trial", False) or (isinstance(code_id, str) and code_id.startswith("trial-"))
                else:
                    result["plan_name"] = "No Plan"
                    result["storage_limit_gb"] = 2
                    result["ai_requests_per_month"] = 0
                    result["is_expired"] = True
                    result["days_remaining"] = 0
                    result["is_trial"] = False
            else:
                result["plan_name"] = "No Plan"
                result["storage_limit_gb"] = 2
                result["ai_requests_per_month"] = 0
                result["is_expired"] = True
                result["days_remaining"] = -1
                result["is_trial"] = False
        except Exception as e:
            logger.warning("Failed to load subscription info for /me: %s", e)
    return result


@router.get("/my-subscription")
async def get_my_subscription(current_user: dict = Depends(get_current_user)):
    try:
        sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if sub:
            plan = await subscription_plan_service.get_by_id(sub["plan_id"])
            plan_name = plan.get("name", "") if plan else "Unknown"
            price_egp = plan.get("price_egp", 0) if plan else 0

            max_students = await subscription_plan_service.get_plan_student_limit(plan_name) if plan else 100
            ai_limit = _get_plan_ai_limit_display(plan_name) if plan else 0
            storage_limit = _get_plan_storage_limit_gb(plan_name) if plan else 2

            expires = sub.get("expires_at")
            if isinstance(expires, str):
                expires_dt = datetime.fromisoformat(expires.replace("Z", "+00:00"))
            else:
                expires_dt = expires
            days_remaining = max(0, (expires_dt - datetime.now(timezone.utc)).days)

            code_id = sub.get("code_id", "")
            is_trial = isinstance(code_id, str) and code_id.startswith("trial-")

            return {
                "has_subscription": True,
                "plan_name": plan_name,
                "price_egp": price_egp,
                "max_students": max_students,
                "ai_limit": ai_limit,
                "storage_limit": storage_limit,
                "days_remaining": days_remaining,
                "is_trial": is_trial,
                "expires_at": expires_dt.isoformat() if isinstance(expires_dt, datetime) else str(expires_dt),
            }
        else:
            has_ever_had = await teacher_subscription_service.repo.count({"teacher_id": current_user["id"]}) > 0
            return {
                "has_subscription": False,
                "trial_available": not has_ever_had,
            }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get my subscription: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get subscription: {str(e)}")


@router.patch("/me")
async def update_me(
    update_data: UserUpdate,
    current_user: dict = Depends(get_current_user),
):
    data = update_data.model_dump(exclude_unset=True)
    updated = await user_service.update(current_user["id"], data)
    return _user_response(updated)


@router.patch("/onboarding")
async def save_onboarding(
    onboarding_data: OnboardingUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    await user_service.update(
        current_user["id"],
        {
            "full_name": sanitize_text(onboarding_data.full_name) or onboarding_data.full_name,
            "subjects": onboarding_data.subjects,
            "levels": onboarding_data.levels,
            "onboarding_completed": True,
        },
    )

    await audit_publisher.publish(AuditEvent(
        actor_type=current_user.get("role", "teacher"),
        action="onboarding_completed",
        actor_id=current_user["id"],
        resource_type="user",
        resource_id=current_user["id"],
        ip_address=request.client.host if request.client else "unknown",
        metadata={"subjects": onboarding_data.subjects, "levels": onboarding_data.levels},
    ))

    updated = await user_service.get_by_id(current_user["id"])
    return _user_response(updated)
