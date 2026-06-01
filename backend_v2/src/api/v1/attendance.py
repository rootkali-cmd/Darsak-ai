import logging
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from src.api.deps import get_current_teacher, get_current_user
from src.core.exceptions import BadRequestException, NotFoundException
from src.services.attendance_service import attendance_service
from src.services.student_service import student_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/attendance")


class MarkAttendanceBody(BaseModel):
    student_id: str
    date: str
    time: str | None = None
    status: str | None = "present"


class BarcodeBody(BaseModel):
    barcode: str


class BulkRecord(BaseModel):
    student_id: str
    date: str
    status: str


class BulkAttendanceBody(BaseModel):
    records: list[BulkRecord]


def _serialize(obj: dict) -> dict:
    result = {}
    for key, value in obj.items():
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        elif isinstance(value, str):
            result[key] = value
        else:
            result[key] = value
    return result


@router.get("/")
async def list_attendance(
    date: str | None = Query(None),
    student_id: str | None = Query(None),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        records = await attendance_service.list_by_teacher(teacher_id, date=date, student_id=student_id)
        return {"data": [_serialize(r) for r in records]}
    except Exception as e:
        logger.error(f"Error listing attendance: {e}", exc_info=True)
        raise BadRequestException("Failed to list attendance")


@router.post("/")
async def mark_attendance(
    body: MarkAttendanceBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        data = {
            "student_id": body.student_id,
            "date": body.date,
            "teacher_id": teacher_id,
            "status": body.status or "present",
        }
        if body.time:
            data["time"] = body.time

        record = await attendance_service.create(data)
        return _serialize(record)
    except Exception as e:
        logger.error(f"Error marking attendance: {e}", exc_info=True)
        raise BadRequestException("Failed to mark attendance")


@router.post("/barcode")
async def mark_attendance_barcode(
    body: BarcodeBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        student = await attendance_service.get_student_by_code(body.barcode)
        if not student:
            raise NotFoundException("Student not found with this code")
        if str(student.get("teacher_id")) != teacher_id:
            raise NotFoundException("Student not found with this code")

        today = date_type.today().isoformat()
        data = {
            "student_id": str(student["id"]),
            "date": today,
            "teacher_id": teacher_id,
            "status": "present",
        }
        record = await attendance_service.create(data)
        return _serialize(record)
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error marking attendance by barcode: {e}", exc_info=True)
        raise BadRequestException("Failed to mark attendance")


@router.post("/bulk")
async def mark_attendance_bulk(
    body: BulkAttendanceBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        records = []
        for rec in body.records:
            record_data = rec.model_dump()
            record_data["teacher_id"] = teacher_id
            records.append(record_data)
        results = await attendance_service.bulk_create(records)
        return {"data": [_serialize(r) for r in results]}
    except Exception as e:
        logger.error(f"Error marking bulk attendance: {e}", exc_info=True)
        raise BadRequestException("Failed to mark bulk attendance")


@router.get("/stats")
async def attendance_stats(
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        stats = await attendance_service.get_today_stats(teacher_id)
        return stats
    except Exception as e:
        logger.error(f"Error getting attendance stats: {e}", exc_info=True)
        raise BadRequestException("Failed to get attendance stats")
