from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from datetime import date as date_type
from src.models.attendance import AttendanceStatus


class AttendanceCreate(BaseModel):
    student_id: UUID
    group_id: UUID | None = None
    status: AttendanceStatus = AttendanceStatus.present
    date: date_type | None = None
    notes: str | None = None


class AttendanceBulkCreate(BaseModel):
    group_id: UUID | None = None
    date: date_type | None = None
    records: list[dict] = Field(..., description="List of {student_id, status, notes}")


class AttendanceResponse(BaseModel):
    id: UUID
    student_id: UUID
    group_id: UUID | None = None
    teacher_id: UUID
    status: AttendanceStatus = AttendanceStatus.absent
    date: date_type | None = None
    notes: str | None = None
    created_at: datetime | None = None
    student_name: str | None = None
    student_code: str | None = None

    model_config = {"from_attributes": True}
