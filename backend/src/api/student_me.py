from datetime import date, datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from pydantic import BaseModel, Field

from src.utils.dependencies import get_current_student
from src.schemas.student import StudentResponse
from src.schemas.grade import GradeResponse
from src.schemas.attendance import AttendanceResponse
from src.schemas.invoice import InvoiceResponse
from src.core.security.auth import verify_password
from src.core.security.sanitizer import sanitize_pin
from src.schemas.student import PIN_PATTERN
from src.services import grade_service, attendance_service, invoice_service, student_service, audit_service, exam_service, student_exam_service, teacher_subscription_service, subscription_plan_service
from src.core.config import get_settings

settings = get_settings()

router = APIRouter(prefix="/students/me", tags=["Student - Self Service"])


# ─── Notifications ───────────────────────────────────────────────────


@router.get("/notifications")
async def get_my_notifications(
    current_student: dict = Depends(get_current_student),
):
    from src.services import notification_service
    return await notification_service.get_unread(current_student["id"])


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_student: dict = Depends(get_current_student),
):
    from src.services import notification_service
    return await notification_service.mark_read(notification_id)


class StudentPinUpdate(BaseModel):
    old_pin: str = Field(..., min_length=6, max_length=8, pattern=PIN_PATTERN)
    new_pin: str = Field(..., min_length=6, max_length=8, pattern=PIN_PATTERN)


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("", response_model=StudentResponse)
async def get_my_profile(
    current_student: dict = Depends(get_current_student),
):
    data = dict(current_student)
    data["has_pin"] = data.get("pin_hash") is not None
    return StudentResponse(**data)


@router.get("/grades", response_model=list[GradeResponse])
async def get_my_grades(
    subject: str | None = None,
    limit: int = Query(100, ge=1, le=200),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": str(current_student["id"])}
    if subject:
        filters["subject"] = subject
    grades = await grade_service.list(filters, limit=limit)
    result = []
    for g in grades:
        try:
            result.append(GradeResponse(**g))
        except Exception:
            continue
    return result


@router.get("/attendance", response_model=list[AttendanceResponse])
async def get_my_attendance(
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = Query(200, ge=1, le=500),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": str(current_student["id"])}
    records = await attendance_service.list(filters, limit=limit)
    if from_date:
        records = [r for r in records if r["date"] >= from_date]
    if to_date:
        records = [r for r in records if r["date"] <= to_date]
    result = []
    for r in records:
        try:
            result.append(AttendanceResponse(**r))
        except Exception:
            continue
    return result


@router.get("/invoices", response_model=list[InvoiceResponse])
async def get_my_invoices(
    paid: bool | None = None,
    limit: int = Query(100, ge=1, le=200),
    current_student: dict = Depends(get_current_student),
):
    filters = {"student_id": current_student["id"]}
    invoices = await invoice_service.list(filters, limit=limit)
    if paid is not None:
        invoices = [i for i in invoices if i.get("paid") == paid]
    return [InvoiceResponse(**i) for i in invoices]


@router.patch("/pin")
async def change_my_pin(
    pin_data: StudentPinUpdate,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    if not current_student.get("pin_hash"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="PIN not set")
    if not verify_password(sanitize_pin(pin_data.old_pin), current_student["pin_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Old PIN is incorrect")

    await student_service.update(current_student["id"], {"pin": sanitize_pin(pin_data.new_pin)})

    await audit_service.log(
        actor_type="student",
        action="pin_changed",
        actor_id=current_student["id"],
        resource_type="student",
        resource_id=current_student["id"],
        ip_address=get_client_ip(request),
    )

    return {"message": "PIN updated successfully"}


# ─── AI Chat ────────────────────────────────────────────────────────

import httpx
import json as _json
import logging

_ai_logger = logging.getLogger("darsak.ai_chat")


class AiChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)
    conversation_id: str | None = None


class AiChatResponse(BaseModel):
    answer: str
    remaining: int
    conversation_id: str


async def _get_teacher_ai_limit(student_id: str) -> int:
    """Get the daily AI limit based on the student's teacher's subscription plan."""
    try:
        student = await student_service.get_by_id(student_id)
        if not student or not student.get("teacher_id"):
            return 5
        sub = await teacher_subscription_service.get_active_subscription(student["teacher_id"])
        if not sub:
            return 5
        plan_id = sub.get("plan_id", "")
        plan = await subscription_plan_service.get_by_id(plan_id) if plan_id else None
        plan_name = plan.get("name", "Basic") if plan else "Basic"
        limit = await subscription_plan_service.get_plan_ai_limit(plan_name)
        return limit if limit and limit > 0 else 5
    except Exception as e:
        _ai_logger.warning("Failed to get teacher AI limit: %s", e)
        return 5


async def _check_and_update_daily_limit(student_id: str, teacher_id: str | None) -> int:
    """Check daily limit using DB columns. Returns remaining count. Raises 403 if exceeded."""
    from datetime import date
    today = date.today().isoformat()

    student = await student_service.get_by_id(student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    last_date = student.get("last_request_date", "")
    count = student.get("daily_requests_count", 0)

    if last_date != today:
        count = 0
        await student_service.update(student_id, {"daily_requests_count": 0, "last_request_date": today})

    limit = await _get_teacher_ai_limit(student_id)

    if limit == -1:
        remaining = 999
    else:
        remaining = max(0, limit - count)
        if remaining <= 0:
            plan_label = "باقة مدرس"
            try:
                if teacher_id:
                    sub = await teacher_subscription_service.get_active_subscription(teacher_id)
                    if sub:
                        plan_label = f"باقة {sub.get('plan_name', 'المدرس')}"
            except Exception:
                pass
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"لقد استهلكت حدك اليومي ({limit} رسائل). اطلب من مدرسك ترقية باقة {plan_label} لفتح المزيد! 😉",
            )

    await student_service.update(student_id, {"daily_requests_count": count + 1, "last_request_date": today})
    return remaining - 1


async def _save_conversation(student_id: str, conversation_id: str | None, user_msg: str, ai_answer: str) -> str:
    """Save messages to ai_conversations table. Returns conversation_id."""
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        now = datetime.now(timezone.utc).isoformat()

        if conversation_id:
            resp = client.table("ai_conversations").select("messages").eq("id", conversation_id).execute()
            if resp.data:
                msgs = resp.data[0].get("messages", [])
                msgs.append({"role": "user", "content": user_msg, "ts": now})
                msgs.append({"role": "assistant", "content": ai_answer, "ts": now})
                client.table("ai_conversations").update({"messages": msgs, "updated_at": now}).eq("id", conversation_id).execute()
                return conversation_id

        msgs = [{"role": "user", "content": user_msg, "ts": now}, {"role": "assistant", "content": ai_answer, "ts": now}]
        new_resp = client.table("ai_conversations").insert({"student_id": student_id, "messages": msgs}).execute()
        if new_resp.data:
            return new_resp.data[0]["id"]
    except Exception as e:
        _ai_logger.warning("Failed to save conversation: %s", e)
    return conversation_id or ""


@router.post("/ai-chat", response_model=AiChatResponse)
async def ai_chat(
    body: AiChatRequest,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    student_id = str(current_student["id"])
    teacher_id = current_student.get("teacher_id")

    remaining = await _check_and_update_daily_limit(student_id, teacher_id)

    api_key = settings.OPENROUTER_API_KEY or settings.GROQ_API_KEY
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="خدمة AI غير متاحة حالياً",
        )

    is_groq = not settings.OPENROUTER_API_KEY and bool(settings.GROQ_API_KEY)
    base_url = "https://api.groq.com/openai/v1" if is_groq else "https://openrouter.ai/api/v1"
    model = settings.GROQ_MODEL if is_groq else "google/gemini-2.5-flash-lite"

    system_prompt = (
        "أنت 'دَرسك AI' — المساعد الذكي المخصص لمنصة 'درسك' التعليمية."
        "مهمتك مساعدة الطلاب في فهم الدروس وإصلاح الأخطاء البرمجية بكفاءة عالية.\n\n"
        "قواعد الإجابة (صارمة):\n"
        "1. ادخل في صلب الموضوع مباشرة بدون مقدمات طويلة.\n"
        "2. عند شرح الكود، اكتب الكود المصلح مع تعليقات قصيرة تشرح التعديل داخل الكود.\n"
        "3. تحدث بلغة عربية عامية مصرية خفيفة مدمجة بالمصطلحات التقنية الإنجليزية عند الحاجة.\n"
        "4. ركّز أسئلتك للاستفادة من حدك اليومي.\n\n"
        "قواعد أمان:\n"
        "- ارفض أي سؤال عن أسلحة، قنابل، مخدرات، عنف، اختراق.\n"
        "- ركز فقط على المناهج التعليمية المصرية.\n\n"
        "شكل الرد:\n"
        "- أجب بالعربية بشكل واضح ومفصل.\n"
        "- استخدم Markdown: **عناوين**، `كود`، - قوائم.\n"
        "- إذا كنت تحلل، ابدأ بـ '🤔 تفكير:'\n"
        "- إذا أنشأت كويز، ابدأ بـ '📝 كويز:'"
    )

    messages = [{"role": "system", "content": system_prompt}]

    if body.conversation_id:
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            resp = client.table("ai_conversations").select("messages").eq("id", body.conversation_id).execute()
            if resp.data:
                hist = resp.data[0].get("messages", [])[-10:]
                for m in hist:
                    role = m.get("role", "user")
                    if role in ("user", "assistant"):
                        messages.append({"role": role, "content": m["content"]})
        except Exception:
            pass

    messages.append({"role": "user", "content": body.question})

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                json={"model": model, "messages": messages, "temperature": 0.7, "max_tokens": 2048},
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://darsakai.com",
                    "X-Title": "DarsakAI Student Chat",
                },
            )
            response.raise_for_status()
            result = response.json()
            answer = result["choices"][0]["message"]["content"]
    except httpx.HTTPStatusError as e:
        _ai_logger.error("AI error %s: %s", e.response.status_code, e.response.text[:300])
        raise HTTPException(status_code=502, detail="خدمة AI غير متاحة حالياً")
    except Exception as e:
        _ai_logger.error("AI chat failed: %s", e)
        raise HTTPException(status_code=502, detail="حدث خطأ في الاتصال بخدمة AI")

    conv_id = await _save_conversation(student_id, body.conversation_id, body.question, answer)

    return AiChatResponse(answer=answer, remaining=remaining, conversation_id=conv_id)


@router.get("/ai-usage")
async def get_ai_usage(
    current_student: dict = Depends(get_current_student),
):
    student_id = str(current_student["id"])
    teacher_id = current_student.get("teacher_id")
    limit = await _get_teacher_ai_limit(student_id)

    student = await student_service.get_by_id(student_id)
    today = date.today().isoformat()
    count = 0
    if student and student.get("last_request_date") == today:
        count = student.get("daily_requests_count", 0)

    if limit == -1:
        return {"remaining": 999, "limit": -1, "used": count}
    return {"remaining": max(0, limit - count), "limit": limit, "used": count}


@router.get("/stats")
async def get_my_stats(
    current_student: dict = Depends(get_current_student),
):
    try:
        student_id = str(current_student["id"])
        exams = await student_exam_service.get_student_exams(student_id)
        scored = [e for e in exams if e.get("total_score") is not None and (e.get("status") in ("graded", "submitted"))]
        total_taken = len(scored)
        if total_taken == 0:
            return {
                "total_exams_taken": 0,
                "average_score": 0,
                "best_score": 0,
                "worst_score": 0,
                "recent_results": [],
            }
        scores = []
        recent = sorted(scored, key=lambda e: e.get("submitted_at") or e.get("created_at") or "", reverse=True)[:5]
        recent_results = []
        for e in recent:
            total = float(e.get("total_score") or 0)
            max_s = float(e.get("max_score") or 0)
            pct = round(total / max_s * 100, 1) if max_s > 0 else 0
            exam = await exam_service.get_by_id(e["exam_id"])
            recent_results.append({
                "student_exam_id": e["id"],
                "exam_title": exam["title"] if exam else "Unknown",
                "score": total,
                "max_score": max_s,
                "percentage": pct,
                "submitted_at": e.get("submitted_at"),
            })
            scores.append(pct)
        avg = round(sum(scores) / len(scores), 1) if scores else 0
        return {
            "total_exams_taken": total_taken,
            "average_score": avg,
            "best_score": max(scores) if scores else 0,
            "worst_score": min(scores) if scores else 0,
            "recent_results": recent_results,
        }
    except Exception as exc:
        logger = logging.getLogger("darsak")
        logger.error("Failed to get student stats: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to get stats")


# ─── Teacher Subscription Check (for students) ─────────────────────

@router.get("/teacher-subscription")
async def get_my_teacher_subscription(
    current_student: dict = Depends(get_current_student),
):
    teacher_id = current_student.get("teacher_id")
    if not teacher_id:
        return {
            "has_active_subscription": False,
            "plan_name": None,
            "expires_at": None,
            "days_remaining": 0,
            "is_trial": False,
        }

    try:
        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        if not sub:
            return {
                "has_active_subscription": False,
                "plan_name": None,
                "expires_at": None,
                "days_remaining": 0,
                "is_trial": sub.get("is_trial", False) if sub else False,
            }

        plan_id = sub.get("plan_id", "")
        plan = await subscription_plan_service.get_by_id(plan_id) if plan_id else None
        plan_name = plan.get("name", "Basic") if plan else "Basic"

        expires_at = sub.get("expires_at")
        days_remaining = 0
        if expires_at:
            from datetime import datetime, timezone
            if isinstance(expires_at, str):
                exp_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            else:
                exp_dt = expires_at
            diff = exp_dt - datetime.now(timezone.utc)
            days_remaining = max(0, diff.days)

        return {
            "has_active_subscription": True,
            "plan_name": plan_name,
            "expires_at": expires_at,
            "days_remaining": days_remaining,
            "is_trial": sub.get("is_trial", False),
        }
    except Exception as e:
        logging.getLogger("darsak").warning("Failed to get teacher subscription: %s", e)
        return {
            "has_active_subscription": False,
            "plan_name": None,
            "expires_at": None,
            "days_remaining": 0,
            "is_trial": False,
        }
