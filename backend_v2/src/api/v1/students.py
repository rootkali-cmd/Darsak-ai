import logging
import random
import string

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from src.api.deps import get_current_teacher, get_current_user
from src.core.exceptions import BadRequestException, NotFoundException
from src.core.security.auth import hash_password
from src.services.student_service import student_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/students")


class CreateStudentBody(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    code: str | None = None
    parent_phone: str | None = None
    group_id: str | None = None
    pin: str | None = None


class UpdateStudentBody(BaseModel):
    full_name: str | None = None
    code: str | None = None
    parent_phone: str | None = None
    group_id: str | None = None
    pin: str | None = None


def _generate_student_code() -> str:
    suffix = "".join(random.choices("0123456789abcdef", k=8))
    return f"STU-{suffix}"


def _serialize(obj: dict) -> dict:
    result = {}
    for key, value in obj.items():
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        elif isinstance(value, str) and len(value) == 36 and value.count("-") == 4:
            result[key] = str(value)
        elif isinstance(value, str):
            result[key] = value
        else:
            result[key] = value
    return result


@router.get("/")
async def list_students(
    search: str | None = Query(None),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        students = await student_service.list_by_teacher(teacher_id, search=search, limit=limit, offset=offset)
        return {"data": [_serialize(s) for s in students]}
    except Exception as e:
        logger.error(f"Error listing students: {e}", exc_info=True)
        raise BadRequestException("Failed to list students")


@router.post("/")
async def create_student(
    body: CreateStudentBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        student_code = body.code or _generate_student_code()

        data = {
            "full_name": body.full_name,
            "code": student_code,
            "teacher_id": teacher_id,
        }
        if body.parent_phone:
            data["parent_phone"] = body.parent_phone
        if body.group_id:
            data["group_id"] = body.group_id
        if body.pin:
            data["pin"] = hash_password(body.pin)

        new_student = await student_service.create(data)
        return _serialize(new_student)
    except Exception as e:
        logger.error(f"Error creating student: {e}", exc_info=True)
        raise BadRequestException("Failed to create student")


@router.get("/count")
async def count_students(
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        count = await student_service.count_by_teacher(teacher_id)
        return {"count": count}
    except Exception as e:
        logger.error(f"Error counting students: {e}", exc_info=True)
        raise BadRequestException("Failed to count students")


@router.get("/{student_id}")
async def get_student(
    student_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student:
            raise NotFoundException("Student not found")
        if str(student.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Student not found")
        return _serialize(student)
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error getting student: {e}", exc_info=True)
        raise BadRequestException("Failed to get student")


@router.put("/{student_id}")
async def update_student(
    student_id: str,
    body: UpdateStudentBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student:
            raise NotFoundException("Student not found")
        if str(student.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Student not found")

        update_data = {}
        if body.full_name is not None:
            update_data["full_name"] = body.full_name
        if body.code is not None:
            update_data["code"] = body.code
        if body.parent_phone is not None:
            update_data["parent_phone"] = body.parent_phone
        if body.group_id is not None:
            update_data["group_id"] = body.group_id
        if body.pin is not None:
            update_data["pin"] = hash_password(body.pin)

        if not update_data:
            return _serialize(student)

        updated = await student_service.update(student_id, update_data)
        return _serialize(updated)
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error updating student: {e}", exc_info=True)
        raise BadRequestException("Failed to update student")


@router.delete("/{student_id}")
async def delete_student(
    student_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student:
            raise NotFoundException("Student not found")
        if str(student.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Student not found")

        deleted = await student_service.delete(student_id)
        return {"deleted": deleted}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error deleting student: {e}", exc_info=True)
        raise BadRequestException("Failed to delete student")


@router.get("/{student_id}/attendance")
async def get_student_attendance(
    student_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student:
            raise NotFoundException("Student not found")
        if str(student.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Student not found")

        records = await student_service.get_attendance(student_id)
        return {"data": [_serialize(r) for r in records]}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error getting student attendance: {e}", exc_info=True)
        raise BadRequestException("Failed to get attendance")


@router.get("/{student_id}/grades")
async def get_student_grades(
    student_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student:
            raise NotFoundException("Student not found")
        if str(student.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Student not found")

        records = await student_service.get_grades(student_id)
        return {"data": [_serialize(r) for r in records]}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error getting student grades: {e}", exc_info=True)
        raise BadRequestException("Failed to get grades")
