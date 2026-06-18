from datetime import datetime, timezone, timedelta
import logging

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

logger = logging.getLogger("darsak")

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])


def _get_limit(name: str, basic: int, pro: int, unlimited: int):
    if "premium" in name or "متكاملة" in name: return -1
    if "pro" in name or "احترافية" in name: return pro
    return basic

def _get_limit_gb(name: str, basic: int, pro: int, unlimited: int):
    if "premium" in name or "متكاملة" in name: return -1
    if "pro" in name or "احترافية" in name: return pro
    return basic


def _get_features(plan: dict) -> list:
    features = plan.get("features_json", [])
    if isinstance(features, str):
        import json
        features = json.loads(features)
    if features:
        return features
    name = (plan.get("name") or "").lower()
    if "pro" in name:
        return ["6 اختبارات شهرياً", "حضور وغياب", "درجات الطلاب", "تقارير AI", "دروس مشتركة", "دعم فني"]
    if "premium" in name:
        return ["15 اختبار شهرياً", "حضور وغياب", "درجات الطلاب", "تقارير AI", "دروس مشتركة", "تحضير اختبارات بالـ AI", "دعم فني أولوية"]
    return ["2 اختبار شهرياً", "حضور وغياب", "درجات الطلاب", "دعم فني"]


def _to_plan_response(plan: dict) -> dict:
    name = (plan.get("name") or "").lower()
    max_students = plan.get("max_students") or _get_limit(name, 2, 6, 15)
    ai_requests = plan.get("max_ai_requests") or plan.get("ai_requests_per_month") or _get_limit(name, 5, 30, 100)
    storage = plan.get("storage_limit_gb") or _get_limit_gb(name, 2, 6, 10)
    # Normalize to -1 if unlimited
    if max_students == -1:
        max_students = -1
    return {
        "id": str(plan.get("id", "")),
        "name": plan.get("name", ""),
        "price_egp": plan.get("price_egp", 0),
        "max_students": max_students,
        "ai_requests_per_month": ai_requests,
        "storage_limit_gb": storage,
        "features": _get_features(plan),
        "is_active": plan.get("is_active", True),
    }


@router.get("/plans")
async def list_plans():
    try:
        plans = await subscription_plan_service.list_active()
        return [_to_plan_response(p) for p in plans]
    except Exception as exc:
        logger.error("Failed to list plans: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to list plans: {str(exc)}")


@router.post("/activate-trial")
async def activate_trial(
    current_user: dict = Depends(get_current_teacher),
):
    try:
        plans = await subscription_plan_service.list_active()
        basic_plan = None
        for p in plans:
            name = (p.get("name") or "").lower()
            if "basic" in name or "أساسي" in name:
                basic_plan = p
                break
        if not basic_plan:
            raise HTTPException(status_code=404, detail="Basic plan not found")

        # Check if teacher already used trial
        if await teacher_subscription_service.has_used_trial(current_user["id"]):
            raise HTTPException(status_code=400, detail="لقد استخدمت الفترة التجريبية من قبل")

        # Check if teacher has active subscription
        existing_sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if existing_sub:
            expires_at = existing_sub.get("expires_at")
            if expires_at:
                if isinstance(expires_at, str):
                    expires_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
                else:
                    expires_dt = expires_at
                if expires_dt.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc):
                    raise HTTPException(status_code=400, detail="لديك اشتراك نشط بالفعل")
            else:
                raise HTTPException(status_code=400, detail="لديك اشتراك نشط بالفعل")

        expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()

        await teacher_subscription_service.create(
            teacher_id=current_user["id"],
            plan_id=basic_plan["id"],
            code_id="",
            expires_at=expires_at,
            is_trial=True,
        )

        await notification_service.create(
            teacher_id=current_user["id"],
            title="تم تفعيل الفترة التجريبية",
            body="تم تفعيل الفترة التجريبية لمدة 30 يوم بنجاح!",
            type="success",
            user_type="teacher",
        )

        return {"success": True, "days_remaining": 30, "expires_at": expires_at}
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to activate trial: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to activate trial: {str(exc)}")


@router.post("/activate")
async def activate_code(
    request: ActivateCodeRequest,
    current_user: dict = Depends(get_current_teacher),
    allowed_students_limit: int | None = None,
):
    try:
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

        plan_name = (plan.get("name") or "").lower()
        if "premium" in plan_name and allowed_students_limit and allowed_students_limit > 0:
            whatsapp_max = max(0, allowed_students_limit)
            await teacher_subscription_service.update(sub["id"], {
                "allowed_students_limit": allowed_students_limit,
                "whatsapp_max_limit": whatsapp_max,
            })

        await notification_service.create(
            teacher_id=current_user["id"],
            title="تم تفعيل اشتراكك بنجاح",
            body=f"تم تفعيل اشتراكك في باقة {plan['name']} بنجاح!",
            type="success",
            user_type="teacher",
        )

        return {
            "success": True,
            "plan_name": plan["name"],
            "expires_at": expires_at,
            "message": f"Subscription activated successfully! Plan: {plan['name']}",
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to activate code: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to activate subscription: {str(exc)}")


@router.get("/my")
async def my_subscription(
    current_user: dict = Depends(get_current_teacher),
):
    try:
        sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if not sub:
            return {
                "id": "",
                "plan_id": "",
                "plan_name": "No Plan",
                "activated_at": datetime.now(timezone.utc).isoformat(),
                "expires_at": datetime.now(timezone.utc).isoformat(),
                "is_active": False,
                "auto_renew": False,
                "days_remaining": 0,
                "is_expired": True,
                "is_trial": False,
            }

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

        activated_at_val = sub.get("activated_at")
        if isinstance(activated_at_val, datetime):
            activated_at_str = activated_at_val.isoformat()
        elif isinstance(activated_at_val, str):
            activated_at_str = activated_at_val
        else:
            activated_at_str = now.isoformat()

        code_id = sub.get("code_id", "")
        is_trial = sub.get("is_trial", False) or (isinstance(code_id, str) and code_id.startswith("trial-"))

        plan_resp = _to_plan_response(plan) if plan else None

        return {
            "id": str(sub["id"]),
            "plan_id": str(sub["plan_id"]),
            "plan_name": plan_name,
            "plan": plan_resp,
            "activated_at": activated_at_str,
            "expires_at": expires_dt.isoformat() if isinstance(expires_dt, datetime) else str(expires_dt),
            "is_active": sub.get("is_active", False) and not is_expired,
            "auto_renew": sub.get("auto_renew", False),
            "days_remaining": days_remaining,
            "is_expired": is_expired,
            "is_trial": is_trial,
            "trial_end_date": expires_dt.isoformat() if is_trial and isinstance(expires_dt, datetime) else (str(expires_dt) if is_trial else None),
            "allowed_students_limit": sub.get("allowed_students_limit", -1),
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get my subscription: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get subscription: {str(exc)}")


@router.post("/check")
async def check_feature(
    request: CheckFeatureRequest,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        result = await get_remaining_limit(current_user["id"], request.feature)
        sub_info = await require_active_subscription(current_user["id"])
        plan_name = sub_info["plan"]["name"] if sub_info else None

        return {
            "allowed": result["allowed"],
            "current_usage": result["current_usage"],
            "limit": result["limit"],
            "remaining": result["remaining"],
            "plan_name": plan_name,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to check feature: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to check feature: {str(exc)}")


ALLOWED_SCREENSHOT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SCREENSHOT_SIZE = 5 * 1024 * 1024


@router.post("/payment-request")
async def create_payment_request(
    plan_id: str = Form(...),
    phone_number: str = Form(...),
    amount: float = Form(...),
    screenshot: UploadFile | None = File(None),
    allowed_students_limit: int | None = Form(None),
    current_user: dict = Depends(get_current_teacher),
):
    try:
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

        req = await payment_request_service.create(
            teacher_id=current_user["id"],
            plan_id=plan_id,
            phone_number=phone_number,
            amount=amount,
            screenshot=screenshot_b64,
        )

        plan_name = (plan.get("name") or "").lower()
        if "premium" in plan_name and allowed_students_limit and allowed_students_limit > 0:
            req["allowed_students_limit"] = allowed_students_limit

        try:
            from src.api.webhook import notify_admin_payment_request
            await notify_admin_payment_request(req, plan, user=current_user)
        except Exception:
            logger.debug("Telegram notification skipped")

        return {"ok": True, "payment_id": str(req["id"])}
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create payment request: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create payment request: {str(exc)}")


@router.get("/payment-requests")
async def list_payment_requests(
    current_user: dict = Depends(get_current_teacher),
):
    try:
        return await payment_request_service.get_by_teacher(current_user["id"])
    except Exception as exc:
        logger.error("Failed to list payment requests: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.get("/notifications")
async def list_notifications(
    current_user: dict = Depends(get_current_teacher),
):
    try:
        return await notification_service.get_unread(current_user["id"])
    except Exception as exc:
        logger.error("Failed to list notifications: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        await notification_service.mark_read(notification_id)
        return {"ok": True}
    except Exception as exc:
        logger.error("Failed to mark notification read: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


from pydantic import BaseModel, Field as PyField


class TeacherFCMTokenRequest(BaseModel):
    fcm_token: str = PyField(..., min_length=1)
    platform: str = PyField(default="android")


@router.post("/fcm-token")
async def register_teacher_fcm_token(
    req: TeacherFCMTokenRequest,
    current_user: dict = Depends(get_current_teacher),
):
    """Register or update FCM token for push notifications."""
    from src.core.security.supabase_repo import get_supabase
    from src.core.config import get_settings
    import httpx

    settings = get_settings()
    url = settings.SUPABASE_URL.rstrip("/")
    key = settings.SUPABASE_SERVICE_ROLE_KEY

    async with httpx.AsyncClient() as http:
        existing = await http.get(
            f"{url}/rest/v1/fcm_tokens",
            params={
                "select": "id",
                "user_id": f"eq.{current_user['id']}",
                "fcm_token": f"eq.{req.fcm_token}",
            },
            headers={"apikey": key, "Authorization": f"Bearer {key}"},
        )

        if existing.status_code == 200 and existing.json():
            token_id = existing.json()[0]["id"]
            await http.patch(
                f"{url}/rest/v1/fcm_tokens?id=eq.{token_id}",
                json={"is_active": True, "platform": req.platform},
                headers={"apikey": key, "Authorization": f"Bearer {key}"},
            )
        else:
            await http.post(
                f"{url}/rest/v1/fcm_tokens",
                json={
                    "user_id": current_user["id"],
                    "user_type": "teacher",
                    "fcm_token": req.fcm_token,
                    "platform": req.platform,
                },
                headers={"apikey": key, "Authorization": f"Bearer {key}"},
            )

    return {"status": "ok"}


@router.get("/admin/codes")
async def list_all_codes(
    current_user: dict = Depends(get_current_admin),
):
    try:
        codes = await subscription_code_service.list_all(limit=200)
        return codes
    except Exception as exc:
        logger.error("Failed to list admin codes: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


@router.post("/admin/codes/generate")
async def admin_generate_code(
    plan_id: str,
    current_user: dict = Depends(get_current_admin),
    expires_in_days: int = 365,
):
    try:
        from src.core.security.crypto_utils import generate_license_key

        plan = await subscription_plan_service.get_by_id(plan_id)
        if not plan:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

        code = generate_license_key()
        expires_at = (datetime.now(timezone.utc) + timedelta(days=expires_in_days)).isoformat()
        record = await subscription_code_service.create(code, plan_id, expires_at)
        return record
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to generate admin code: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: {str(exc)}")


# ─── Dynamic Pricing ─────────────────────────────────────────────────

PREMIUM_BASE_PRICE = 1100
PREMIUM_VARIABLE_PRICE = 1.5
PREMIUM_FREE_STUDENTS = 700
PREMIUM_MAX_STUDENTS = 2000


@router.get("/pricing/premium")
async def get_premium_pricing(desired_students: int = 700):
    if desired_students < 700:
        desired_students = 700
    if desired_students > PREMIUM_MAX_STUDENTS:
        desired_students = PREMIUM_MAX_STUDENTS

    extra = max(0, desired_students - PREMIUM_FREE_STUDENTS)
    price = PREMIUM_BASE_PRICE + (extra * PREMIUM_VARIABLE_PRICE)
    price = round(price, 0)

    return {
        "base_price": PREMIUM_BASE_PRICE,
        "variable_price_per_student": PREMIUM_VARIABLE_PRICE,
        "free_students": PREMIUM_FREE_STUDENTS,
        "desired_students": desired_students,
        "extra_students": extra,
        "total_price": price,
        "currency": "EGP",
        "whatsapp_reports": True,
        "ai_reports": True,
    }


# ─── WhatsApp Delivery Logs ──────────────────────────────────────────

@router.get("/whatsapp/status")
async def get_whatsapp_status(current_user: dict = Depends(get_current_teacher)):
    try:
        sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if not sub:
            return {"allowed": False, "reason": "no_subscription"}

        plan = await subscription_plan_service.get_by_id(sub["plan_id"])
        plan_name = (plan.get("name") or "").lower() if plan else ""

        allowed_limit = sub.get("allowed_students_limit") or plan.get("max_students", 0)
        sent_count = sub.get("whatsapp_messages_counter", 0)
        max_limit = sub.get("whatsapp_max_limit", 0)

        if "basic" in plan_name:
            return {"allowed": False, "reason": "upgrade_required", "plan": "Basic"}
        if "pro" in plan_name:
            return {
                "allowed": True,
                "plan": "Pro",
                "sent": sent_count,
                "limit": allowed_limit if allowed_limit else 400,
                "remaining": max(0, (allowed_limit if allowed_limit else 400) - sent_count),
            }
        return {
            "allowed": True,
            "plan": "Premium",
            "sent": sent_count,
            "limit": allowed_limit if allowed_limit and allowed_limit > 0 else -1,
            "remaining": -1 if not allowed_limit or allowed_limit <= 0 else max(0, allowed_limit - sent_count),
        }
    except Exception as exc:
        logger.error("Failed to get WhatsApp status: %s", exc)
        return {"allowed": False, "reason": "error"}


@router.get("/whatsapp/logs")
async def get_whatsapp_logs(
    filter_status: str = "all",
    current_user: dict = Depends(get_current_teacher),
):
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()

        q = client.table("whatsapp_delivery_logs").select("*").eq("teacher_id", current_user["id"])

        if filter_status in ("accepted", "rejected"):
            q = q.eq("status", filter_status)

        result = await q.order("sent_at", desc=True).limit(200).execute()
        logs = result.data or []

        return {
            "total": len(logs),
            "logs": logs,
        }
    except Exception as exc:
        logger.error("Failed to fetch WhatsApp logs: %s", exc)
        return {"total": 0, "logs": []}


@router.post("/whatsapp/log")
async def log_whatsapp_delivery(
    student_id: str | None = None,
    phone_number: str | None = None,
    status_val: str = "all",
    error_reason: str | None = None,
    message_id: str | None = None,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()

        now = datetime.now(timezone.utc)
        billing_cycle = f"{now.year}-{now.month:02d}"

        await client.table("whatsapp_delivery_logs").insert({
            "teacher_id": current_user["id"],
            "student_id": student_id,
            "phone_number": phone_number,
            "status": status_val,
            "error_reason": error_reason,
            "message_id": message_id,
            "billing_cycle": billing_cycle,
        })

        if status_val in ("all", "accepted"):
            sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
            if sub:
                current_count = sub.get("whatsapp_messages_counter", 0) or 0
                await teacher_subscription_service.update(sub["id"], {
                    "whatsapp_messages_counter": current_count + 1,
                })

        return {"ok": True}
    except Exception as exc:
        logger.error("Failed to log WhatsApp delivery: %s", exc)
        return {"ok": False}


# ═══════════════════════════════════════════════════════════════
# SIGNED SUBSCRIPTION TOKEN — Anti-tamper protection
# ═══════════════════════════════════════════════════════════════

import hmac
import hashlib
import json as json_mod
import base64
import time

from src.core.config import get_settings


def _generate_subscription_token(teacher_id: str, plan_name: str, features: list[str], expires_at: str) -> str:
    """Generate HMAC-SHA256 signed subscription token."""
    payload = {
        "tid": teacher_id[:8],
        "plan": plan_name.lower(),
        "features": sorted(features),
        "exp": expires_at,
        "iat": int(time.time()),
        "nonce": hashlib.sha256(f"{teacher_id}:{plan_name}:{int(time.time())}".encode()).hexdigest()[:16],
    }
    payload_json = json_mod.dumps(payload, sort_keys=True, separators=(",", ":"))
    sig = hmac.new(
        get_settings().SUBSCRIPTION_SECRET_KEY.encode(),
        payload_json.encode(),
        hashlib.sha256,
    ).hexdigest()
    encoded = base64.urlsafe_b64encode(payload_json.encode()).decode()
    return f"{encoded}.{sig}"


def _verify_subscription_token(token: str) -> dict | None:
    """Verify signed token. Returns payload if valid, None if tampered."""
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        encoded_payload, sig = parts
        payload_json = base64.urlsafe_b64decode(encoded_payload.encode()).decode()
        expected_sig = hmac.new(
            get_settings().SUBSCRIPTION_SECRET_KEY.encode(),
            payload_json.encode(),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(sig, expected_sig):
            return None
        return json_mod.loads(payload_json)
    except Exception:
        return None


def _get_plan_features(plan_name: str) -> list[str]:
    """Return feature list for a plan."""
    name_lower = plan_name.lower()
    base_features = ["students", "attendance", "grades", "exams", "invoices"]
    if "premium" in name_lower or "متكامل" in name_lower:
        return base_features + ["ai_generate_exam", "ai_reports", "groups", "lessons", "priority_support"]
    if "pro" in name_lower or "احتراف" in name_lower:
        return base_features + ["ai_generate_exam", "ai_reports", "groups", "lessons"]
    return base_features


@router.get("/token")
async def get_subscription_token(
    current_user: dict = Depends(get_current_teacher),
):
    """Generate a signed subscription token for client-side anti-tamper verification."""
    try:
        sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
        if not sub:
            raise HTTPException(status_code=404, detail="No active subscription")

        plan = await subscription_plan_service.get_by_id(sub["plan_id"])
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")

        plan_name = plan.get("name", "Basic")
        expires_at = sub.get("expires_at", "")

        if isinstance(expires_at, str):
            exp_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
        else:
            exp_dt = expires_at

        if exp_dt < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail="Subscription expired")

        features = _get_plan_features(plan_name)

        token = _generate_subscription_token(
            teacher_id=current_user["id"],
            plan_name=plan_name,
            features=features,
            expires_at=str(expires_at),
        )

        return {
            "token": token,
            "plan_name": plan_name,
            "features": features,
            "expires_at": str(expires_at),
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to generate subscription token: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to generate token")


@router.post("/verify-token")
async def verify_subscription_token(
    token: str,
    current_user: dict = Depends(get_current_teacher),
):
    """Server-side verification of subscription token."""
    payload = _verify_subscription_token(token)
    if not payload:
        return {"valid": False, "reason": "tampered"}

    sub = await teacher_subscription_service.get_active_subscription(current_user["id"])
    if not sub:
        return {"valid": False, "reason": "no_subscription"}

    plan = await subscription_plan_service.get_by_id(sub["plan_id"])
    plan_name = plan.get("name", "Basic") if plan else "Basic"

    if payload.get("plan", "").lower() != plan_name.lower():
        return {"valid": False, "reason": "plan_mismatch"}

    return {"valid": True, "plan_name": plan_name, "features": _get_plan_features(plan_name)}
