import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status

from src.services import (
    teacher_subscription_service,
    subscription_plan_service,
    student_service,
    grade_service,
    invoice_service,
)

logger = logging.getLogger("darsak")


async def get_teacher_subscription(teacher_id: str) -> dict | None:
    sub = await teacher_subscription_service.get_active_subscription(teacher_id)
    if not sub:
        return None
    plan = await subscription_plan_service.get_by_id(sub["plan_id"])
    if not plan:
        return None
    code_id = sub.get("code_id", "")
    is_trial = sub.get("is_trial", False) or (isinstance(code_id, str) and code_id.startswith("trial-"))
    expires_at = sub.get("expires_at")
    if expires_at and is_trial:
        try:
            expiry = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            if expiry < datetime.now(timezone.utc):
                logger.info("Trial expired for teacher %s, deactivating", teacher_id)
                await teacher_subscription_service.repo.update(
                    {"teacher_id": teacher_id}, {"is_active": False}
                )
                return None
        except (ValueError, TypeError):
            pass
    return {"subscription": sub, "plan": plan, "is_trial": is_trial, "trial_end_date": expires_at}


async def check_subscription_limit(teacher_id: str, feature: str) -> bool:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="لا يوجد اشتراك نشط — يجب تفعيل اشتراك أولاً",
        )

    plan = result["plan"]
    features = plan.get("features_json", []) or []
    if feature not in features:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"باقتك لا تشمل '{feature}' — قم بالترقية للوصول",
        )
    return True


async def get_remaining_limit(teacher_id: str, feature: str) -> dict:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        return {"allowed": False, "current_usage": 0, "limit": 0, "remaining": 0}

    plan = result["plan"]
    features = plan.get("features_json", []) or []

    if feature == "student_management":
        sub = result["subscription"]
        custom_limit = sub.get("custom_max_students", 0)
        if custom_limit and custom_limit > 0:
            limit = custom_limit
        else:
            plan_name = plan.get("name", "")
            limit = await subscription_plan_service.get_plan_student_limit(plan_name)
        current = await student_service.count(teacher_id)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "ai_analysis":
        plan_name = plan.get("name", "")
        limit = await subscription_plan_service.get_plan_ai_limit(plan_name)
        current = await subscription_plan_service.get_teacher_ai_usage_this_month(teacher_id)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_grades":
        limit = plan.get("max_grades")
        if limit is None:
            limit = 999999
        grades = await grade_service.repo.select({"teacher_id": teacher_id}, limit=10000)
        current = len(grades)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_invoices":
        limit = plan.get("max_invoices")
        if limit is None:
            limit = 999999
        invoices = await invoice_service.repo.select({"teacher_id": teacher_id}, limit=10000)
        current = len(invoices)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_assistants":
        limit = plan.get("max_assistants", 0)
        if limit <= 0:
            return {"allowed": False, "current_usage": 0, "limit": 0, "remaining": 0}
        try:
            from src.services import assistant_service
            assistants = await assistant_service.repo.select({"teacher_id": teacher_id, "is_active": True}, limit=1000)
            current = len(assistants)
        except Exception:
            current = 0
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_ai_exams":
        limit = plan.get("max_ai_exams_per_month", 5)
        try:
            from src.services import supabase_services
            current = await supabase_services.subscription_plan_service.get_teacher_ai_exam_usage_this_month(teacher_id)
        except Exception:
            current = 0
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_ai_grading":
        limit = plan.get("max_ai_grading_per_month", 100)
        try:
            from src.services import supabase_services
            current = await supabase_services.subscription_plan_service.get_teacher_ai_grading_usage_this_month(teacher_id)
        except Exception:
            current = 0
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    allowed = feature in features
    return {"allowed": allowed, "current_usage": 0, "limit": None, "remaining": None}


async def enforce_student_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "student_management")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من الطلاب ({result['current_usage']}/{result['limit']}) — قم بالترقية لإضافة المزيد",
        )
    return True


async def enforce_ai_request_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "ai_analysis")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من طلبات AI ({result['current_usage']}/{result['limit']}) — قم بالترقية",
        )
    return True


async def increment_ai_usage(teacher_id: str) -> None:
    pass  # AI usage now tracked via audit_logs


async def require_active_subscription(teacher_id: str) -> dict:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="لا يوجد اشتراك نشط — يجب تفعيل اشتراك أولاً",
        )
    return result


async def enforce_grade_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_grades")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من الدرجات ({result['current_usage']}/{result['limit']}) — قم بالترقية",
        )
    return True


async def enforce_invoice_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_invoices")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من الفواتير ({result['current_usage']}/{result['limit']}) — قم بالترقية",
        )
    return True


async def enforce_assistant_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_assistants")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من المساعدين ({result['current_usage']}/{result['limit']}) — قم بالترقية",
        )
    return True


async def enforce_ai_exam_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_ai_exams")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من توليد الاختبارات ({result['current_usage']}/{result['limit']}) هذا الشهر — قم بالترقية",
        )
    return True


async def enforce_ai_grading_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_ai_grading")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"وصلت للحد الأقصى من تصحيح AI ({result['current_usage']}/{result['limit']}) هذا الشهر — قم بالترقية",
        )
    return True
