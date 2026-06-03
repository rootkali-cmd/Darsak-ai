import uuid
import secrets

from fastapi import APIRouter, HTTPException, Request, Query

from src.core.security.auth import create_access_token, verify_password
from src.core.security.supabase_repo import SupabaseRepository

router = APIRouter(prefix="/admin", tags=["Admin"])


def _hash_password(password: str) -> str:
    import bcrypt
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


@router.post("/login")
async def admin_login(request: Request):
    body = await request.json()
    email = body.get("email", "").strip().lower()
    password = body.get("password", "")

    admin = await SupabaseRepository("admin_users").select_one({"email": email})
    if not admin:
        raise HTTPException(401, "Invalid credentials")
    if not admin.get("is_active", True):
        raise HTTPException(403, "Account deactivated")
    if not verify_password(password, admin.get("hashed_password", "")):
        raise HTTPException(401, "Invalid credentials")

    token = create_access_token(
        admin["id"], extra_claims={"name": admin.get("full_name", "Admin"), "role": "admin"}
    )
    return {"access_token": token, "token_type": "bearer"}


@router.get("/students")
async def list_students(
    search: str = Query(None),
    status: str = Query(None),
    limit: int = Query(100),
):
    repo = SupabaseRepository("students")
    filters = {}
    if status:
        filters["is_active"] = status == "active"
    if search:
        return await repo.search(
            filters,
            text_search={"name": search, "phone": search},
            limit=limit,
        )
    return await repo.select(filters, limit=limit)


@router.put("/students/{student_id}/status")
async def toggle_student_status(student_id: str, request: Request):
    body = await request.json()
    is_active = body.get("is_active", True)
    await SupabaseRepository("students").update(
        {"id": student_id}, {"is_active": is_active}
    )
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
        await SupabaseRepository("subscription_codes").insert(
            {"code": code, "plan_id": plan_id, "is_used": False}
        )
        codes.append(code)
    return {"ok": True, "codes": codes}


@router.get("/codes")
async def list_codes(
    plan_id: str = Query(None),
    is_used: bool = Query(None),
):
    filters = {}
    if plan_id:
        filters["plan_id"] = plan_id
    if is_used is not None:
        filters["is_used"] = is_used
    return await SupabaseRepository("subscription_codes").select(filters, limit=200)


@router.get("/templates")
async def list_templates(type: str = Query(None)):
    filters = {}
    if type:
        filters["type"] = type
    return await SupabaseRepository("admin_templates").select(filters, limit=200)


@router.put("/templates/{template_id}")
async def update_template(template_id: str, request: Request):
    body = await request.json()
    await SupabaseRepository("admin_templates").update({"id": template_id}, body)
    return {"ok": True}


@router.get("/transactions")
async def list_transactions(
    status: str = Query(None),
    limit: int = Query(50),
):
    filters = {}
    if status:
        filters["status"] = status
    return await SupabaseRepository("payment_transactions").select(
        filters, limit=limit, order="created_at"
    )


@router.put("/transactions/{tx_id}")
async def update_transaction(tx_id: str, request: Request):
    body = await request.json()
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, body)
    return {"ok": True}


@router.get("/stats")
async def admin_stats():
    students_repo = SupabaseRepository("students")
    codes_repo = SupabaseRepository("subscription_codes")
    tx_repo = SupabaseRepository("payment_transactions")
    return {
        "total_students": await students_repo.count(),
        "active_students": await students_repo.count({"is_active": True}),
        "total_codes": await codes_repo.count(),
        "used_codes": await codes_repo.count({"is_used": True}),
        "pending_transactions": await tx_repo.count({"status": "pending"}),
    }
