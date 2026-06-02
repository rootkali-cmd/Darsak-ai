import logging

from fastapi import APIRouter, Depends, Query, UploadFile, File, Form
from pydantic import BaseModel

from src.api.deps import get_current_teacher
from src.core.exceptions import NotFoundException, BadRequestException, ForbiddenException
from src.services.lesson_service import lesson_service
from src.services.video_bot import video_bot_service
from src.services.user_service import user_service

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


@router.post("/{lesson_id}/upload-video")
async def upload_lesson_video(
    lesson_id: str,
    file: UploadFile = File(...),
    caption: str = Form(""),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if lesson is None:
            raise NotFoundException("Lesson not found")
        if str(lesson.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your lesson")

        if not video_bot_service.is_configured:
            raise BadRequestException("Video bot is not configured")

        user = await user_service.get_by_id(teacher["id"])
        if user is None:
            raise NotFoundException("Teacher record not found")

        channel_id = user.get("telegram_channel_id")
        if not channel_id:
            result = await video_bot_service.create_channel(user.get("full_name", teacher["id"]))
            if not result.get("ok"):
                raise BadRequestException(f"Failed to create channel: {result.get('error')}")
            channel_id = result["channel_id"]
            await user_service.update(teacher["id"], {"telegram_channel_id": channel_id})

        content = await file.read()
        if len(content) > 2 * 1024 * 1024 * 1024:
            raise BadRequestException("File size exceeds 2GB limit")

        upload_result = await video_bot_service.send_video(
            chat_id=channel_id,
            file_data=content,
            file_name=file.filename or "lesson_video.mp4",
            caption=caption,
        )
        if not upload_result.get("ok"):
            raise BadRequestException(f"Video upload failed: {upload_result.get('error')}")

        video_url = await video_bot_service.get_file_url(upload_result["file_id"])

        await lesson_service.update(lesson_id, {
            "tg_message_id": upload_result["message_id"],
            "tg_file_id": upload_result["file_id"],
            "duration_seconds": upload_result.get("duration", 0),
            "video_url": video_url,
            "is_published": True,
        })

        return {
            "ok": True,
            "message_id": upload_result["message_id"],
            "file_id": upload_result["file_id"],
            "duration": upload_result.get("duration", 0),
        }
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error uploading video: {e}", exc_info=True)
        raise BadRequestException(str(e) or "Failed to upload video")


@router.get("/{lesson_id}/stream-url")
async def get_lesson_stream_url(
    lesson_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if lesson is None:
            raise NotFoundException("Lesson not found")
        if str(lesson.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your lesson")

        video_url = lesson.get("video_url")
        if video_url:
            return {"stream_url": video_url}

        file_id = lesson.get("tg_file_id")
        if not file_id:
            raise BadRequestException("No video file associated with this lesson")

        fresh_url = await video_bot_service.get_file_url(file_id)
        if not fresh_url:
            raise BadRequestException("Could not retrieve video stream URL")

        return {"stream_url": fresh_url}
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error getting stream url: {e}", exc_info=True)
        raise BadRequestException(str(e) or "Failed to get stream URL")


@router.post("/setup-channel")
async def setup_teacher_channel(
    teacher: dict = Depends(get_current_teacher),
):
    try:
        user = await user_service.get_by_id(teacher["id"])
        if user is None:
            raise NotFoundException("Teacher record not found")

        existing_channel_id = user.get("telegram_channel_id")
        if existing_channel_id:
            info = await video_bot_service.get_channel_info(existing_channel_id)
            return {
                "ok": True,
                "channel_id": existing_channel_id,
                "title": info.get("result", {}).get("title", ""),
            }

        result = await video_bot_service.create_channel(user.get("full_name", teacher["id"]))
        if not result.get("ok"):
            raise BadRequestException(f"Failed to create channel: {result.get('error')}")

        await user_service.update(teacher["id"], {"telegram_channel_id": result["channel_id"]})

        return {
            "ok": True,
            "channel_id": result["channel_id"],
            "title": result.get("title", ""),
        }
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error setting up channel: {e}", exc_info=True)
        raise BadRequestException(str(e) or "Failed to setup channel")
