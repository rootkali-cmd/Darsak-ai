from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime, date


class InvoiceCreate(BaseModel):
    student_id: UUID
    amount: float = Field(..., gt=0)
    description: str | None = None
    paid: bool = False
    payment_date: date | None = None
    signature: str | None = None


class InvoiceUpdate(BaseModel):
    amount: float | None = Field(None, gt=0)
    description: str | None = None
    paid: bool | None = None
    payment_date: date | None = None
    signature: str | None = None


class InvoiceResponse(BaseModel):
    id: UUID
    teacher_id: UUID
    student_id: UUID
    amount: float
    description: str | None = None
    paid: bool
    payment_date: date | None = None
    signature: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
