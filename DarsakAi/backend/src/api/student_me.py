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
from src.services import grade_service, attendance_service, invoice_service, student_service, audit_service, exam_service, student_exam_service
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

_student_ai_usage: dict[str, dict] = {}
AI_DAILY_LIMIT = 5


class AiChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)


class AiChatResponse(BaseModel):
    answer: str
    remaining: int


def _get_ai_usage(student_id: str) -> dict:
    today = date.today().isoformat()
    if student_id not in _student_ai_usage or _student_ai_usage[student_id]["date"] != today:
        _student_ai_usage[student_id] = {"date": today, "count": 0}
    return _student_ai_usage[student_id]


@router.post("/ai-chat", response_model=AiChatResponse)
async def ai_chat(
    body: AiChatRequest,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    student_id = str(current_student["id"])
    usage = _get_ai_usage(student_id)

    if usage["count"] >= AI_DAILY_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="لقد استنفدت حد الأسئلة اليومي. ارجع غداً",
        )

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
        "أنت مساعد تعليمي ذكي اسمك 'دَرسك AI'. تابع لمنصة DarsakAI التعليمية."
        "مهمتك الأساسية: مساعدة الطلاب في الدراسة والمناهج التعليمية المصرية فقط."
        ""
        "قواعد أمان صارمة - مهم جداً:"
        "- أنت ملتزم بالتعليم فقط. أي سؤال عن أسلحة، قنابل، مخدرات، عنف، اختراق، أو أي محتوى ضار أو خطير - ارفض الرد فوراً وقل 'لا أستطيع الإجابة على هذا السؤال'"
        "- لا تقدم أي معلومات عن كيفية صنع أي شيء خطير أو غير قانوني"
        "- ركز فقط على المناهج التعليمية: الرياضيات، العلوم، اللغة العربية، اللغة الإنجليزية، الدراسات الاجتماعية، وغيرها من المواد الدراسية"
        "- استخدم مصادر موثوقة في إجاباتك"
        ""
        "قدرات خاصة:"
        "- يمكنك البحث والتفكير المنطقي لحل المسائل"
        "- إذا طلب منك الطالب إنشاء اختبار (quiz) أو أسئلة في مادة معينة، قم بتوليد أسئلة متنوعة (اختيار من متعدد + مقالي) مع الإجابات النموذجية"
        "- قدم تفسيرات مبسطة ومناسبة لعمر الطالب"
        "- استخدم الأمثلة الواقعية لتوضيح المفاهيم"
        ""
        "شكل الرد:"
        "- أجب بالعربية بشكل واضح ومفصل"
        "- استخدم تنسيق Markdown: **نص عريض** للعناوين، *نص مائل* للتوضيح، `كود` للأكواد، - نقاط للقوائم، # للعناوين"
        "- إذا كنت تفكر أو تحلل، ابدأ بعبارة '🤔 تفكير:' ثم اكتب تحليلك"
        "- إذا قمت بإنشاء كويز، ابدأ بعبارة '📝 كويز:'"
    )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": body.question},
    ]

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": 0.7,
                    "max_tokens": 2048,
                },
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
        _ai_logger.error("OpenRouter error %s: %s", e.response.status_code, e.response.text[:300])
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="خدمة AI غير متاحة حالياً")
    except Exception as e:
        _ai_logger.error("AI chat failed: %s", e)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="حدث خطأ في الاتصال بخدمة AI")

    usage["count"] += 1
    remaining = AI_DAILY_LIMIT - usage["count"]

    return AiChatResponse(answer=answer, remaining=remaining)


@router.get("/ai-usage")
async def get_ai_usage(
    current_student: dict = Depends(get_current_student),
):
    student_id = str(current_student["id"])
    usage = _get_ai_usage(student_id)
    remaining = max(0, AI_DAILY_LIMIT - usage["count"])
    return {"remaining": remaining, "limit": AI_DAILY_LIMIT, "used": usage["count"]}


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
                "exam_id": e["exam_id"],
                "exam_title": exam["title"] if exam else "Unknown",
                "score": total,
                "max_score": max_s,
                "percentage": pct,
                "submitted_at": e.get("submitted_at"),
                "created_at": e.get("created_at") or e.get("submitted_at"),
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
