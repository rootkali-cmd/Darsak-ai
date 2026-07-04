import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from src.utils.dependencies import get_current_teacher
from src.core.security.supabase_repo import get_supabase

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/wallet")


async def _get_teacher_wallet(teacher_id: str):
    client = await get_supabase()
    result = await client.table("teacher_wallets").select("*").eq("teacher_id", teacher_id).execute()
    if result.data:
        return result.data[0]
    wallet = {"teacher_id": teacher_id, "available_balance": 0, "pending_balance": 0, "total_earned": 0, "total_withdrawn": 0}
    result = await client.table("teacher_wallets").insert(wallet).execute()
    return result.data[0] if result.data else wallet


@router.get("")
async def get_wallet(current_user: dict = Depends(get_current_teacher)):
    wallet = await _get_teacher_wallet(current_user["id"])
    return {
        "balance": float(wallet.get("available_balance", 0)),
        "pending_balance": float(wallet.get("pending_balance", 0)),
        "total_deposited": float(wallet.get("total_earned", 0)),
        "total_withdrawn": float(wallet.get("total_withdrawn", 0)),
        "currency": wallet.get("currency", "EGP"),
    }


@router.get("/transactions")
async def get_wallet_transactions(
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        client = await get_supabase()
        wallet = await _get_teacher_wallet(current_user["id"])
        result = (
            await client.table("wallet_transactions")
            .select("*")
            .eq("teacher_id", current_user["id"])
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return {"items": result.data or []}
    except Exception as e:
        logger.error("get_wallet_transactions failed: %s", e)
        return {"items": []}


class PayoutRequest(BaseModel):
    amount: float
    payout_method: str = "vodafone_cash"
    payout_phone: str = ""


@router.post("/payout-request")
async def request_payout(body: PayoutRequest, current_user: dict = Depends(get_current_teacher)):
    wallet = await _get_teacher_wallet(current_user["id"])
    available = float(wallet.get("available_balance", 0))
    if body.amount < 10:
        raise HTTPException(status_code=400, detail="الحد الأدنى للسحب هو 10 جنيه")
    if body.amount > available:
        raise HTTPException(status_code=400, detail=f"الرصيد غير كافي. الرصيد المتاح: {available}")
    try:
        client = await get_supabase()
        commission_rate = 5.0
        commission_amount = round(body.amount * commission_rate / 100, 2)
        net_amount = round(body.amount - commission_amount, 2)
        payout = {
            "teacher_id": current_user["id"],
            "wallet_id": wallet["id"],
            "requested_amount": body.amount,
            "commission_rate": commission_rate,
            "commission_amount": commission_amount,
            "net_amount": net_amount,
            "payout_method": body.payout_method,
            "payout_phone": body.payout_phone,
            "status": "pending",
        }
        result = await client.table("payout_requests").insert(payout).execute()
        return {"ok": True, "data": result.data[0] if result.data else payout}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_payout failed: %s", e)
        raise HTTPException(status_code=500, detail="internal error")


@router.get("/payout-requests")
async def get_payout_requests(
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    try:
        client = await get_supabase()
        result = (
            await client.table("payout_requests")
            .select("*")
            .eq("teacher_id", current_user["id"])
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return {"items": result.data or []}
    except Exception as e:
        logger.error("get_payout_requests failed: %s", e)
        return {"items": []}
