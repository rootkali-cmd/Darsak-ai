import os
import json
import logging

import httpx

from src.core.config import get_settings

logger = logging.getLogger("darsak")

settings = get_settings()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", settings.TELEGRAM_BOT_TOKEN)
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", settings.TELEGRAM_CHAT_ID)

TG_API = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"


async def send_message(chat_id: int | str, text: str, parse_mode: str | None = None):
    if not TELEGRAM_BOT_TOKEN:
        logger.warning("send_message skipped: TELEGRAM_BOT_TOKEN not set")
        return
    payload: dict = {"chat_id": chat_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(f"{TG_API}/sendMessage", json=payload, timeout=10)
            return resp.json()
    except Exception as e:
        logger.error("Telegram send_message failed: %s", e)


async def send_payment_request(
    chat_id: int | str,
    teacher_name: str,
    plan_name: str,
    amount: float,
    payment_method: str,
    request_id: str,
    payment_info: str = "",
    screenshot_b64: str | None = None,
    teacher_id: str = "",
    billing_period: str = "شهري",
):
    method_label = "Vodafone Cash" if payment_method == "vodafone_cash" else "InstaPay" if payment_method == "instapay" else "نقدي"
    text = (
        f"💰 طلب اشتراك جديد\n\n"
        f"👤 الاسم: {teacher_name}\n"
        f"🆔 معرف المعلم: {teacher_id}\n"
        f"📌 الباقة: {plan_name}\n"
        f"📅 الفتره: {billing_period}\n"
        f"💵 المبلغ: {amount} ج.م\n"
        f"💳 الطريقة: {method_label}\n"
        f"🆔 رقم الطلب: {request_id}"
    )
    if payment_info:
        text += f"\n\n{payment_info}"
    keyboard = [[
        {"text": "✅ تفعيل", "callback_data": f"pay_approve_{request_id}"},
        {"text": "❌ رفض", "callback_data": f"pay_reject_{request_id}"},
    ]]
    if not TELEGRAM_BOT_TOKEN:
        logger.warning("send_payment_request skipped: TELEGRAM_BOT_TOKEN not set")
        return
    try:
        async with httpx.AsyncClient() as client:
            if screenshot_b64:
                import base64 as _b64
                photo_bytes = _b64.b64decode(screenshot_b64)
                files = {"photo": ("screenshot.jpg", photo_bytes, "image/jpeg")}
                data = {
                    "chat_id": str(chat_id),
                    "caption": text,
                    "reply_markup": json.dumps({"inline_keyboard": keyboard}),
                }
                resp = await client.post(f"{TG_API}/sendPhoto", files=files, data=data, timeout=15)
                return resp.json()
            else:
                payload: dict = {
                    "chat_id": chat_id,
                    "text": text,
                    "reply_markup": {"inline_keyboard": keyboard},
                }
                resp = await client.post(f"{TG_API}/sendMessage", json=payload, timeout=10)
                return resp.json()
    except Exception as e:
        logger.error("Telegram send_payment_request failed: %s (chat_id=%s, token=%s...)", e, chat_id, TELEGRAM_BOT_TOKEN[:10] if TELEGRAM_BOT_TOKEN else "NONE")


async def answer_callback_query(callback_query_id: str, text: str | None = None):
    if not TELEGRAM_BOT_TOKEN:
        return
    payload: dict = {"callback_query_id": callback_query_id}
    if text:
        payload["text"] = text
    try:
        async with httpx.AsyncClient() as client:
            await client.post(f"{TG_API}/answerCallbackQuery", json=payload, timeout=10)
    except Exception as e:
        logger.error("Telegram answer_callback_query failed: %s", e)
