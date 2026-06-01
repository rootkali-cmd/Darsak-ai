from fastapi import APIRouter, Depends, HTTPException, status, Query
from src.utils.dependencies import get_current_teacher, get_current_student
from src.schemas.video_analytics import (
    VideoAnalyticsUpdate,
    VideoAnalyticsResponse,
    ScheduleCheckResponse,
)
from src.services import video_analytics_service, lesson_service, group_service

router = APIRouter(prefix="/video-analytics", tags=["Video Analytics"])


@router.post("/track")
async def track_watching(
    data: VideoAnalyticsUpdate,
    video_id: str = Query(..., description="Lesson ID"),
    current_student: dict = Depends(get_current_student),
):
    lesson = await lesson_service.get_by_id(video_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    is_cheated = data.is_flagged_cheated
    if not is_cheated and data.is_completed and lesson.get("duration_seconds"):
        expected_duration = lesson["duration_seconds"] / max(data.current_speed, 0.25)
        if data.max_watched_duration < expected_duration * 0.5 and data.max_watched_duration > 0:
            is_cheated = True

    record = await video_analytics_service.upsert(
        student_id=current_student["id"],
        video_id=video_id,
        teacher_id=lesson.get("teacher_id", ""),
        last_position=data.last_position,
        max_watched_duration=data.max_watched_duration,
        current_speed=data.current_speed,
        is_completed=data.is_completed,
        is_flagged_cheated=is_cheated,
        last_event_type=data.last_event_type,
    )
    return {"ok": True, "record_id": record.get("id"), "is_flagged_cheated": is_cheated}


@router.get("/student/{student_id}", response_model=list[VideoAnalyticsResponse])
async def get_student_analytics(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    records = await video_analytics_service.list_all({"student_id": student_id, "teacher_id": current_user["id"]}, limit=500)
    return [VideoAnalyticsResponse(**r) for r in records]


@router.get("/video/{video_id}", response_model=list[VideoAnalyticsResponse])
async def get_video_analytics(
    video_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await lesson_service.get_by_id(video_id)
    if not lesson or lesson["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    records = await video_analytics_service.get_by_video(video_id)
    return [VideoAnalyticsResponse(**r) for r in records]


@router.get("/my/{video_id}", response_model=VideoAnalyticsResponse)
async def get_my_analytics(
    video_id: str,
    current_student: dict = Depends(get_current_student),
):
    records = await video_analytics_service.list_all({"student_id": current_student["id"], "video_id": video_id}, limit=1)
    if not records:
        return VideoAnalyticsResponse(
            id="",
            student_id=current_student["id"],
            video_id=video_id,
            teacher_id="",
            last_position=0,
            max_watched_duration=0,
            current_speed=1.0,
            is_completed=False,
            is_flagged_cheated=False,
            is_delayed=False,
        )
    return VideoAnalyticsResponse(**records[0])


@router.post("/check-schedule", response_model=ScheduleCheckResponse)
async def check_group_schedule(
    group_id: str = Query(...),
    lesson_id: str = Query(...),
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson or lesson["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    delayed = await video_analytics_service.get_delayed_students(group_id, lesson_id)
    completed_records = await video_analytics_service.get_by_video(lesson_id)
    completed = [r for r in completed_records if r.get("is_completed")]

    for s in delayed:
        existing = await video_analytics_service.list_all(
            {"student_id": s["student_id"], "video_id": lesson_id}, limit=1
        )
        if existing:
            await video_analytics_service.upsert(
                student_id=s["student_id"],
                video_id=lesson_id,
                teacher_id=current_user["id"],
                is_delayed=True,
                delay_reason="لم يشاهد الفيديو قبل الموعد الجديد",
                last_event_type="cron_delayed",
            )

    return ScheduleCheckResponse(
        group_id=group_id,
        total_students=len(delayed) + len(completed),
        delayed_students=delayed,
        completed_students=[
            {"student_id": c["student_id"], "is_flagged_cheated": c.get("is_flagged_cheated", False)}
            for c in completed
        ],
        lesson_id=lesson_id,
    )
