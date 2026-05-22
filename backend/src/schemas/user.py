from pydantic import BaseModel, EmailStr, Field
from uuid import UUID
from datetime import datetime
from src.models.user import UserRole


class UserCreate(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=6, max_length=128)
    role: UserRole = UserRole.teacher


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: UUID
    email: str
    full_name: str
    role: UserRole
    teacher_code: str | None = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    refresh_token: str


class UserUpdate(BaseModel):
    full_name: str | None = None
    password: str | None = Field(None, min_length=6, max_length=128)
