import logging
from fastapi import APIRouter, Depends
from src.utils.dependencies import get_current_teacher
from src.core.security.supabase_repo import get_supabase

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/finance")


@router.get("/overview")
async def get_finance_overview(current_user: dict = Depends(get_current_teacher)):
    try:
        client = await get_supabase()
        wallet_result = await client.table("teacher_wallets").select("*").eq("teacher_id", current_user["id"]).execute()
        wallet = wallet_result.data[0] if wallet_result.data else {}

        pending_result = await (
            client.table("payout_requests")
            .select("*", count="exact")
            .eq("teacher_id", current_user["id"])
            .eq("status", "pending")
            .execute()
        )
        completed_result = await (
            client.table("payout_requests")
            .select("*", count="exact")
            .eq("teacher_id", current_user["id"])
            .eq("status", "completed")
            .execute()
        )

        return {
            "available_balance": float(wallet.get("available_balance", 0)),
            "pending_balance": float(wallet.get("pending_balance", 0)),
            "total_earned": float(wallet.get("total_earned", 0)),
            "total_withdrawn": float(wallet.get("total_withdrawn", 0)),
            "pending_payouts": len(pending_result.data or []),
            "completed_payouts": len(completed_result.data or []),
        }
    except Exception as e:
        logger.error("get_finance_overview failed: %s", e)
        return {
            "available_balance": 0,
            "pending_balance": 0,
            "total_earned": 0,
            "total_withdrawn": 0,
            "pending_payouts": 0,
            "completed_payouts": 0,
        }
