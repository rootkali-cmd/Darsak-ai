from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Form
from src.utils.dependencies import get_current_teacher, get_current_student
from src.schemas.lesson import LessonCreate, LessonUpdate, LessonResponse
from src.services import lesson_service, group_service, user_service

router = APIRouter(prefix="/lessons", tags=["Lessons"])


@router.post("/", response_model=LessonResponse, status_code=status.HTTP_201_CREATED)
async def create_lesson(
    lesson_data: LessonCreate,
    current_user: dict = Depends(get_current_teacher),
):
    if lesson_data.group_id:
        group = await group_service.get_by_id(str(lesson_data.group_id))
        if not group or group["teacher_id"] != current_user["id"]:
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
    return LessonResponse(**lesson)


@router.get("/", response_model=list[LessonResponse])
async def list_lessons(
    group_id: str | None = None,
    is_published: bool | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    filters = {"teacher_id": current_user["id"]}
    if group_id:
        filters["group_id"] = group_id
    if is_published is not None:
        filters["is_published"] = is_published
    lessons = await lesson_service.list(filters, limit=limit, offset=skip)
    return [LessonResponse(**l) for l in lessons]


@router.get("/group/{group_id}", response_model=list[LessonResponse])
async def list_group_lessons(
    group_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
    lessons = await lesson_service.get_by_group(group_id, published_only=False)
    return [LessonResponse(**l) for l in lessons]


@router.get("/me", response_model=list[LessonResponse])
async def list_my_lessons(
    current_student: dict = Depends(get_current_student),
):
    group_id = current_student.get("group_id")
    if not group_id:
        return []
    lessons = await lesson_service.get_by_group(group_id, published_only=True)
    return [LessonResponse(**l) for l in lessons]


@router.get("/{lesson_id}", response_model=LessonResponse)
async def get_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson or lesson["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    return LessonResponse(**lesson)


@router.put("/{lesson_id}", response_model=LessonResponse)
async def update_lesson(
    lesson_id: str,
    lesson_data: LessonUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson or lesson["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    update_data = lesson_data.model_dump(exclude_none=True)
    if update_data.get("group_id"):
        update_data["group_id"] = str(update_data["group_id"])
    updated = await lesson_service.update(lesson_id, update_data)
    return LessonResponse(**updated)


@router.delete("/{lesson_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson or lesson["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    await lesson_service.delete(lesson_id)


@router.post("/{lesson_id}/upload-video")
async def upload_lesson_video(
    lesson_id: str,
    file: UploadFile = File(...),
    caption: str = Form(""),
    current_user: dict = Depends(get_current_teacher),
):
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
    if len(content) > 2 * 1024 * 1024 * 1024:  # 2GB limit
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


@router.get("/{lesson_id}/stream-url")
async def get_stream_url(
    lesson_id: str,
    current_student: dict = Depends(get_current_student),
):
    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson or not lesson.get("is_published"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found or not published")

    group_id = current_student.get("group_id")
    if lesson.get("group_id") and str(lesson.get("group_id")) != str(group_id):
        raise HTTPException(status_code=403, detail="Access denied")

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


@router.post("/setup-channel")
async def setup_teacher_channel(current_user: dict = Depends(get_current_teacher)):
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

