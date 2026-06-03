import re
from datetime import date, datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from pydantic import BaseModel
from src.utils.dependencies import get_current_teacher
from src.schemas.attendance import AttendanceCreate, AttendanceBulkCreate, AttendanceResponse
from src.services import attendance_service, audit_service, student_service
from src.core.security.supabase_repo import get_supabase

router = APIRouter(prefix="/attendance", tags=["Attendance"])


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


@router.post("/", status_code=status.HTTP_201_CREATED)
async def mark_attendance(
    attendance_data: AttendanceCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    attendance_date = attendance_data.date or date.today()

    existing = await attendance_service.get_by_student_and_date(
        str(attendance_data.student_id),
        attendance_date.isoformat(),
    )
    if existing:
        updated = await attendance_service.update(
            existing["id"],
            {
                "status": attendance_data.status.value if hasattr(attendance_data.status, 'value') else attendance_data.status,
                "notes": attendance_data.notes,
            },
        )
        return _to_response(updated)

    attendance = await attendance_service.create(
        student_id=str(attendance_data.student_id),
        group_id=str(attendance_data.group_id) if attendance_data.group_id else None,
        teacher_id=current_user["id"],
        status=attendance_data.status.value if hasattr(attendance_data.status, 'value') else attendance_data.status,
        date=attendance_date.isoformat(),
        notes=attendance_data.notes,
    )

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="attendance_marked",
        actor_id=current_user["id"],
        resource_type="attendance",
        resource_id=attendance["id"],
        ip_address=get_client_ip(request),
    )

    return _to_response(attendance)


@router.post("/bulk", status_code=status.HTTP_201_CREATED)
async def mark_bulk_attendance(
    bulk_data: AttendanceBulkCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    attendance_date = bulk_data.date or date.today()
    results = []

    for record in bulk_data.records:
        student_id = record.get("student_id")
        status_val = record.get("status", "present")
        notes = record.get("notes")

        existing = await attendance_service.get_by_student_and_date(student_id, attendance_date.isoformat())

        if existing:
            updated = await attendance_service.update(
                existing["id"],
                {"status": status_val, "notes": notes},
            )
            results.append(_to_response(updated))
        else:
            attendance = await attendance_service.create(
                student_id=student_id,
                group_id=str(bulk_data.group_id) if bulk_data.group_id else None,
                teacher_id=current_user["id"],
                status=status_val,
                date=attendance_date.isoformat(),
                notes=notes,
            )
            results.append(_to_response(attendance))

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="attendance_bulk",
        actor_id=current_user["id"],
        resource_type="attendance",
        ip_address=get_client_ip(request),
        metadata={"count": len(results)},
    )

    return results


@router.get("/")
async def get_attendance(
    student_id: str | None = None,
    group_id: str | None = None,
    date: date | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    current_user: dict = Depends(get_current_teacher),
):
    filters = {"teacher_id": current_user["id"]}
    if student_id:
        filters["student_id"] = student_id
    if group_id:
        filters["group_id"] = group_id

    records = await attendance_service.list(filters, limit=200)

    if date:
        date_str = date.isoformat()
        records = [r for r in records if r["date"] == date_str]
    if from_date:
        records = [r for r in records if r["date"] >= from_date.isoformat()]
    if to_date:
        records = [r for r in records if r["date"] <= to_date.isoformat()]

    # Enrich with student names via batch lookup
    if records:
        student_ids = list({str(r["student_id"]) for r in records})
        client = await get_supabase()
        students_resp = await client.table("students").select("id, full_name").in_("id", student_ids).execute()
        student_map = {s["id"]: s.get("full_name", "") for s in (students_resp.data or [])}
        for r in records:
            r["student_name"] = student_map.get(str(r["student_id"]), "")

    return [_to_response(r) for r in records]


@router.get("/stats")
async def attendance_stats(
    group_id: str | None = None,
    date: date | None = None,
    current_user: dict = Depends(get_current_teacher),
):
    target_date = date.isoformat() if date else None
    stats = await attendance_service.get_stats(current_user["id"], target_date)
    return stats


@router.put("/{attendance_id}")
async def update_attendance(
    attendance_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        existing = await attendance_service.get_by_id(attendance_id)
        if not existing or existing.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

        body = await request.json()
        update_dict = {k: v for k, v in body.items() if v is not None and k not in ("id", "teacher_id")}
        updated = await attendance_service.update(attendance_id, update_dict)

        return {
            "ok": True,
            "data": {
                k: str(v) if hasattr(v, "hex") else (v.isoformat() if hasattr(v, "isoformat") else v)
                for k, v in updated.items()
            }
        }
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to update attendance %s: %s", attendance_id, exc)
        raise HTTPException(status_code=500, detail="Update failed")


class BarcodeScan(BaseModel):
    barcode: str


@router.post("/barcode")
async def mark_attendance_by_barcode(
    scan: BarcodeScan,
    current_user: dict = Depends(get_current_teacher),
):
    raw = scan.barcode.strip()

    student = None

    m = re.match(r"^darsak://student/(\w+)$", raw)
    if m:
        student = await student_service.get_by_id(m.group(1))
    elif raw.isdigit():
        student = await student_service.get_by_id(raw)
    else:
        student = await student_service.get_by_code(raw)

    if not student or student.get("teacher_id") != current_user["id"]:
        raise HTTPException(status_code=404, detail="الطالب غير موجود")

    student_id = student["id"]
    today = date.today()
    existing = await attendance_service.get_by_student_and_date(student_id, today.isoformat())

    if existing:
        updated = await attendance_service.update(
            existing["id"],
            {"status": "present"},
        )
        result = updated
    else:
        result = await attendance_service.create(
            student_id=student_id,
            teacher_id=current_user["id"],
            status="present",
            date=today.isoformat(),
        )

    return {
        **result,
        "student": {
            "id": student["id"],
            "full_name": student.get("full_name", ""),
            "name": student.get("full_name", ""),
        },
    }
