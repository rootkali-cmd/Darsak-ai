import uuid
import secrets
import logging
import time
from typing import Any

from fastapi import APIRouter, HTTPException, Request, Query, Depends
from pydantic import BaseModel, field_validator

from src.core.config import get_settings
from src.core.security.auth import create_access_token, verify_password, decode_token
from src.core.security.supabase_repo import SupabaseRepository
from src.infrastructure.rate_limiter import rate_limiter

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("darsak.admin")

# ─── Admin Login Rate Limiting ──────────────────────────────────────────
ADMIN_LOGIN_MAX_ATTEMPTS = 5
ADMIN_LOGIN_WINDOW_SECONDS = 60
ADMIN_LOGIN_BAN_SECONDS = 300  # 5 minutes lockout after 5 failures


def _get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class AdminStudentStatusUpdate(BaseModel):
    is_active: bool


class AdminTemplateUpdate(BaseModel):
    name: str | None = None
    title: str | None = None
    description: str | None = None
    content: str | None = None
    subject: str | None = None
    grade_level: str | None = None
    is_active: bool | None = None


class AdminTransactionUpdate(BaseModel):
    status: str | None = None
    admin_message: str | None = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str | None) -> str | None:
        if v is not None and v not in ("pending", "approved", "rejected", "cancelled"):
            raise ValueError("Invalid transaction status")
        return v


class AdminCodeGenerateRequest(BaseModel):
    plan_id: str
    quantity: int = 1

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: int) -> int:
        if v < 1 or v > 100:
            raise ValueError("Quantity must be between 1 and 100")
        return v


async def get_current_admin(request: Request) -> dict:
    """Verify admin token from Authorization header."""
    settings = get_settings()
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing admin token")
    token = auth_header[7:]
    payload = decode_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid token")
    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return payload


@router.post("/login")
async def admin_login(request: Request):
    settings = get_settings()
    client_ip = _get_client_ip(request)

    # Check ban via Redis (distributed-safe)
    remaining_ban = await rate_limiter.ban_check(f"admin_login:{client_ip}", ADMIN_LOGIN_BAN_SECONDS)
    if remaining_ban > 0:
        raise HTTPException(
            status_code=429,
            detail=f"تم حظر هذا العنوان مؤقتاً بسبب محاولات دخول كثيرة. حاول مرة أخرى بعد {remaining_ban} ثانية.",
        )

    body = await request.json()
    password = body.get("password", "")
    email = body.get("email", "")

    if not settings.ADMIN_PASSWORD:
        raise HTTPException(status_code=500, detail="Admin password not configured")
    if email != settings.ADMIN_EMAIL:
        # Track failed attempt
        count = await rate_limiter.increment(f"admin_login_fail:{client_ip}", ADMIN_LOGIN_WINDOW_SECONDS)
        if count >= ADMIN_LOGIN_MAX_ATTEMPTS:
            await rate_limiter.set_ban(f"admin_login:{client_ip}", ADMIN_LOGIN_BAN_SECONDS)
            logger.warning("Admin login banned IP %s for %ds after %d failures", client_ip, ADMIN_LOGIN_BAN_SECONDS, count)
        raise HTTPException(401, "Invalid credentials")

    # Verify password against stored bcrypt hash
    from src.core.security.supabase_repo import get_supabase
    client = await get_supabase()
    hash_resp = await client.table("admin_config").select("value").eq("key", "admin_password_hash").limit(1).execute()
    stored_hash = (hash_resp.data[0]["value"]) if (hash_resp.data and len(hash_resp.data) > 0) else None
    if not stored_hash or not verify_password(password, stored_hash):
        count = await rate_limiter.increment(f"admin_login_fail:{client_ip}", ADMIN_LOGIN_WINDOW_SECONDS)
        if count >= ADMIN_LOGIN_MAX_ATTEMPTS:
            await rate_limiter.set_ban(f"admin_login:{client_ip}", ADMIN_LOGIN_BAN_SECONDS)
            logger.warning("Admin login banned IP %s for %ds after %d failures", client_ip, ADMIN_LOGIN_BAN_SECONDS, count)
        raise HTTPException(401, "Invalid credentials")

    # Successful login — clear any failure counters (ban key will expire naturally)
    token = create_access_token(
        "admin", extra_claims={"name": "Ahmed Telly", "role": "admin"}
    )
    return {"access_token": token, "token_type": "bearer"}


@router.get("/students")
async def list_students(
    search: str = Query(None),
    status: str = Query(None),
    limit: int = Query(100),
    admin: dict = Depends(get_current_admin),
):
    repo = SupabaseRepository("students")
    filters = {}
    if status:
        filters["is_active"] = status == "active"
    if search:
        return await repo.search(
            filters,
            text_search={"full_name": search, "code": search},
            limit=limit,
        )
    return await repo.select(filters, limit=limit)


@router.put("/students/{student_id}/status")
async def toggle_student_status(
    student_id: str, request: Request, admin: dict = Depends(get_current_admin)
):
    body = await request.json()
    await SupabaseRepository("students").update(
        {"id": student_id}, {"is_active": body.get("is_active", True)}
    )
    return {"ok": True}


@router.delete("/students/{student_id}")
async def delete_student(student_id: str, admin: dict = Depends(get_current_admin)):
    await SupabaseRepository("students").delete({"id": student_id})
    return {"ok": True}


@router.post("/codes/generate")
async def generate_code(
    body: AdminCodeGenerateRequest, admin: dict = Depends(get_current_admin)
):
    codes = []
    for _ in range(body.quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await SupabaseRepository("subscription_codes").insert(
            {"code": code, "plan_id": body.plan_id, "is_used": False}
        )
        codes.append(code)
    return {"ok": True, "codes": codes}


@router.get("/codes")
async def list_codes(
    plan_id: str = Query(None),
    is_used: bool = Query(None),
    admin: dict = Depends(get_current_admin),
):
    filters = {}
    if plan_id:
        filters["plan_id"] = plan_id
    if is_used is not None:
        filters["is_used"] = is_used
    return await SupabaseRepository("subscription_codes").select(filters, limit=200)


@router.get("/templates")
async def list_templates(
    type: str = Query(None), admin: dict = Depends(get_current_admin)
):
    filters = {}
    if type:
        filters["type"] = type
    return await SupabaseRepository("admin_templates").select(filters, limit=200)


@router.put("/templates/{template_id}")
async def update_template(
    template_id: str,
    update_data: AdminTemplateUpdate,
    admin: dict = Depends(get_current_admin),
):
    update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
    if not update_dict:
        raise HTTPException(status_code=400, detail="No fields to update")
    await SupabaseRepository("admin_templates").update({"id": template_id}, update_dict)
    return {"ok": True}


@router.get("/transactions")
async def list_transactions(
    status: str = Query(None),
    limit: int = Query(50),
    admin: dict = Depends(get_current_admin),
):
    filters = {}
    if status:
        filters["status"] = status
    return await SupabaseRepository("payment_transactions").select(
        filters, limit=limit
    )


@router.put("/transactions/{tx_id}")
async def update_transaction(
    tx_id: str, update_data: AdminTransactionUpdate, admin: dict = Depends(get_current_admin)
):
    update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
    if not update_dict:
        raise HTTPException(status_code=400, detail="No fields to update")
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, update_dict)
    return {"ok": True}


@router.get("/stats")
async def admin_stats(admin: dict = Depends(get_current_admin)):
    sr = SupabaseRepository("students")
    cr = SupabaseRepository("subscription_codes")
    pr = SupabaseRepository("payment_transactions")
    return {
        "total_students": await sr.count(),
        "active_students": await sr.count({"is_active": True}),
        "total_codes": await cr.count(),
        "used_codes": await cr.count({"is_used": True}),
        "pending_transactions": await pr.count({"status": "pending"}),
    }
