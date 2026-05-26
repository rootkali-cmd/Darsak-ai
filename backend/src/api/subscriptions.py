from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File

from src.utils.dependencies import get_current_teacher, get_current_admin
from src.schemas.subscription import (
    SubscriptionPlanResponse,
    ActivateCodeRequest,
    ActivateCodeResponse,
    TeacherSubscriptionResponse,
    CheckFeatureRequest,
    CheckFeatureResponse,
)
from src.services import (
    subscription_plan_service,
    subscription_code_service,
    teacher_subscription_service,
    payment_request_service,
    notification_service,
)
from src.core.subscription_guard import get_remaining_limit, require_active_subscription

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


@router.get("/plans", response_model=list[SubscriptionPlanResponse])
async def list_plans():
    plans = await subscription_plan_service.list_active()
    return [SubscriptionPlanResponse(**p) for p in plans]


@router.post("/activate", response_model=ActivateCodeResponse)
async def activate_code(
    request: ActivateCodeRequest,
    current_user: dict = Depends(get_current_teacher),
):
    code_str = request.code.strip().upper()
    code_record = await subscription_code_service.get_by_code(code_str)
    if not code_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid subscription code.",
        )

    if code_record.get("is_used"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This code has already been used.",
        )

    expires_at_str = code_record.get("expires_at")
    if expires_at_str:
        if isinstance(expires_at_str, str):
            expires_dt = datetime.fromisoformat(expires_at_str.replace("Z", "+00:00"))
        else:
            expires_dt = expires_at_str
        if expires_dt < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This code has expired.",
            )

    plan = await subscription_plan_service.get_by_id(code_record["plan_id"])
    if not plan or not plan.get("is_active"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The plan associated with this code is no longer available.",
        )

    existing_sub = await teacher_subscription_service.get_by_teacher(current_user["id"])
    if existing_sub:
        if existing_sub.get("is_active"):
            expires = existing_sub["expires_at"]
            if isinstance(expires, str):
                expires_dt = datetime.fromisoformat(expires.replace("Z", "+00:00"))
            else:
                expires_dt = expires
            if expires_dt > datetime.now(timezone.utc):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="You already have an active subscription.",
                )

    await subscription_code_service.mark_used(code_record["id"], current_user["id"])

    plan_duration_days = 365
    expires_at = (datetime.now(timezone.utc) + timedelta(days=plan_duration_days)).isoformat()

    sub = await teacher_subscription_service.create(
        teacher_id=current_user["id"],
        plan_id=plan["id"],
        code_id=code_record["id"],
        expires_at=expires_at,
    )

    return ActivateCodeResponse(
        success=True,
        plan_name=plan["name"],
        expires_at=datetime.fromisoformat(expires_at),
        message=f"Subscription activated successfully! Plan: {plan['name']}",
    )


@router.get("/my", response_model=TeacherSubscriptionResponse)
async def my_subscription(
    current_user: dict = Depends(get_current_teacher),
):
    sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
    if not sub:
        return TeacherSubscriptionResponse(
            id="",
            plan_id="",
            plan_name="No Plan",
            activated_at=datetime.now(timezone.utc),
            expires_at=datetime.now(timezone.utc),
            is_active=False,
            auto_renew=False,
            days_remaining=0,
            is_expired=True,
        )

    plan = await subscription_plan_service.get_by_id(sub["plan_id"])
    plan_name = plan["name"] if plan else "Unknown"

    expires = sub["expires_at"]
    if isinstance(expires, str):
        expires_dt = datetime.fromisoformat(expires.replace("Z", "+00:00"))
    else:
        expires_dt = expires

    now = datetime.now(timezone.utc)
    days_remaining = max(0, (expires_dt - now).days)
    is_expired = expires_dt < now

    plan_resp = SubscriptionPlanResponse(**plan) if plan else None

    return TeacherSubscriptionResponse(
        id=sub["id"],
        plan_id=sub["plan_id"],
        plan_name=plan_name,
        plan=plan_resp,
        activated_at=sub["activated_at"],
        expires_at=expires_dt,
        is_active=sub["is_active"] and not is_expired,
        auto_renew=sub.get("auto_renew", False),
        days_remaining=days_remaining,
        is_expired=is_expired,
    )


@router.post("/check", response_model=CheckFeatureResponse)
async def check_feature(
    request: CheckFeatureRequest,
    current_user: dict = Depends(get_current_teacher),
):
    result = await get_remaining_limit(current_user["id"], request.feature)
    sub_info = await require_active_subscription(current_user["id"])
    plan_name = sub_info["plan"]["name"] if sub_info else None

    return CheckFeatureResponse(
        allowed=result["allowed"],
        current_usage=result["current_usage"],
        limit=result["limit"],
        remaining=result["remaining"],
        plan_name=plan_name,
    )


ALLOWED_SCREENSHOT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SCREENSHOT_SIZE = 5 * 1024 * 1024


@router.post("/payment-request")
async def create_payment_request(
    plan_id: str = Form(...),
    phone_number: str = Form(...),
    amount: float = Form(...),
    screenshot: UploadFile | None = File(None),
    current_user: dict = Depends(get_current_teacher),
):
    plan = await subscription_plan_service.get_by_id(plan_id)
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

    screenshot_b64 = None
    if screenshot:
        if screenshot.content_type not in ALLOWED_SCREENSHOT_TYPES:
            raise HTTPException(status_code=400, detail=f"Unsupported screenshot type: {screenshot.content_type}")
        import base64
        content = await screenshot.read()
        if len(content) > MAX_SCREENSHOT_SIZE:
            raise HTTPException(status_code=400, detail="Screenshot too large (max 5MB)")
        screenshot_b64 = f"data:image/png;base64,{base64.b64encode(content).decode()}"

    request = await payment_request_service.create(
        teacher_id=current_user["id"],
        plan_id=plan_id,
        phone_number=phone_number,
        amount=amount,
        screenshot=screenshot_b64,
    )

    # Notify admin via Telegram bot
    try:
        from src.api.webhook import notify_admin_payment_request
        await notify_admin_payment_request(request, plan)
    except Exception:
        pass

    return {"ok": True, "payment_id": request["id"]}


@router.get("/payment-requests")
async def list_payment_requests(
    current_user: dict = Depends(get_current_teacher),
):
    return await payment_request_service.get_by_teacher(current_user["id"])


@router.get("/notifications")
async def list_notifications(
    current_user: dict = Depends(get_current_teacher),
):
    return await notification_service.get_unread(current_user["id"])


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    await notification_service.mark_read(notification_id)
    return {"ok": True}


@router.get("/admin/codes", response_model=list)
async def list_all_codes(
    current_user: dict = Depends(get_current_admin),
):
    codes = await subscription_code_service.list_all(limit=200)
    return codes


@router.post("/admin/codes/generate")
async def admin_generate_code(
    plan_id: str,
    current_user: dict = Depends(get_current_admin),
    expires_in_days: int = 365,
):
    from src.core.security.crypto_utils import generate_license_key

    plan = await subscription_plan_service.get_by_id(plan_id)
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

    code = generate_license_key()
    expires_at = (datetime.now(timezone.utc) + timedelta(days=expires_in_days)).isoformat()
    record = await subscription_code_service.create(code, plan_id, expires_at)
    return record
