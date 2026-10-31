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
            dep = result.data[0] if result.data else deposit
            # Record pending transaction
            try:
                await client.table("student_transactions").insert({
                    "student_id": student_id,
                    "amount": total_amount,
                    "type": "deposit",
                    "note": f"طلب إيداع ({amount:.0f} ج.م) - قيد المراجعة",
                }).execute()
            except Exception:
                pass
            return dep
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

    async def process_deposit_approve(self, dep_id: str) -> dict:
        try:
            client = await self._get_client()
            result = await client.table("student_deposit_requests").select("*").eq("id", dep_id).execute()
            if not result.data:
                raise ValueError("Deposit request not found")
            dep = result.data[0]
            if dep.get("status") != "pending":
                raise ValueError(f"Deposit is already {dep.get('status')}")
            student_id = dep["student_id"]
            amount = float(dep.get("amount", 0))
            total_amount = float(dep.get("total_amount", amount))
            # Update deposit status
            from datetime import datetime, timezone
            await client.table("student_deposit_requests").update({
                "status": "approved",
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", dep_id).execute()
            # Update wallet
            wallet_result = await client.table("student_wallets").select("*").eq("student_id", student_id).execute()
            if wallet_result.data:
                w = wallet_result.data[0]
                new_balance = float(w.get("balance", 0)) + total_amount
                new_deposited = float(w.get("total_deposited", 0)) + total_amount
                await client.table("student_wallets").update({
                    "balance": new_balance,
                    "total_deposited": new_deposited,
                }).eq("student_id", student_id).execute()
            else:
                new_balance = total_amount
                await client.table("student_wallets").insert({
                    "student_id": student_id,
                    "balance": total_amount,
                    "total_deposited": total_amount,
                    "total_spent": 0,
                }).execute()
            # Record transaction
            await client.table("student_transactions").insert({
                "student_id": student_id,
                "amount": total_amount,
                "type": "deposit",
                "note": f"إيداع مقبول (طلب #{dep_id[:8]})",
            }).execute()
            return {"new_balance": new_balance, "deposit_id": dep_id}
        except Exception as e:
            logger.error("process_deposit_approve failed: %s", e)
            raise

    async def process_deposit_reject(self, dep_id: str, reason: str = "") -> dict:
        try:
            client = await self._get_client()
            from datetime import datetime, timezone
            await client.table("student_deposit_requests").update({
                "status": "rejected",
                "rejection_reason": reason,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", dep_id).execute()
            return {"deposit_id": dep_id, "status": "rejected"}
        except Exception as e:
            logger.error("process_deposit_reject failed: %s", e)
            raise


finance_service = FinanceService()
