import logging
import hashlib
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

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/auth", tags=["Authentication"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


# ── Token Blacklist (prevents refresh token replay) ──
# Uses an in-memory set with TTL cleanup + lock for race-condition safety.
# In multi-worker deployments, replace with Redis-backed implementation.

_blacklist_lock = asyncio.Lock()
_used_refresh_tokens: dict[str, float] = {}  # token_hash -> expiry_time
_BLACKLIST_TTL = 3600 * 24 * 31  # 31 days (same as refresh token lifetime)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def _is_token_blacklisted(token: str) -> bool:
    token_hash = _hash_token(token)
    async with _blacklist_lock:
        # Cleanup expired entries
        now = time.time()
        expired = [h for h, exp in _used_refresh_tokens.items() if now >= exp]
        for h in expired:
            del _used_refresh_tokens[h]
        return token_hash in _used_refresh_tokens


async def _blacklist_token(token: str) -> bool:
    """Atomically add token to blacklist. Returns True if it was already blacklisted (race loser)."""
    token_hash = _hash_token(token)
    async with _blacklist_lock:
        if token_hash in _used_refresh_tokens:
            return False  # Already blacklisted — another request used this token first
        _used_refresh_tokens[token_hash] = time.time() + _BLACKLIST_TTL
        return True


# ── Endpoints ──


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, request: Request):
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

    # Auto-activate 7-day trial on premium plan for new registered teachers
    if user.get("role") in ("teacher", None):
        try:
            plans = await subscription_plan_service.list_active()
            premium_plan = None
            for p in plans:
                if "متقدمة" in p.get("name", ""):
                    premium_plan = p
                    break
            if not premium_plan and plans:
                premium_plan = plans[0]

            if premium_plan:
                import uuid
                from datetime import timedelta
                from datetime import timezone
                trial_code_id = f"trial-{uuid.uuid4().hex[:12]}"
                trial_expires = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
                await teacher_subscription_service.repo.insert({
                    "teacher_id": user["id"],
                    "plan_id": premium_plan["id"],
                    "code_id": trial_code_id,
                    "expires_at": trial_expires,
                    "is_active": True,
                })
                logger.info("Trial subscription activated for user %s on plan %s", user["id"], premium_plan["name"])
        except Exception as e:
            logger.warning("Failed to auto-activate trial for user %s: %s", user["id"], e)

    return UserResponse(**user)


@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin, request: Request, response: Response):
    user = await user_service.get_by_email(credentials.email.lower().strip())
    if not user or not verify_password(credentials.password, user["hashed_password"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
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

    access_token = create_access_token(user["id"])
    refresh_token = create_refresh_token(user["id"])

    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=3600,
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=2592000,
        path="/",
    )

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
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
        max_age=3600,
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=new_refresh,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=2592000,
        path="/",
    )

    return TokenResponse(access_token=new_access, refresh_token=new_refresh)


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserResponse(**current_user)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    update_data: UserUpdate,
    current_user: dict = Depends(get_current_user),
):
    data = update_data.model_dump(exclude_unset=True)
    updated = await user_service.update(current_user["id"], data)
    return UserResponse(**updated)


@router.patch("/onboarding", response_model=UserResponse)
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
    return UserResponse(**updated)
