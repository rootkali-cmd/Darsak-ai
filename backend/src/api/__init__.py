from src.api.auth import router as auth_router
from src.api.students import router as students_router
from src.api.groups import router as groups_router
from src.api.attendance import router as attendance_router
from src.api.grades import router as grades_router
from src.api.invoices import router as invoices_router
from src.api.qr import router as qr_router
from src.api.sync import router as sync_router
from src.api.student_me import router as student_me_router
from src.api.subscriptions import router as subscriptions_router
from src.api.versions import router as versions_router
from src.api.webhook import router as webhook_router
from src.api.exams import router as exams_router
from src.api.analytics import router as analytics_router
from src.api.audit import router as audit_router
from src.api.dashboard import router as dashboard_router
from src.api.lessons import router as lessons_router
from src.api.video_analytics import router as video_analytics_router
from src.api.whatsapp_notifications import router as whatsapp_router
from src.api.quiz import router as quiz_router
from src.api.admin import router as admin_router
from src.api.subjects import router as subjects_router
from src.api.payments import router as payments_router
from src.api.reports import router as reports_router
from src.api.assistants import router as assistants_router
from src.api.teacher_contacts import router as teacher_contacts_router
from src.api.app_status import router as app_status_router
from src.api.fcm import router as fcm_router
from src.api.error_reporter import router as error_reporter_router
from src.api.ai_classroom import router as ai_classroom_router

__all__ = [
    "admin_router",
    "app_status_router",
    "audit_router",
    "dashboard_router",
    "fcm_router",
    "quiz_router",
    "subjects_router",
    "payments_router",
    "reports_router",
    "teacher_contacts_router",
    "ai_classroom_router",
]
