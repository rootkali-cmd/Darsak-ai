import logging
from fastapi import APIRouter, Depends
from src.utils.dependencies import get_current_teacher
from src.services import student_service, group_service, attendance_service, invoice_service

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats")
async def dashboard_stats(current_user: dict = Depends(get_current_teacher)):
    teacher_id = current_user["id"]
    try:
        students_count = await student_service.count(teacher_id)
    except Exception as e:
        logger.warning("Failed to count students for %s: %s", teacher_id, e)
        students_count = 0

    try:
        groups = await group_service.list_by_teacher(teacher_id)
        groups_count = len(groups) if groups else 0
    except Exception as e:
        logger.warning("Failed to load groups for %s: %s", teacher_id, e)
        groups_count = 0

    try:
        attendance_stats = await attendance_service.get_stats(teacher_id)
        today_attendance = attendance_stats.get("today_count", 0) if attendance_stats else 0
    except Exception as e:
        logger.warning("Failed to get today attendance for %s: %s", teacher_id, e)
        today_attendance = 0

    try:
        invoice_stats = await invoice_service.get_stats(teacher_id)
        total_revenue = invoice_stats.get("total_paid", 0) if invoice_stats else 0
    except Exception as e:
        logger.warning("Failed to get invoice stats for %s: %s", teacher_id, e)
        total_revenue = 0

    return {
        "total_students": students_count,
        "total_groups": groups_count,
        "today_attendance": today_attendance,
        "total_revenue": total_revenue,
    }
