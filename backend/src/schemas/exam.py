from datetime import datetime
from typing import Any
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


class QuestionCreate(BaseModel):
    type: str = Field(..., pattern=r"^(multiple_choice|essay)$")
    question_text: str
    options: list[dict] | None = None
    correct_answer: str | None = None
    points: int = 1
    order_index: int = 1
    page_number: int = 1


class QuestionResponse(BaseModel):
    id: str
    exam_id: str
    type: str
    question_text: str
    options: Any = None
    correct_answer: str | None = None
    points: int
    order_index: int
    page_number: int
    created_at: str | None = None

    @field_validator('id', 'exam_id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v

    @field_validator('created_at', mode='before')
    @classmethod
    def _coerce_datetime(cls, v):
        if v is None or isinstance(v, str):
            return v
        if hasattr(v, 'isoformat'):
            return v.isoformat()
        return str(v)


class ExamCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    duration_minutes: int = Field(default=30, ge=1, le=180)


class ExamUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    duration_minutes: int | None = Field(default=None, ge=1, le=180)
    status: str | None = Field(default=None, pattern=r"^(draft|published|closed)$")


class ExamResponse(BaseModel):
    id: str
    teacher_id: str
    title: str
    description: str | None = None
    duration_minutes: int | None = None
    total_points: int | None = 0
    status: str | None = None
    source_type: str | None = None
    created_at: str | None = None
    updated_at: str | None = None

    @field_validator('id', 'teacher_id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v

    @field_validator('total_points', 'duration_minutes', mode='before')
    @classmethod
    def _coerce_int(cls, v):
        if v is None:
            return v
        try:
            return int(v)
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


class StudentExamAnswer(BaseModel):
    question_id: str
    answer: str


class StudentExamSubmit(BaseModel):
    answers: list[StudentExamAnswer]


class ExamResultResponse(BaseModel):
    id: str | None = None
    student_exam_id: str
    total_score: float = 0
    max_score: float = 0
    correct_count: int = 0
    wrong_count: int = 0
    essay_score: float = 0
    strengths: str | None = None
    weaknesses: str | None = None
    recommendations: str | None = None
    created_at: str | None = None

    @field_validator('id', 'student_exam_id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v

    @field_validator('created_at', mode='before')
    @classmethod
    def _coerce_datetime(cls, v):
        if v is None or isinstance(v, str):
            return v
        if hasattr(v, 'isoformat'):
            return v.isoformat()
        return str(v)


class StudentExamResponse(BaseModel):
    id: str
    exam_id: str
    student_id: str
    started_at: str | None = None
    submitted_at: str | None = None
    duration_seconds: int | None = None
    status: str
    total_score: float | None = None
    max_score: float | None = None
    exam: ExamResponse | None = None

    @field_validator('id', 'exam_id', 'student_id', mode='before')
    @classmethod
    def _coerce_str(cls, v):
        return str(v) if v is not None else v

    @field_validator('started_at', 'submitted_at', mode='before')
    @classmethod
    def _coerce_datetime(cls, v):
        if v is None or isinstance(v, str):
            return v
        if hasattr(v, 'isoformat'):
            return v.isoformat()
        return str(v)
