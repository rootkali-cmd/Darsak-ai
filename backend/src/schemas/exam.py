from datetime import datetime
from typing import Any
from uuid import UUID
from pydantic import BaseModel, Field


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
    duration_minutes: int
    total_points: int = 0
    status: str
    source_type: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


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
