import uuid
import secrets
import logging

from fastapi import APIRouter, HTTPException, Request, Query
from sqlalchemy import text

from src.core.security.auth import create_access_token, verify_password
from src.core.database import get_engine

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("darsak.admin")


async def _db_fetchone(query: str, params: dict = None) -> dict | None:
    engine = get_engine()
    async with engine.begin() as conn:
        result = await conn.execute(text(query), params or {})
        row = result.fetchone()
        if row:
            return dict(zip(result.keys(), row))
    return None


async def _db_fetchall(query: str, params: dict = None) -> list[dict]:
    engine = get_engine()
    async with engine.begin() as conn:
        result = await conn.execute(text(query), params or {})
        return [dict(zip(result.keys(), row)) for row in result.fetchall()]


async def _db_execute(query: str, params: dict = None) -> int:
    engine = get_engine()
    async with engine.begin() as conn:
        result = await conn.execute(text(query), params or {})
        return result.rowcount


@router.post("/login")
async def admin_login(request: Request):
    body = await request.json()
    email = body.get("email", "").strip().lower()
    password = body.get("password", "")
    admin = await _db_fetchone("SELECT * FROM admin_users WHERE email = :email", {"email": email})
    if not admin:
        raise HTTPException(401, "Invalid credentials")
    if not admin.get("is_active", True):
        raise HTTPException(403, "Account deactivated")
    if not verify_password(password, admin.get("hashed_password", "")):
        raise HTTPException(401, "Invalid credentials")
    token = create_access_token(str(admin["id"]), extra_claims={"name": admin.get("full_name", "Admin"), "role": "admin"})
    return {"access_token": token, "token_type": "bearer"}


@router.get("/students")
async def list_students(search: str = Query(None), status: str = Query(None), limit: int = Query(100)):
    query = "SELECT id, full_name, code, parent_phone, group_id, is_active, created_at FROM students"
    conditions = []
    params = {}
    if status:
        conditions.append("is_active = :status")
        params["status"] = status == "active"
    if search:
        conditions.append("(full_name ILIKE :search OR code ILIKE :search2 OR parent_phone ILIKE :search3)")
        params["search"] = f"%{search}%"
        params["search2"] = f"%{search}%"
        params["search3"] = f"%{search}%"
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    query += " ORDER BY created_at DESC LIMIT :limit"
    params["limit"] = limit
    return await _db_fetchall(query, params)


@router.put("/students/{student_id}/status")
async def toggle_student_status(student_id: str, request: Request):
    body = await request.json()
    await _db_execute("UPDATE students SET is_active = :active WHERE id = :id", {"active": body.get("is_active", True), "id": student_id})
    return {"ok": True}


@router.delete("/students/{student_id}")
async def delete_student(student_id: str):
    await _db_execute("DELETE FROM students WHERE id = :id", {"id": student_id})
    return {"ok": True}


@router.post("/codes/generate")
async def generate_code(request: Request):
    body = await request.json()
    plan_id = body.get("plan_id", "")
    quantity = body.get("quantity", 1)
    codes = []
    for _ in range(quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await _db_execute("INSERT INTO subscription_codes (code, plan_id, is_used) VALUES (:code, :plan_id, false)", {"code": code, "plan_id": plan_id})
        codes.append(code)
    return {"ok": True, "codes": codes}


@router.get("/codes")
async def list_codes(plan_id: str = Query(None), is_used: bool = Query(None)):
    query = "SELECT * FROM subscription_codes"
    conditions = []
    params = {}
    if plan_id:
        conditions.append("plan_id = :plan_id")
        params["plan_id"] = plan_id
    if is_used is not None:
        conditions.append("is_used = :is_used")
        params["is_used"] = is_used
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    query += " ORDER BY created_at DESC LIMIT 200"
    return await _db_fetchall(query, params)


@router.get("/templates")
async def list_templates(type: str = Query(None)):
    query = "SELECT * FROM admin_templates"
    params = {}
    if type:
        query += " WHERE type = :type"
        params["type"] = type
    query += " ORDER BY created_at DESC"
    return await _db_fetchall(query, params)


@router.put("/templates/{template_id}")
async def update_template(template_id: str, request: Request):
    body = await request.json()
    for key, val in body.items():
        if val is not None:
            await _db_execute(f"UPDATE admin_templates SET {key} = :val WHERE id = :id", {"val": val, "id": template_id})
    return {"ok": True}


@router.get("/transactions")
async def list_transactions(status: str = Query(None), limit: int = Query(50)):
    query = "SELECT * FROM payment_transactions"
    params = {}
    if status:
        query += " WHERE status = :status"
        params["status"] = status
    query += " ORDER BY created_at DESC LIMIT :limit"
    params["limit"] = limit
    return await _db_fetchall(query, params)


@router.put("/transactions/{tx_id}")
async def update_transaction(tx_id: str, request: Request):
    body = await request.json()
    for key, val in body.items():
        if val is not None:
            await _db_execute(f"UPDATE payment_transactions SET {key} = :val WHERE id = :id", {"val": val, "id": tx_id})
    return {"ok": True}


@router.get("/stats")
async def admin_stats():
    total = await _db_fetchone("SELECT COUNT(*) as cnt FROM students")
    active = await _db_fetchone("SELECT COUNT(*) as cnt FROM students WHERE is_active = true")
    total_codes = await _db_fetchone("SELECT COUNT(*) as cnt FROM subscription_codes")
    used_codes = await _db_fetchone("SELECT COUNT(*) as cnt FROM subscription_codes WHERE is_used = true")
    pending = await _db_fetchone("SELECT COUNT(*) as cnt FROM payment_transactions WHERE status = 'pending'")
    return {
        "total_students": total["cnt"] if total else 0,
        "active_students": active["cnt"] if active else 0,
        "total_codes": total_codes["cnt"] if total_codes else 0,
        "used_codes": used_codes["cnt"] if used_codes else 0,
        "pending_transactions": pending["cnt"] if pending else 0,
    }
