from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


PIN_PATTERN = r'^[A-Z0-9]{6,8}$'


class StudentCreate(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: str | None = None
    parent_phone: str | None = None
    grade_level: str | None = None
    pin: str | None = Field(None, min_length=6, max_length=8, pattern=PIN_PATTERN)


class StudentUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    parent_phone: str | None = None
    grade_level: str | None = None
    pin: str | None = Field(None, min_length=6, max_length=8, pattern=PIN_PATTERN)


class StudentPinUpdate(BaseModel):
    pin: str = Field(..., min_length=6, max_length=8, pattern=PIN_PATTERN)


class StudentResponse(BaseModel):
    id: UUID
    code: str
    full_name: str
    phone: str | None = None
    parent_phone: str | None = None
    grade_level: str | None = None
    teacher_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class StudentLogin(BaseModel):
    code: str
    pin: str


class StudentTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    student_id: UUID
    student_code: str
