import os
import logging
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Request, HTTPException
import httpx

from src.core.config import get_settings
from src.core.security.crypto_utils import generate_license_key
from src.services import subscription_plan_service, subscription_code_service, teacher_subscription_service, payment_request_service, notification_service

logger = logging.getLogger("darsak")

router = APIRouter()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", get_settings().TELEGRAM_BOT_TOKEN)
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", get_settings().TELEGRAM_CHAT_ID)

TG_API = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"
_user_states: dict[int, str] = {}


def is_authorized(chat_id: int) -> bool:
    return str(chat_id) == str(TELEGRAM_CHAT_ID)


async def tg_send(chat_id: int, text: str, keyboard: list | None = None, parse_mode: str | None = None):
    payload = {"chat_id": chat_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    if keyboard:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    async with httpx.AsyncClient() as client:
        await client.post(f"{TG_API}/sendMessage", json=payload)


async def tg_edit(chat_id: int, message_id: int, text: str, keyboard: list | None = None, parse_mode: str | None = None):
    payload = {"chat_id": chat_id, "message_id": message_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    if keyboard:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    async with httpx.AsyncClient() as client:
        await client.post(f"{TG_API}/editMessageText", json=payload)


async def answer_callback(callback_query_id: str, text: str | None = None):
    payload = {"callback_query_id": callback_query_id}
    if text:
        payload["text"] = text
    async with httpx.AsyncClient() as client:
        await client.post(f"{TG_API}/answerCallbackQuery", json=payload)


def main_keyboard():
    return [
        [{"text": "🔑 توليد كود", "callback_data": "generate_code"}],
        [{"text": "🔍 فحص كود", "callback_data": "check_code"}],
        [{"text": "📋 الباقات", "callback_data": "list_plans"}],
        [{"text": "📊 إحصائيات", "callback_data": "stats"}],
    ]


async def handle_message(chat_id: int, text: str):
    if not is_authorized(chat_id):
        await tg_send(chat_id, "⛔ غير مصرح لك باستخدام هذا البوت.")
        return

    state = _user_states.get(chat_id)

    if state and state.startswith("reject_msg_"):
        payment_id = state.replace("reject_msg_", "")
        payment = await payment_request_service.get_by_id(payment_id)
        if not payment:
            await tg_send(chat_id, "❌ طلب الدفع غير موجود.")
            _user_states.pop(chat_id, None)
            return

        await payment_request_service.reject(payment_id, text)
        await notification_service.create(
            teacher_id=payment["teacher_id"],
            title="❌ لم يتم تفعيل اشتراكك",
            body=text,
            type="error",
        )
        await tg_send(chat_id, f"✅ تم إرسال رسالة الرفض للمعلم.")
        _user_states.pop(chat_id, None)
        await tg_send(chat_id, "اختر من الأزرار:", keyboard=main_keyboard())
        return

    if state == "waiting_for_code_check":
        code = text.strip().upper()
        record = await subscription_code_service.get_by_code(code)
        if not record:
            await tg_send(chat_id, "❌ الكود غير صالح أو غير موجود.")
        elif record.get("is_used"):
            used_at = record.get("used_at", "غير معروف")
            await tg_send(chat_id, f"⚠️ هذا الكود مستخدم بالفعل.\n📅 تاريخ الاستخدام: {used_at}")
        else:
            plan = await subscription_plan_service.get_by_id(record["plan_id"])
            plan_name = plan["name"] if plan else "غير معروفة"
            await tg_send(chat_id, f"✅ الكود صالح!\n\n📌 الباقة: {plan_name}\n🔑 الكود: `{code}`\n📅 الحالة: غير مستخدم", parse_mode="Markdown")

        _user_states.pop(chat_id, None)
        await tg_send(chat_id, "اختر من الأزرار:", keyboard=main_keyboard())
    else:
        await tg_send(chat_id, "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\nاختر من الأزرار أدناه:", keyboard=main_keyboard())


async def handle_callback(chat_id: int, message_id: int, data: str):
    if not is_authorized(chat_id):
        await tg_edit(chat_id, message_id, "⛔ غير مصرح لك باستخدام هذا البوت.")
        return

    if data == "generate_code":
        plans = await subscription_plan_service.list_active()
        keyboard = []
        for plan in plans:
            plan_id = plan["id"]
            if hasattr(plan_id, "hex"):
                plan_id_str = plan_id.hex
            else:
                plan_id_str = str(plan_id)
            keyboard.append([
                {"text": f"{plan['name']} - {plan['price_egp']} ج.م", "callback_data": f"plan_{plan_id_str}"}
            ])
        keyboard.append([{"text": "🔙 رجوع", "callback_data": "back"}])
        await tg_edit(chat_id, message_id, "اختر الباقة لتوليد كود:", keyboard=keyboard)

    elif data.startswith("plan_"):
        plan_id_str = data.replace("plan_", "")
        plan = await subscription_plan_service.get_by_id(plan_id_str)
        if not plan:
            await tg_edit(chat_id, message_id, "❌ الباقة غير موجودة.")
            return

        code = generate_license_key()
        expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
        plan_id = plan["id"]
        if hasattr(plan_id, "hex"):
            plan_id_str = plan_id.hex
        else:
            plan_id_str = str(plan_id)

        await subscription_code_service.create(code, plan_id_str, expires_at)
        await tg_edit(chat_id, message_id,
            f"✅ تم توليد الكود بنجاح!\n\n"
            f"📌 الباقة: {plan['name']}\n"
            f"🔑 الكود: `{code}`\n"
            f"💰 السعر: {plan['price_egp']} ج.م\n"
            f"📅 الصلاحية: شهر من تاريخ التفعيل\n"
            f"🔒 استخدام مرة واحدة فقط\n\n"
            f"أرسل هذا الكود للمدرس لتفعيل اشتراكه.",
            parse_mode="Markdown")

    elif data == "check_code":
        await tg_edit(chat_id, message_id, "أرسل الكود الذي تريد فحصه (مثال: XXXX-XXXX-XXXX-XXXX):")
        _user_states[chat_id] = "waiting_for_code_check"

    elif data == "list_plans":
        plans = await subscription_plan_service.list_active()
        text = "📋 *الباقات المتاحة:*\n\n"
        for plan in plans:
            features = plan.get("features_json", []) or []
            features_text = "\n".join([f"• {f}" for f in features]) if features else "لا توجد مميزات محددة"
            max_students_text = "غير محدود" if plan["max_students"] == -1 else str(plan["max_students"])
            text += (
                f"*{plan['name']}*\n"
                f"💰 {plan['price_egp']} ج.م\n"
                f"👥 الطلاب: {max_students_text}\n"
                f"🤖 طلبات AI: {plan['max_ai_requests']}/شهر\n"
                f"📌 المميزات:\n{features_text}\n\n"
            )
        await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]], parse_mode="Markdown")

    elif data == "stats":
        all_codes = await subscription_code_service.list_all(limit=9999)
        total = len(all_codes)
        used = sum(1 for c in all_codes if c.get("is_used"))
        remaining = total - used
        plans = await subscription_plan_service.list_active()
        text = (
            f"📊 *الإحصائيات:*\n\n"
            f"إجمالي الأكواد: {total}\n"
            f"✅ مستخدم: {used}\n"
            f"🆓 متبقي: {remaining}\n"
            f"📋 الباقات النشطة: {len(plans)}\n"
        )
        await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]], parse_mode="Markdown")

    elif data == "back":
        await tg_edit(chat_id, message_id, "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\nاختر من الأزرار أدناه:", keyboard=main_keyboard())

    elif data.startswith("pay_approve_") or data.startswith("pay_reject_"):
        payment_id = data.replace("pay_approve_", "").replace("pay_reject_", "")
        payment = await payment_request_service.get_by_id(payment_id)

        if not payment:
            await tg_edit(chat_id, message_id, "❌ طلب الدفع غير موجود.")
            return

        if payment["status"] != "pending":
            await tg_edit(chat_id, message_id, "⚠️ تمت معالجة هذا الطلب بالفعل.")
            return

        if data.startswith("pay_approve_"):
            plan = await subscription_plan_service.get_by_id(payment["plan_id"])
            if not plan:
                await tg_edit(chat_id, message_id, "❌ الباقة غير موجودة.")
                return

            expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
            await teacher_subscription_service.create(
                teacher_id=payment["teacher_id"],
                plan_id=payment["plan_id"],
                code_id=payment_id,
                expires_at=expires_at,
            )
            await payment_request_service.approve(payment_id)
            await notification_service.create(
                teacher_id=payment["teacher_id"],
                title="✅ تم تفعيل اشتراكك",
                body=f"تم تفعيل اشتراكك في باقة {plan['name']} بنجاح! الباقة سارية لمدة 30 يوماً.",
                type="success",
            )

            teacher_str = str(payment["teacher_id"])[:8] if not hasattr(payment["teacher_id"], "hex") else payment["teacher_id"].hex[:8]
            await tg_edit(chat_id, message_id,
                f"✅ تم تفعيل الاشتراك بنجاح!\n\n"
                f"📌 الباقة: {plan['name']}\n"
                f"👤 المعلم: {teacher_str}\n"
                f"📅 ينتهي في: {(datetime.now(timezone.utc) + timedelta(days=30)).strftime('%Y-%m-%d')}",
                keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]],
            )

        elif data.startswith("pay_reject_"):
            _user_states[chat_id] = f"reject_msg_{payment_id}"
            await tg_edit(chat_id, message_id,
                "✍️ اكتب رسالة الرفض للمعلم:\n\n"
                "(سيتم إرسالها كإشعار للمعلم)",
                keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]],
            )


async def handle_start(chat_id: int):
    if not is_authorized(chat_id):
        await tg_send(chat_id, "⛔ غير مصرح لك باستخدام هذا البوت.")
        return
    await tg_send(chat_id, "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\nاختر من الأزرار أدناه:", keyboard=main_keyboard())


@router.post("/telegram-webhook")
async def telegram_webhook(request: Request):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    if not TELEGRAM_BOT_TOKEN:
        raise HTTPException(status_code=500, detail="Bot token not configured")

    try:
        update = body
        if "message" in update:
            msg = update["message"]
            chat_id = msg["chat"]["id"]
            text = msg.get("text", "")
            entities = msg.get("entities", [])
            is_command = any(e.get("type") == "bot_command" for e in entities)

            if is_command and text == "/start":
                await handle_start(chat_id)
            else:
                await handle_message(chat_id, text)

        elif "callback_query" in update:
            cq = update["callback_query"]
            await answer_callback(cq["id"])
            chat_id = cq["message"]["chat"]["id"]
            message_id = cq["message"]["message_id"]
            data = cq.get("data", "")
            await handle_callback(chat_id, message_id, data)

    except Exception as e:
        logger.error("Failed to process Telegram update: %s", e)

    return {"ok": True}


async def _setup_webhook():
    if not TELEGRAM_BOT_TOKEN:
        return False, "Bot token not configured"

    webhook_url = "https://darsak-ai-o8cs.vercel.app/api/telegram-webhook"
    async with httpx.AsyncClient() as client:
        resp = await client.post(f"{TG_API}/setWebhook", json={"url": webhook_url})
        if resp.status_code == 200 and resp.json().get("ok"):
            logger.info("Telegram webhook set to %s", webhook_url)
            return True, webhook_url
        return False, resp.text
    async with httpx.AsyncClient() as client:
        resp = await client.post(f"{TG_API}/setWebhook", json={"url": webhook_url})
        if resp.status_code == 200 and resp.json().get("ok"):
            logger.info("Telegram webhook set to %s", webhook_url)
            return True, webhook_url
        return False, resp.text


@router.post("/setup-telegram-webhook")
async def setup_telegram_webhook():
    ok, detail = await _setup_webhook()
    if ok:
        return {"ok": True, "webhook_url": detail}
    raise HTTPException(status_code=500, detail=detail)


async def notify_admin_payment_request(payment_request: dict, plan: dict):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    chat_id = int(TELEGRAM_CHAT_ID)
    payment_id = payment_request["id"]
    if hasattr(payment_id, "hex"):
        payment_id_str = payment_id.hex
    else:
        payment_id_str = str(payment_id)

    teacher = payment_request.get("teacher_id", "-")
    if hasattr(teacher, "hex"):
        teacher_str = teacher.hex[:8]
    else:
        teacher_str = str(teacher)[:8]

    text = (
        f"💰 طلب اشتراك جديد\n\n"
        f"📌 الباقة: {plan['name']}\n"
        f"💵 المبلغ: {payment_request['amount']} ج.م\n"
        f"📱 رقم المحول: {payment_request['phone_number']}\n"
        f"🆔 المعلم: {teacher_str}\n"
        f"🆔 الطلب: {payment_id_str}\n"
    )

    keyboard = [
        [
            {"text": "✅ تفعيل", "callback_data": f"pay_approve_{payment_id_str}"},
            {"text": "❌ إلغاء", "callback_data": f"pay_reject_{payment_id_str}"},
        ]
    ]
    await tg_send(chat_id, text, keyboard=keyboard)

