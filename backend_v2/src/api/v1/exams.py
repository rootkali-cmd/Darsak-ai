import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from src.api.deps import get_current_teacher
from src.core.exceptions import BadRequestException, NotFoundException, ForbiddenException
from src.services.exam_service import exam_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/exams")


class CreateExamRequest(BaseModel):
    title: str
    description: str | None = None
    duration_minutes: int | None = None
    total_points: float | None = None


class UpdateExamRequest(BaseModel):
    title: str | None = None
    description: str | None = None
    duration_minutes: int | None = None
    total_points: float | None = None


class AddQuestionRequest(BaseModel):
    question_text: str
    options: list | None = None
    correct_answer: str | None = None
    points: float | None = None
    order_num: int | None = None


class UpdateQuestionRequest(BaseModel):
    question_text: str | None = None
    options: list | None = None
    correct_answer: str | None = None
    points: float | None = None
    order_num: int | None = None


@router.get("/")
async def list_exams(
    limit: int = Query(100, le=1000),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        exams = await exam_service.list_by_teacher(
            teacher_id=teacher_id,
            limit=limit,
        )
        return {"data": exams}
    except Exception as e:
        logger.error(f"Error listing exams: {e}", exc_info=True)
        raise BadRequestException("Failed to list exams")


@router.post("/")
async def create_exam(
    body: CreateExamRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        data = {
            "title": body.title,
            "teacher_id": teacher_id,
        }
        if body.description is not None:
            data["description"] = body.description
        if body.duration_minutes is not None:
            data["duration_minutes"] = body.duration_minutes
        if body.total_points is not None:
            data["total_points"] = body.total_points
        exam = await exam_service.create(data)
        return exam
    except Exception as e:
        logger.error(f"Error creating exam: {e}", exc_info=True)
        raise BadRequestException("Failed to create exam")


@router.get("/{exam_id}")
async def get_exam(
    exam_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam:
            raise NotFoundException("Exam not found")
        if str(exam.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your exam")
        return exam
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error getting exam {exam_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to get exam")


@router.put("/{exam_id}")
async def update_exam(
    exam_id: str,
    body: UpdateExamRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await exam_service.get_by_id(exam_id)
        if not existing:
            raise NotFoundException("Exam not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your exam")

        data = {}
        if body.title is not None:
            data["title"] = body.title
        if body.description is not None:
            data["description"] = body.description
        if body.duration_minutes is not None:
            data["duration_minutes"] = body.duration_minutes
        if body.total_points is not None:
            data["total_points"] = body.total_points
        if not data:
            raise BadRequestException("No fields to update")
        exam = await exam_service.update(exam_id, data)
        return exam
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error updating exam {exam_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to update exam")


@router.delete("/{exam_id}")
async def delete_exam(
    exam_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await exam_service.get_by_id(exam_id)
        if not existing:
            raise NotFoundException("Exam not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your exam")

        deleted = await exam_service.delete(exam_id)
        if not deleted:
            raise NotFoundException("Exam not found")
        return {"deleted": True}
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error deleting exam {exam_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to delete exam")


@router.post("/{exam_id}/questions")
async def add_question(
    exam_id: str,
    body: AddQuestionRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam:
            raise NotFoundException("Exam not found")
        if str(exam.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your exam")

        data = {"question_text": body.question_text}
        if body.options is not None:
            data["options"] = body.options
        if body.correct_answer is not None:
            data["correct_answer"] = body.correct_answer
        if body.points is not None:
            data["points"] = body.points
        if body.order_num is not None:
            data["order_num"] = body.order_num
        question = await exam_service.add_question(exam_id, data)
        return question
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error adding question to exam {exam_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to add question")


@router.put("/questions/{question_id}")
async def update_question(
    question_id: str,
    body: UpdateQuestionRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        data = {}
        if body.question_text is not None:
            data["question_text"] = body.question_text
        if body.options is not None:
            data["options"] = body.options
        if body.correct_answer is not None:
            data["correct_answer"] = body.correct_answer
        if body.points is not None:
            data["points"] = body.points
        if body.order_num is not None:
            data["order_num"] = body.order_num
        if not data:
            raise BadRequestException("No fields to update")
        question = await exam_service.update_question(question_id, data)
        return question
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error updating question {question_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to update question")


@router.delete("/questions/{question_id}")
async def delete_question(
    question_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        deleted = await exam_service.delete_question(question_id)
        if not deleted:
            raise NotFoundException("Question not found")
        return {"deleted": True}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error deleting question {question_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to delete question")
