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
from src.services import grade_service, attendance_service, invoice_service, student_service, audit_service
from src.core.config import get_settings

settings = get_settings()

router = APIRouter(prefix="/students/me", tags=["Student - Self Service"])


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
        "أنت مساعد تعليمي ذكي اسمك 'دَرسك AI'. "
        "طالب يدرس في مصر يسألك. "
        "أجب بالعربية بشكل واضح ومفصل. "
        "إذا كان السؤال عن مادة دراسية، اشرح بأسلوب بسيط مع أمثلة. "
        "إذا كان السؤال عام، أجب باختصار ومفيد. "
        "يمكنك استخدام تنسيق Markdown: "
        "**نص عريض** للعناوين المهمة، "
        "*نص مائل* للتوضيح، "
        "`كود` للأكواد، "
        "- نقاط للقوائم، "
        "# للعناوين الرئيسية. "
        "لا تستخدم رموز خاصة معقدة، فقط التنسيق البسيط."
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
