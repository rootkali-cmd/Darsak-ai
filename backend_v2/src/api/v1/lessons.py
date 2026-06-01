import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from src.api.deps import get_current_teacher
from src.core.exceptions import NotFoundException, BadRequestException
from src.services.lesson_service import lesson_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lessons")


class CreateLessonRequest(BaseModel):
    title: str
    description: str = None
    subject: str = None
    group_id: str = None
    week_number: int = None


class UpdateLessonRequest(BaseModel):
    title: str = None
    description: str = None
    subject: str = None
    is_published: bool = None
    week_number: int = None


@router.get("/")
async def list_lessons(
    group_id: str = Query(None),
    is_published: bool = Query(None),
    skip: int = Query(0),
    limit: int = Query(50),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        result = await lesson_service.list_by_teacher(
            teacher_id=teacher["id"],
            group_id=group_id,
            is_published=is_published,
            limit=limit,
            offset=skip,
        )
        return result
    except Exception as e:
        logger.error(f"Error listing lessons: {e}", exc_info=True)
        raise BadRequestException("Failed to list lessons")


@router.post("/")
async def create_lesson(
    body: CreateLessonRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        data = {
            "teacher_id": teacher["id"],
            "title": body.title,
        }
        if body.description is not None:
            data["description"] = body.description
        if body.subject is not None:
            data["subject"] = body.subject
        if body.group_id is not None:
            data["group_id"] = body.group_id
        if body.week_number is not None:
            data["week_number"] = body.week_number

        result = await lesson_service.create(data)
        return result
    except Exception as e:
        logger.error(f"Error creating lesson: {e}", exc_info=True)
        raise BadRequestException("Failed to create lesson")


@router.get("/{lesson_id}")
async def get_lesson(
    lesson_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if lesson is None:
            raise NotFoundException("Lesson not found")
        return lesson
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error getting lesson: {e}", exc_info=True)
        raise BadRequestException("Failed to get lesson")


@router.put("/{lesson_id}")
async def update_lesson(
    lesson_id: str,
    body: UpdateLessonRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await lesson_service.get_by_id(lesson_id)
        if existing is None:
            raise NotFoundException("Lesson not found")

        data = {}
        if body.title is not None:
            data["title"] = body.title
        if body.description is not None:
            data["description"] = body.description
        if body.subject is not None:
            data["subject"] = body.subject
        if body.is_published is not None:
            data["is_published"] = body.is_published
        if body.week_number is not None:
            data["week_number"] = body.week_number

        if not data:
            return existing

        result = await lesson_service.update(lesson_id, data)
        return result
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error updating lesson: {e}", exc_info=True)
        raise BadRequestException("Failed to update lesson")


@router.delete("/{lesson_id}")
async def delete_lesson(
    lesson_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await lesson_service.get_by_id(lesson_id)
        if existing is None:
            raise NotFoundException("Lesson not found")

        await lesson_service.delete(lesson_id)
        return {"detail": "Lesson deleted"}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error deleting lesson: {e}", exc_info=True)
        raise BadRequestException("Failed to delete lesson")
