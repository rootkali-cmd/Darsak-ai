import uuid
import secrets
import logging

from fastapi import APIRouter, HTTPException, Request, Query, Depends

from src.core.config import get_settings
from src.core.security.auth import create_access_token, verify_password, decode_token
from src.core.security.supabase_repo import SupabaseRepository

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("darsak.admin")


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
    body = await request.json()
    password = body.get("password", "")
    email = body.get("email", "")

    if not settings.ADMIN_PASSWORD:
        raise HTTPException(status_code=500, detail="Admin password not configured")
    if email != settings.ADMIN_EMAIL or password != settings.ADMIN_PASSWORD:
        raise HTTPException(401, "Invalid credentials")
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
    request: Request, admin: dict = Depends(get_current_admin)
):
    body = await request.json()
    plan_id = body.get("plan_id", "")
    quantity = body.get("quantity", 1)
    codes = []
    for _ in range(quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await SupabaseRepository("subscription_codes").insert(
            {"code": code, "plan_id": plan_id, "is_used": False}
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
    request: Request,
    admin: dict = Depends(get_current_admin),
):
    body = await request.json()
    await SupabaseRepository("admin_templates").update({"id": template_id}, body)
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
    tx_id: str, request: Request, admin: dict = Depends(get_current_admin)
):
    body = await request.json()
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, body)
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
