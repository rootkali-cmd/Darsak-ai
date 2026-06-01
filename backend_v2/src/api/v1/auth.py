import logging
import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from src.api.deps import get_current_user
from src.core.security.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from src.core.exceptions import (
    BadRequestException,
    UnauthorizedException,
)
from src.repositories.supabase import SupabaseRepository
from src.services.user_service import user_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth")


class LoginRequest(BaseModel):
    email: str
    password: str


class RegisterRequest(BaseModel):
    email: str
    full_name: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=6, max_length=128)


def _generate_teacher_code() -> str:
    chars = string.ascii_uppercase + string.digits
    suffix = "".join(random.choices(chars, k=8))
    return f"TCH-{suffix}"


def _serialize_user(user: dict) -> dict:
    result = {}
    for key, value in user.items():
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        elif isinstance(value, str):
            result[key] = value
        else:
            result[key] = value
    return result


@router.post("/register")
async def register(body: RegisterRequest):
    try:
        email = body.email.strip().lower()

        existing = await user_service.get_by_email(email)
        if existing:
            raise BadRequestException("Email already registered")

        hashed_pw = hash_password(body.password)

        teacher_code = _generate_teacher_code()

        user_data = {
            "email": email,
            "full_name": body.full_name,
            "password_hash": hashed_pw,
            "role": "teacher",
            "teacher_code": teacher_code,
            "is_active": True,
            "onboarding_completed": False,
            "subjects": [],
            "levels": [],
        }

        new_user = await user_service.create(user_data)

        try:
            plans_repo = SupabaseRepository("plans")
            plans = await plans_repo.select({"is_active": True}, limit=100)
            trial_plan = None
            for p in plans:
                if "basic" in p.get("name", "").lower():
                    trial_plan = p
                    break
            if trial_plan is None and plans:
                trial_plan = plans[0]

            if trial_plan:
                subs_repo = SupabaseRepository("subscriptions")
                trial_end = datetime.now(timezone.utc) + timedelta(days=30)
                await subs_repo.insert({
                    "user_id": new_user["id"],
                    "plan_id": trial_plan["id"],
                    "status": "active",
                    "start_date": datetime.now(timezone.utc).isoformat(),
                    "end_date": trial_end.isoformat(),
                    "is_trial": True,
                })
        except Exception:
            logger.warning(f"Failed to create trial subscription for user {new_user.get('id')}", exc_info=True)

        return _serialize_user(new_user)
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error in register: {e}", exc_info=True)
        raise BadRequestException("Registration failed")


@router.post("/login")
async def login(body: LoginRequest):
    try:
        email = body.email.strip().lower()

        user = await user_service.get_by_email(email)
        if user is None:
            raise UnauthorizedException("Invalid email or password")

        if not verify_password(body.password, user.get("password_hash", "")):
            raise UnauthorizedException("Invalid email or password")

        if not user.get("is_active"):
            raise UnauthorizedException("Account is inactive")

        user_id = str(user["id"])
        access_token = create_access_token(
            subject=user_id,
            extra_claims={"name": user["full_name"]},
        )
        refresh_token = create_refresh_token(subject=user_id)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
        }
    except UnauthorizedException:
        raise
    except Exception as e:
        logger.error(f"Error in login: {e}", exc_info=True)
        raise UnauthorizedException("Login failed")


@router.get("/me")
async def me(current_user: dict = Depends(get_current_user)):
    try:
        fields = [
            "id", "email", "full_name", "role", "teacher_code",
            "is_active", "onboarding_completed", "subjects", "levels",
            "created_at", "telegram_channel_id",
        ]
        result = {}
        for f in fields:
            value = current_user.get(f)
            if hasattr(value, "isoformat"):
                result[f] = value.isoformat()
            elif value is not None:
                result[f] = value
            else:
                result[f] = None
        return result
    except Exception as e:
        logger.error(f"Error in me: {e}", exc_info=True)
        raise BadRequestException("Failed to get profile")


@router.post("/refresh")
async def refresh(body: dict):
    try:
        refresh_token_value = body.get("refresh_token")
        if not refresh_token_value:
            raise UnauthorizedException("refresh_token is required")

        payload = decode_token(refresh_token_value)
        if payload is None:
            raise UnauthorizedException("Invalid or expired refresh token")
        if payload.get("type") != "refresh":
            raise UnauthorizedException("Invalid token type")

        user_id = payload.get("sub")
        if not user_id:
            raise UnauthorizedException("Token missing subject")

        user = await user_service.get_by_id(user_id)
        if user is None:
            raise UnauthorizedException("User not found")
        if not user.get("is_active"):
            raise UnauthorizedException("Account is inactive")

        new_access_token = create_access_token(
            subject=user_id,
            extra_claims={"name": user["full_name"]},
        )
        new_refresh_token = create_refresh_token(subject=user_id)

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
        }
    except UnauthorizedException:
        raise
    except Exception as e:
        logger.error(f"Error in refresh: {e}", exc_info=True)
        raise UnauthorizedException("Token refresh failed")
