from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from src.models.group import EducationLevel


class GroupCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    subject: str = Field(..., min_length=2, max_length=100)
    level: EducationLevel
    day_of_week: str = Field(..., min_length=3, max_length=20)
    time_slot: str = Field(..., min_length=2, max_length=50)


class GroupUpdate(BaseModel):
    name: str | None = None
    subject: str | None = None
    level: EducationLevel | None = None
    day_of_week: str | None = None
    time_slot: str | None = None


class GroupResponse(BaseModel):
    id: UUID
    teacher_id: UUID
    name: str
    subject: str
    level: EducationLevel
    day_of_week: str
    time_slot: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
