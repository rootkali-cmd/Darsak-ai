from pydantic import BaseModel, Field, field_validator
from uuid import UUID
from datetime import datetime, date


# ─── Student billing schemas (new) ───────────────────────────────────

class InvoiceCreateRequest(BaseModel):
    student_id: UUID
    lesson_id: UUID | None = None
    amount: float = Field(..., gt=0)
    payment_method: str = Field(..., pattern=r"^(vodafone_cash|instapay|bank_transfer|cash)$")


class InvoiceUploadProof(BaseModel):
    invoice_id: str
    screenshot_url: str = Field(..., min_length=1)


class InvoiceApproveReject(BaseModel):
    teacher_note: str | None = None


class InvoiceResponse(BaseModel):
    id: str
    student_id: str
    lesson_id: str | None = None
    teacher_id: str
    amount: float
    currency: str = "EGP"
    payment_method: str | None = None
    screenshot_url: str | None = None
    status: str = "pending"
    teacher_note: str | None = None
    created_at: str | None = None
    updated_at: str | None = None

    @field_validator('id', 'student_id', 'teacher_id', 'lesson_id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v

    @field_validator('amount', mode='before')
    @classmethod
    def _coerce_float(cls, v):
        if v is None:
            return v
        try:
            return float(v)
        except (ValueError, TypeError):
            return None

    @field_validator('created_at', 'updated_at', mode='before')
    @classmethod
    def _coerce_datetime(cls, v):
        if v is None or isinstance(v, str):
            return v
        if hasattr(v, 'isoformat'):
            return v.isoformat()
        return str(v)


class LessonBrief(BaseModel):
    id: str
    title: str
    subject: str | None = None
    week_number: int | None = None
    description: str | None = None

    @field_validator('id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v


class InvoiceWithLesson(InvoiceResponse):
    lesson: LessonBrief | None = None


# ─── Legacy schemas (kept for backward compat) ───────────────────────

class LegacyInvoiceCreate(BaseModel):
    student_id: UUID
    amount: float = Field(..., gt=0)
    description: str | None = None
    paid: bool = False
    payment_date: date | None = None
    signature: str | None = None


class LegacyInvoiceUpdate(BaseModel):
    amount: float | None = Field(None, gt=0)
    description: str | None = None
    paid: bool | None = None
    payment_date: date | None = None
    signature: str | None = None


class LegacyInvoiceResponse(BaseModel):
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
