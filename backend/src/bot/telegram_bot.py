import os
import logging
from datetime import datetime, timezone, timedelta

from src.core.config import get_settings
from src.core.security.crypto_utils import generate_license_key
from src.services import (
    subscription_plan_service,
    subscription_code_service,
    user_service,
    student_service,
    grade_service,
    attendance_service,
    teacher_subscription_service,
)

logger = logging.getLogger("darsak")
settings = get_settings()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", settings.TELEGRAM_BOT_TOKEN)
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", settings.TELEGRAM_CHAT_ID)
TELEGRAM_WEBHOOK_URL = os.environ.get("TELEGRAM_WEBHOOK_URL", "")

_bot_app = None
_user_states: dict[int, str] = {}
_user_context: dict[int, dict] = {}

TEACHERS_PER_PAGE = 8
STUDENTS_PER_PAGE = 8


def is_authorized(chat_id: int) -> bool:
    if not TELEGRAM_CHAT_ID:
        return True
    return str(chat_id) == str(TELEGRAM_CHAT_ID)


def _main_menu_keyboard():
    from telegram import InlineKeyboardButton
    return [
        [InlineKeyboardButton("🔑 توليد كود", callback_data="generate_code")],
        [InlineKeyboardButton("🔍 فحص كود", callback_data="check_code")],
        [InlineKeyboardButton("📋 الباقات", callback_data="list_plans")],
        [InlineKeyboardButton("📊 إحصائيات", callback_data="stats")],
        [InlineKeyboardButton("فك حظر مستخدم", callback_data="unban_menu")],
    ]


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


async def _fetch_teachers():
    return await user_service.repo.select({"role": "teacher"}, limit=2000)


async def _fetch_all_students():
    return await student_service.repo.select({}, limit=2000)


async def _get_teacher_plan_name(teacher_id: str) -> str:
    try:
        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        if sub:
            plan = await subscription_plan_service.get_by_id(sub["plan_id"])
            if plan:
                return plan.get("name", "غير معروفة")
    except Exception:
        pass
    return "غير معروفة"


async def _get_student_grades_summary(student_id: str) -> str:
    try:
        grades = await grade_service.list({"student_id": student_id}, limit=100)
        if not grades:
            return "لا توجد درجات"
        total = len(grades)
        avg = sum(g.get("score", 0) for g in grades) / total if total else 0
        return f"{total} درجة - متوسط: {avg:.1f}"
    except Exception:
        return "خطأ في جلب الدرجات"


async def _get_student_attendance_summary(student_id: str) -> str:
    try:
        records = await attendance_service.list({"student_id": student_id}, limit=200)
        if not records:
            return "لا توجد سجلات حضور"
        present = sum(1 for r in records if r.get("status") == "present")
        absent = sum(1 for r in records if r.get("status") == "absent")
        return f"حضور: {present} | غياب: {absent}"
    except Exception:
        return "خطأ في جلب الحضور"


def _format_teacher_info(teacher: dict, plan_name: str, student_count: int) -> str:
    name = teacher.get("full_name", "غير معروف")
    email = teacher.get("email", "غير معروف")
    created = teacher.get("created_at", "غير معروف")
    if created and isinstance(created, str) and len(created) > 10:
        created = created[:10]
    code = teacher.get("teacher_code", "غير معروف")
    is_active = teacher.get("is_active", True)
    status = "نشط" if is_active else "محظور"
    return (
        f"👤 معلومات المدرس:\n\n"
        f"الاسم: {name}\n"
        f"البريد: {email}\n"
        f"الكود: {code}\n"
        f"تاريخ التسجيل: {created}\n"
        f"الباقة: {plan_name}\n"
        f"عدد الطلاب: {student_count}\n"
        f"الحالة: {status}"
    )


def _format_student_info(student: dict, teacher: dict, grades_summary: str, attendance_summary: str) -> str:
    name = student.get("full_name", "غير معروف")
    code = student.get("code", "غير معروف")
    has_pin = student.get("pin_hash") is not None
    pin_status = "نعم" if has_pin else "لا"
    parent_phone = student.get("parent_phone", "غير متوفر")
    grade_level = student.get("grade_level", "غير محدد")
    is_active = student.get("is_active", True)
    status = "نشط" if is_active else "محظور"

    teacher_name = teacher.get("full_name", "غير معروف") if teacher else "غير معروف"
    teacher_code = teacher.get("teacher_code", "غير معروف") if teacher else "غير معروف"
    teacher_phone = teacher.get("phone", "غير متوفر") if teacher else "غير متوفر"

    return (
        f"🎓 معلومات الطالب:\n\n"
        f"الاسم: {name}\n"
        f"الكود: {code}\n"
        f"الرمز السري: {pin_status}\n"
        f"هاتف ولي الأمر: {parent_phone}\n"
        f"المستوى الدراسي: {grade_level}\n"
        f"الحالة: {status}\n\n"
        f"👨‍🏫 معلومات المدرس:\n"
        f"الاسم: {teacher_name}\n"
        f"الكود: {teacher_code}\n"
        f"الهاتف: {teacher_phone}\n\n"
        f"📊 الدرجات: {grades_summary}\n"
        f"📅 الحضور: {attendance_summary}"
    )


def _get_user_id_str(user_id) -> str:
    if hasattr(user_id, "hex"):
        return user_id.hex
    return str(user_id)


async def _unban_teachers_page(query, page: int = 0):
    from telegram import InlineKeyboardButton, InlineKeyboardMarkup

    teachers = await _fetch_teachers()
    total = len(teachers)
    total_pages = max(1, (total + TEACHERS_PER_PAGE - 1) // TEACHERS_PER_PAGE)
    page = max(0, min(page, total_pages - 1))
    start = page * TEACHERS_PER_PAGE
    end = start + TEACHERS_PER_PAGE
    page_teachers = teachers[start:end]

    if not page_teachers:
        await query.edit_message_text("لا يوجد مدرسين مسجلين.")
        return

    keyboard = []
    for t in page_teachers:
        uid = _get_user_id_str(t["id"])
        label = f"{t.get('full_name', '?')} ({t.get('email', '?')})"
        keyboard.append([InlineKeyboardButton(label, callback_data=f"unban_t:{uid}")])

    nav = []
    if page > 0:
        nav.append(InlineKeyboardButton("◀️ السابق", callback_data=f"unban_t_page:{page - 1}"))
    nav.append(InlineKeyboardButton(f"{page + 1}/{total_pages}", callback_data="noop"))
    if page < total_pages - 1:
        nav.append(InlineKeyboardButton("التالي ▶️", callback_data=f"unban_t_page:{page + 1}"))
    keyboard.append(nav)
    keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_menu")])

    await query.edit_message_text(
        f"👨‍🏫 قائمة المدرسين ({total} مدرس):\nاختر مدرساً لعرض معلوماته:",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )


async def _unban_students_page(query, page: int = 0):
    from telegram import InlineKeyboardButton, InlineKeyboardMarkup

    students = await _fetch_all_students()
    total = len(students)
    total_pages = max(1, (total + STUDENTS_PER_PAGE - 1) // STUDENTS_PER_PAGE)
    page = max(0, min(page, total_pages - 1))
    start = page * STUDENTS_PER_PAGE
    end = start + STUDENTS_PER_PAGE
    page_students = students[start:end]

    if not page_students:
        await query.edit_message_text("لا يوجد طلاب مسجلين.")
        return

    keyboard = []
    for s in page_students:
        sid = _get_user_id_str(s["id"])
        label = f"{s.get('full_name', '?')} ({s.get('code', '?')})"
        keyboard.append([InlineKeyboardButton(label, callback_data=f"unban_s:{sid}")])

    nav = []
    if page > 0:
        nav.append(InlineKeyboardButton("◀️ السابق", callback_data=f"unban_s_page:{page - 1}"))
    nav.append(InlineKeyboardButton(f"{page + 1}/{total_pages}", callback_data="noop"))
    if page < total_pages - 1:
        nav.append(InlineKeyboardButton("التالي ▶️", callback_data=f"unban_s_page:{page + 1}"))
    keyboard.append(nav)
    keyboard.append([InlineKeyboardButton("🔍 بحث بكود", callback_data="search_student")])
    keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_menu")])

    await query.edit_message_text(
        f"🎓 قائمة الطلاب ({total} طالب):\nاختر طالباً لعرض معلوماته:",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )


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

            keyboard = _main_menu_keyboard()
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

            # ─── Unban Menu ───────────────────────────────────────────
            elif data == "unban_menu":
                keyboard = [
                    [InlineKeyboardButton("المدرسين", callback_data="unban_teachers")],
                    [InlineKeyboardButton("الطلاب", callback_data="unban_students")],
                    [InlineKeyboardButton("🔙 رجوع", callback_data="back")],
                ]
                await query.edit_message_text(
                    "اختر نوع المستخدم:",
                    reply_markup=InlineKeyboardMarkup(keyboard),
                )

            elif data == "unban_teachers":
                await _unban_teachers_page(query, page=0)

            elif data.startswith("unban_t_page:"):
                page = int(data.split(":")[1])
                await _unban_teachers_page(query, page=page)

            elif data.startswith("unban_t:"):
                uid = data.split(":", 1)[1]
                teacher = await user_service.get_by_id(uid)
                if not teacher:
                    await query.edit_message_text("❌ المدرس غير موجود.")
                    return

                plan_name = await _get_teacher_plan_name(uid)
                student_count = await student_service.count(uid)
                info = _format_teacher_info(teacher, plan_name, student_count)

                keyboard = []
                if not teacher.get("is_active", True):
                    keyboard.append([InlineKeyboardButton("فك الحظر", callback_data=f"do_unban_t:{uid}")])
                keyboard.append([InlineKeyboardButton("إعادة تعيين كلمة المرور", callback_data=f"reset_pwd:{uid}")])
                keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_teachers")])

                await query.edit_message_text(info, reply_markup=InlineKeyboardMarkup(keyboard))

            elif data.startswith("do_unban_t:"):
                uid = data.split(":", 1)[1]
                teacher = await user_service.get_by_id(uid)
                if not teacher:
                    await query.edit_message_text("❌ المدرس غير موجود.")
                    return
                if teacher.get("is_active", True):
                    await query.edit_message_text("⚠️ المدرس غير محظور أصلاً.")
                    return

                await user_service.update(uid, {"is_active": True})
                await query.edit_message_text(
                    f"✅ تم فك حظر المدرس {teacher.get('full_name', '')} بنجاح.",
                )

            elif data.startswith("reset_pwd:"):
                uid = data.split(":", 1)[1]
                teacher = await user_service.get_by_id(uid)
                if not teacher:
                    await query.edit_message_text("❌ المدرس غير موجود.")
                    return
                _user_states[chat_id] = f"waiting_for_new_password:{uid}"
                _user_context[chat_id] = {"teacher_name": teacher.get("full_name", "")}
                await query.edit_message_text(
                    f"🔑 أدخل كلمة المرور الجديدة للمدرس {teacher.get('full_name', '')}:\n\n"
                    "أرسل كلمة المرور الجديدة الآن.",
                )

            elif data == "unban_students":
                await _unban_students_page(query, page=0)

            elif data.startswith("unban_s_page:"):
                page = int(data.split(":")[1])
                await _unban_students_page(query, page=page)

            elif data.startswith("unban_s:"):
                sid = data.split(":", 1)[1]
                student = await student_service.get_by_id(sid)
                if not student:
                    await query.edit_message_text("❌ الطالب غير موجود.")
                    return

                teacher = None
                teacher_id = student.get("teacher_id")
                if teacher_id:
                    teacher = await user_service.get_by_id(str(teacher_id))

                grades_summary = await _get_student_grades_summary(sid)
                attendance_summary = await _get_student_attendance_summary(sid)
                info = _format_student_info(student, teacher, grades_summary, attendance_summary)

                keyboard = []
                if not student.get("is_active", True):
                    keyboard.append([InlineKeyboardButton("فك الحظر", callback_data=f"do_unban_s:{sid}")])
                keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_students")])

                await query.edit_message_text(info, reply_markup=InlineKeyboardMarkup(keyboard))

            elif data.startswith("do_unban_s:"):
                sid = data.split(":", 1)[1]
                student = await student_service.get_by_id(sid)
                if not student:
                    await query.edit_message_text("❌ الطالب غير موجود.")
                    return
                if student.get("is_active", True):
                    await query.edit_message_text("⚠️ الطالب غير محظور أصلاً.")
                    return

                await student_service.update(sid, {"is_active": True})
                await query.edit_message_text(
                    f"✅ تم فك حظر الطالب {student.get('full_name', '')} بنجاح.",
                )

            elif data == "search_student":
                _user_states[chat_id] = "waiting_for_student_search"
                await query.edit_message_text(
                    "🔍 أرسل كود الطالب للبحث عنه:",
                )

            elif data == "noop":
                await query.answer("")

            elif data == "back":
                keyboard = _main_menu_keyboard()
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

                keyboard = _main_menu_keyboard()
                reply_markup = InlineKeyboardMarkup(keyboard)
                await update.message.reply_text("اختر من الأزرار:", reply_markup=reply_markup)

            elif state and state.startswith("waiting_for_new_password:"):
                uid = state.split(":", 1)[1]
                new_password = update.message.text.strip()
                if len(new_password) < 6:
                    await update.message.reply_text(
                        "❌ كلمة المرور قصيرة جداً. يجب أن تكون 6 أحرف على الأقل.\nأرسل كلمة مرور جديدة:"
                    )
                    return

                try:
                    await user_service.update(uid, {"password": new_password})
                    teacher_name = _user_context.get(chat_id, {}).get("teacher_name", "")
                    await update.message.reply_text(
                        f"✅ تم إعادة تعيين كلمة المرور بنجاح للمدرس {teacher_name}."
                    )
                except Exception as e:
                    logger.error("Failed to reset password for %s: %s", uid, e)
                    await update.message.reply_text("❌ حدث خطأ أثناء إعادة تعيين كلمة المرور.")

                _user_states.pop(chat_id, None)
                _user_context.pop(chat_id, None)

                keyboard = _main_menu_keyboard()
                reply_markup = InlineKeyboardMarkup(keyboard)
                await update.message.reply_text("اختر من الأزرار:", reply_markup=reply_markup)

            elif state == "waiting_for_student_search":
                search_code = update.message.text.strip()
                student = await student_service.get_by_code(search_code)
                if not student:
                    students = await student_service.repo.search(
                        text_search={"full_name": search_code},
                        limit=20,
                    )
                    if students:
                        from telegram import InlineKeyboardButton, InlineKeyboardMarkup
                        keyboard = []
                        for s in students[:10]:
                            sid = _get_user_id_str(s["id"])
                            label = f"{s.get('full_name', '?')} ({s.get('code', '?')})"
                            keyboard.append([InlineKeyboardButton(label, callback_data=f"unban_s:{sid}")])
                        keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_menu")])
                        await update.message.reply_text(
                            f"🔍 نتائج البحث عن '{search_code}':",
                            reply_markup=InlineKeyboardMarkup(keyboard),
                        )
                    else:
                        await update.message.reply_text(
                            f"❌ لم يتم العثور على طالب بالكود '{search_code}'.\n"
                            "جرب البحث بالاسم أو أرسل كود آخر:"
                        )
                    return

                _user_states.pop(chat_id, None)

                teacher = None
                teacher_id = student.get("teacher_id")
                if teacher_id:
                    teacher = await user_service.get_by_id(str(teacher_id))

                grades_summary = await _get_student_grades_summary(student["id"])
                attendance_summary = await _get_student_attendance_summary(student["id"])
                info = _format_student_info(student, teacher, grades_summary, attendance_summary)

                from telegram import InlineKeyboardButton, InlineKeyboardMarkup
                keyboard = []
                if not student.get("is_active", True):
                    sid = _get_user_id_str(student["id"])
                    keyboard.append([InlineKeyboardButton("فك الحظر", callback_data=f"do_unban_s:{sid}")])
                keyboard.append([InlineKeyboardButton("🔙 رجوع", callback_data="unban_menu")])

                await update.message.reply_text(info, reply_markup=InlineKeyboardMarkup(keyboard))

            else:
                keyboard = _main_menu_keyboard()
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
