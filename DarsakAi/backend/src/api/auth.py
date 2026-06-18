import logging
import hashlib
import asyncio
import re
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


async def _is_token_blacklisted(token: str) -> bool:
    async with _blacklist_lock:
        return token in _token_blacklist


async def _blacklist_token(token: str) -> bool:
    async with _blacklist_lock:
        if token in _token_blacklist:
            return False
        _token_blacklist.add(token)
        return True


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


_LOGIN_ATTEMPTS: dict[str, dict] = {}
LOGIN_ATTEMPTS_PER_WINDOW = 5
LOGIN_WINDOW_SECONDS = 300  # 5 min
LOGIN_BAN_DURATION = 900  # 15 min


def _check_teacher_login_limit(email: str):
    now = time.time()
    state = _LOGIN_ATTEMPTS.get(email, {"attempts": [], "banned_until": 0})
    if state["banned_until"] > now:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="تم حظر الحساب مؤقتاً بسبب محاولات تسجيل دخول كثيرة. حاول بعد 15 دقيقة."
        )
    state["attempts"] = [t for t in state["attempts"] if now - t < LOGIN_WINDOW_SECONDS]
    if len(state["attempts"]) >= LOGIN_ATTEMPTS_PER_WINDOW:
        state["banned_until"] = now + LOGIN_BAN_DURATION
        state["attempts"] = []
        _LOGIN_ATTEMPTS[email] = state
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="تم حظر الحساب مؤقتاً بسبب محاولات تسجيل دخول كثيرة. حاول بعد 15 دقيقة."
        )
    return state


def _validate_password_strength(password: str):
    if len(password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="كلمة المرور يجب أن تكون 8 أحرف على الأقل")
    if not re.search(r"[A-Z]", password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل")
    if not re.search(r"[a-z]", password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل")
    if not re.search(r"\d", password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="كلمة المرور يجب أن تحتوي على رقم واحد على الأقل")


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, request: Request):
    _validate_password_strength(user_data.password)
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
    client_ip = get_client_ip(request)
    allowed = await rate_limiter.is_allowed(("login", client_ip), 20)
    if not allowed:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many login attempts from this IP")
    _check_teacher_login_limit(email)
    user = await user_service.get_by_email(email)
    if not user or not verify_password(credentials.password, user["hashed_password"]):
        if email not in _LOGIN_ATTEMPTS:
            _LOGIN_ATTEMPTS[email] = {"attempts": [], "banned_until": 0}
        _LOGIN_ATTEMPTS[email]["attempts"].append(time.time())
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")
    _LOGIN_ATTEMPTS.pop(email, None)  # Clear on success

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
        max_age=2592000,  # 30 days
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=31536000,  # 1 year
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
        max_age=2592000,  # 30 days
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=new_refresh,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=31536000,  # 1 year
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
                        "allowed_students_limit": sub.get("allowed_students_limit", -1),
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
