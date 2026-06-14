from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class LessonCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    subject: str | None = Field(None, max_length=100)
    group_id: UUID | None = None
    week_number: int | None = None
    duration_seconds: int | None = None


class LessonUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    subject: str | None = Field(None, max_length=100)
    group_id: UUID | None = None
    week_number: int | None = None
    is_published: bool | None = None


class LessonResponse(BaseModel):
    id: UUID
    teacher_id: UUID
    group_id: UUID | None = None
    title: str
    description: str | None = None
    subject: str | None = None
    week_number: int | None = None
    video_url: str | None = None
    duration_seconds: int | None = None
    tg_message_id: str | None = None
    tg_file_id: str | None = None
    is_published: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
