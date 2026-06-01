from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class VideoAnalyticsUpdate(BaseModel):
    last_position: int = 0
    max_watched_duration: int = 0
    current_speed: float = 1.0
    is_completed: bool | None = None
    is_flagged_cheated: bool | None = None
    last_event_type: str | None = None


class VideoAnalyticsResponse(BaseModel):
    id: UUID
    student_id: UUID
    video_id: UUID
    teacher_id: UUID
    last_position: int = 0
    max_watched_duration: int = 0
    current_speed: float = 1.0
    is_completed: bool = False
    is_flagged_cheated: bool = False
    is_delayed: bool = False
    delay_reason: str | None = None
    last_event_type: str | None = None
    updated_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


class GroupScheduleCheckRequest(BaseModel):
    group_id: UUID


class ScheduleCheckResponse(BaseModel):
    group_id: UUID
    total_students: int
    delayed_students: list[dict]
    completed_students: list[dict]
    lesson_id: UUID | None = None
