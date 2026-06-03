import uuid
import secrets
import logging

from fastapi import APIRouter, HTTPException, Request, Query
from sqlalchemy import text

from src.core.security.auth import create_access_token, verify_password
from src.core.database import get_engine
from src.core.security.supabase_repo import SupabaseRepository

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("darsak.admin")

# Admin credentials — hashed in production
ADMIN_EMAIL = "ahmedtelly32@gmail.com"
ADMIN_PASSWORD = "Ahmedtelly2008@"


@router.post("/login")
async def admin_login(request: Request):
    body = await request.json()
    password = body.get("password", "")
    if password != ADMIN_PASSWORD:
        raise HTTPException(401, "Invalid credentials")
    token = create_access_token(
        "admin", extra_claims={"name": "Ahmed Telly", "role": "admin"}
    )
    return {"access_token": token, "token_type": "bearer"}


@router.get("/students")
async def list_students(search: str = Query(None), status: str = Query(None), limit: int = Query(100)):
    repo = SupabaseRepository("students")
    filters = {}
    if status: filters["is_active"] = status == "active"
    if search:
        return await repo.search(filters, text_search={"full_name": search, "code": search}, limit=limit)
    return await repo.select(filters, limit=limit)


@router.put("/students/{student_id}/status")
async def toggle_student_status(student_id: str, request: Request):
    body = await request.json()
    await SupabaseRepository("students").update({"id": student_id}, {"is_active": body.get("is_active", True)})
    return {"ok": True}


@router.delete("/students/{student_id}")
async def delete_student(student_id: str):
    await SupabaseRepository("students").delete({"id": student_id})
    return {"ok": True}


@router.post("/codes/generate")
async def generate_code(request: Request):
    body = await request.json()
    plan_id = body.get("plan_id", "")
    quantity = body.get("quantity", 1)
    codes = []
    for _ in range(quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await SupabaseRepository("subscription_codes").insert({"code": code, "plan_id": plan_id, "is_used": False})
        codes.append(code)
    return {"ok": True, "codes": codes}


@router.get("/codes")
async def list_codes(plan_id: str = Query(None), is_used: bool = Query(None)):
    filters = {}
    if plan_id: filters["plan_id"] = plan_id
    if is_used is not None: filters["is_used"] = is_used
    return await SupabaseRepository("subscription_codes").select(filters, limit=200)


@router.get("/templates")
async def list_templates(type: str = Query(None)):
    filters = {}
    if type: filters["type"] = type
    return await SupabaseRepository("admin_templates").select(filters, limit=200)


@router.put("/templates/{template_id}")
async def update_template(template_id: str, request: Request):
    body = await request.json()
    await SupabaseRepository("admin_templates").update({"id": template_id}, body)
    return {"ok": True}


@router.get("/transactions")
async def list_transactions(status: str = Query(None), limit: int = Query(50)):
    filters = {}
    if status: filters["status"] = status
    return await SupabaseRepository("payment_transactions").select(filters, limit=limit)


@router.put("/transactions/{tx_id}")
async def update_transaction(tx_id: str, request: Request):
    body = await request.json()
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, body)
    return {"ok": True}


@router.get("/stats")
async def admin_stats():
    try:
        sr = SupabaseRepository("students")
        cr = SupabaseRepository("subscription_codes")
        return {
            "total_students": await sr.count(),
            "active_students": await sr.count({"is_active": True}),
            "total_codes": await cr.count(),
            "used_codes": await cr.count({"is_used": True}),
            "pending_transactions": 0,
        }
    except Exception as e:
        logger.error("Admin stats failed: %s", e)
        return {
            "total_students": 0, "active_students": 0,
            "total_codes": 0, "used_codes": 0,
            "pending_transactions": 0,
        }
