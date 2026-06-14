from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Request

from src.utils.dependencies import get_current_student
from src.services.quiz_service import quiz_service
from src.services import lesson_service

import logging
logger = logging.getLogger("darsak.quiz")

router = APIRouter(prefix="/quiz", tags=["Quiz"])


@router.post("/generate")
async def generate_quiz(
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    body = await request.json()
    lesson_id = body.get("lesson_id")

    if not lesson_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="lesson_id is required")

    lesson = await lesson_service.get_by_id(lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    group_id = current_student.get("group_id")
    if lesson.get("group_id") and str(lesson.get("group_id")) != str(group_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    count = await quiz_service.count_today_quizzes(current_student["id"], today)
    if count >= 7:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="وصلت للحد اليومي (7 كويزات). حاول غداً."
        )

    transcript = lesson.get("transcript") or lesson.get("description") or ""
    if not transcript or len(transcript) < 50:
        transcript = f"درس: {lesson.get('title', '')}. {lesson.get('description', '')}"

    questions = await quiz_service.generate_quiz(transcript, lesson.get("title", ""))
    if not questions:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="فشل توليد الأسئلة. حاول مرة أخرى."
        )

    quiz = await quiz_service.save_quiz(current_student["id"], lesson_id, questions)

    return {"ok": True, "quiz_id": quiz["id"], "questions": questions}


@router.get("/history")
async def get_quiz_history(
    current_student: dict = Depends(get_current_student),
):
    try:
        history = await quiz_service.get_history(current_student["id"], days=30)
        return history
    except Exception as exc:
        logger.error("Get quiz history failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get quiz history: {str(exc)}")


@router.get("/{quiz_id}")
async def get_quiz(
    quiz_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        quiz = await quiz_service.get_quiz(quiz_id, current_student["id"])
        if not quiz:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
        return quiz
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Get quiz failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")
