import logging
from datetime import datetime, timezone

logger = logging.getLogger("darsak")


class FinanceService:
    async def _get_client(self):
        from src.core.security.supabase_repo import get_supabase
        return await get_supabase()

    async def get_or_create_wallet(self, student_id: str) -> dict:
        try:
            client = await self._get_client()
            result = await client.table("student_wallets").select("*").eq("student_id", student_id).execute()
            if result.data:
                return result.data[0]
            wallet = {
                "student_id": student_id,
                "balance": 0.00,
                "total_deposited": 0.00,
                "total_spent": 0.00,
            }
            result = await client.table("student_wallets").insert(wallet).execute()
            return result.data[0] if result.data else wallet
        except Exception as e:
            logger.error("get_or_create_wallet failed: %s", e)
            return {"balance": 0, "total_deposited": 0, "total_spent": 0}

    async def get_transactions(self, student_id: str, limit: int = 50, offset: int = 0) -> list:
        try:
            client = await self._get_client()
            result = await (
                client.table("student_transactions")
                .select("*")
                .eq("student_id", student_id)
                .order("created_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
            return result.data or []
        except Exception as e:
            logger.error("get_transactions failed: %s", e)
            return []

    async def request_deposit(self, student_id: str, amount: float) -> dict:
        tax_rate = 1.50
        tax_amount = round(amount * tax_rate / 100, 2)
        total_amount = round(amount + tax_amount, 2)
        try:
            client = await self._get_client()
            deposit = {
                "student_id": student_id,
                "amount": amount,
                "tax_rate": tax_rate,
                "tax_amount": tax_amount,
                "total_amount": total_amount,
                "status": "pending",
            }
            result = await client.table("student_deposit_requests").insert(deposit).execute()
            return result.data[0] if result.data else deposit
        except Exception as e:
            logger.error("request_deposit failed: %s", e)
            raise

    async def record_transaction(self, **kwargs):
        logger.info("Finance service record_transaction called")
        return None

    async def get_teacher_balance(self, teacher_id: str) -> float:
        return 0.0

    async def get_teacher_transactions(self, teacher_id: str, limit: int = 50):
        return []


finance_service = FinanceService()
