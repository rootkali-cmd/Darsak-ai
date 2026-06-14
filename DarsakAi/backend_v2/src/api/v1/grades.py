import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from src.api.deps import get_current_teacher
from src.core.exceptions import BadRequestException, NotFoundException, ForbiddenException
from src.services.grade_service import grade_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/grades")


class CreateGradeRequest(BaseModel):
    student_id: str
    subject: str | None = None
    score: float
    max_score: float | None = None
    type: str | None = None


class UpdateGradeRequest(BaseModel):
    student_id: str | None = None
    subject: str | None = None
    score: float | None = None
    max_score: float | None = None
    type: str | None = None


@router.get("/")
async def list_grades(
    subject: str | None = Query(None),
    student_id: str | None = Query(None),
    limit: int = Query(200, le=2000),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        grades = await grade_service.list_by_teacher(
            teacher_id=teacher_id,
            subject=subject,
            student_id=student_id,
            limit=limit,
        )
        return {"data": grades}
    except Exception as e:
        logger.error(f"Error listing grades: {e}", exc_info=True)
        raise BadRequestException("Failed to list grades")


@router.post("/")
async def create_grade(
    body: CreateGradeRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        data = {
            "student_id": body.student_id,
            "score": body.score,
            "teacher_id": teacher_id,
        }
        if body.subject is not None:
            data["subject"] = body.subject
        if body.max_score is not None:
            data["max_score"] = body.max_score
        if body.type is not None:
            data["type"] = body.type
        grade = await grade_service.create(data)
        return grade
    except Exception as e:
        logger.error(f"Error creating grade: {e}", exc_info=True)
        raise BadRequestException("Failed to create grade")


@router.put("/{grade_id}")
async def update_grade(
    grade_id: str,
    body: UpdateGradeRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await grade_service.get_by_id(grade_id)
        if not existing:
            raise NotFoundException("Grade not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your grade")

        data = {}
        if body.student_id is not None:
            data["student_id"] = body.student_id
        if body.subject is not None:
            data["subject"] = body.subject
        if body.score is not None:
            data["score"] = body.score
        if body.max_score is not None:
            data["max_score"] = body.max_score
        if body.type is not None:
            data["type"] = body.type
        if not data:
            raise BadRequestException("No fields to update")
        grade = await grade_service.update(grade_id, data)
        return grade
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error updating grade {grade_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to update grade")


@router.delete("/{grade_id}")
async def delete_grade(
    grade_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await grade_service.get_by_id(grade_id)
        if not existing:
            raise NotFoundException("Grade not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your grade")

        deleted = await grade_service.delete(grade_id)
        if not deleted:
            raise NotFoundException("Grade not found")
        return {"deleted": True}
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error deleting grade {grade_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to delete grade")
