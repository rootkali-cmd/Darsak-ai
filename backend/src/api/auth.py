from fastapi import APIRouter, Depends, HTTPException, status, Request
from src.utils.dependencies import get_current_user, get_current_teacher
from src.schemas.user import UserCreate, UserLogin, UserResponse, TokenResponse, TokenRefresh, UserUpdate, OnboardingUpdate
from src.core.security.auth import verify_password, create_access_token, create_refresh_token, decode_token
from src.core.security.sanitizer import sanitize_text, sanitize_email
from src.services import user_service, audit_service

router = APIRouter(prefix="/auth", tags=["Authentication"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


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

    await audit_service.log(
        actor_type="system",
        action="user_registered",
        actor_id=user["id"],
        resource_type="user",
        resource_id=user["id"],
        ip_address=get_client_ip(request),
    )

    return UserResponse(**user)


@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin, request: Request):
    user = await user_service.get_by_email(credentials.email.lower().strip())
    if not user or not verify_password(credentials.password, user["hashed_password"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    await audit_service.log(
        actor_type=user.get("role", "teacher"),
        action="user_login",
        actor_id=user["id"],
        ip_address=get_client_ip(request),
    )

    return TokenResponse(
        access_token=create_access_token(user["id"]),
        refresh_token=create_refresh_token(user["id"]),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token_endpoint(token_data: TokenRefresh):
    decoded = decode_token(token_data.refresh_token)
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user_id = decoded.get("sub")
    user = await user_service.get_by_id(user_id)
    if not user or not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    return TokenResponse(
        access_token=create_access_token(user["id"]),
        refresh_token=create_refresh_token(user["id"]),
    )


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

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="onboarding_completed",
        actor_id=current_user["id"],
        resource_type="user",
        resource_id=current_user["id"],
        ip_address=request.client.host if request.client else "unknown",
        metadata={"subjects": onboarding_data.subjects, "levels": onboarding_data.levels},
    )

    updated = await user_service.get_by_id(current_user["id"])
    return UserResponse(**updated)
