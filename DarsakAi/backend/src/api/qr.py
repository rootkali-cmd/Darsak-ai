from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status, Request
from src.utils.dependencies import get_current_teacher, get_current_student
from src.services import qr_service, user_service, audit_service, attendance_service, student_service

router = APIRouter(prefix="/qr", tags=["QR Codes"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("/generate/{teacher_id}")
async def generate_qr(
    teacher_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    if current_user["id"] != teacher_id and current_user.get("role") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    teacher_code = current_user.get("teacher_code")
    if not teacher_code:
        import uuid
        teacher_code = f"TCH-{uuid.uuid4().hex[:8].upper()}"
        await user_service.update(current_user["id"], {"teacher_code": teacher_code})
        current_user["teacher_code"] = teacher_code

    qr_base64 = qr_service.generate_teacher_qr(current_user["id"], teacher_code)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="qr_generated",
        actor_id=current_user["id"],
        resource_type="qr",
        ip_address=get_client_ip(request),
    )

    return {
        "teacher_id": current_user["id"],
        "teacher_code": current_user["teacher_code"],
        "qr_base64": qr_base64,
    }


@router.post("/verify")
async def verify_qr(
    payload: dict,
    current_user: dict = Depends(get_current_teacher),
):
    teacher_id = payload.get("teacher_id")
    teacher_code = payload.get("teacher_code")

    if not teacher_id or not teacher_code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid QR payload")

    teacher = await user_service.get_by_id(teacher_id)
    if not teacher or teacher.get("teacher_code") != teacher_code:
        return {"valid": False, "message": "Invalid QR code"}

    return {
        "valid": True,
        "teacher_name": teacher["full_name"],
        "teacher_code": teacher["teacher_code"],
    }


@router.post("/student-checkin")
async def student_checkin(
    payload: dict,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    teacher_id = payload.get("teacher_id")
    group_id = payload.get("group_id")
    lecture_date = payload.get("lecture_date") or date.today().isoformat()

    if not teacher_id or not group_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing required fields: teacher_id, group_id",
        )

    # Verify student belongs to this group
    if current_student.get("group_id") != group_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student is not enrolled in this group",
        )

    # Idempotency check: prevent duplicate check-in
    existing = await attendance_service.get_by_student_and_date(
        current_student["id"], lecture_date
    )
    if existing:
        return {
            "message": "Already checked in today",
            "status": "already_present",
            "attendance": existing,
        }

    attendance = await attendance_service.create(
        student_id=current_student["id"],
        group_id=group_id,
        teacher_id=teacher_id,
        status="present",
        date=lecture_date,
    )

    await audit_service.log(
        actor_type="student",
        action="checkin",
        actor_id=current_student["id"],
        resource_type="attendance",
        resource_id=attendance["id"],
        ip_address=request.client.host if request.client else "unknown",
        metadata={"group_id": group_id, "lecture_date": lecture_date},
    )

    return {
        "message": "Check-in successful",
        "status": "checked_in",
        "attendance": attendance,
    }
