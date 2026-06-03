import uuid
from datetime import datetime
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_user, get_current_teacher
from src.models.audit_log import ActorType
from src.schemas.student import (
    StudentCreate, StudentUpdate, StudentResponse, StudentLogin, StudentTokenResponse,
    StudentPinUpdate, TeacherVerifyRequest, TeacherVerifyResponse,
)
from src.schemas.grade import AIAnalysisRequest, AIAnalysisResponse
from src.core.security.auth import create_access_token, verify_password, hash_password
from src.core.security.sanitizer import sanitize_text, sanitize_student_code, sanitize_pin, sanitize_teacher_code
from src.services import student_service, grade_service, ai_analyzer, audit_service, pdf_generator, user_service, teacher_subscription_service, subscription_plan_service
from src.core.subscription_guard import enforce_ai_request_limit, increment_ai_usage

router = APIRouter(prefix="/students", tags=["Students"])


def _to_response(data: dict) -> dict:
    result = {}
    for key, value in data.items():
        if hasattr(value, 'isoformat'):
            result[key] = value.isoformat()
        elif isinstance(value, UUID) or hasattr(value, 'hex'):
            result[key] = str(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _serialize_student(s: dict) -> dict:
    return {
        "id": str(s.get("id", "")),
        "teacher_id": str(s.get("teacher_id", "")),
        "full_name": s.get("full_name", ""),
        "code": s.get("code", ""),
        "parent_phone": s.get("parent_phone"),
        "group_id": str(s.get("group_id")) if s.get("group_id") else None,
        "pin_hash": s.get("pin_hash"),
        "has_pin": s.get("pin_hash") is not None,
        "is_active": s.get("is_active", True),
        "created_at": str(s.get("created_at", "")),
        "updated_at": str(s.get("updated_at", "")),
    }


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_student(
    student_data: StudentCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    # Check student limit
    sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
    if sub:
        plan = await subscription_plan_service.get_by_id(sub.get("plan_id", ""))
        if plan:
            limit = await subscription_plan_service.get_plan_student_limit(plan.get("name", ""))
            if limit > 0:
                count = await student_service.count(current_user["id"])
                if count >= limit:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=f"وصلت للحد الأقصى للطلاب في باقتك ({limit} طالب). قم بالترقية لإضافة المزيد."
                    )

    student = await student_service.create(
        teacher_id=current_user["id"],
        full_name=sanitize_text(student_data.full_name) or student_data.full_name,
        phone=sanitize_text(student_data.phone) if student_data.phone else None,
        parent_phone=sanitize_text(student_data.parent_phone) if student_data.parent_phone else None,
        grade_level=sanitize_text(student_data.grade_level) if student_data.grade_level else None,
        pin=sanitize_pin(student_data.pin) if student_data.pin else None,
    )

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="student_created",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student["id"],
        ip_address=get_client_ip(request),
    )

    return _serialize_student(student)


@router.get("/")
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
    result = []
    for s in students:
        s["has_pin"] = s.get("pin_hash") is not None
        result.append(_serialize_student(s))
    return result


@router.get("/count")
async def student_count(current_user: dict = Depends(get_current_teacher)):
    count = await student_service.count(current_user["id"])
    return {"count": count}


@router.get("/{student_id}")
async def get_student(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        student["has_pin"] = student.get("pin_hash") is not None
        return _serialize_student(student)
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to get student %s: %s", student_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to get student: {str(exc)}")


@router.put("/{student_id}")
async def update_student(
    student_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        body = await request.json()
        update_dict = {k: v for k, v in body.items() if v is not None and k != "id" and k != "teacher_id"}
        if "pin" in update_dict:
            update_dict["pin_hash"] = hash_password(update_dict.pop("pin"))
        updated = await student_service.update(student_id, update_dict)
        return {"ok": True, "student": _serialize_student(updated)}
    except HTTPException:
        raise
    except Exception as exc:
        logging.getLogger("darsak").error("Failed to update student %s: %s", student_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to update student: {str(exc)}")


@router.get("/{student_id}/pin")
async def check_student_pin(
    student_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    if not student.get("pin_hash"):
        return {"has_pin": False, "hint": "لم يتم تعيين رمز سري بعد"}

    return {
        "has_pin": True,
        "hint": "تم تعيين رمز سري للطالب",
    }


@router.patch("/{student_id}/pin")
async def reset_student_pin(
    student_id: str,
    pin_data: StudentPinUpdate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    student = await student_service.get_by_id(student_id)
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    await student_service.update(student_id, {"pin": sanitize_pin(pin_data.pin)})

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="pin_reset",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=student_id,
        ip_address=get_client_ip(request),
        metadata={"target_student": student.get("full_name")},
    )

    return {"message": "PIN updated successfully", "has_pin": True}


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


@router.post("/verify-teacher")
async def verify_teacher(request: TeacherVerifyRequest):
    import logging
    logger = logging.getLogger("darsak")
    try:
        teacher = await user_service.repo.select_one({"teacher_code": sanitize_teacher_code(request.teacher_code)})
        if not teacher:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid teacher code")

        return {
            "teacher_id": str(teacher["id"]),
            "teacher_code": teacher["teacher_code"],
            "teacher_name": teacher["full_name"],
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to verify teacher code %s: %s", request.teacher_code, exc)
        raise HTTPException(status_code=500, detail=f"Failed to verify teacher: {str(exc)}")


@router.post("/login")
async def student_login(credentials: StudentLogin):
    import logging
    logger = logging.getLogger("darsak")
    try:
        student = await student_service.get_by_code(sanitize_student_code(credentials.code))
        if not student or not student.get("pin_hash"):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid code or PIN")

        if not verify_password(sanitize_pin(credentials.pin), student["pin_hash"]):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid code or PIN")

        # If teacher_code provided, verify student belongs to that teacher
        if credentials.teacher_code:
            teacher = await user_service.repo.select_one({"teacher_code": credentials.teacher_code})
            if not teacher or str(student.get("teacher_id")) != str(teacher["id"]):
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Student does not belong to this teacher")

        token = create_access_token(student["id"], expires_delta=None)

        return {
            "access_token": token,
            "token_type": "bearer",
            "student_id": str(student["id"]),
            "student_code": student["code"],
            "student_name": student.get("full_name", ""),
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to login student %s: %s", credentials.code, exc)
        raise HTTPException(status_code=500, detail=f"Failed to login: {str(exc)}")


@router.post("/analyze")
async def analyze_student(
    request: Request,
    analyze_request: AIAnalysisRequest,
    current_user: dict = Depends(get_current_teacher),
):
    await enforce_ai_request_limit(current_user["id"])

    student = await student_service.get_by_id(str(analyze_request.student_id))
    if not student or student["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

    analysis = await ai_analyzer.analyze_student(
        teacher_id=current_user["id"],
        student_name=student["full_name"],
        subject=analyze_request.subject,
        grades=analyze_request.grades,
    )

    await increment_ai_usage(current_user["id"])
    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="ai_request",
        actor_id=current_user["id"],
        resource_type="student",
        resource_id=str(analyze_request.student_id),
        ip_address=get_client_ip(request),
        metadata={"subject": analyze_request.subject},
    )

    return _to_response(analysis)


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
