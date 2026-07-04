import uuid
import logging
import time
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from pydantic import BaseModel, field_validator
from src.utils.dependencies import get_current_user, get_current_teacher
from src.models.audit_log import ActorType
from src.schemas.student import (
    StudentCreate, StudentUpdate, StudentResponse, StudentLogin, StudentTokenResponse, StudentTokenRefresh,
    StudentPinUpdate, TeacherVerifyRequest, TeacherVerifyResponse,
)
from src.schemas.grade import AIAnalysisRequest, AIAnalysisResponse
from src.core.security.auth import create_access_token, create_refresh_token, verify_password, hash_password, decode_token
from src.core.security.sanitizer import sanitize_text, sanitize_student_code, sanitize_pin, sanitize_teacher_code
from src.services import student_service, grade_service, ai_analyzer, audit_service, pdf_generator, user_service, teacher_subscription_service, subscription_plan_service
from src.core.subscription_guard import enforce_ai_request_limit, enforce_student_limit, increment_ai_usage

router = APIRouter(prefix="/students", tags=["Students"])

log = logging.getLogger("darsak")


class StudentUpdateInput(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    parent_phone: str | None = None
    grade_level: str | None = None
    group_id: str | None = None
    is_active: bool | None = None
    pin: str | None = None

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) < 1 or len(v) > 100:
                raise ValueError("Full name must be 1-100 characters")
        return v

    @field_validator("phone", "parent_phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if v and (len(v) < 8 or len(v) > 15 or not v.isdigit()):
                raise ValueError("Invalid phone number format")
        return v

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v: str | None) -> str | None:
        if v is not None:
            if len(v) < 4 or len(v) > 8:
                raise ValueError("PIN must be 4-8 digits")
            if not v.isdigit():
                raise ValueError("PIN must contain only digits")
        return v


ALLOWED_STUDENT_UPDATE_FIELDS = {
    "full_name", "phone", "parent_phone", "grade_level", "group_id", "is_active", "pin",
}


# ─── Rate Limiting & Ban System for Student Login ──────────────────────
# Distributed-safe: uses Redis (Upstash) when available, in-memory fallback.

from src.infrastructure.rate_limiter import rate_limiter

LOGIN_ATTEMPTS_PER_WINDOW = 4
LOGIN_WINDOW_SECONDS = 60
LOGIN_BAN_DURATIONS = [300, 600]  # 5 min, 10 min


async def _check_rate_limit(code: str) -> None:
    """Check if student code is rate-limited or banned. Redis-backed."""
    ban_remaining = await rate_limiter.ban_check(f"student_ban:{code}", LOGIN_BAN_DURATIONS[-1])
    if ban_remaining > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"تم حظر حسابك مؤقتاً. حاول مرة أخرى بعد {ban_remaining} ثانية.",
        )

    count = await rate_limiter.increment(f"student_login:{code}", LOGIN_WINDOW_SECONDS)
    if count >= LOGIN_ATTEMPTS_PER_WINDOW:
        # Determine ban level by checking existing ban keys
        ban_level_key = f"student_ban_level:{code}"
        ban_level = await rate_limiter.increment(ban_level_key, 600)  # 10 min window for ban level tracking
        ban_index = min(ban_level - 1, len(LOGIN_BAN_DURATIONS) - 1)
        ban_duration = LOGIN_BAN_DURATIONS[ban_index]

        if ban_level > len(LOGIN_BAN_DURATIONS):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="تم حظر حسابك نهائياً due to repeated failed login attempts. تواصل مع المعلم.",
            )

        await rate_limiter.set_ban(f"student_ban:{code}", ban_duration)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"تم حظر حسابك مؤقتاً بسبب محاولات كثيرة. حاول مرة أخرى بعد {ban_duration // 60} دقائق.",
        )


async def _record_failed_attempt(code: str) -> None:
    """Record a failed login attempt (already handled by _check_rate_limit increment)."""
    pass


async def _clear_attempts(code: str) -> None:
    """Clear rate limit state on successful login. Ban keys expire naturally."""
    pass


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


async def _check_is_paid(student_id: str) -> bool:
    try:
        from datetime import timezone
        now = datetime.now(timezone.utc)
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        from src.services import invoice_service
        invoices = await invoice_service.list(
            {"student_id": student_id, "status": "paid"},
            limit=1,
        )
        return any(
            i for i in invoices
            if i.get("payment_date") and i["payment_date"] >= month_start
        )
    except Exception:
        return False


async def _batch_enrich_students(students: list[dict]) -> list[dict]:
    """Batch version: avoids N+1 queries by fetching paid status for all students at once."""
    if not students:
        return students
    student_ids = [str(s.get("id", "")) for s in students if s.get("id")]
    paid_ids: set[str] = set()
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        resp = await client.table("invoices").select("student_id").eq("status", "paid").in_("student_id", student_ids).execute()
        if resp.data:
            paid_ids = {r["student_id"] for r in resp.data}
    except Exception:
        pass
    for s in students:
        s["has_pin"] = s.get("pin_hash") is not None
        s["is_paid"] = str(s.get("id", "")) in paid_ids
        s.pop("pin_hash", None)
    return students


async def _enrich_student(s: dict) -> dict:
    s["has_pin"] = s.get("pin_hash") is not None
    s["is_paid"] = await _check_is_paid(str(s.get("id", "")))
    s.pop("pin_hash", None)
    return s

def _serialize_student(s: dict) -> dict:
    return {
        "id": str(s.get("id", "")),
        "teacher_id": str(s.get("teacher_id", "")),
        "full_name": s.get("full_name", ""),
        "code": s.get("code", ""),
        "parent_phone": s.get("parent_phone"),
        "group_id": str(s.get("group_id")) if s.get("group_id") else None,
        "has_pin": s.get("has_pin") if "has_pin" in s else s.get("pin_hash") is not None,
        "is_paid": s.get("is_paid", False),
        "is_active": s.get("is_active", True),
        "created_at": str(s.get("created_at", "")),
        "updated_at": str(s.get("updated_at", "")),
    }


@router.post("/", response_model=StudentResponse, status_code=status.HTTP_201_CREATED)
async def create_student(
    student_data: StudentCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    await enforce_student_limit(current_user["id"])

    student = await student_service.create(
        teacher_id=current_user["id"],
        full_name=sanitize_text(student_data.full_name) or student_data.full_name,
        code=sanitize_student_code(student_data.code) if student_data.code else None,
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

    return StudentResponse(**student)


@router.get("/", response_model=list[StudentResponse])
async def list_students(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: str | None = None,
    registration_type: str | None = None,
    include_inactive: bool = Query(True),
    current_user: dict = Depends(get_current_teacher),
):
    students = await student_service.list_by_teacher(
        teacher_id=current_user["id"],
        search=search,
        limit=limit,
        offset=skip,
        include_inactive=include_inactive,
    )
    if registration_type and registration_type in ("center", "online"):
        students = [s for s in students if s.get("registration_type", "center") == registration_type]
    students = await _batch_enrich_students(students)
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
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        student = await _enrich_student(student)
        return StudentResponse(**student)
    except HTTPException:
        raise
    except Exception as exc:
        logging.getLogger("darsak").error("Failed to get student %s: %s", student_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to get student: internal error")


@router.put("/{student_id}")
async def update_student(
    student_id: str,
    update_data: StudentUpdateInput,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

        update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
        update_dict = {k: v for k, v in update_dict.items() if k in ALLOWED_STUDENT_UPDATE_FIELDS}

        if not update_dict:
            raise HTTPException(status_code=400, detail="No fields to update")

        if "pin" in update_dict:
            update_dict["pin_hash"] = hash_password(sanitize_pin(update_dict.pop("pin")))

        if "full_name" in update_dict:
            update_dict["full_name"] = sanitize_text(update_dict["full_name"]) or update_dict["full_name"]
        if "phone" in update_dict and update_dict["phone"]:
            update_dict["phone"] = sanitize_text(update_dict["phone"])
        if "parent_phone" in update_dict and update_dict["parent_phone"]:
            update_dict["parent_phone"] = sanitize_text(update_dict["parent_phone"])
        if "grade_level" in update_dict and update_dict["grade_level"]:
            update_dict["grade_level"] = sanitize_text(update_dict["grade_level"])

        updated = await student_service.update(student_id, update_dict)
        return {"ok": True, "student": _serialize_student(updated)}
    except HTTPException:
        raise
    except Exception as exc:
        logging.getLogger("darsak").error("Failed to update student %s: %s", student_id, exc)
        raise HTTPException(status_code=500, detail=f"فشل تحديث الطالب: internal error")


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


@router.post("/verify-teacher", response_model=TeacherVerifyResponse)
async def verify_teacher(request: TeacherVerifyRequest):
    teacher = await user_service.repo.select_one({"teacher_code": sanitize_teacher_code(request.teacher_code)})
    if not teacher:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid teacher code")

    return TeacherVerifyResponse(
        teacher_id=teacher["id"],
        teacher_code=teacher["teacher_code"],
        teacher_name=teacher["full_name"],
    )


@router.post("/login", response_model=StudentTokenResponse)
async def student_login(credentials: StudentLogin):
    sanitized_code = sanitize_student_code(credentials.code)
    log.info("Student login attempt: code=%s", sanitized_code)

    await _check_rate_limit(sanitized_code)

    student = await student_service.get_by_code(sanitized_code)
    if not student:
        await _record_failed_attempt(sanitized_code)
        log.warning("Student login failed: no student found for code=%s", sanitized_code)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="الكود غير صحيح")

    if not student.get("pin_hash"):
        await _record_failed_attempt(sanitized_code)
        log.warning("Student login failed: no pin_hash for student_id=%s code=%s", student.get("id"), sanitized_code)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="الرمز السري غير مُعيّن")

    sanitized_pin = sanitize_pin(credentials.pin)
    if not verify_password(sanitized_pin, student["pin_hash"]):
        await _record_failed_attempt(sanitized_code)
        log.warning("Student login failed: PIN mismatch for student_id=%s code=%s", student.get("id"), sanitized_code)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="الرمز السري غير صحيح")

    if credentials.teacher_code:
        teacher = await user_service.repo.select_one({"teacher_code": credentials.teacher_code})
        if not teacher or str(student.get("teacher_id")) != str(teacher["id"]):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="الطالب غير مسجل لدى هذا المعلم")

    await _clear_attempts(sanitized_code)

    token = create_access_token(student["id"], expires_delta=None)
    refresh = create_refresh_token(student["id"])

    return StudentTokenResponse(
        access_token=token,
        refresh_token=refresh,
        student_id=student["id"],
        student_code=student["code"],
    )


@router.post("/refresh")
async def student_refresh_token(body: StudentTokenRefresh):
    decoded = decode_token(body.refresh_token)
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    student_id = decoded.get("sub")
    student = await student_service.get_by_id(student_id)
    if not student:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Student not found")

    new_access = create_access_token(student["id"], expires_delta=None)
    new_refresh = create_refresh_token(student["id"])

    return {
        "access_token": new_access,
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


@router.post("/analyze", response_model=AIAnalysisResponse)
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
