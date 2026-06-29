from pydantic import BaseModel, Field
from typing import Optional


class CourseCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    subject: Optional[str] = Field(None, max_length=100)
    level: Optional[str] = Field(None, max_length=50)


class CourseUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    subject: Optional[str] = None
    level: Optional[str] = None
    is_published: Optional[bool] = None


class CoursePricingUpdate(BaseModel):
    center_price: float = Field(default=0.00)
    platform_price: float = Field(default=0.00)
    is_free_for_center: bool = False
    currency: str = "EGP"


class ChapterCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    sort_order: int = 0


class LessonCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    is_free: bool = False
    has_exam: bool = False
    has_homework: bool = False
    sort_order: int = 0


class SharedLectureCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    group_ids: list[str] = Field(..., min_length=1, max_length=50)
    is_free: bool = False
    has_exam: bool = False


class ContentLockUpdate(BaseModel):
    requires_exam_id: Optional[str] = None
    lock_type: str = "exam"
