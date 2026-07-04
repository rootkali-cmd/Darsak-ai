from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Form, Request
from pydantic import BaseModel
from src.utils.dependencies import get_current_teacher, get_current_student
from src.schemas.lesson import LessonCreate, LessonUpdate, LessonResponse
from src.services import lesson_service, group_service, user_service
from src.core.security.supabase_repo import SupabaseRepository

import logging
logger = logging.getLogger("darsak.lessons")

class VideoProgressUpdate(BaseModel):
    position_seconds: float = 0.0
    duration_seconds: float | None = None

router = APIRouter(prefix="/lessons", tags=["Lessons"])

def _to_response(lesson: dict) -> dict:
    """Safe conversion from DB dict to API response dict."""
    _id = lesson.get("id")
    teacher_id = lesson.get("teacher_id")
    group_id = lesson.get("group_id")
    created_at = lesson.get("created_at")
    updated_at = lesson.get("updated_at")
    return {
        "id": str(_id) if _id is not None else "",
        "teacher_id": str(teacher_id) if teacher_id is not None else "",
        "group_id": str(group_id) if group_id is not None else None,
        "title": lesson.get("title", ""),
        "description": lesson.get("description"),
        "subject": lesson.get("subject"),
        "week_number": lesson.get("week_number"),
        "video_url": lesson.get("video_url"),
        "duration_seconds": lesson.get("duration_seconds"),
        "tg_message_id": lesson.get("tg_message_id"),
        "tg_file_id": lesson.get("tg_file_id"),
        "is_published": lesson.get("is_published", False),
        "created_at": str(created_at) if created_at is not None else "",
        "updated_at": str(updated_at) if updated_at is not None else "",
    }


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_lesson(
    lesson_data: LessonCreate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        if lesson_data.group_id:
            group = await group_service.get_by_id(str(lesson_data.group_id))
            if not group or group.get("teacher_id") != current_user["id"]:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

        lesson = await lesson_service.create(
            teacher_id=current_user["id"],
            title=lesson_data.title,
            description=lesson_data.description,
            subject=lesson_data.subject,
            group_id=str(lesson_data.group_id) if lesson_data.group_id else None,
            week_number=lesson_data.week_number,
            duration_seconds=lesson_data.duration_seconds,
        )
        return _to_response(lesson)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Create lesson failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create lesson: {str(exc)}")


@router.get("/")
async def list_lessons(
    group_id: str | None = None,
    is_published: bool | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        filters = {"teacher_id": current_user["id"]}
        if group_id:
            filters["group_id"] = group_id
        if is_published is not None:
            filters["is_published"] = is_published
        lessons = await lesson_service.list_all(filters, limit=limit, offset=skip)
        return [_to_response(l) for l in lessons]
    except Exception as exc:
        logger.error("List lessons failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to list lessons: {str(exc)}")


@router.get("/group/{group_id}")
async def list_group_lessons(
    group_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        group = await group_service.get_by_id(group_id)
        if not group or group.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
        lessons = await lesson_service.get_by_group(group_id, published_only=False)
        return [_to_response(l) for l in lessons]
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("List group lessons failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.get("/me")
async def list_my_lessons(
    current_student: dict = Depends(get_current_student),
):
    try:
        group_id = current_student.get("group_id")
        if not group_id:
            return []
        lessons = await lesson_service.get_by_group(group_id, published_only=True)
        return [_to_response(l) for l in lessons]
    except Exception as exc:
        logger.error("List my lessons failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.get("/{lesson_id}")
async def get_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if not lesson or lesson.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
        return _to_response(lesson)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Get lesson failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.put("/{lesson_id}")
async def update_lesson(
    lesson_id: str,
    lesson_data: LessonUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if not lesson or lesson.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
        update_data = lesson_data.model_dump(exclude_none=True)
        if update_data.get("group_id"):
            update_data["group_id"] = str(update_data["group_id"])
        updated = await lesson_service.update(lesson_id, update_data)
        return _to_response(updated)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Update lesson failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.delete("/{lesson_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if not lesson or lesson.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
        await lesson_service.delete(lesson_id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Delete lesson failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.post("/{lesson_id}/upload-video")
async def upload_lesson_video(
    lesson_id: str,
    file: UploadFile = File(...),
    caption: str = Form(""),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if not lesson or lesson["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

        try:
            from src.bot.video_bot import video_bot_service
        except ImportError:
            raise HTTPException(status_code=501, detail="Video bot service not available")

        if not video_bot_service.is_configured:
            raise HTTPException(status_code=501, detail="Video Telegram bot token not configured")

        teacher = await user_service.get_by_id(current_user["id"])
        channel_id = teacher.get("telegram_channel_id") if teacher else None

        if not channel_id:
            teacher_name = teacher.get("full_name", current_user.get("full_name", "Teacher"))
            result = await video_bot_service.create_channel(teacher_name)
            if not result.get("ok"):
                raise HTTPException(status_code=500, detail=f"Failed to create channel: {result.get('error')}")
            channel_id = result["channel_id"]
            await user_service.update(current_user["id"], {"telegram_channel_id": channel_id})

        content = await file.read()

        from src.services import subscription_plan_service, teacher_subscription_service
        teacher_sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if teacher_sub:
            plan = await subscription_plan_service.get_by_id(teacher_sub.get("plan_id"))
            if plan:
                limit = await subscription_plan_service.get_plan_storage_limit(plan.get("name", ""))
            else:
                limit = await subscription_plan_service.get_plan_storage_limit(teacher_sub.get("plan_name", ""))
            if limit > 0 and len(content) > limit:
                limit_gb = limit // (1024 * 1024 * 1024)
                raise HTTPException(
                    status_code=400,
                    detail=f"حجم الفيديو ({len(content) // (1024 * 1024)}MB) يتجاوز الحد الأقصى للباقة ({limit_gb}GB)"
                )

        if len(content) > 2 * 1024 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Video file too large (max 2GB)")

        result = await video_bot_service.send_video(
            chat_id=channel_id,
            file_data=content,
            file_name=file.filename or "lesson_video.mp4",
            caption=f"<b>{lesson['title']}</b>\n{caption}" if caption else f"<b>{lesson['title']}</b>",
            supports_streaming=True,
        )

        if not result.get("ok"):
            raise HTTPException(status_code=500, detail=f"Upload failed: {result.get('error')}")

        await lesson_service.update(lesson_id, {
            "tg_message_id": result["message_id"],
            "tg_file_id": result["file_id"],
            "duration_seconds": result.get("duration"),
            "video_url": await video_bot_service.get_file_url(result["file_id"]),
            "is_published": True,
        })

        return {
            "ok": True,
            "message_id": result["message_id"],
            "file_id": result["file_id"],
            "duration": result.get("duration"),
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Upload video failed for lesson %s: %s", lesson_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to upload video: {str(exc)}")


@router.get("/{lesson_id}/stream-url")
async def get_stream_url(
    lesson_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        lesson = await lesson_service.get_by_id(lesson_id)
        if not lesson or not lesson.get("is_published"):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found or not published")

        group_id = current_student.get("group_id")
        if lesson.get("group_id") and str(lesson.get("group_id")) != str(group_id):
            raise HTTPException(status_code=403, detail="Access denied")

        course_id = lesson.get("course_id")
        if course_id:
            from src.core.security.supabase_repo import SupabaseRepository
            enrollments_repo = SupabaseRepository("student_course_enrollments")
            enrollment = await enrollments_repo.select_one({
                "student_id": current_student["id"],
                "course_id": str(course_id),
            })
            if not enrollment:
                raise HTTPException(status_code=403, detail="يجب شراء الكورس أولاً")

        file_id = lesson.get("tg_file_id")
        video_url = lesson.get("video_url")

        if not file_id and not video_url:
            raise HTTPException(status_code=404, detail="No video uploaded for this lesson")

        if video_url:
            return {"stream_url": video_url, "file_id": file_id}

        try:
            from src.bot.video_bot import video_bot_service
            stream_url = await video_bot_service.get_file_url(file_id)
            if stream_url:
                return {"stream_url": stream_url, "file_id": file_id}
        except Exception:
            pass

        raise HTTPException(status_code=502, detail="Cannot get stream URL")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Get stream URL failed for lesson %s: %s", lesson_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.get("/{lesson_id}/progress")
async def get_lesson_progress(
    lesson_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        repo = SupabaseRepository("video_progress")
        record = await repo.select_one({
            "student_id": current_student["id"],
            "lesson_id": lesson_id,
        })
        if not record:
            return {"position_seconds": 0.0, "duration_seconds": 0.0, "updated_at": None}
        return {
            "position_seconds": float(record.get("position_seconds", 0)),
            "duration_seconds": float(record.get("duration_seconds", 0)),
            "updated_at": str(record.get("updated_at")) if record.get("updated_at") else None,
        }
    except Exception as exc:
        logger.error("Get lesson progress failed for lesson %s: %s", lesson_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="internal error")


@router.post("/{lesson_id}/progress")
async def save_lesson_progress(
    lesson_id: str,
    payload: VideoProgressUpdate,
    current_student: dict = Depends(get_current_student),
):
    try:
        repo = SupabaseRepository("video_progress")
        update_data = {
            "student_id": current_student["id"],
            "lesson_id": lesson_id,
            "position_seconds": payload.position_seconds,
        }
        if payload.duration_seconds is not None:
            update_data["duration_seconds"] = payload.duration_seconds
        await repo.upsert(update_data, on_conflict="student_id,lesson_id")
        return {"ok": True}
    except Exception as exc:
        logger.error("Save lesson progress failed for lesson %s: %s", lesson_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="internal error")


@router.post("/setup-channel")
async def setup_teacher_channel(current_user: dict = Depends(get_current_teacher)):
    try:
        try:
            from src.bot.video_bot import video_bot_service
        except ImportError:
            raise HTTPException(status_code=501, detail="Video bot service not available")

        if not video_bot_service.is_configured:
            raise HTTPException(status_code=501, detail="Video Telegram bot token not configured")

        teacher = await user_service.get_by_id(current_user["id"])
        if teacher and teacher.get("telegram_channel_id"):
            info = await video_bot_service.get_channel_info(teacher["telegram_channel_id"])
            return {"ok": True, "channel_id": teacher["telegram_channel_id"], "channel_info": info}

        teacher_name = teacher.get("full_name", "Teacher") if teacher else "Teacher"
        result = await video_bot_service.create_channel(teacher_name)
        if not result.get("ok"):
            raise HTTPException(status_code=500, detail=f"Failed to create channel: {result.get('error')}")

        await user_service.update(current_user["id"], {"telegram_channel_id": result["channel_id"]})
        return {"ok": True, "channel_id": result["channel_id"], "title": result.get("title")}
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Setup channel failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to setup channel: {str(exc)}")

