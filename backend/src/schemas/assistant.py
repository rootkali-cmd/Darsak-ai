from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional


class AssistantCreate(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=255)
    phone: str | None = None
    salary: float = 0
    incentives: float = 0
    payment_status: str = "unpaid"
    notes: str | None = None


class AssistantUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    salary: float | None = None
    incentives: float | None = None
    payment_status: str | None = None
    notes: str | None = None
    is_active: bool | None = None


class AssistantResponse(BaseModel):
    id: str
    teacher_id: str
    full_name: str
    phone: str | None = None
    salary: float
    incentives: float
    payment_status: str
    notes: str | None = None
    is_active: bool
    created_at: str | None = None
    updated_at: str | None = None


class AssistantsPasswordRequest(BaseModel):
    password: str = Field(..., min_length=4, max_length=128)


class AssistantsPasswordVerifyRequest(BaseModel):
    password: str = Field(..., min_length=4, max_length=128)
