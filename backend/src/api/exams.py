import json
import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form

logger = logging.getLogger("darsak")

from src.utils.dependencies import get_current_teacher, get_current_student
from src.schemas.exam import (
    ExamCreate, ExamUpdate, ExamResponse,
    QuestionCreate, QuestionResponse,
    StudentExamSubmit, StudentExamResponse, ExamResultResponse,
)
from src.services import exam_service, student_exam_service, exam_ai_service

router = APIRouter(prefix="/exams", tags=["Exams"])


def _to_exam_response(exam: dict) -> dict:
    return {
        "id": str(exam.get("id", "")),
        "teacher_id": str(exam.get("teacher_id", "")),
        "title": str(exam.get("title", "")),
        "description": exam.get("description"),
        "duration_minutes": exam.get("duration_minutes"),
        "total_points": exam.get("total_points", 0),
        "status": exam.get("status"),
        "source_type": exam.get("source_type"),
        "created_at": str(exam.get("created_at", "")),
        "updated_at": str(exam.get("updated_at", "")),
    }


def _to_question_response(q: dict) -> dict:
    return {
        "id": str(q.get("id", "")),
        "exam_id": str(q.get("exam_id", "")),
        "type": str(q.get("type", "")),
        "question_text": str(q.get("question_text", "")),
        "options": q.get("options"),
        "correct_answer": q.get("correct_answer"),
        "points": q.get("points", 0),
        "order_index": q.get("order_index", 0),
        "page_number": q.get("page_number", 0),
        "created_at": str(q.get("created_at", "")),
    }


def _to_student_exam_response(se: dict) -> dict:
    exam = se.get("exam")
    return {
        "id": str(se.get("id", "")),
        "exam_id": str(se.get("exam_id", "")),
        "student_id": str(se.get("student_id", "")),
        "started_at": str(se.get("started_at", "")),
        "submitted_at": str(se.get("submitted_at", "")),
        "duration_seconds": se.get("duration_seconds"),
        "status": str(se.get("status", "")),
        "total_score": se.get("total_score"),
        "max_score": se.get("max_score"),
        "exam": _to_exam_response(exam) if exam else None,
    }


def _to_exam_result_response(result: dict) -> dict:
    return {
        "id": str(result.get("id", "")),
        "student_exam_id": str(result.get("student_exam_id", "")),
        "total_score": result.get("total_score", 0),
        "max_score": result.get("max_score", 0),
        "correct_count": result.get("correct_count", 0),
        "wrong_count": result.get("wrong_count", 0),
        "essay_score": result.get("essay_score", 0),
        "strengths": result.get("strengths"),
        "weaknesses": result.get("weaknesses"),
        "recommendations": result.get("recommendations"),
        "created_at": str(result.get("created_at", "")),
    }


# ─── Teacher: Exam CRUD ───────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_exam(
    data: ExamCreate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.create(
            teacher_id=current_user["id"],
            title=data.title,
            duration_minutes=data.duration_minutes,
            description=data.description,
        )
        return _to_exam_response(exam)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create exam: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create exam: {str(exc)}")


MAX_FILE_SIZE = 20 * 1024 * 1024
ALLOWED_MIME_TYPES = {
    "application/pdf",
    "image/jpeg", "image/png", "image/webp", "image/gif",
}


@router.post("/ai-generate", status_code=status.HTTP_201_CREATED)
async def ai_generate_exam(
    file: UploadFile = File(...),
    title: str = Form(...),
    subject: str | None = Form(None),
    duration_minutes: int = Form(30),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        if file.content_type and file.content_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(status_code=400, detail=f"Unsupported file type: {file.content_type}")

        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="Empty file")
        if len(contents) > MAX_FILE_SIZE:
            raise HTTPException(status_code=400, detail="File too large (max 20MB)")

        source_type = "pdf" if file.filename and file.filename.endswith(".pdf") else "images"
        if source_type == "pdf":
            result = await exam_ai_service.generate_questions_from_pdf(contents, subject)
        else:
            result = await exam_ai_service.generate_questions_from_image(contents, subject)

        description = result.get("description", "")
        ai_title = result.get("title", title)

        exam = await exam_service.create(
            teacher_id=current_user["id"],
            title=title or ai_title,
            duration_minutes=duration_minutes,
            description=description,
        )

        questions_data = result.get("questions", [])
        if questions_data:
            for i, q in enumerate(questions_data, 1):
                q.setdefault("order_index", i)
            await exam_service.bulk_add_questions(exam["id"], questions_data)

        questions = await exam_service.get_questions(exam["id"])
        return {
            "exam": _to_exam_response(exam),
            "questions": [_to_question_response(q) for q in questions],
            "ai_generated": True,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to AI-generate exam: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to generate exam: {str(exc)}")


@router.get("")
async def list_my_exams(
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exams = await exam_service.get_by_teacher(current_user["id"])
    except Exception as exc:
        logger.error("Failed to fetch exams: %s", exc, exc_info=True)
        return []
    results = []
    for e in exams:
        try:
            results.append(_to_exam_response(e))
        except Exception as exc:
            logger.warning("Skipping invalid exam record %s: %s", e.get("id"), exc)
            continue
    return results


@router.get("/{exam_id}")
async def get_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        return _to_exam_response(exam)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Exam data is corrupted")


@router.put("/{exam_id}")
async def update_exam(
    exam_id: str,
    data: ExamUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        updated = await exam_service.update(exam_id, data.model_dump(exclude_unset=True))
        return _to_exam_response(updated)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to update exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Exam data is corrupted")


@router.delete("/{exam_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    await exam_service.delete(exam_id)


@router.post("/{exam_id}/publish")
async def publish_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        published = await exam_service.publish(exam_id)
        return _to_exam_response(published)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to publish exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Exam data is corrupted")


# ─── Teacher: Questions ──────────────────────────────────────────────

@router.get("/{exam_id}/questions")
async def list_questions(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        questions = await exam_service.get_questions(exam_id)
        results = []
        for q in questions:
            try:
                results.append(_to_question_response(q))
            except Exception as exc:
                logger.warning("Skipping invalid question %s: %s", q.get("id"), exc)
                continue
        return results
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to list questions for exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to list questions: {str(exc)}")


@router.post("/{exam_id}/questions", status_code=status.HTTP_201_CREATED)
async def add_question(
    exam_id: str,
    data: QuestionCreate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        q = await exam_service.add_question(
            exam_id=exam_id,
            question_type=data.type,
            question_text=data.question_text,
            options=data.options,
            correct_answer=data.correct_answer,
            points=data.points,
            order_index=data.order_index,
            page_number=data.page_number,
        )
        return _to_question_response(q)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to add question to exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to add question: {str(exc)}")


@router.put("/{exam_id}/questions/{question_id}")
async def update_question(
    exam_id: str,
    question_id: str,
    data: QuestionCreate,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        updated = await exam_service.update_question(question_id, data.model_dump())
        return _to_question_response(updated)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to update question %s: %s", question_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to update question: {str(exc)}")


@router.delete("/{exam_id}/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question(
    exam_id: str,
    question_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    await exam_service.delete_question(question_id)


# ─── Student: Take Exam ──────────────────────────────────────────────

@router.get("/available")
async def get_available_exams(
    current_student: dict = Depends(get_current_student),
):
    try:
        exams = await exam_service.get_published_for_student(current_student["id"])
    except Exception as exc:
        logger.error("Failed to fetch available exams: %s", exc, exc_info=True)
        return []
    results = []
    for e in exams:
        try:
            results.append(_to_exam_response(e))
        except Exception as exc:
            logger.warning("Skipping invalid available exam %s: %s", e.get("id"), exc)
            continue
    return results


@router.post("/{exam_id}/start")
async def start_exam(
    exam_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["status"] != "published":
            raise HTTPException(status_code=404, detail="Exam not found or not available")
        se = await student_exam_service.start(exam_id, current_student["id"])
        se["exam"] = exam
        return _to_student_exam_response(se)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to start exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to start exam")


@router.get("/{exam_id}/questions-student")
async def get_exam_questions_student(
    exam_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["status"] != "published":
            raise HTTPException(status_code=404, detail="Exam not found")
        questions = await exam_service.get_questions(exam_id)
        results = []
        for q in questions:
            try:
                q_copy = dict(q)
                q_copy.pop("correct_answer", None)
                results.append(_to_question_response(q_copy))
            except Exception as exc:
                logger.warning("Skipping invalid student question %s: %s", q.get("id"), exc)
                continue
        return results
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get student questions for exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get questions: {str(exc)}")


@router.post("/{exam_id}/submit")
async def submit_exam(
    exam_id: str,
    data: StudentExamSubmit,
    current_student: dict = Depends(get_current_student),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam:
            raise HTTPException(status_code=404, detail="Exam not found")
        se = await student_exam_service.start(exam_id, current_student["id"])
        await student_exam_service.submit(se["id"], [a.model_dump() for a in data.answers])
        await student_exam_service.grade_mc_questions(se["id"])
        updated = await student_exam_service.get_by_id(se["id"])
        return _to_student_exam_response(updated)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to submit exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to submit exam")


@router.get("/my-results")
async def get_my_results(
    current_student: dict = Depends(get_current_student),
):
    try:
        exams = await student_exam_service.get_student_exams(current_student["id"])
    except Exception as exc:
        logger.error("Failed to fetch student results: %s", exc, exc_info=True)
        return []
    results = []
    for se in exams:
        try:
            exam = await exam_service.get_by_id(se["exam_id"])
            se["exam"] = exam
            results.append(_to_student_exam_response(se))
        except Exception as exc:
            logger.warning("Skipping invalid student exam result %s: %s", se.get("id"), exc)
            continue
    return results


# ─── Teacher: Results ────────────────────────────────────────────────

@router.get("/{exam_id}/results")
async def get_exam_results(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        exam = await exam_service.get_by_id(exam_id)
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        submissions = await student_exam_service.get_class_results(exam_id)
        results = []
        for se in submissions:
            se["exam"] = exam
            try:
                results.append(_to_student_exam_response(se))
            except Exception as exc:
                logger.warning("Skipping invalid class result %s: %s", se.get("id"), exc)
                continue
        return results
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get exam results %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get results: {str(exc)}")


@router.get("/result/{student_exam_id}")
async def get_student_exam_result(
    student_exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        result = await student_exam_service.get_result(student_exam_id)
        if not result:
            raise HTTPException(status_code=404, detail="Result not found")
        return _to_exam_result_response(result)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to parse exam result %s: %s", student_exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Result data is corrupted")


@router.post("/analyze/{student_exam_id}")
async def analyze_student_exam(
    student_exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        se = await student_exam_service.get_by_id(student_exam_id)
        if not se:
            raise HTTPException(status_code=404, detail="Student exam not found")

        questions = await exam_service.get_questions(se["exam_id"])
        answers = await student_exam_service.get_answers(student_exam_id)

        exam = await exam_service.get_by_id(se["exam_id"])
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Access denied")

        questions_safe = []
        for q in questions:
            questions_safe.append({
                "type": q.get("type"),
                "question_text": q.get("question_text"),
                "points": q.get("points"),
                "correct_answer": q.get("correct_answer"),
            })

        answers_safe = []
        for a in answers:
            q_id = a.get("question_id")
            q = next((q for q in questions if q["id"] == q_id), {})
            answers_safe.append({
                "question": q.get("question_text", ""),
                "answer": a.get("answer"),
                "correct_answer": q.get("correct_answer"),
                "is_correct": a.get("is_correct"),
                "score": a.get("score"),
            })

        analysis = await exam_ai_service.analyze_student_exam(
            exam_title=exam.get("title", ""),
            questions=questions_safe,
            student_answers=answers_safe,
            total_score=se.get("total_score", 0) or 0,
            max_score=se.get("max_score", 0) or 0,
        )

        await student_exam_service.save_ai_analysis(student_exam_id, analysis)
        return analysis
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to analyze exam %s: %s", student_exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to analyze exam: {str(exc)}")
