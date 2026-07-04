import logging

logger = logging.getLogger("darsak")


class FinanceService:
    async def record_transaction(self, **kwargs):
        logger.info("Finance service not configured")
        return None

    async def get_teacher_balance(self, teacher_id: str) -> float:
        return 0.0

    async def get_teacher_transactions(self, teacher_id: str, limit: int = 50):
        return []


finance_service = FinanceService()
