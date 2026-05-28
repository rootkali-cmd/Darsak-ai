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
    is_trial = isinstance(code_id, str) and code_id.startswith("trial-")
    return {"subscription": sub, "plan": plan, "is_trial": is_trial, "trial_end_date": sub.get("expires_at")}


async def check_subscription_limit(teacher_id: str, feature: str) -> bool:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="No active subscription. Please activate a subscription code.",
        )

    plan = result["plan"]
    features = plan.get("features_json", []) or []
    if feature not in features:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Your plan does not include '{feature}'. Upgrade to access this feature.",
        )
    return True


async def get_remaining_limit(teacher_id: str, feature: str) -> dict:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        return {"allowed": False, "current_usage": 0, "limit": 0, "remaining": 0}

    plan = result["plan"]
    features = plan.get("features_json", []) or []

    if feature == "student_management":
        limit = plan.get("max_students", 50)
        if limit == -1:
            return {"allowed": True, "current_usage": 0, "limit": None, "remaining": None}
        current = await student_service.count(teacher_id)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "ai_analysis":
        limit = plan.get("max_ai_requests", 100)
        if limit == -1:
            return {"allowed": True, "current_usage": 0, "limit": None, "remaining": None}
        current = 0
        remaining = limit - current
        return {"allowed": True, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_grades":
        limit = plan.get("max_grades")
        if limit is None or limit == -1:
            return {"allowed": True, "current_usage": 0, "limit": None, "remaining": None}
        grades = await grade_service.repo.select({"teacher_id": teacher_id}, limit=10000)
        current = len(grades)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    if feature == "max_invoices":
        limit = plan.get("max_invoices")
        if limit is None or limit == -1:
            return {"allowed": True, "current_usage": 0, "limit": None, "remaining": None}
        invoices = await invoice_service.repo.select({"teacher_id": teacher_id}, limit=10000)
        current = len(invoices)
        remaining = limit - current
        return {"allowed": remaining > 0, "current_usage": current, "limit": limit, "remaining": remaining}

    allowed = feature in features
    return {"allowed": allowed, "current_usage": 0, "limit": None, "remaining": None}


async def enforce_student_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "student_management")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Student limit reached ({result['current_usage']}/{result['limit']}). Upgrade your plan to add more students.",
        )
    return True


async def enforce_ai_request_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "ai_analysis")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"AI request limit reached ({result['current_usage']}/{result['limit']}). Upgrade your plan.",
        )
    return True


async def require_active_subscription(teacher_id: str) -> dict:
    result = await get_teacher_subscription(teacher_id)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="No active subscription. Please activate a subscription code.",
        )
    return result


async def enforce_grade_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_grades")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Grade limit reached ({result['current_usage']}/{result['limit']}). Upgrade your plan.",
        )
    return True


async def enforce_invoice_limit(teacher_id: str) -> bool:
    result = await get_remaining_limit(teacher_id, "max_invoices")
    if not result["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Invoice limit reached ({result['current_usage']}/{result['limit']}). Upgrade your plan.",
        )
    return True
