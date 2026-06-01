import logging

from fastapi import APIRouter, Depends

from src.api.deps import get_current_teacher
from src.core.exceptions import BadRequestException
from src.repositories.supabase import SupabaseRepository

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dashboard")


@router.get("/stats")
async def get_stats(teacher: dict = Depends(get_current_teacher)):
    try:
        teacher_id = teacher["id"]
        filters = {"teacher_id": teacher_id}

        students_repo = SupabaseRepository("students")
        groups_repo = SupabaseRepository("groups")
        attendance_repo = SupabaseRepository("attendance")
        invoices_repo = SupabaseRepository("invoices")
        exams_repo = SupabaseRepository("exams")

        students_count = await students_repo.count(filters)
        groups_count = await groups_repo.count(filters)
        attendance_count = await attendance_repo.count(filters)
        pending_invoices = await invoices_repo.count({**filters, "status": "pending"})
        active_exams = await exams_repo.count({**filters, "is_active": True})

        return {
            "students": students_count,
            "groups": groups_count,
            "today_attendance": attendance_count,
            "pending_invoices": pending_invoices,
            "active_exams": active_exams,
        }
    except Exception as e:
        logger.error(f"Error getting dashboard stats: {e}", exc_info=True)
        raise BadRequestException("Failed to get dashboard stats")
