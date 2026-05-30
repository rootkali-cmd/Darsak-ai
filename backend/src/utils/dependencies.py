from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from src.core.security.auth import decode_token, decode_supabase_token
from src.services import user_service, student_service
from src.infrastructure.cache import user_cache, student_cache

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials

    token_data = decode_token(token)
    if token_data is None:
        token_data = decode_supabase_token(token)

    if token_data is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    # Try cache first
    cache_key = f"user:{user_id}"
    user = await user_cache.get(cache_key)
    if user is None:
        user = await user_service.get_by_id(user_id)
        if user:
            await user_cache.set(cache_key, user)

    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is deactivated")
    return user


async def get_current_teacher(
    user: dict = Depends(get_current_user),
) -> dict:
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher or admin access required",
        )
    return user


async def get_current_admin(
    user: dict = Depends(get_current_user),
) -> dict:
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return user


async def get_current_student(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials

    token_data = decode_token(token)
    if token_data is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    student_id = token_data.get("sub")
    if not student_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    # Try cache first
    cache_key = f"student:{student_id}"
    student = await student_cache.get(cache_key)
    if student is None:
        student = await student_service.get_by_id(student_id)
        if student:
            await student_cache.set(cache_key, student)

    if not student:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Student not found")
    return student
