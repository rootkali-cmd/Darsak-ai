import json
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form

from src.utils.dependencies import get_current_teacher, get_current_student
from src.schemas.exam import (
    ExamCreate, ExamUpdate, ExamResponse,
    QuestionCreate, QuestionResponse,
    StudentExamSubmit, StudentExamResponse, ExamResultResponse,
)
from src.services import exam_service, student_exam_service, exam_ai_service

router = APIRouter(prefix="/exams", tags=["Exams"])


# ─── Teacher: Exam CRUD ───────────────────────────────────────────────

@router.post("", response_model=ExamResponse, status_code=status.HTTP_201_CREATED)
async def create_exam(
    data: ExamCreate,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.create(
        teacher_id=current_user["id"],
        title=data.title,
        duration_minutes=data.duration_minutes,
        description=data.description,
    )
    return ExamResponse(**exam)


@router.post("/ai-generate", status_code=status.HTTP_201_CREATED)
async def ai_generate_exam(
    file: UploadFile = File(...),
    title: str = Form(...),
    subject: str | None = Form(None),
    duration_minutes: int = Form(30),
    current_user: dict = Depends(get_current_teacher),
):
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Empty file")

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
        "exam": ExamResponse(**exam),
        "questions": [QuestionResponse(**q) for q in questions],
        "ai_generated": True,
    }


@router.get("", response_model=list[ExamResponse])
async def list_my_exams(
    current_user: dict = Depends(get_current_teacher),
):
    exams = await exam_service.get_by_teacher(current_user["id"])
    return [ExamResponse(**e) for e in exams]


@router.get("/{exam_id}", response_model=ExamResponse)
async def get_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    return ExamResponse(**exam)


@router.put("/{exam_id}", response_model=ExamResponse)
async def update_exam(
    exam_id: str,
    data: ExamUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    updated = await exam_service.update(exam_id, data.model_dump(exclude_unset=True))
    return ExamResponse(**updated)


@router.delete("/{exam_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    await exam_service.delete(exam_id)


@router.post("/{exam_id}/publish", response_model=ExamResponse)
async def publish_exam(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    published = await exam_service.publish(exam_id)
    return ExamResponse(**published)


# ─── Teacher: Questions ──────────────────────────────────────────────

@router.get("/{exam_id}/questions", response_model=list[QuestionResponse])
async def list_questions(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    questions = await exam_service.get_questions(exam_id)
    return [QuestionResponse(**q) for q in questions]


@router.post("/{exam_id}/questions", response_model=QuestionResponse, status_code=status.HTTP_201_CREATED)
async def add_question(
    exam_id: str,
    data: QuestionCreate,
    current_user: dict = Depends(get_current_teacher),
):
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
    return QuestionResponse(**q)


@router.put("/{exam_id}/questions/{question_id}", response_model=QuestionResponse)
async def update_question(
    exam_id: str,
    question_id: str,
    data: QuestionCreate,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    updated = await exam_service.update_question(question_id, data.model_dump())
    return QuestionResponse(**updated)


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

@router.get("/available", response_model=list[ExamResponse])
async def get_available_exams(
    current_student: dict = Depends(get_current_student),
):
    exams = await exam_service.get_published_for_student(current_student["id"])
    return [ExamResponse(**e) for e in exams]


@router.post("/{exam_id}/start", response_model=StudentExamResponse)
async def start_exam(
    exam_id: str,
    current_student: dict = Depends(get_current_student),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["status"] != "published":
        raise HTTPException(status_code=404, detail="Exam not found or not available")
    se = await student_exam_service.start(exam_id, current_student["id"])
    se["exam"] = exam
    return StudentExamResponse(**se)


@router.get("/{exam_id}/questions-student", response_model=list[QuestionResponse])
async def get_exam_questions_student(
    exam_id: str,
    current_student: dict = Depends(get_current_student),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["status"] != "published":
        raise HTTPException(status_code=404, detail="Exam not found")
    questions = await exam_service.get_questions(exam_id)
    hidden = []
    for q in questions:
        q.pop("correct_answer", None)
        hidden.append(q)
    return [QuestionResponse(**q) for q in hidden]


@router.post("/{exam_id}/submit", response_model=StudentExamResponse)
async def submit_exam(
    exam_id: str,
    data: StudentExamSubmit,
    current_student: dict = Depends(get_current_student),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
    se = await student_exam_service.start(exam_id, current_student["id"])
    await student_exam_service.submit(se["id"], [a.model_dump() for a in data.answers])
    await student_exam_service.grade_mc_questions(se["id"])
    updated = await student_exam_service.get_by_id(se["id"])
    return StudentExamResponse(**updated)


@router.get("/my-results", response_model=list[StudentExamResponse])
async def get_my_results(
    current_student: dict = Depends(get_current_student),
):
    exams = await student_exam_service.get_student_exams(current_student["id"])
    results = []
    for se in exams:
        exam = await exam_service.get_by_id(se["exam_id"])
        se["exam"] = exam
        results.append(StudentExamResponse(**se))
    return results


# ─── Teacher: Results ────────────────────────────────────────────────

@router.get("/{exam_id}/results", response_model=list[StudentExamResponse])
async def get_exam_results(
    exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    exam = await exam_service.get_by_id(exam_id)
    if not exam or exam["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Exam not found")
    submissions = await student_exam_service.get_class_results(exam_id)
    results = []
    for se in submissions:
        se["exam"] = exam
        results.append(StudentExamResponse(**se))
    return results


@router.get("/result/{student_exam_id}", response_model=ExamResultResponse)
async def get_student_exam_result(
    student_exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    result = await student_exam_service.get_result(student_exam_id)
    if not result:
        raise HTTPException(status_code=404, detail="Result not found")
    return ExamResultResponse(**result)


@router.post("/analyze/{student_exam_id}")
async def analyze_student_exam(
    student_exam_id: str,
    current_user: dict = Depends(get_current_teacher),
):
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
