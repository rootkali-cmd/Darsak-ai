from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Any


class SubscriptionPlanResponse(BaseModel):
    id: UUID
    name: str
    price_egp: float
    max_students: int
    max_ai_requests: int
    max_grades: int | None = None
    max_invoices: int | None = None
    features_json: list[Any] = []
    is_active: bool = True

    model_config = {"from_attributes": True}


class ActivateCodeRequest(BaseModel):
    code: str = Field(..., min_length=16, max_length=19)


class ActivateCodeResponse(BaseModel):
    success: bool
    plan_name: str
    expires_at: datetime
    message: str


class TeacherSubscriptionResponse(BaseModel):
    id: UUID
    plan_id: UUID
    plan_name: str
    plan: SubscriptionPlanResponse | None = None
    activated_at: datetime
    expires_at: datetime
    is_active: bool
    auto_renew: bool
    days_remaining: int = 0
    is_expired: bool = False

    model_config = {"from_attributes": True}


class CheckFeatureRequest(BaseModel):
    feature: str = Field(..., description="Feature to check")


class CheckFeatureResponse(BaseModel):
    allowed: bool
    current_usage: int = 0
    limit: int | None = None
    remaining: int | None = None
    plan_name: str | None = None


class SubscriptionCodeResponse(BaseModel):
    id: UUID
    code: str
    plan_id: UUID
    is_used: bool
    used_by_teacher_id: str | None = None
    used_at: datetime | None = None
    expires_at: datetime | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
