import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from src.api.deps import get_current_teacher
from src.core.exceptions import NotFoundException, BadRequestException
from src.services.subscription_service import subscription_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/subscriptions")


class ActivateCodeRequest(BaseModel):
    code: str


class PaymentRequestRequest(BaseModel):
    plan_id: str
    phone_number: str
    amount: float


@router.get("/plans")
async def list_plans(teacher: dict = Depends(get_current_teacher)):
    try:
        plans = await subscription_service.list_active_plans()
        return plans
    except Exception as e:
        logger.error(f"Error listing plans: {e}", exc_info=True)
        raise BadRequestException("Failed to list plans")


@router.get("/my")
async def my_subscription(teacher: dict = Depends(get_current_teacher)):
    try:
        sub = await subscription_service.get_teacher_subscription(teacher["id"])
        if sub is None:
            return {"subscription": None, "plan": None}

        plan = await subscription_service.get_plan_by_id(sub.get("plan_id"))
        return {"subscription": sub, "plan": plan}
    except Exception as e:
        logger.error(f"Error getting subscription: {e}", exc_info=True)
        raise BadRequestException("Failed to get subscription")


@router.post("/activate")
async def activate_code(
    body: ActivateCodeRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        code_record = await subscription_service.get_code_by_value(body.code)
        if code_record is None:
            raise BadRequestException("Invalid subscription code")
        if code_record.get("is_used"):
            raise BadRequestException("Code already used")

        plan_id = code_record.get("plan_id")
        if not plan_id:
            raise BadRequestException("Code has no associated plan")

        plan = await subscription_service.get_plan_by_id(plan_id)
        if plan is None:
            raise BadRequestException("Plan not found")

        duration_days = plan.get("duration_days", 30)
        now = datetime.now(timezone.utc)
        end_date = now + timedelta(days=duration_days)

        sub_data = {
            "teacher_id": teacher["id"],
            "plan_id": plan_id,
            "code_id": code_record["id"],
            "is_active": True,
            "start_date": now.isoformat(),
            "end_date": end_date.isoformat(),
        }

        sub = await subscription_service.create_subscription(sub_data)
        await subscription_service.activate_code(code_record["id"])

        return {"subscription": sub, "plan": plan}
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error activating code: {e}", exc_info=True)
        raise BadRequestException("Failed to activate subscription")


@router.post("/payment-request")
async def payment_request(
    body: PaymentRequestRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        plan = await subscription_service.get_plan_by_id(body.plan_id)
        if plan is None:
            raise BadRequestException("Plan not found")

        data = {
            "teacher_id": teacher["id"],
            "plan_id": body.plan_id,
            "phone_number": body.phone_number,
            "amount": body.amount,
            "status": "pending",
        }

        result = await subscription_service.create_payment_request(data)
        return result
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error creating payment request: {e}", exc_info=True)
        raise BadRequestException("Failed to create payment request")
