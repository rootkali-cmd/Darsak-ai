from fastapi import APIRouter, Depends, HTTPException, Query
from src.utils.dependencies import get_current_teacher
from src.services import group_service, lesson_service, video_analytics_service

router = APIRouter(prefix="/notifications/whatsapp", tags=["WhatsApp Notifications"])


@router.get("/delayed-students/{group_id}")
async def get_delayed_students_for_whatsapp(
    group_id: str,
    lesson_id: str = Query(...),
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Group not found")

    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")

    delayed = await video_analytics_service.get_delayed_students(group_id, lesson_id)

    return {
        "group_name": group.get("name", ""),
        "lesson_title": lesson.get("title", ""),
        "delayed_students": delayed,
    }
