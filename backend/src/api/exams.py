import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query

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
        "deadline_at": exam.get("deadline_at"),
        "show_results_at": exam.get("show_results_at"),
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
        "student_name": se.get("student_name", ""),
        "student_code": se.get("student_code", ""),
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
            deadline_at=data.deadline_at,
            show_results_at=data.show_results_at,
        )
        return _to_exam_response(exam)
    except HTTPException:
        raise
    except Exception as exc:
        original = getattr(exc, 'original', exc)
        logger.error("Failed to create exam: %s (original: %s)", exc, original, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create exam: internal error")


AI_MAX_FILE_SIZE = 50 * 1024 * 1024
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
    question_count: int = Form(10),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        if file.content_type and file.content_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(status_code=400, detail=f"نوع الملف غير مدعوم: {file.content_type}")

        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="الملف فارغ")
        if len(contents) > AI_MAX_FILE_SIZE:
            raise HTTPException(status_code=400, detail="حجم الملف كبير جداً (الحد الأقصى 50MB)")

        source_type = "pdf" if file.filename and file.filename.endswith(".pdf") else "images"
        if source_type == "pdf":
            result = await exam_ai_service.generate_questions_from_pdf(contents, subject, question_count=question_count)
        else:
            result = await exam_ai_service.generate_questions_from_image(contents, subject, question_count=question_count)

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
                if "question_text" not in q and "text" in q:
                    q["question_text"] = q.pop("text")
                if "correct_answer" not in q and "answer" in q:
                    q["correct_answer"] = q.pop("answer")
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
        raise HTTPException(status_code=500, detail=f"تعذر إنشاء الاختبار: internal error")


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


# ─── Student: Take Exam ──────────────────────────────────────────────

@router.get("/available")
async def get_available_exams(
    current_student: dict = Depends(get_current_student),
):
    try:
        student_id = current_student["id"]
        student_tid = current_student.get("teacher_id")
        logger.info("Student %s (teacher=%s) fetching available exams", student_id, student_tid)
        exams = await exam_service.get_published_for_student(student_id)
        logger.info("Found %d published exams for student %s", len(exams), student_id)
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
        deadline_at = exam.get("deadline_at")
        if deadline_at:
            if isinstance(deadline_at, str):
                deadline_dt = datetime.fromisoformat(deadline_at.replace("Z", "+00:00"))
            else:
                deadline_dt = deadline_at
            if deadline_dt.tzinfo is None:
                deadline_dt = deadline_dt.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > deadline_dt:
                raise HTTPException(status_code=403, detail="الامتحان انتهى")
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
        raise HTTPException(status_code=500, detail=f"Failed to get questions: internal error")


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
        deadline_at = exam.get("deadline_at")
        if deadline_at:
            if isinstance(deadline_at, str):
                deadline_dt = datetime.fromisoformat(deadline_at.replace("Z", "+00:00"))
            else:
                deadline_dt = deadline_at
            if deadline_dt.tzinfo is None:
                deadline_dt = deadline_dt.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > deadline_dt:
                raise HTTPException(status_code=403, detail="الامتحان انتهى")
        se = await student_exam_service.start(exam_id, current_student["id"])
        if se.get("status") in ("graded", "submitted"):
            se["exam"] = exam
            return _to_student_exam_response(se)
        await student_exam_service.submit(se["id"], [a.model_dump() for a in data.answers])
        await student_exam_service.grade_mc_questions(se["id"])
        updated = await student_exam_service.get_by_id(se["id"])
        if updated is None:
            logger.error("Student exam %s not found after submit/grade", se["id"])
            raise HTTPException(status_code=500, detail="Failed to find submitted exam")
        updated["exam"] = exam
        return _to_student_exam_response(updated)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to submit exam %s: %s", exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"فشل التسليم: internal error")


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


@router.get("/my-result/{student_exam_id}")
async def get_my_exam_result(
    student_exam_id: str,
    current_student: dict = Depends(get_current_student),
):
    try:
        se = await student_exam_service.get_by_id(student_exam_id)
        if not se or se["student_id"] != current_student["id"]:
            raise HTTPException(status_code=404, detail="Result not found")
        exam = await exam_service.get_by_id(se["exam_id"])
        show_results = True
        if exam and exam.get("show_results_at"):
            try:
                show_at = datetime.fromisoformat(exam["show_results_at"].replace("Z", "+00:00"))
                if datetime.now(timezone.utc) < show_at:
                    show_results = False
            except (ValueError, TypeError):
                pass
        correct_count = 0
        wrong_count = 0
        total_mc = 0
        if se.get("status") == "graded":
            answers = await student_exam_service.get_answers(student_exam_id)
            for a in answers:
                if a.get("type") == "multiple_choice" or True:
                    total_mc += 1
                    if a.get("is_correct"):
                        correct_count += 1
                    else:
                        wrong_count += 1
        correct_pct = (correct_count / total_mc * 100) if total_mc > 0 else 0
        wrong_pct = (wrong_count / total_mc * 100) if total_mc > 0 else 0
        max_score = se.get("max_score") or 0
        total_score = se.get("total_score") or 0
        score_pct = (total_score / max_score * 100) if max_score > 0 else 0
        result = {
            "student_exam_id": student_exam_id,
            "status": se.get("status", ""),
            "total_score": total_score,
            "max_score": max_score,
            "score_percentage": round(score_pct, 1),
        }
        if show_results:
            result["correct_percentage"] = round(correct_pct, 1)
            result["wrong_percentage"] = round(wrong_pct, 1)
            result["total_mc_questions"] = total_mc
        else:
            result["correct_percentage"] = None
            result["wrong_percentage"] = None
            result["total_mc_questions"] = None
            result["results_hidden_until"] = exam["show_results_at"]
        return result
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get student result %s: %s", student_exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to get result")
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

        try:
            from src.services import notification_service
            from src.core.security.supabase_repo import SupabaseRepository
            student_repo = SupabaseRepository("students")
            students_res = await student_repo.select({"teacher_id": current_user["id"]})
            students = students_res if isinstance(students_res, list) else []
            for student in students:
                student_id = student.get("id")
                if student_id:
                    await notification_service.create(
                        teacher_id=student_id,
                        title="📝 اختبار جديد متاح",
                        body=f"اختبار '{exam.get('title', '')}' متاح الآن!",
                        type="info",
                    )
        except Exception as notif_err:
            logger.warning("Exam publish notifications skipped: %s", notif_err)

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
        raise HTTPException(status_code=500, detail=f"Failed to list questions: internal error")


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
        raise HTTPException(status_code=500, detail=f"Failed to add question: internal error")


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
        raise HTTPException(status_code=500, detail=f"Failed to update question: internal error")


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
        raise HTTPException(status_code=500, detail=f"Failed to get results: internal error")


@router.get("/result/{student_exam_id}")
async def get_student_exam_result(
    student_exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        se = await student_exam_service.get_by_id(student_exam_id)
        if not se:
            raise HTTPException(status_code=404, detail="Student exam not found")
        # Verify teacher owns the exam
        exam = await exam_service.get_by_id(se["exam_id"])
        if not exam or exam["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=404, detail="Exam not found")
        
        answers = await student_exam_service.get_answers(student_exam_id)
        questions = await exam_service.get_questions(se["exam_id"])
        questions_map = {q["id"]: q for q in questions}
        
        # Get student info
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        stu_res = await client.table("students").select("full_name, code").eq("id", se["student_id"]).execute()
        student_info = (stu_res.data or [{}])[0] if stu_res.data else {}
        
        question_details = []
        correct_count = 0
        wrong_count = 0
        total_mc = 0
        for a in answers:
            q = questions_map.get(a.get("question_id"))
            if not q:
                continue
            detail = {
                "question_id": q["id"],
                "question_text": q.get("question_text", ""),
                "type": q.get("type", ""),
                "points": q.get("points", 1),
                "student_answer": a.get("answer", ""),
            }
            if q["type"] == "multiple_choice":
                total_mc += 1
                detail["correct_answer"] = q.get("correct_answer", "")
                detail["is_correct"] = a.get("is_correct", False)
                if a.get("is_correct"):
                    correct_count += 1
                else:
                    wrong_count += 1
            question_details.append(detail)
        
        correct_pct = (correct_count / total_mc * 100) if total_mc > 0 else 0
        wrong_pct = (wrong_count / total_mc * 100) if total_mc > 0 else 0
        max_score = se.get("max_score") or 0
        total_score = se.get("total_score") or 0
        score_pct = (total_score / max_score * 100) if max_score > 0 else 0
        
        return {
            "student_exam_id": student_exam_id,
            "student_name": student_info.get("full_name", "غير معروف"),
            "student_code": student_info.get("code", ""),
            "exam_title": exam.get("title", ""),
            "status": se.get("status", ""),
            "total_score": total_score,
            "max_score": max_score,
            "score_percentage": round(score_pct, 1),
            "correct_percentage": round(correct_pct, 1),
            "wrong_percentage": round(wrong_pct, 1),
            "total_mc_questions": total_mc,
            "questions": question_details,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get student exam result %s: %s", student_exam_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Result data is corrupted")


@router.get("/check-new/{student_id}")
async def check_new_exams(
    student_id: str,
    last_check: str = Query(..., description="ISO timestamp of last check"),
    current_student: dict = Depends(get_current_student),
):
    if current_student["id"] != student_id:
        raise HTTPException(status_code=403, detail="Access denied")
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()

        from datetime import datetime as dt
        last_dt = dt.fromisoformat(last_check.replace("Z", "+00:00"))
        if last_dt.tzinfo is None:
            last_dt = last_dt.replace(tzinfo=timezone.utc)

        stu_res = await client.table("students").select("group_id, teacher_id").eq("id", student_id).execute()
        if not stu_res.data:
            return []
        student = stu_res.data[0]
        teacher_id = student.get("teacher_id")
        group_id = student.get("group_id")
        
        if not teacher_id and group_id:
            grp_res = await client.table("groups").select("teacher_id").eq("id", group_id).execute()
            if grp_res.data:
                teacher_id = grp_res.data[0].get("teacher_id")
        
        if not teacher_id:
            return []

        exams_res = await (
            client.table("exams")
            .select("id, title, description, duration_minutes, total_points, deadline_at, created_at")
            .eq("status", "published")
            .eq("teacher_id", teacher_id)
            .gt("created_at", last_dt.isoformat())
            .execute()
        )
        exams = exams_res.data or []

        results = []
        for e in exams:
            results.append({
                "id": str(e.get("id", "")),
                "title": e.get("title", ""),
                "description": e.get("description"),
                "duration_minutes": e.get("duration_minutes", 30),
                "total_points": e.get("total_points", 0),
                "deadline_at": e.get("deadline_at"),
                "created_at": str(e.get("created_at", "")),
            })
        return results
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to check new exams: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to check new exams: internal error")


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
        raise HTTPException(status_code=500, detail=f"Failed to analyze exam: internal error")
