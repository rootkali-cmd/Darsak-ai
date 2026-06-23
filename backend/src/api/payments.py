import os
import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form, status
from pydantic import BaseModel

from src.utils.dependencies import get_current_teacher, get_current_admin
from src.services import (
    payment_request_service,
    subscription_plan_service,
    teacher_subscription_service,
    notification_service,
    user_service,
)
from src.services.telegram_bot import send_payment_request, answer_callback_query, send_message

logger = logging.getLogger("darsak")

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/request")
async def create_payment_request(
    plan_id: str = Form(...),
    payment_method: str = Form(...),
    amount: float = Form(...),
    phone_number: str = Form(""),
    instapay_id: str = Form(""),
    billing_period: str = Form("monthly"),
    screenshot: UploadFile = File(...),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = current_user.get("id") or current_user.get("teacher_id")
        if not teacher_id:
            raise HTTPException(status_code=401, detail="No teacher ID")

        if payment_method not in ("vodafone_cash", "instapay", "cash"):
            raise HTTPException(status_code=400, detail="Invalid payment_method")

        plan = await subscription_plan_service.get_by_id(plan_id)
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")

        screenshot_bytes = await screenshot.read()
        screenshot_b64 = None
        if screenshot_bytes:
            import base64
            screenshot_b64 = base64.b64encode(screenshot_bytes).decode()

        payment_info = f"طريقة الدفع: {'فودافون كاش' if payment_method == 'vodafone_cash' else 'انستاباي' if payment_method == 'instapay' else 'نقدي'}"
        if phone_number:
            payment_info += f"\nرقم الهاتف: {phone_number}"
        if instapay_id:
            payment_info += f"\nمعرف انستاباي: {instapay_id}"

        user = await user_service.get_by_id(teacher_id)
        teacher_name = user.get("full_name", "-") if user else "-"

        req = await payment_request_service.create(
            teacher_id=teacher_id,
            plan_id=plan_id,
            phone_number=phone_number or "",
            amount=amount,
            billing_period=billing_period,
        )

        request_id = req["id"]
        request_id_str = request_id.hex if hasattr(request_id, "hex") else str(request_id)

        period_label = "سنوي" if billing_period == "yearly" else "شهري"

        try:
            chat_id = int(os.environ.get("TELEGRAM_CHAT_ID", "0"))
            if chat_id:
                await send_payment_request(
                    chat_id=chat_id,
                    teacher_name=teacher_name,
                    plan_name=plan["name"],
                    amount=amount,
                    payment_method=payment_method,
                    request_id=request_id_str,
                    payment_info=payment_info,
                    screenshot_b64=screenshot_b64,
                    teacher_id=teacher_id,
                    billing_period=period_label,
                )
        except Exception as e:
            logger.warning("Telegram notification skipped: %s", e)

        return {"ok": True, "payment_id": request_id_str}
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create payment request: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: internal error")


class CallbackQuery(BaseModel):
    callback_query_id: str
    callback_data: str


@router.post("/callback")
async def payment_callback(body: CallbackQuery, admin: dict = Depends(get_current_admin)):
    try:
        data = body.callback_data
        request_id = None
        action = None

        if data.startswith("approve_"):
            request_id = data[len("approve_"):]
            action = "approve"
        elif data.startswith("reject_"):
            request_id = data[len("reject_"):]
            action = "reject"
        else:
            raise HTTPException(status_code=400, detail="Invalid callback data")

        await answer_callback_query(body.callback_query_id, "جاري المعالجة...")

        payment = await payment_request_service.get_by_id(request_id)
        if not payment:
            await answer_callback_query(body.callback_query_id, "الطلب غير موجود")
            raise HTTPException(status_code=404, detail="Payment request not found")

        if payment["status"] != "pending":
            await answer_callback_query(body.callback_query_id, "تمت معالجة هذا الطلب بالفعل")
            return {"ok": True, "status": payment["status"]}

        if action == "approve":
            plan = await subscription_plan_service.get_by_id(payment["plan_id"])
            if not plan:
                raise HTTPException(status_code=404, detail="Plan not found")

            expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
            await teacher_subscription_service.create(
                teacher_id=payment["teacher_id"],
                plan_id=payment["plan_id"],
                code_id=request_id,
                expires_at=expires_at,
            )
            await payment_request_service.approve(request_id)
            await notification_service.create(
                teacher_id=payment["teacher_id"],
                title="✅ تم تفعيل اشتراكك",
                body=f"تم تفعيل اشتراكك في باقة {plan['name']} بنجاح!",
                type="success",
            )
            await answer_callback_query(body.callback_query_id, "تم التفعيل بنجاح")
            return {"ok": True, "status": "approved"}

        else:
            await payment_request_service.reject(request_id, "تم الرفض من قبل الأدمن")
            await notification_service.create(
                teacher_id=payment["teacher_id"],
                title="❌ تم رفض طلب الدفع",
                body="تم رفض طلب الدفع الخاص بك.",
                type="error",
            )
            await answer_callback_query(body.callback_query_id, "تم الرفض")
            return {"ok": True, "status": "rejected"}

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Payment callback failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: internal error")


def _mask_phone(phone: str) -> str:
    if len(phone) < 7:
        return phone
    return phone[:3] + "****" + phone[-4:]


@router.get("/config")
async def get_payment_config(current_user: dict = Depends(get_current_teacher)):
    phone = "01031524947"
    masked = _mask_phone(phone)
    return {
        "vodafone_cash_number": masked,
        "whatsapp_link": f"https://wa.me/{phone}",
        "instapay_username": "ahmed-mahmoud-1@instapay",
    }


@router.post("/test-telegram")
async def test_telegram(admin: dict = Depends(get_current_admin)):
    """Test Telegram bot connectivity."""
    from src.services.telegram_bot import send_message
    import os
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id_raw = os.environ.get("TELEGRAM_CHAT_ID", "")
    
    if not token:
        return {"ok": False, "error": "TELEGRAM_BOT_TOKEN not set"}
    if not chat_id_raw:
        return {"ok": False, "error": "TELEGRAM_CHAT_ID not set"}
    
    try:
        chat_id = int(chat_id_raw)
    except ValueError:
        return {"ok": False, "error": f"TELEGRAM_CHAT_ID is not a valid integer: {chat_id_raw!r}"}
    
    try:
        result = await send_message(chat_id, "🔧 اختبار البوت - DarsakAI Backend Test")
        return {"ok": True, "chat_id": chat_id, "result": result}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@router.get("/{teacher_id}/status")
async def get_teacher_subscription_status(
    teacher_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        current_teacher_id = current_user.get("id") or current_user.get("teacher_id")
        if str(current_teacher_id) != str(teacher_id):
            raise HTTPException(status_code=403, detail="You can only view your own subscription status")

        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        if not sub:
            return {
                "has_active_subscription": False,
                "plan_name": None,
                "expires_at": None,
                "days_remaining": 0,
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
        is_active = sub.get("is_active", False) and expires_dt > now

        return {
            "has_active_subscription": is_active,
            "plan_name": plan_name,
            "expires_at": expires_dt.isoformat(),
            "days_remaining": days_remaining,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get subscription status: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed: internal error")
