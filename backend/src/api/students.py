import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_user, get_current_teacher
from src.models.audit_log import ActorType
from src.schemas.student import (
    StudentCreate, StudentUpdate, StudentResponse, StudentLogin, StudentTokenResponse,
    StudentPinUpdate, TeacherVerifyRequest, TeacherVerifyResponse,
)
from src.schemas.grade import AIAnalysisRequest, AIAnalysisResponse
from src.core.security.auth import create_access_token, verify_password
from src.services import student_service, grade_service, ai_analyzer, audit_service, pdf_generator, user_service

router = APIRouter(prefix="/students", tags=["Students"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/", response_model=StudentResponse, status_code=status.HTTP_201_CREATED)
async def create_student(
    student_data: StudentCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.create(
        teacher_id=current_user["id"],
        full_name=student_data.full_name,
        phone=student_data.phone,
        parent_phone=student_data.parent_phone,
        grade_level=student_data.grade_level,
        pin=student_data.pin,
    )

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="student_created",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student["id"],
        ip_address=get_client_ip(request),
    )

    return StudentResponse(**student)


@router.get("/", response_model=list[StudentResponse])
async def list_students(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: str | None = None,
    current_user: dict = Depends(get_current_teacher),
):
    students = await student_service.list_by_teacher(
        teacher_id=current_user["id"],
        search=search,
        limit=limit,
        offset=skip,
    )
    return [StudentResponse(**s) for s in students]


@router.get("/count")
async def student_count(current_user: dict = Depends(get_current_teacher)):
    count = await student_service.count(current_user["id"])
    return {"count": count}


@router.get("/{student_id}", response_model=StudentResponse)
async def get_student(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    return StudentResponse(**student)


@router.patch("/{student_id}", response_model=StudentResponse)
async def update_student(
    student_id: str,
    update_data: StudentUpdate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    data = update_data.model_dump(exclude_unset=True)
    updated = await student_service.update(student_id, data)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="student_updated",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student_id,
        ip_address=get_client_ip(request),
    )

    return StudentResponse(**updated)


@router.delete("/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student(
    student_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    await student_service.delete(student_id)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="student_deleted",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student_id,
        ip_address=get_client_ip(request),
    )


@router.get("/{student_id}/pin")
async def get_student_pin(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    if not student.get("pin_hash"):
        return {"has_pin": False, "pin": None, "hint": "لم يتم تعيين رمز سري بعد"}

    return {
        "has_pin": True,
        "pin": None,
        "hint": "الرمز السري موجود. يمكنك إعادة تعيينه من خلال هذا الرابط أو الاتصال بالمدرس.",
    }


@router.patch("/{student_id}/pin", response_model=StudentResponse)
async def update_student_pin(
    student_id: str,
    pin_data: StudentPinUpdate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    updated = await student_service.update(student_id, {"pin": pin_data.pin})

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="student_pin_reset",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student_id,
        ip_address=get_client_ip(request),
    )

    return StudentResponse(**updated)


@router.post("/verify-teacher", response_model=TeacherVerifyResponse)
async def verify_teacher(request: TeacherVerifyRequest):
    teacher = await user_service.repo.select_one({"teacher_code": request.teacher_code})
    if not teacher:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid teacher code")

    return TeacherVerifyResponse(
        teacher_id=teacher["id"],
        teacher_code=teacher["teacher_code"],
        teacher_name=teacher["full_name"],
    )


@router.post("/login", response_model=StudentTokenResponse)
async def student_login(credentials: StudentLogin):
    student = await student_service.get_by_code(credentials.code)
    if not student or not student.get("pin_hash"):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid code or PIN")

    if not verify_password(credentials.pin, student["pin_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid code or PIN")

    # If teacher_code provided, verify student belongs to that teacher
    if credentials.teacher_code:
        teacher = await user_service.repo.select_one({"teacher_code": credentials.teacher_code})
        if not teacher or str(student.get("teacher_id")) != str(teacher["id"]):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Student does not belong to this teacher")

    token = create_access_token(student["id"], expires_delta=None)

    return StudentTokenResponse(
        access_token=token,
        student_id=student["id"],
        student_code=student["code"],
    )


@router.post("/analyze", response_model=AIAnalysisResponse)
async def analyze_student(
    request: Request,
    analyze_request: AIAnalysisRequest,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(str(analyze_request.student_id))
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    analysis = await ai_analyzer.analyze_student(
        student_name=student["full_name"],
        subject=analyze_request.subject,
        grades=analyze_request.grades,
    )

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="ai_analysis",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=str(analyze_request.student_id),
        ip_address=get_client_ip(request),
        metadata={"subject": analyze_request.subject},
    )

    return AIAnalysisResponse(**analysis)


@router.get("/{student_id}/report/pdf")
async def export_student_report(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    from fastapi.responses import Response

    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    grades = await grade_service.list({"student_id": student_id}, limit=20)

    ai_report = {
        "strengths": ["تقرير تجريبي"],
        "weaknesses": ["يحتاج تحليل AI"],
        "recommended_focus": ["مراجعة الدروس السابقة"],
        "next_exercise_suggestion": "حل تمارين إضافية",
    }

    pdf_bytes = pdf_generator.generate_student_report(
        student_name=student["full_name"],
        student_code=student["code"],
        subject="عام",
        ai_report=ai_report,
        grades=[{"exam_name": g["exam_name"], "score": g["score"], "max_score": g["max_score"]} for g in grades],
        teacher_name=current_user["full_name"],
    )

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=report_{student['code']}.pdf"},
    )
