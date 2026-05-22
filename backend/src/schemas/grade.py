from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class GradeCreate(BaseModel):
    student_id: UUID
    exam_name: str = Field(..., min_length=1, max_length=255)
    subject: str = Field(..., min_length=2, max_length=100)
    score: float = Field(..., ge=0)
    max_score: float = Field(default=100.0, gt=0)
    wrong_questions: list[int] | None = None
    notes: str | None = None


class GradeCSVRow(BaseModel):
    student_code: str
    exam_name: str
    subject: str
    score: float
    max_score: float = 100.0


class GradeBulkUpload(BaseModel):
    subject: str = Field(..., min_length=2, max_length=100)
    exam_name: str = Field(..., min_length=1, max_length=255)
    grades: list[GradeCSVRow]


class GradeResponse(BaseModel):
    id: UUID
    student_id: UUID
    teacher_id: UUID
    exam_name: str
    subject: str
    score: float
    max_score: float
    wrong_questions: list[int] | None = None
    notes: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AIAnalysisRequest(BaseModel):
    student_id: UUID
    subject: str = Field(..., min_length=2, max_length=100)
    grades: list[dict] = Field(
        ...,
        description='List of grade objects like [{"exam": "quiz1", "score": 65, "wrong_questions": [3,7,12]}]',
    )


class AIAnalysisResponse(BaseModel):
    strengths: list[str]
    weaknesses: list[str]
    recommended_focus: list[str]
    next_exercise_suggestion: str
