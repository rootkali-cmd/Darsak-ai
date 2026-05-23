import os
import logging
from datetime import datetime, timezone, timedelta

from src.core.config import get_settings
from src.core.security.crypto_utils import generate_license_key
from src.services import subscription_plan_service, subscription_code_service

logger = logging.getLogger("darsak")
settings = get_settings()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", settings.TELEGRAM_BOT_TOKEN)
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", settings.TELEGRAM_CHAT_ID)
TELEGRAM_WEBHOOK_URL = os.environ.get("TELEGRAM_WEBHOOK_URL", "")

_bot_app = None
_user_states: dict[int, str] = {}


def is_authorized(chat_id: int) -> bool:
    return str(chat_id) == str(TELEGRAM_CHAT_ID)


async def set_webhook():
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_WEBHOOK_URL:
        logger.info("TELEGRAM_WEBHOOK_URL not set, skipping webhook registration")
        return
    try:
        import httpx
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/setWebhook"
        async with httpx.AsyncClient() as client:
            resp = await client.post(url, json={"url": TELEGRAM_WEBHOOK_URL})
            if resp.status_code == 200:
                logger.info("Telegram webhook set to %s", TELEGRAM_WEBHOOK_URL)
            else:
                logger.error("Failed to set webhook: %s", resp.text)
    except Exception as e:
        logger.error("Failed to set Telegram webhook: %s", e)


def get_bot_app():
    global _bot_app
    if _bot_app is not None:
        return _bot_app

    try:
        from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
        from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes

        if not TELEGRAM_BOT_TOKEN:
            logger.warning("TELEGRAM_BOT_TOKEN not set, bot disabled")
            return None

        application = Application.builder().token(TELEGRAM_BOT_TOKEN).build()

        async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
            chat_id = update.effective_chat.id
            if not is_authorized(chat_id):
                await update.message.reply_text("⛔ غير مصرح لك باستخدام هذا البوت.")
                return

            keyboard = [
                [InlineKeyboardButton("🔑 توليد كود", callback_data="generate_code")],
                [InlineKeyboardButton("🔍 فحص كود", callback_data="check_code")],
                [InlineKeyboardButton("📋 الباقات", callback_data="list_plans")],
                [InlineKeyboardButton("📊 إحصائيات", callback_data="stats")],
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            await update.message.reply_text(
                "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\n"
                "اختر من الأزرار أدناه:",
                reply_markup=reply_markup,
            )

        async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
            query = update.callback_query
            await query.answer()
            chat_id = query.message.chat_id

            if not is_authorized(chat_id):
                await query.edit_message_text("⛔ غير مصرح لك باستخدام هذا البوت.")
                return

            data = query.data

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
                        InlineKeyboardButton(
                            f"{plan['name']} - {plan['price_egp']} ج.م",
                            callback_data=f"plan_{plan_id_str}",
                        )
                    ])
                keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="back")])
                reply_markup = InlineKeyboardMarkup(keyboard)
                await query.edit_message_text(
                    "اختر الباقة لتوليد كود:\n",
                    reply_markup=reply_markup,
                )

            elif data.startswith("plan_"):
                plan_id_str = data.replace("plan_", "")
                plan = await subscription_plan_service.get_by_id(plan_id_str)
                if not plan:
                    await query.edit_message_text("❌ الباقة غير موجودة.")
                    return

                code = generate_license_key()
                expires_at = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
                plan_id = plan["id"]
                if hasattr(plan_id, "hex"):
                    plan_id_str = plan_id.hex
                else:
                    plan_id_str = str(plan_id)

                await subscription_code_service.create(code, plan_id_str, expires_at)
                await query.edit_message_text(
                    f"✅ تم توليد الكود بنجاح!\n\n"
                    f"📌 الباقة: {plan['name']}\n"
                    f"🔑 الكود: `{code}`\n"
                    f"💰 السعر: {plan['price_egp']} ج.م\n"
                    f"📅 الصلاحية: سنة من تاريخ التفعيل\n\n"
                    f"أرسل هذا الكود للمدرس لتفعيل اشتراكه.",
                    parse_mode="Markdown",
                )

            elif data == "check_code":
                await query.edit_message_text(
                    "أرسل الكود الذي تريد فحصه (مثال: XXXX-XXXX-XXXX-XXXX):"
                )
                _user_states[chat_id] = "waiting_for_code_check"

            elif data == "list_plans":
                plans = await subscription_plan_service.list_active()
                text = "📋 *الباقات المتاحة:*\n\n"
                for plan in plans:
                    features = plan.get("features_json", []) or []
                    features_text = "\n".join([f"• {f}" for f in features]) if features else "لا توجد مميزات محددة"

                    max_students_text = "غير محدود" if plan["max_students"] == -1 else str(plan["max_students"])
                    max_ai_text = str(plan["max_ai_requests"])

                    text += (
                        f"*{plan['name']}*\n"
                        f"💰 {plan['price_egp']} ج.م\n"
                        f"👥 الطلاب: {max_students_text}\n"
                        f"🤖 طلبات AI: {max_ai_text}/شهر\n"
                        f"📌 المميزات:\n{features_text}\n\n"
                    )
                keyboard = [[InlineKeyboardButton("🔙 رجوع", callback_data="back")]]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await query.edit_message_text(text, parse_mode="Markdown", reply_markup=reply_markup)

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
                keyboard = [[InlineKeyboardButton("🔙 رجوع", callback_data="back")]]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await query.edit_message_text(text, parse_mode="Markdown", reply_markup=reply_markup)

            elif data == "back":
                keyboard = [
                    [InlineKeyboardButton("🔑 توليد كود", callback_data="generate_code")],
                    [InlineKeyboardButton("🔍 فحص كود", callback_data="check_code")],
                    [InlineKeyboardButton("📋 الباقات", callback_data="list_plans")],
                    [InlineKeyboardButton("📊 إحصائيات", callback_data="stats")],
                ]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await query.edit_message_text(
                    "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\nاختر من الأزرار أدناه:",
                    reply_markup=reply_markup,
                )

        async def message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
            chat_id = update.effective_chat.id
            if not is_authorized(chat_id):
                await update.message.reply_text("⛔ غير مصرح لك باستخدام هذا البوت.")
                return

            state = _user_states.get(chat_id)

            if state == "waiting_for_code_check":
                code = update.message.text.strip().upper()
                record = await subscription_code_service.get_by_code(code)
                if not record:
                    await update.message.reply_text("❌ الكود غير صالح أو غير موجود.")
                elif record.get("is_used"):
                    used_at = record.get("used_at", "غير معروف")
                    await update.message.reply_text(
                        f"⚠️ هذا الكود مستخدم بالفعل.\n📅 تاريخ الاستخدام: {used_at}"
                    )
                else:
                    plan = await subscription_plan_service.get_by_id(record["plan_id"])
                    plan_name = plan["name"] if plan else "غير معروفة"
                    await update.message.reply_text(
                        f"✅ الكود صالح!\n\n"
                        f"📌 الباقة: {plan_name}\n"
                        f"🔑 الكود: `{code}`\n"
                        f"📅 الحالة: غير مستخدم",
                        parse_mode="Markdown",
                    )

                _user_states.pop(chat_id, None)

                keyboard = [
                    [InlineKeyboardButton("🔑 توليد كود", callback_data="generate_code")],
                    [InlineKeyboardButton("🔍 فحص كود", callback_data="check_code")],
                    [InlineKeyboardButton("📋 الباقات", callback_data="list_plans")],
                    [InlineKeyboardButton("📊 إحصائيات", callback_data="stats")],
                ]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await update.message.reply_text("اختر من الأزرار:", reply_markup=reply_markup)

            else:
                keyboard = [
                    [InlineKeyboardButton("🔑 توليد كود", callback_data="generate_code")],
                    [InlineKeyboardButton("🔍 فحص كود", callback_data="check_code")],
                    [InlineKeyboardButton("📋 الباقات", callback_data="list_plans")],
                    [InlineKeyboardButton("📊 إحصائيات", callback_data="stats")],
                ]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await update.message.reply_text(
                    "🎓 مرحباً بك في بوت الاشتراكات - درسك AI\n\nاختر من الأزرار أدناه:",
                    reply_markup=reply_markup,
                )

        application.add_handler(CommandHandler("start", start))
        application.add_handler(CallbackQueryHandler(button_handler))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))

        _bot_app = application
        return application

    except ImportError:
        logger.warning("python-telegram-bot not installed, bot disabled")
        return None
    except Exception as e:
        logger.error("Failed to initialize Telegram bot: %s", e)
        return None


async def start_bot():
    app = get_bot_app()
    if app is None:
        logger.info("Telegram bot not available (token missing or import error)")
        return
    try:
        await app.initialize()
        await app.start()

        webhook_url = TELEGRAM_WEBHOOK_URL or os.environ.get("VERCEL_URL", "")
        if webhook_url:
            full_webhook = f"https://{webhook_url}" if not webhook_url.startswith("http") else webhook_url
            if not full_webhook.endswith("/api/telegram-webhook"):
                if full_webhook.endswith("/"):
                    full_webhook = f"{full_webhook}api/telegram-webhook"
                else:
                    full_webhook = f"{full_webhook}/api/telegram-webhook"
            await app.bot.set_webhook(url=full_webhook)
            logger.info("Telegram bot ready (webhook mode) at %s", full_webhook)
        else:
            await app.updater.start_polling()
            logger.info("Telegram bot started (polling mode)")
    except Exception as e:
        logger.error("Failed to start Telegram bot: %s", e)


async def stop_bot():
    global _bot_app
    if _bot_app is None:
        return
    try:
        if _bot_app.updater and _bot_app.updater.running:
            await _bot_app.updater.stop()
        await _bot_app.stop()
        await _bot_app.shutdown()
        logger.info("Telegram bot stopped")
    except Exception as e:
        logger.error("Failed to stop Telegram bot: %s", e)
