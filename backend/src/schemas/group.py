from pydantic import BaseModel, Field, field_validator
from uuid import UUID
from datetime import datetime
from src.models.group import EducationLevel

DAY_NAMES = {
    1: "Saturday",
    2: "Sunday",
    3: "Monday",
    4: "Tuesday",
    5: "Wednesday",
    6: "Thursday",
    7: "Friday",
}


class GroupCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    subject: str = Field(..., min_length=2, max_length=100)
    level: EducationLevel
    day_of_week: str = Field(..., min_length=1, max_length=20)
    time_slot: str = Field(..., min_length=2, max_length=50)

    @field_validator("day_of_week", mode="before")
    @classmethod
    def coerce_day_of_week(cls, v):
        if isinstance(v, (int, float)):
            day_num = int(v)
            if day_num in DAY_NAMES:
                return DAY_NAMES[day_num]
        if isinstance(v, str) and v.strip().isdigit():
            day_num = int(v.strip())
            if day_num in DAY_NAMES:
                return DAY_NAMES[day_num]
        return v


class GroupUpdate(BaseModel):
    name: str | None = None
    subject: str | None = None
    level: EducationLevel | None = None
    day_of_week: str | None = None
    time_slot: str | None = None

    @field_validator("day_of_week", mode="before")
    @classmethod
    def coerce_day_of_week(cls, v):
        if v is None:
            return v
        if isinstance(v, (int, float)):
            day_num = int(v)
            if day_num in DAY_NAMES:
                return DAY_NAMES[day_num]
        if isinstance(v, str) and v.strip().isdigit():
            day_num = int(v.strip())
            if day_num in DAY_NAMES:
                return DAY_NAMES[day_num]
        return v


class GroupResponse(BaseModel):
    id: UUID
    teacher_id: UUID
    name: str
    subject: str
    level: EducationLevel
    day_of_week: str
    time_slot: str
    student_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
