import os
import logging
import asyncio
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Request, HTTPException, Depends
import httpx

from src.core.config import get_settings
from src.utils.dependencies import get_current_admin
from src.core.security.crypto_utils import generate_license_key
from src.services import (
    subscription_plan_service,
    subscription_code_service,
    teacher_subscription_service,
    payment_request_service,
    notification_service,
)
from src.services.fcm_service import send_push_notification, send_push_to_all

logger = logging.getLogger("darsak")
settings = get_settings()

router = APIRouter()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", settings.TELEGRAM_BOT_TOKEN)
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", settings.TELEGRAM_CHAT_ID)
SUPABASE_URL = os.environ.get("SUPABASE_URL", settings.SUPABASE_URL).rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", settings.SUPABASE_SERVICE_ROLE_KEY)

TG_API = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"
SB_HEADERS = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
_user_states: dict[int, str] = {}


# ─── Telegram API helpers ──────────────────────────────────────────────


def is_authorized(chat_id: int) -> bool:
    if not TELEGRAM_CHAT_ID:
        return True
    return str(chat_id) == str(TELEGRAM_CHAT_ID)


async def tg_send(chat_id: int, text: str, keyboard=None, parse_mode="Markdown"):
    payload = {"chat_id": chat_id, "text": text, "parse_mode": parse_mode}
    if keyboard:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            await c.post(f"{TG_API}/sendMessage", json=payload)
    except Exception as e:
        logger.error("tg_send: %s", e)


async def tg_edit(chat_id, msg_id, text, keyboard=None, parse_mode="Markdown"):
    payload = {"chat_id": chat_id, "message_id": msg_id, "text": text, "parse_mode": parse_mode}
    if keyboard:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            await c.post(f"{TG_API}/editMessageText", json=payload)
    except Exception as e:
        logger.error("tg_edit: %s", e)


async def tg_answer(callback_id, text=None):
    payload = {"callback_query_id": callback_id}
    if text:
        payload["text"] = text
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            await c.post(f"{TG_API}/answerCallbackQuery", json=payload)
    except Exception:
        pass


# ─── Supabase direct query helper ──────────────────────────────────────


async def sb_query(table, filters=None, limit=100, order="created_at.desc"):
    """Direct Supabase REST API query — no SupabaseRepository dependency."""
    params = {"limit": limit}
    if order:
        col, _, desc = order.partition(".")
        params["order"] = f"{col}.{'desc' if desc == 'desc' else 'asc'}"
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    if filters:
        parts = []
        for k, v in filters.items():
            if v is None:
                continue
            parts.append(f"{k}=eq.{v}")
        if parts:
            url += "?" + "&".join(parts) + f"&limit={limit}"
            if order:
                url += f"&order={params['order']}"
    else:
        url += f"?limit={limit}"
        if order:
            url += f"&order={params['order']}"

    try:
        async with httpx.AsyncClient(timeout=15) as c:
            resp = await c.get(url, headers=SB_HEADERS)
            if resp.status_code == 200:
                return resp.json()
            logger.error("sb_query %s failed: %s %s", table, resp.status_code, resp.text[:200])
            return []
    except Exception as e:
        logger.error("sb_query %s error: %s", table, e)
        return []


async def sb_update(table, filters, data):
    """Update rows in Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    parts = []
    for k, v in filters.items():
        parts.append(f"{k}=eq.{v}")
    if parts:
        url += "?" + "&".join(parts)
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            resp = await c.patch(
                url,
                headers={**SB_HEADERS, "Content-Type": "application/json", "Prefer": "return=minimal"},
                json=data,
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        logger.error("sb_update %s error: %s", table, e)
        return False


async def sb_insert(table, data):
    """Insert row in Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            resp = await c.post(
                url,
                headers={**SB_HEADERS, "Content-Type": "application/json", "Prefer": "return=representation"},
                json=data,
            )
            if resp.status_code in (200, 201):
                result = resp.json()
                return result[0] if isinstance(result, list) and result else result
    except Exception as e:
        logger.error("sb_insert %s error: %s", table, e)
    return None


async def set_admin_config(key: str, value: str) -> bool:
    """Upsert an admin_config row. Returns True on success."""
    try:
        ok = await sb_update("admin_config", {"key": key},
                             {"value": value, "updated_at": datetime.now(timezone.utc).isoformat()})
        if not ok:
            await sb_insert("admin_config", {"key": key, "value": value})
        return True
    except Exception as e:
        logger.error("set_admin_config(%s): %s", key, e)
        return False


# ─── Main menu ─────────────────────────────────────────────────────────


def main_menu():
    return [
        [{"text": "🔑 توليد كود", "callback_data": "generate_code"}],
        [{"text": "🔍 فحص كود", "callback_data": "check_code"}],
        [{"text": "📋 الباقات", "callback_data": "list_plans"}],
        [{"text": "📊 إحصائيات", "callback_data": "stats"}],
        [{"text": "🔍 بحث برقم العملية", "callback_data": "search_payment"}],
        [{"text": "💰 أرباح المنصة", "callback_data": "platform_profit"}],
        [{"text": "🏦 المالية", "callback_data": "finance_menu"}],
        [{"text": "🔄 التحويلات", "callback_data": "transfers_menu"}],
        [{"text": "💰 رأس المال", "callback_data": "capital_management"}],
        [{"text": "💳 إعدادات الدفع", "callback_data": "payment_settings"}],
        [{"text": "فك حظر مستخدم", "callback_data": "unban_menu"}],
        [{"text": "🛑 إيقاف الخدمة", "callback_data": "maintenance_menu"}],
        [{"text": "✅ إعادة التشغيل", "callback_data": "maintenance_restore"}],
    ]


# ─── /start handler ────────────────────────────────────────────────────


async def handle_start(chat_id: int, username: str = None):
    if is_authorized(chat_id):
        await tg_send(
            chat_id,
            "🎓 *بوت إدارة دَرسَك AI*\n\nاختر من القائمة:",
            keyboard=main_menu(),
        )
        return

    # Student flow — ask for phone number
    _user_states[chat_id] = "waiting_for_student_phone"
    await tg_send(
        chat_id,
        "🎓 *مرحباً بك في بوت دَرسَك AI*\n\n"
        "لربط حسابك بالبوت، أرسل رقم تليفونك المسجل به في التطبيق.\n"
        "سيصلك كود الطالب والرقم السري عند قبولك من المدرس.",
        parse_mode="Markdown",
    )


async def handle_deep_link(chat_id: int, student_code: str):
    """Student links Telegram account via /start STUDENT_CODE"""
    students = await sb_query("students", {"code": student_code}, limit=1)
    if not students:
        await tg_send(chat_id, "لم يتم العثور على حسابك. تأكد من استخدام الرابط الصحيح.")
        return
    student = students[0]
    # Save telegram chat_id with phone
    existing = await sb_query("student_telegram_links", {"telegram_chat_id": str(chat_id)}, limit=1)
    data = {
        "student_id": student["id"],
        "teacher_id": student.get("teacher_id"),
        "telegram_chat_id": str(chat_id),
        "phone": student.get("phone"),
        "is_active": True,
    }
    if existing:
        await sb_update("student_telegram_links", {"telegram_chat_id": str(chat_id)}, data)
    else:
        await sb_insert("student_telegram_links", data)
    await tg_send(chat_id, f"تم ربط حسابك بنجاح!\nالاسم: {student.get('full_name', '—')}\nالكود: `{student_code}`\n\nسيصلك كود الطالب ورقمك السري عند قبولك من المدرس.")


# ─── Message handler (text input) ──────────────────────────────────────


async def handle_message(chat_id: int, text: str):
    state = _user_states.get(chat_id)

    # ── Student phone registration ──
    if state == "waiting_for_student_phone":
        _user_states.pop(chat_id, None)
        phone = text.strip()
        # Normalize phone
        phone = phone.replace(" ", "").replace("-", "")
        if phone.startswith("002"):
            phone = phone[3:]
        elif phone.startswith("+2"):
            phone = phone[1:]

        # First try students table (already approved)
        students = await sb_query("students", {"phone": phone}, limit=5)
        if students:
            s = students[0]
            existing = await sb_query("student_telegram_links", {"telegram_chat_id": str(chat_id)}, limit=1)
            data = {
                "student_id": s["id"],
                "teacher_id": s.get("teacher_id"),
                "telegram_chat_id": str(chat_id),
                "phone": phone,
                "is_active": True,
            }
            if existing:
                await sb_update("student_telegram_links", {"telegram_chat_id": str(chat_id)}, data)
            else:
                await sb_insert("student_telegram_links", data)
            await tg_send(
                chat_id,
                f"تم ربط حسابك بنجاح!\n\n"
                f"👤 الاسم: {s.get('full_name', '—')}\n"
                f"🆔 الكود: `{s.get('code', '—')}`\n\n"
                f"يمكنك تسجيل الدخول لتطبيق الدرساك.",
                parse_mode="Markdown",
            )
            return

        # Try admission requests (pending or approved)
        admissions = await sb_query("student_admission_requests", {"phone": phone}, limit=5)
        pending = [a for a in admissions if a.get("status") in ("pending", "approved")]
        if pending:
            a = pending[0]
            # Save link with phone (no student_id yet)
            existing = await sb_query("student_telegram_links", {"telegram_chat_id": str(chat_id)}, limit=1)
            data = {
                "teacher_id": a.get("teacher_id"),
                "telegram_chat_id": str(chat_id),
                "phone": phone,
                "is_active": True,
            }
            if existing:
                await sb_update("student_telegram_links", {"telegram_chat_id": str(chat_id)}, data)
            else:
                await sb_insert("student_telegram_links", data)

            if a.get("status") == "approved" and a.get("student_id"):
                # Already approved — send credentials
                s_list = await sb_query("students", {"id": a["student_id"]}, limit=1)
                if s_list:
                    s = s_list[0]
                    await tg_send(
                        chat_id,
                        f"تم ربط حسابك!\n\n"
                        f"👤 الاسم: {a.get('full_name', '—')}\n"
                        f"🆔 الكود: `{s.get('code', '—')}`\n\n"
                        f"يمكنك تسجيل الدخول لتطبيق الدرساك.",
                        parse_mode="Markdown",
                    )
                else:
                    await tg_send(chat_id, "تم حفظ رقمك. سيتم إرسال بيانات حسابك عند قبولك من المدرس.")
            else:
                await tg_send(
                    chat_id,
                    f"تم حفظ رقمك: `{phone}`\n\n"
                    f"⏳ طلب التسجيل معلق — سيتم إرسال كود الطالب والرقم السري فور قبولك من المدرس.",
                    parse_mode="Markdown",
                )
            return

        # Not found
        _user_states[chat_id] = "waiting_for_student_phone"
        await tg_send(
            chat_id,
            f"❌ لم يتم العثور على حساب بالرقم `{phone}`.\n\n"
            "تأكد من صحة الرقم والمسجل به في التطبيق.\nأرسل الرقم مرة أخرى:",
            parse_mode="Markdown",
        )
        return

    # ── Admin-only states below ──
    if not is_authorized(chat_id):
        await tg_send(chat_id, "اختر من القائمة:", keyboard=main_menu())
        return

    # ── Waiting for code check ──
    if state == "waiting_for_code_check":
        _user_states.pop(chat_id, None)
        code = text.strip().upper()
        codes = await sb_query("subscription_codes", {"code": code}, limit=1)
        if not codes:
            await tg_send(chat_id, "الكود غير صالح.")
        elif codes[0].get("is_used"):
            await tg_send(chat_id, f"هذا الكود مستخدم بالفعل.")
        else:
            await tg_send(chat_id, f"الكود صالح! الباقة: {codes[0].get('plan_id', 'غير معروفة')}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for payment search ──
    if state == "waiting_for_payment_search":
        _user_states.pop(chat_id, None)
        payments = await sb_query("payment_requests", {"id": text.strip()}, limit=1)
        if not payments:
            await tg_send(chat_id, "لم يتم العثور على عملية.")
        else:
            p = payments[0]
            await tg_send(chat_id, f"الحالة: {p.get('status', '—')}\nالمبلغ: {p.get('amount', '—')}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for teacher ID (finance search) ──
    if state == "waiting_for_teacher_id":
        _user_states.pop(chat_id, None)
        tid = text.strip()
        wallets = await sb_query("teacher_wallets", {"teacher_id": tid}, limit=1)
        if not wallets:
            await tg_send(chat_id, "لم يتم العثور على محفظة لهذا المدرس.")
        else:
            w = wallets[0]
            payouts = await sb_query("payout_requests", {"teacher_id": tid}, limit=5)
            msg = (
                f"🏦 *محفظة المدرس*\n\n"
                f"💰 الرصيد المتاح: {float(w.get('available_balance', 0)):,.2f} ج.م\n"
                f"⏳ المعلق: {float(w.get('pending_balance', 0)):,.2f} ج.م\n"
                f"📊 إجمالي الأرباح: {float(w.get('total_earned', 0)):,.2f} ج.م\n"
                f"💸 إجمالي المسحوب: {float(w.get('total_withdrawn', 0)):,.2f} ج.م\n\n"
            )
            if payouts:
                msg += "📋 *آخر طلبات السحب:*\n"
                for p in payouts[:3]:
                    msg += f"• {p.get('status', '—')} — {float(p.get('requested_amount', 0)):,.0f} ج.م\n"
            await tg_send(chat_id, msg)
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for reject reason (payment) ──
    if state and state.startswith("reject_msg_"):
        _user_states.pop(chat_id, None)
        await tg_send(chat_id, f"تم رفض الطلب.\nالسبب: {text}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for deposit reject reason ──
    if state and state.startswith("deposit_reject_"):
        dep_id = state.replace("deposit_reject_", "")
        _user_states.pop(chat_id, None)
        try:
            from src.modules.finance.service import finance_service
            await finance_service.process_deposit_reject(dep_id, reason=text)
            await tg_send(chat_id, f"❌ تم رفض الإيداع\nالسبب: {text}")
        except Exception as e:
            logger.error("deposit_reject: %s", e)
            await tg_send(chat_id, f"خطأ: {str(e)[:100]}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for Vodafone Cash number ──
    if state == "waiting_for_vodafone_number":
        _user_states.pop(chat_id, None)
        phone = text.strip().replace(" ", "").replace("-", "")
        if phone.startswith("+2"):
            phone = phone[1:]
        if len(phone) < 10 or not phone.isdigit():
            await tg_send(chat_id, "❌ رقم غير صالح. أرسل رقم صحيح (11 رقم):")
            _user_states[chat_id] = "waiting_for_vodafone_number"
            return
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            await client.table("instapay_config").update({"vodafone_cash_number": phone}).eq("is_active", True).execute()
            masked = f"{phone[:3]}****{phone[-4:]}"
            await tg_send(chat_id, f"✅ تم تحديث رقم فودافون كاش إلى: `{masked}`", parse_mode="Markdown")
        except Exception as e:
            logger.error("update vodafone: %s", e)
            await tg_send(chat_id, f"❌ خطأ: {str(e)[:100]}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for Instapay username ──
    if state == "waiting_for_instapay_username":
        _user_states.pop(chat_id, None)
        username = text.strip()
        if "@" not in username or len(username) < 5:
            await tg_send(chat_id, "❌ يوزرنيم غير صالح. أرسل يوزرنيم صحيح:")
            _user_states[chat_id] = "waiting_for_instapay_username"
            return
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            await client.table("instapay_config").update({"username": username}).eq("is_active", True).execute()
            await tg_send(chat_id, f"✅ تم تحديث يوزرنيم إنستاباي إلى: `{username}`", parse_mode="Markdown")
        except Exception as e:
            logger.error("update instapay: %s", e)
            await tg_send(chat_id, f"❌ خطأ: {str(e)[:100]}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── Waiting for capital percentage ──
    if state.startswith("waiting_capital_pct_"):
        cat = state.replace("waiting_capital_pct_", "")
        _user_states.pop(chat_id, None)
        try:
            pct = float(text.strip().replace("%", ""))
            if pct < 0 or pct > 100:
                raise ValueError("out of range")
        except ValueError:
            await tg_send(chat_id, "❌ نسبة غير صالحة. أرسل رقم من 0 إلى 100:")
            _user_states[chat_id] = f"waiting_capital_pct_{cat}"
            return
        try:
            await sb_update("platform_capital", {"category": cat},
                            {"percentage": pct, "updated_at": datetime.now(timezone.utc).isoformat()})
            # Verify total doesn't exceed 100%
            rows = await sb_query("platform_capital", limit=10)
            total = sum(float(r.get("percentage", 0)) for r in rows)
            status = "⚠️ مجموع النسب يتجاوز 100%!" if total > 100.01 else "✅"
            await tg_send(chat_id, f"{status} تم تحديث نسبة `{cat}` إلى {pct:.0f}%\nالمجموع الحالي: {total:.0f}%")
        except Exception as e:
            logger.error("update capital pct: %s", e)
            await tg_send(chat_id, f"❌ خطأ: {str(e)[:100]}")
        await tg_send(chat_id, "اختر:", keyboard=main_menu())
        return

    # ── No state — show menu ──
    await tg_send(chat_id, "اختر من القائمة:", keyboard=main_menu())


# ─── Callback handler ──────────────────────────────────────────────────


async def handle_callback(chat_id: int, message_id: int, data: str):
    if not is_authorized(chat_id):
        return

    # ── Generate code ──
    if data == "generate_code":
        plans = await sb_query("subscription_plans", {"is_active": "true"}, limit=20)
        kb = [[{"text": f"{p['name']} - {p['price_egp']} ج.م", "callback_data": f"plan_{p['id']}"}] for p in plans]
        kb.append([{"text": "🔙 رجوع", "callback_data": "back"}])
        await tg_edit(chat_id, message_id, "اختر الباقة:", keyboard=kb)

    elif data.startswith("plan_"):
        plan_id = data.replace("plan_", "")
        plans = await sb_query("subscription_plans", {"id": plan_id}, limit=1)
        if not plans:
            await tg_edit(chat_id, message_id, "الباقة غير موجودة.")
            return
        plan = plans[0]
        code = generate_license_key()
        expires = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
        await sb_insert("subscription_codes", {"code": code, "plan_id": plan_id, "is_used": False, "expires_at": expires})
        await tg_edit(
            chat_id,
            message_id,
            f"✅ *تم توليد الكود!*\n\nالباقة: {plan['name']}\nالكود: `{code}`\nالسعر: {plan['price_egp']} ج.م",
            keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]],
        )

    elif data == "check_code":
        _user_states[chat_id] = "waiting_for_code_check"
        await tg_edit(chat_id, message_id, "أرسل الكود:")

    elif data == "list_plans":
        plans = await sb_query("subscription_plans", {"is_active": "true"}, limit=20)
        text = "📋 *الباقات:*\n\n"
        for p in plans:
            max_s = str(p.get("max_students", "—"))
            text += f"*{p['name']}*\n💰 {p['price_egp']} ج.م\n👥 {max_s} طالب\n\n"
        await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])

    elif data == "stats":
        codes = await sb_query("subscription_codes", limit=1000)
        plans = await sb_query("subscription_plans", {"is_active": "true"}, limit=20)
        total = len(codes)
        used = sum(1 for c in codes if c.get("is_used"))
        await tg_edit(
            chat_id,
            message_id,
            f"📊 *الإحصائيات:*\n\nالأكواد: {total}\nمستخدم: {used}\nمتبقي: {total - used}\nالباقات: {len(plans)}",
            keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]],
        )

    elif data == "search_payment":
        _user_states[chat_id] = "waiting_for_payment_search"
        await tg_edit(chat_id, message_id, "أرسل رقم العملية:")

    # ── Platform profit ──
    elif data == "platform_profit":
        try:
            wallets = await sb_query("teacher_wallets", limit=100)
            payouts = await sb_query("payout_requests", limit=100)
            subs = await sb_query("teacher_subscriptions", {"is_active": "true"}, limit=100)
            deposits = await sb_query("student_deposit_requests", limit=100)

            total_balance = sum(float(w.get("available_balance", 0)) for w in wallets)
            total_withdrawn = sum(float(w.get("total_withdrawn", 0)) for w in wallets)
            completed_payouts = [p for p in payouts if p.get("status") == "completed"]
            commission = sum(float(p.get("commission_amount", 0)) for p in completed_payouts)
            pending_payouts = [p for p in payouts if p.get("status") == "pending"]
            pending_amount = sum(float(p.get("requested_amount", 0)) for p in pending_payouts)
            approved_deposits = [d for d in deposits if d.get("status") == "approved"]
            deposit_tax = sum(float(d.get("tax_amount", 0)) for d in approved_deposits)
            active_subs = len(subs)

            text = (
                f"💰 *أرباح المنصة*\n\n"
                f"👥 المحافظ: {len(wallets)}\n"
                f"📋 الاشتراكات النشطة: {active_subs}\n\n"
                f"💵 أرصدة المدرسين: {total_balance:,.2f} ج.م\n"
                f"💸 المسحوب: {total_withdrawn:,.2f} ج.م\n\n"
                f"🏦 عمولة السحبات: {commission:,.2f} ج.م\n"
                f"📊 ضريبة الإيداعات: {deposit_tax:,.2f} ج.م\n"
                f"📋 طلبات سحب معلقة: {len(pending_payouts)} = {pending_amount:,.2f} ج.م\n"
            )
            await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        except Exception as e:
            logger.error("platform_profit: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])

    # ── Finance menu ──
    elif data == "finance_menu":
        kb = [
            [{"text": "🔍 بحث عن مدرس", "callback_data": "finance_search_teacher"}],
            [{"text": "👥 كل المدرسين", "callback_data": "finance_all_teachers"}],
            [{"text": "📊 إجمالي الماليات", "callback_data": "finance_overview"}],
            [{"text": "🔙 رجوع", "callback_data": "back"}],
        ]
        await tg_edit(chat_id, message_id, "🏦 *المالية*\n\nاختر:", keyboard=kb)

    elif data == "finance_search_teacher":
        _user_states[chat_id] = "waiting_for_teacher_id"
        await tg_edit(chat_id, message_id, "أرسل معرف المدرس (UUID):")

    elif data == "finance_all_teachers":
        try:
            teachers = await sb_query("users", {"role": "teacher"}, limit=100, order="created_at.desc")
            if not teachers:
                await tg_edit(chat_id, message_id, "لا يوجد مدرسين مسجلين.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "finance_menu"}]])
                return
            wallets = await sb_query("teacher_wallets", limit=100)
            wallet_map = {str(w.get("teacher_id")): w for w in wallets}
            lines = [f"👥 *كل المدرسين* ({len(teachers)}):\n"]
            for t in teachers[:20]:
                tid = str(t.get("id", ""))
                tid_short = tid[:8]
                name = t.get("full_name", "غير معروف")
                email = t.get("email", "—")
                w = wallet_map.get(tid)
                avail = float(w.get("available_balance", 0)) if w else 0.0
                pending = float(w.get("pending_balance", 0)) if w else 0.0
                withdrawn = float(w.get("total_withdrawn", 0)) if w else 0.0
                lines.append(f"👤 {name}\n🆔 `{tid_short}...` | 💰 {avail:,.0f} | ⏳ {pending:,.0f} | 💸 {withdrawn:,.0f}")
            text = "\n".join(lines)
            if len(text) > 4000:
                text = text[:3950] + "\n..."
            await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "finance_menu"}]])
        except Exception as e:
            logger.error("finance_all_teachers: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "finance_menu"}]])

    elif data == "finance_overview":
        try:
            wallets = await sb_query("teacher_wallets", limit=100)
            payouts = await sb_query("payout_requests", limit=100)
            total_avail = sum(float(w.get("available_balance", 0)) for w in wallets)
            total_pending = sum(float(w.get("pending_balance", 0)) for w in wallets)
            total_withdrawn = sum(float(w.get("total_withdrawn", 0)) for w in wallets)
            completed = [p for p in payouts if p.get("status") == "completed"]
            commission = sum(float(p.get("commission_amount", 0)) for p in completed)
            pending = sum(float(p.get("requested_amount", 0)) for p in payouts if p.get("status") == "pending")
            text = (
                f"📊 *إجمالي الماليات*\n\n"
                f"المحافظ: {len(wallets)}\n\n"
                f"💰 المتاح: {total_avail:,.2f} ج.م\n"
                f"⏳ المعلق: {total_pending:,.2f} ج.م\n"
                f"💸 المسحوب: {total_withdrawn:,.2f} ج.م\n\n"
                f"🏦 العمولة: {commission:,.2f} ج.م\n"
                f"📋 معلقة: {pending:,.2f} ج.م\n"
            )
            await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "finance_menu"}]])
        except Exception as e:
            logger.error("finance_overview: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "finance_menu"}]])

    # ── Deposit approve/reject ──
    elif data.startswith("deposit_approve:"):
        dep_id = data.split(":", 1)[1]
        try:
            from src.modules.finance.service import finance_service
            result = await finance_service.process_deposit_approve(dep_id)
            dep_data = (await sb_query("student_deposit_requests", {"id": dep_id}, limit=1) or [{}])[0]
            amount = float(dep_data.get("amount", 0))
            tax_amount = float(dep_data.get("tax_amount", 0))
            student_id = dep_data.get("student_id")
            # Track deposit tax revenue
            if tax_amount > 0:
                caps = await sb_query("platform_capital", limit=10)
                cap_pcts = {r["category"]: float(r.get("percentage", 0)) for r in caps}
                total_pct = sum(cap_pcts.values()) or 100
                def _dshare(amt, cat):
                    return round(amt * cap_pcts.get(cat, 0) / total_pct, 2)
                await sb_insert("deposit_revenue", {
                    "deposit_id": dep_id,
                    "student_id": student_id,
                    "tax_amount": tax_amount,
                    "platform_share": _dshare(tax_amount, "platform"),
                    "operations_share": _dshare(tax_amount, "operations"),
                    "emergency_share": _dshare(tax_amount, "emergency"),
                    "labor_share": _dshare(tax_amount, "labor"),
                    "marketing_share": _dshare(tax_amount, "marketing"),
                })
            await tg_edit(chat_id, message_id, f"✅ *تم تأكيد الإيداع*\n\nالمبلغ: {amount:,.2f}\nالرصيد الجديد: {result['new_balance']:,.2f}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        except Exception as e:
            logger.error("deposit_approve: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}")

    elif data.startswith("deposit_reject:"):
        dep_id = data.split(":", 1)[1]
        _user_states[chat_id] = f"deposit_reject_{dep_id}"
        await tg_edit(chat_id, message_id, "اكتب سبب الرفض:")

    # ── Payout approve/reject ──
    elif data.startswith("payout_confirm:") or data.startswith("payout_reject:"):
        payout_id = data.split(":", 1)[1]
        action = "confirm" if data.startswith("payout_confirm:") else "reject"
        try:
            payouts_data = await sb_query("payout_requests", {"id": payout_id}, limit=1)
            if not payouts_data:
                await tg_edit(chat_id, message_id, "طلب السحب غير موجود.")
                return
            payout = payouts_data[0]
            if payout.get("status") != "pending":
                await tg_edit(chat_id, message_id, "تمت معالجته بالفعل.")
                return
            tid = payout.get("teacher_id")
            if action == "confirm":
                # Move from pending to withdrawn
                wallets = await sb_query("teacher_wallets", {"teacher_id": tid}, limit=1)
                if wallets:
                    w = wallets[0]
                    new_pending = max(0, float(w.get("pending_balance", 0)) - float(payout.get("requested_amount", 0)))
                    new_withdrawn = float(w.get("total_withdrawn", 0)) + float(payout.get("net_amount", 0))
                    await sb_update("teacher_wallets", {"teacher_id": tid}, {"pending_balance": new_pending, "total_withdrawn": new_withdrawn})
                await sb_update("payout_requests", {"id": payout_id}, {"status": "completed", "processed_at": datetime.now(timezone.utc).isoformat()})
                # Track commission revenue
                commission = float(payout.get("commission_amount", 0))
                if commission > 0:
                    caps = await sb_query("platform_capital", limit=10)
                    cap_pcts = {r["category"]: float(r.get("percentage", 0)) for r in caps}
                    total_pct = sum(cap_pcts.values()) or 100
                    def _share(amt, cat):
                        return round(amt * cap_pcts.get(cat, 0) / total_pct, 2)
                    await sb_insert("commission_revenue", {
                        "payout_id": payout_id,
                        "teacher_id": tid,
                        "commission_amount": commission,
                        "platform_share": _share(commission, "platform"),
                        "operations_share": _share(commission, "operations"),
                        "emergency_share": _share(commission, "emergency"),
                        "labor_share": _share(commission, "labor"),
                        "marketing_share": _share(commission, "marketing"),
                    })
                await tg_edit(chat_id, message_id, f"✅ *تم تأكيد السحب*\n\nالصافي: {float(payout.get('net_amount', 0)):,.2f} ج.م", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
            else:
                # Refund to available
                wallets = await sb_query("teacher_wallets", {"teacher_id": tid}, limit=1)
                if wallets:
                    w = wallets[0]
                    new_avail = float(w.get("available_balance", 0)) + float(payout.get("requested_amount", 0))
                    new_pending = max(0, float(w.get("pending_balance", 0)) - float(payout.get("requested_amount", 0)))
                    await sb_update("teacher_wallets", {"teacher_id": tid}, {"available_balance": new_avail, "pending_balance": new_pending})
                await sb_update("payout_requests", {"id": payout_id}, {"status": "rejected", "processed_at": datetime.now(timezone.utc).isoformat()})
                await tg_edit(chat_id, message_id, "❌ تم رفض السحب. تم استرداد المبلغ.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        except Exception as e:
            logger.error("payout {action}: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}")

    # ── Payment approve/reject (subscription) ──
    elif data.startswith("pay_approve_") or data.startswith("pay_reject_"):
        payment_id = data.replace("pay_approve_", "").replace("pay_reject_", "")
        try:
            payments = await sb_query("payment_requests", {"id": payment_id}, limit=1)
            if not payments:
                await tg_edit(chat_id, message_id, "العملية غير موجودة.")
                return
            p = payments[0]
            if p.get("status") != "pending":
                await tg_edit(chat_id, message_id, "تمت معالجتها بالفعل.")
                return
            if data.startswith("pay_approve_"):
                await sb_update("payment_requests", {"id": payment_id}, {"status": "approved", "admin_message": "تمت الموافقة"})
                # Activate subscription
                try:
                    from datetime import timedelta
                    billing = p.get("billing_period", "monthly")
                    days = 365 if billing == "yearly" else 30
                    expires_at = (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()
                    plan_id = p.get("plan_id")
                    teacher_id = p.get("teacher_id")
                    max_students = int(p.get("max_students", 0) or 0)
                    sub_data = {
                        "teacher_id": teacher_id,
                        "plan_id": plan_id,
                        "code_id": payment_id,
                        "expires_at": expires_at,
                        "is_active": True,
                    }
                    if max_students > 0:
                        sub_data["custom_max_students"] = max_students
                    await sb_insert("teacher_subscriptions", sub_data)
                except Exception as sub_err:
                    logger.error("activate subscription: %s", sub_err)
                # Track subscription revenue
                try:
                    amount = float(p.get("amount", 0))
                    plan_name = p.get("plan_name", "")
                    billing = p.get("billing_period", "monthly")
                    sub_id = p.get("subscription_id")
                    if amount > 0:
                        caps = await sb_query("platform_capital", limit=10)
                        cap_pcts = {r["category"]: float(r.get("percentage", 0)) for r in caps}
                        total_pct = sum(cap_pcts.values()) or 100
                        def _s_share(amt, cat):
                            return round(amt * cap_pcts.get(cat, 0) / total_pct, 2)
                        await sb_insert("subscription_revenue", {
                            "subscription_id": sub_id,
                            "plan_name": plan_name,
                            "billing_period": billing,
                            "total_amount": amount,
                            "platform_share": _s_share(amount, "platform"),
                            "operations_share": _s_share(amount, "operations"),
                            "emergency_share": _s_share(amount, "emergency"),
                            "labor_share": _s_share(amount, "labor"),
                            "marketing_share": _s_share(amount, "marketing"),
                        })
                except Exception as rev_err:
                    logger.error("track subscription revenue: %s", rev_err)
                await tg_edit(chat_id, message_id, "✅ تم تفعيل الاشتراك.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
            else:
                _user_states[chat_id] = f"reject_msg_{payment_id}"
                await tg_edit(chat_id, message_id, "اكتب سبب الرفض:")
        except Exception as e:
            logger.error("pay callback: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}")

    # ── Unban menu ──
    elif data == "unban_menu":
        kb = [
            [{"text": "المدرسين", "callback_data": "unban_teachers"}],
            [{"text": "الطلاب", "callback_data": "unban_students"}],
            [{"text": "🔙 رجوع", "callback_data": "back"}],
        ]
        await tg_edit(chat_id, message_id, "اختر:", keyboard=kb)

    elif data == "unban_teachers":
        teachers = await sb_query("users", {"is_active": "false", "role": "teacher"}, limit=20)
        if not teachers:
            await tg_edit(chat_id, message_id, "لا يوجد مدرسين محظورين.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "unban_menu"}]])
            return
        kb = [[{"text": f"{t.get('full_name', '—')} ({t.get('email', '—')})", "callback_data": f"unban_user_{t['id']}"}] for t in teachers[:10]]
        kb.append([{"text": "🔙 رجوع", "callback_data": "unban_menu"}])
        await tg_edit(chat_id, message_id, "المدرسين المحظورين:", keyboard=kb)

    elif data == "unban_students":
        students = await sb_query("students", {"is_active": "false"}, limit=20)
        if not students:
            await tg_edit(chat_id, message_id, "لا يوجد طلاب محظورين.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "unban_menu"}]])
            return
        kb = [[{"text": f"{s.get('full_name', '—')} ({s.get('code', '—')})", "callback_data": f"unban_student_{s['id']}"}] for s in students[:10]]
        kb.append([{"text": "🔙 رجوع", "callback_data": "unban_menu"}])
        await tg_edit(chat_id, message_id, "الطلاب المحظورين:", keyboard=kb)

    elif data.startswith("unban_user_"):
        uid = data.replace("unban_user_", "")
        await sb_update("users", {"id": uid}, {"is_active": True})
        await tg_edit(chat_id, message_id, "✅ تم فك الحظر.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "unban_menu"}]])

    elif data.startswith("unban_student_"):
        sid = data.replace("unban_student_", "")
        await sb_update("students", {"id": sid}, {"is_active": True})
        await tg_edit(chat_id, message_id, "✅ تم فك الحظر.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "unban_menu"}]])

    # ── Payment settings ──
    elif data == "payment_settings":
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            result = client.table("instapay_config").select("vodafone_cash_number, username").eq("is_active", True).limit(1).execute()
            rows = result.data if hasattr(result, "data") else []
            phone = rows[0].get("vodafone_cash_number", "01031524947") if rows else "01031524947"
            instapay = rows[0].get("username", "—") if rows else "—"
            masked = f"{phone[:3]}****{phone[-4:]}"
            text = (
                f"💳 *إعدادات الدفع*\n\n"
                f"📱 فودافون كاش: `{masked}`\n"
                f"🏦 إنستاباي: `{instapay}`\n\n"
                f"اختر ما تريد تغييره:"
            )
            kb = [
                [{"text": "📱 تغيير رقم فودافون كاش", "callback_data": "edit_vodafone"}],
                [{"text": "🏦 تغيير يوزرنيم إنستاباي", "callback_data": "edit_instapay"}],
                [{"text": "🔙 رجوع", "callback_data": "back"}],
            ]
            await tg_edit(chat_id, message_id, text, keyboard=kb, parse_mode="Markdown")
        except Exception as e:
            logger.error("payment_settings: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}")

    elif data == "edit_vodafone":
        _user_states[chat_id] = "waiting_for_vodafone_number"
        await tg_edit(chat_id, message_id, "📱 أرسل رقم فودافون كاش الجديد:\n\nمثال: `01031524947`", parse_mode="Markdown")

    elif data == "edit_instapay":
        _user_states[chat_id] = "waiting_for_instapay_username"
        await tg_edit(chat_id, message_id, "🏦 أرسل يوزرنيم إنستاباي الجديد:\n\nمثال: `ahmed-mahmoud-1@instapay`", parse_mode="Markdown")

    # ── Capital management ──
    elif data == "capital_management":
        try:
            rows = await sb_query("platform_capital", limit=10, order="percentage.desc")
            if not rows:
                await tg_edit(chat_id, message_id, "لا توجد بيانات رأس المال بعد.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
                return
            total_bal = sum(float(r.get("current_balance", 0)) for r in rows)
            total_inflow = sum(float(r.get("total_inflow", 0)) for r in rows)
            lines = [f"💰 *رأس المال*\n\nإجمالي التدفق: {total_inflow:,.2f} ج.م\nالرصيد الحالي: {total_bal:,.2f} ج.م\n\n📊 *التوزيع حسب النسب:*\n"]
            for r in rows:
                pct = float(r.get("percentage", 0))
                name = r.get("name_ar", r.get("category", "—"))
                bal = float(r.get("current_balance", 0))
                inflow = float(r.get("total_inflow", 0))
                bar_len = int(pct / 5)
                bar = "█" * bar_len + "░" * (20 - bar_len)
                lines.append(f"*{name}* ({pct:.0f}%)\n`{bar}`\n  💰 {bal:,.0f} | 📈 {inflow:,.0f} ج.م\n")
            text = "\n".join(lines)
            kb = [
                [{"text": "✏️ تعديل النسب", "callback_data": "edit_capital_pct"}],
                [{"text": "📊 تفصيل الأرباح", "callback_data": "capital_revenue_detail"}],
                [{"text": "🔙 رجوع", "callback_data": "back"}],
            ]
            await tg_edit(chat_id, message_id, text, keyboard=kb)
        except Exception as e:
            logger.error("capital_management: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])

    elif data == "edit_capital_pct":
        rows = await sb_query("platform_capital", limit=10, order="percentage.desc")
        kb = []
        for r in rows:
            cat = r.get("category", "")
            name = r.get("name_ar", cat)
            pct = float(r.get("percentage", 0))
            kb.append([{"text": f"{name} ({pct:.0f}%)", "callback_data": f"edit_pct_{cat}"}])
        kb.append([{"text": "🔙 رجوع", "callback_data": "capital_management"}])
        await tg_edit(chat_id, message_id, "اختر الفئة لتعديل النسبة:", keyboard=kb)

    elif data.startswith("edit_pct_"):
        cat = data.replace("edit_pct_", "")
        _user_states[chat_id] = f"waiting_capital_pct_{cat}"
        await tg_edit(chat_id, message_id, f"أرسل النسبة الجديدة لـ `{cat}` (0-100):", parse_mode="Markdown")

    elif data == "capital_revenue_detail":
        try:
            subs = await sb_query("subscription_revenue", limit=100)
            deposits = await sb_query("deposit_revenue", limit=100)
            commissions = await sb_query("commission_revenue", limit=100)

            total_sub = sum(float(s.get("total_amount", 0)) for s in subs)
            total_dep_tax = sum(float(d.get("tax_amount", 0)) for d in deposits)
            total_comm = sum(float(c.get("commission_amount", 0)) for c in commissions)
            total_rev = total_sub + total_dep_tax + total_comm

            def shares(items, key):
                return sum(float(i.get(key, 0)) for i in items)

            p_shares = shares(subs, "platform_share") + shares(deposits, "platform_share") + shares(commissions, "platform_share")
            o_shares = shares(subs, "operations_share") + shares(deposits, "operations_share") + shares(commissions, "operations_share")
            e_shares = shares(subs, "emergency_share") + shares(deposits, "emergency_share") + shares(commissions, "emergency_share")
            l_shares = shares(subs, "labor_share") + shares(deposits, "labor_share") + shares(commissions, "labor_share")
            m_shares = shares(subs, "marketing_share") + shares(deposits, "marketing_share") + shares(commissions, "marketing_share")

            text = (
                f"📊 *تفصيل الأرباح*\n\n"
                f"💵 إجمالي الإيراد: {total_rev:,.2f} ج.م\n\n"
                f"📦 الاشتراكات: {total_sub:,.2f} ({len(subs)})\n"
                f"🏦 ضرائب الإيداعات: {total_dep_tax:,.2f} ({len(deposits)})\n"
                f"💸 العمولات: {total_comm:,.2f} ({len(commissions)})\n\n"
                f"📊 *التوزيع:*\n"
                f"🖥 المنصة (35%): {p_shares:,.2f}\n"
                f"⚙️ التشغيل (25%): {o_shares:,.2f}\n"
                f"🛡 الاحتياطي (20%): {e_shares:,.2f}\n"
                f"👷 العمالة (15%): {l_shares:,.2f}\n"
                f"📢 التسويق (5%): {m_shares:,.2f}\n"
            )
            kb = [
                [{"text": "🔄 تحديث التوزيع", "callback_data": "capital_distribute_now"}],
                [{"text": "🔙 رجوع", "callback_data": "capital_management"}],
            ]
            await tg_edit(chat_id, message_id, text, keyboard=kb)
        except Exception as e:
            logger.error("capital_revenue_detail: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "capital_management"}]])

    elif data == "capital_distribute_now":
        try:
            # Distribute pending subscription revenue
            subs_pending = await sb_query("subscription_revenue", {"status": "pending"}, limit=100)
            caps = await sb_query("platform_capital", limit=10)
            cap_map = {r["category"]: r for r in caps}

            for s in subs_pending:
                for cat, key in [("platform", "platform_share"), ("operations", "operations_share"),
                                 ("emergency", "emergency_share"), ("labor", "labor_share"),
                                 ("marketing", "marketing_share")]:
                    amt = float(s.get(key, 0))
                    cap = cap_map.get(cat)
                    if cap:
                        new_bal = float(cap.get("current_balance", 0)) + amt
                        new_inflow = float(cap.get("total_inflow", 0)) + amt
                        await sb_update("platform_capital", {"category": cat},
                                        {"current_balance": new_bal, "total_inflow": new_inflow, "updated_at": datetime.now(timezone.utc).isoformat()})
                        cap_map[cat] = {**cap, "current_balance": new_bal, "total_inflow": new_inflow}
                await sb_update("subscription_revenue", {"id": s["id"]},
                                {"status": "distributed", "distributed_at": datetime.now(timezone.utc).isoformat()})

            # Distribute pending deposit revenue
            dep_pending = await sb_query("deposit_revenue", {"status": "pending"}, limit=100)
            for d in dep_pending:
                for cat, key in [("platform", "platform_share"), ("operations", "operations_share"),
                                 ("emergency", "emergency_share"), ("labor", "labor_share"),
                                 ("marketing", "marketing_share")]:
                    amt = float(d.get(key, 0))
                    cap = cap_map.get(cat)
                    if cap:
                        new_bal = float(cap.get("current_balance", 0)) + amt
                        new_inflow = float(cap.get("total_inflow", 0)) + amt
                        await sb_update("platform_capital", {"category": cat},
                                        {"current_balance": new_bal, "total_inflow": new_inflow, "updated_at": datetime.now(timezone.utc).isoformat()})
                        cap_map[cat] = {**cap, "current_balance": new_bal, "total_inflow": new_inflow}
                await sb_update("deposit_revenue", {"id": d["id"]},
                                {"status": "distributed", "distributed_at": datetime.now(timezone.utc).isoformat()})

            # Distribute pending commission revenue
            comm_pending = await sb_query("commission_revenue", {"status": "pending"}, limit=100)
            for c in comm_pending:
                for cat, key in [("platform", "platform_share"), ("operations", "operations_share"),
                                 ("emergency", "emergency_share"), ("labor", "labor_share"),
                                 ("marketing", "marketing_share")]:
                    amt = float(c.get(key, 0))
                    cap = cap_map.get(cat)
                    if cap:
                        new_bal = float(cap.get("current_balance", 0)) + amt
                        new_inflow = float(cap.get("total_inflow", 0)) + amt
                        await sb_update("platform_capital", {"category": cat},
                                        {"current_balance": new_bal, "total_inflow": new_inflow, "updated_at": datetime.now(timezone.utc).isoformat()})
                        cap_map[cat] = {**cap, "current_balance": new_bal, "total_inflow": new_inflow}
                await sb_update("commission_revenue", {"id": c["id"]},
                                {"status": "distributed", "distributed_at": datetime.now(timezone.utc).isoformat()})

            total_distributed = len(subs_pending) + len(dep_pending) + len(comm_pending)
            await tg_edit(chat_id, message_id,
                          f"✅ *تم توزيع الأرباح*\n\n"
                          f"📦 اشتراكات: {len(subs_pending)}\n"
                          f"🏦 إيداعات: {len(dep_pending)}\n"
                          f"💸 عمولات: {len(comm_pending)}\n"
                          f"المجموع: {total_distributed} معاملة",
                          keyboard=[[{"text": "🔙 رجوع", "callback_data": "capital_management"}]])
        except Exception as e:
            logger.error("capital_distribute_now: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "capital_management"}]])

    # ── Transfers section ──
    elif data == "transfers_menu":
        kb = [
            [{"text": "💸 سحوبات المعلمين", "callback_data": "transfers_teacher_list"}],
            [{"text": "💰 إيداعات الطلاب", "callback_data": "transfers_student_deposits"}],
            [{"text": "🔙 رجوع", "callback_data": "back"}],
        ]
        await tg_edit(chat_id, message_id, "🔄 *التحويلات*\n\nاختر نوع العرض:", keyboard=kb)

    elif data == "transfers_teacher_list":
        try:
            wallets = await sb_query("teacher_wallets", limit=50)
            if not wallets:
                await tg_edit(chat_id, message_id, "لا توجد محفظات معلمين.", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])
                return
            text = "💸 *سحوبات المعلمين*\n\n"
            kb = []
            for w in wallets[:20]:
                teacher_id = w.get("teacher_id", "")
                available = float(w.get("available_balance", 0) or 0)
                withdrawn = float(w.get("total_withdrawn", 0) or 0)
                short_id = str(teacher_id)[:8]
                text_line = f"• {short_id}... | متاح: {available:,.0f} | مُسحب: {withdrawn:,.0f}"
                kb.append([{"text": f"👤 {short_id}...", "callback_data": f"transfers_teacher_{teacher_id}"}])
            kb.append([{"text": "🔙 رجوع", "callback_data": "transfers_menu"}])
            await tg_edit(chat_id, message_id, text, keyboard=kb)
        except Exception as e:
            logger.error("transfers_teacher_list: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])

    elif data.startswith("transfers_teacher_"):
        teacher_id = data.replace("transfers_teacher_", "")
        try:
            payouts = await sb_query("payout_requests", {"teacher_id": teacher_id}, limit=20)
            wallet_rows = await sb_query("teacher_wallets", {"teacher_id": teacher_id}, limit=1)
            wallet = wallet_rows[0] if wallet_rows else {}
            available = float(wallet.get("available_balance", 0) or 0)
            withdrawn = float(wallet.get("total_withdrawn", 0) or 0)
            short_id = str(teacher_id)[:12]
            text = f"💸 *سحوبات المعلم {short_id}*\n\nالمتاح: {available:,.2f} ج.م\nالمحسوب: {withdrawn:,.2f} ج.م\n\n"
            if payouts:
                for p in payouts[:10]:
                    status = p.get("status", "pending")
                    amt = float(p.get("requested_amount", 0) or p.get("amount", 0) or 0)
                    comm_rate = float(p.get("commission_rate", 0) or 0)
                    comm_amt = float(p.get("commission_amount", 0) or 0)
                    net = float(p.get("net_amount", 0) or 0)
                    created = (p.get("created_at", "") or "")[:10]
                    emoji = "⏳" if status == "pending" else ("✅" if status == "approved" else "❌")
                    text += f"{emoji} {amt:,.0f} ج.م | نسب: {comm_rate*100:.0f}% ({comm_amt:,.0f}) | صافي: {net:,.0f} | {created}\n"
            else:
                text += "لا توجد سحوبات."
            kb = [
                [{"text": "🔄 سحوبات المعلم", "callback_data": f"transfers_teacher_{teacher_id}"}],
                [{"text": "👥 طلاب المعلم", "callback_data": f"transfers_teacher_students_{teacher_id}"}],
                [{"text": "🔙 رجوع", "callback_data": "transfers_teacher_list"}],
            ]
            await tg_edit(chat_id, message_id, text, keyboard=kb)
        except Exception as e:
            logger.error("transfers_teacher_detail: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])

    elif data.startswith("transfers_teacher_students_"):
        teacher_id = data.replace("transfers_teacher_students_", "")
        try:
            students = await sb_query("students", {"teacher_id": teacher_id}, limit=50)
            text = f"👥 *طلاب المعلم {str(teacher_id)[:8]}*\n\n"
            kb = []
            for s in (students or [])[:15]:
                sid = s.get("id", "")
                sname = s.get("full_name", "?")
                deposits = await sb_query("student_deposit_requests", {"student_id": sid}, limit=10)
                total_dep = sum(float(d.get("amount", 0) or 0) for d in (deposits or []))
                text += f"• {sname} | إيداعات: {total_dep:,.0f} ج.م\n"
                kb.append([{"text": f"👤 {sname}", "callback_data": f"transfers_student_detail_{sid}"}])
            kb.append([{"text": "🔙 رجوع", "callback_data": f"transfers_teacher_{teacher_id}"}])
            await tg_edit(chat_id, message_id, text, keyboard=kb)
        except Exception as e:
            logger.error("transfers_teacher_students: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])

    elif data.startswith("transfers_student_detail_"):
        student_id = data.replace("transfers_student_detail_", "")
        try:
            deposits = await sb_query("student_deposit_requests", {"student_id": student_id}, limit=20)
            students = await sb_query("students", {"id": student_id}, limit=1)
            student = students[0] if students else {}
            sname = student.get("full_name", "?")
            text = f"👤 *{sname}*\n\n"
            if deposits:
                total_dep = 0
                total_tax = 0
                for d in deposits[:10]:
                    amt = float(d.get("amount", 0) or 0)
                    tax = float(d.get("tax_amount", 0) or 0)
                    status = d.get("status", "pending")
                    created = (d.get("created_at", "") or "")[:10]
                    emoji = "⏳" if status == "pending" else ("✅" if status == "approved" else "❌")
                    text += f"{emoji} {amt:,.0f} ج.م | ضريبة: {tax:,.0f} | {created}\n"
                    total_dep += amt
                    total_tax += tax
                profit = total_dep * 0.35
                text += f"\n📊 الإجمالي: {total_dep:,.0f} ج.م\n💰 نسب الربح (35%): {profit:,.0f} ج.م\n"
            else:
                text += "لا توجد إيداعات."
            await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])
        except Exception as e:
            logger.error("transfers_student_detail: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])

    elif data == "transfers_student_deposits":
        try:
            deposits = await sb_query("student_deposit_requests", limit=30)
            text = "💰 *إيداعات الطلاب*\n\n"
            if deposits:
                for d in deposits[:20]:
                    student_id = (d.get("student_id", "") or "")[:8]
                    amount = float(d.get("amount", 0) or 0)
                    tax = float(d.get("tax_amount", 0) or 0)
                    status = d.get("status", "pending")
                    created = (d.get("created_at", "") or "")[:10]
                    emoji = "⏳" if status == "pending" else ("✅" if status == "approved" else "❌")
                    text += f"{emoji} {student_id}... | {amount:,.0f} ج.م | ضريبة: {tax:,.0f} | {created}\n"
            else:
                text += "لا توجد إيداعات."
            await tg_edit(chat_id, message_id, text, keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])
        except Exception as e:
            logger.error("transfers_student_deposits: %s", e)
            await tg_edit(chat_id, message_id, f"خطأ: {str(e)[:100]}", keyboard=[[{"text": "🔙 رجوع", "callback_data": "transfers_menu"}]])

    # ── Maintenance ──
    elif data == "maintenance_menu":
        kb = [
            [{"text": "تطبيق الطلاب", "callback_data": "maintenance_stop_student"}],
            [{"text": "تطبيق المدرسين", "callback_data": "maintenance_stop_teacher"}],
            [{"text": "🔙 رجوع", "callback_data": "back"}],
        ]
        await tg_edit(chat_id, message_id, "🛑 *إيقاف الخدمة*\n\nاختر التطبيق المراد إيقافه:", keyboard=kb)

    elif data == "maintenance_stop_student":
        await set_admin_config("maintenance_student", "true")
        await set_admin_config("maintenance_message", "تم إيقاف الخدمة مؤقتاً — جاري الإصلاح")
        asyncio.create_task(send_push_to_all(
            "student",
            "التطبيق تحت الصيانة",
            "جاري إجراء إصلاحات، سنعود قريباً"
        ))
        await tg_edit(chat_id, message_id,
                       "🛑 *تم إيقاف خدمة تطبيق الطلاب*\n\nتم إيقاف الخدمة مؤقتاً — جاري الإصلاح",
                       keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        await tg_send(chat_id, "🛑 *تم إيقاف خدمة تطبيق الطلاب*\n\nتم إيقاف الخدمة مؤقتاً — جاري الإصلاح")

    elif data == "maintenance_stop_teacher":
        await set_admin_config("maintenance_teacher", "true")
        await set_admin_config("maintenance_message", "تم إيقاف الخدمة مؤقتاً — جاري الإصلاح")
        asyncio.create_task(send_push_to_all(
            "teacher",
            "التطبيق تحت الصيانة",
            "جاري إجراء إصلاحات، سنعود قريباً"
        ))
        await tg_edit(chat_id, message_id,
                       "🛑 *تم إيقاف خدمة تطبيق المدرسين*\n\nتم إيقاف الخدمة مؤقتاً — جاري الإصلاح",
                       keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        await tg_send(chat_id, "🛑 *تم إيقاف خدمة تطبيق المدرسين*\n\nتم إيقاف الخدمة مؤقتاً — جاري الإصلاح")

    elif data == "maintenance_restore":
        await set_admin_config("maintenance_student", "false")
        await set_admin_config("maintenance_teacher", "false")
        await set_admin_config("maintenance_message", "")
        asyncio.create_task(send_push_to_all(
            "student",
            "تم إعادة تشغيل الخدمة",
            "يمكنك استخدام التطبيق الآن",
            {"action": "maintenance_restored"}
        ))
        asyncio.create_task(send_push_to_all(
            "teacher",
            "تم إعادة تشغيل الخدمة",
            "يمكنك استخدام التطبيق الآن",
            {"action": "maintenance_restored"}
        ))
        await tg_edit(chat_id, message_id,
                       "✅ *تم إعادة تشغيل الخدمة*\n\nجميع التطبيقات تعمل الآن بشكل طبيعي.",
                       keyboard=[[{"text": "🔙 رجوع", "callback_data": "back"}]])
        await tg_send(chat_id, "✅ *تم إعادة تشغيل الخدمة*\n\nجميع التطبيقات تعمل الآن بشكل طبيعي.")

    # ── Back ──
    elif data == "back":
        await tg_edit(chat_id, message_id, "🎓 *بوت دَرسَك AI*\n\nاختر:", keyboard=main_menu())

    else:
        logger.warning("Unknown callback: %s", data)


# ─── Notification helper ───────────────────────────────────────────────


async def notify_admin_payment_request(payment_request: dict, plan: dict, user=None):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    try:
        chat_id = int(TELEGRAM_CHAT_ID)
    except (ValueError, TypeError):
        return
    text = (
        f"💰 طلب اشتراك جديد\n\n"
        f"👤 {user.get('full_name', '—') if user else '—'}\n"
        f"📌 {plan.get('name', '—')}\n"
        f"💵 {payment_request.get('amount', '—')} ج.م\n"
    )
    pid = payment_request["id"]
    pid_str = pid.hex if hasattr(pid, "hex") else str(pid)
    kb = [[
        {"text": "✅ موافقة", "callback_data": f"pay_approve_{pid_str}"},
        {"text": "❌ رفض", "callback_data": f"pay_reject_{pid_str}"},
    ]]
    await tg_send(chat_id, text, keyboard=kb)


async def notify_payout_request(teacher_name, amount, commission_rate, commission_amount, net_amount, method, phone, payout_id):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("Payout notification skipped: bot not configured")
        return False
    try:
        chat_id = int(TELEGRAM_CHAT_ID)
    except (ValueError, TypeError):
        logger.warning("Payout notification skipped: invalid chat_id")
        return False
    text = (
        f"💰 *طلب سحب جديد*\n\n"
        f"👤 المدرس: {teacher_name}\n"
        f"💵 المبلغ: {amount:,.2f} ج.م\n"
        f"📊 العمولة ({commission_rate:.0f}%): {commission_amount:,.2f} ج.م\n"
        f"✅ الصافي: {net_amount:,.2f} ج.م\n"
        f"📱 {method}\n"
        f"📞 {phone or '—'}\n"
    )
    kb = [[
        {"text": "✅ تأكيد", "callback_data": f"payout_confirm:{payout_id}"},
        {"text": "❌ رفض", "callback_data": f"payout_reject:{payout_id}"},
    ]]
    await tg_send(chat_id, text, keyboard=kb)
    logger.info("Payout notification sent: payout_id=%s teacher=%s amount=%.2f", payout_id, teacher_name, amount)
    return True


async def notify_student_deposit(student_name, amount, tax_amount, total_amount, deposit_id, sender_phone="", method="vodafone_cash"):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    try:
        chat_id = int(TELEGRAM_CHAT_ID)
    except (ValueError, TypeError):
        return
    method_label = {"vodafone_cash": "فودافون كاش", "instapay": "إنستاباي"}.get(method, method)
    text = (
        f"💰 *إيداع طالب جديد*\n\n"
        f"👤 الطالب: {student_name}\n"
        f"📱 رقم المرسل: {sender_phone}\n"
        f"💵 المبلغ: {amount:,.2f} ج.م\n"
        f"📊 الضريبة (1.5%): {tax_amount:,.2f} ج.م\n"
        f"💳 الإجمالي: {total_amount:,.2f} ج.م\n"
        f"🏦 الطريقة: {method_label}\n"
    )
    kb = [[
        {"text": "✅ تأكيد", "callback_data": f"deposit_approve:{deposit_id}"},
        {"text": "❌ رفض", "callback_data": f"deposit_reject:{deposit_id}"},
    ]]
    await tg_send(chat_id, text, keyboard=kb)


# ─── Webhook endpoint ──────────────────────────────────────────────────


@router.post("/telegram-webhook")
async def telegram_webhook(request: Request):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    if not TELEGRAM_BOT_TOKEN:
        return {"ok": False, "error": "Bot not configured"}

    try:
        update = body

        # Handle message
        if "message" in update:
            msg = update["message"]
            chat_id = msg["chat"]["id"]
            text = msg.get("text", "")
            username = msg.get("from", {}).get("username")
            entities = msg.get("entities", [])
            is_cmd = any(e.get("type") == "bot_command" for e in entities)

            if is_cmd and text.startswith("/start"):
                args = text.split()
                if len(args) > 1:
                    await handle_deep_link(chat_id, args[1])
                else:
                    await handle_start(chat_id, username)
            else:
                await handle_message(chat_id, text)

        # Handle callback query
        elif "callback_query" in update:
            cq = update["callback_query"]
            data = cq.get("data", "")
            chat_id = cq["message"]["chat"]["id"]
            msg_id = cq["message"]["message_id"]
            cq_id = cq["id"]

            # Answer callback first
            await tg_answer(cq_id)

            # Route to handler
            await handle_callback(chat_id, msg_id, data)

    except Exception as e:
        logger.error("Webhook error: %s", e, exc_info=True)

    return {"ok": True}


@router.post("/setup-telegram-webhook")
async def setup_telegram_webhook(admin: dict = Depends(get_current_admin)):
    webhook_url = f"https://darsak-backend.fly.dev/api/telegram-webhook"
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            resp = await c.post(f"{TG_API}/setWebhook", json={"url": webhook_url})
            data = resp.json()
            if data.get("ok"):
                return {"ok": True, "url": webhook_url}
            return {"ok": False, "error": data.get("description")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/telegram-status")
async def telegram_status(admin: dict = Depends(get_current_admin)):
    return {
        "token_configured": bool(TELEGRAM_BOT_TOKEN),
        "chat_id_configured": bool(TELEGRAM_CHAT_ID),
        "supabase_configured": bool(SUPABASE_URL and SUPABASE_KEY),
    }
