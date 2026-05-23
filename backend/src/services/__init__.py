from src.services.supabase_services import (
    UserService,
    StudentService,
    GroupService,
    AttendanceService,
    GradeService,
    InvoiceService,
    AuditService,
    SubscriptionPlanService,
    SubscriptionCodeService,
    TeacherSubscriptionService,
)
from src.services.ai_analyzer import ai_analyzer
from src.services.sync_buffer import sync_buffer
from src.services.qr_service import qr_service
from src.services.pdf_generator import pdf_generator
from src.services.conflict_resolver import ConflictResolver
from src.services.scheduler import start_scheduler, stop_scheduler
from src.services.audit_service import log_audit

user_service = UserService()
student_service = StudentService()
group_service = GroupService()
attendance_service = AttendanceService()
grade_service = GradeService()
invoice_service = InvoiceService()
audit_service = AuditService()
subscription_plan_service = SubscriptionPlanService()
subscription_code_service = SubscriptionCodeService()
teacher_subscription_service = TeacherSubscriptionService()

__all__ = [
    "user_service",
    "student_service",
    "group_service",
    "attendance_service",
    "grade_service",
    "invoice_service",
    "audit_service",
    "subscription_plan_service",
    "subscription_code_service",
    "teacher_subscription_service",
    "ai_analyzer",
    "sync_buffer",
    "qr_service",
    "pdf_generator",
    "ConflictResolver",
    "start_scheduler",
    "stop_scheduler",
    "log_audit",
]
