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

__all__ = [
    "auth_router",
    "students_router",
    "groups_router",
    "attendance_router",
    "grades_router",
    "invoices_router",
    "qr_router",
    "sync_router",
    "student_me_router",
    "subscriptions_router",
    "versions_router",
    "webhook_router",
    "exams_router",
    "analytics_router",
]
