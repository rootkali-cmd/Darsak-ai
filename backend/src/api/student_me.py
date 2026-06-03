from datetime import date, datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from pydantic import BaseModel, Field

from src.utils.dependencies import get_current_student
from src.schemas.student import StudentResponse
from src.schemas.grade import GradeResponse
from src.schemas.attendance import AttendanceResponse
from src.schemas.invoice import InvoiceResponse
from src.core.security.auth import verify_password
from src.core.security.sanitizer import sanitize_pin
from src.schemas.student import PIN_PATTERN
from src.services import grade_service, attendance_service, invoice_service, student_service, audit_service

router = APIRouter(prefix="/students/me", tags=["Student - Self Service"])


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


class StudentPinUpdate(BaseModel):
    old_pin: str = Field(..., min_length=6, max_length=8, pattern=PIN_PATTERN)
    new_pin: str = Field(..., min_length=6, max_length=8, pattern=PIN_PATTERN)


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("")
async def get_my_profile(
    current_student: dict = Depends(get_current_student),
):
    return {
        "id": str(current_student.get("id", "")),
        "teacher_id": str(current_student.get("teacher_id", "")),
        "full_name": current_student.get("full_name", ""),
        "code": current_student.get("code", ""),
        "parent_phone": current_student.get("parent_phone"),
        "group_id": str(current_student.get("group_id")) if current_student.get("group_id") else None,
        "has_pin": current_student.get("pin_hash") is not None,
        "is_active": current_student.get("is_active", True),
        "created_at": str(current_student.get("created_at", "")),
        "updated_at": str(current_student.get("updated_at", "")),
    }


@router.get("/grades")
async def get_my_grades(
    subject: str | None = None,
    limit: int = Query(100, ge=1, le=200),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": current_student["id"]}
    if subject:
        filters["subject"] = subject
    grades = await grade_service.list(filters, limit=limit)
    return [_to_response(g) for g in grades]


@router.get("/attendance")
async def get_my_attendance(
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = Query(200, ge=1, le=500),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": current_student["id"]}
    records = await attendance_service.list(filters, limit=limit)
    if from_date:
        records = [r for r in records if r["date"] >= from_date]
    if to_date:
        records = [r for r in records if r["date"] <= to_date]
    return [_to_response(r) for r in records]


@router.get("/invoices")
async def get_my_invoices(
    paid: bool | None = None,
    limit: int = Query(100, ge=1, le=200),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": current_student["id"]}
    invoices = await invoice_service.list(filters, limit=limit)
    if paid is not None:
        invoices = [i for i in invoices if i.get("paid") == paid]
    return [_to_response(i) for i in invoices]


@router.patch("/pin")
async def change_my_pin(
    pin_data: StudentPinUpdate,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    if not current_student.get("pin_hash"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="PIN not set")
    if not verify_password(sanitize_pin(pin_data.old_pin), current_student["pin_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Old PIN is incorrect")

    await student_service.update(current_student["id"], {"pin": sanitize_pin(pin_data.new_pin)})

    await audit_service.log(
        actor_type="student",
        action="pin_changed",
        actor_id=current_student["id"],
        resource_type="student",
        resource_id=current_student["id"],
        ip_address=get_client_ip(request),
    )

    return {"message": "PIN updated successfully"}
