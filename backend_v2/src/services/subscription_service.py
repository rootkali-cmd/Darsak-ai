from src.repositories.supabase import SupabaseRepository
from datetime import datetime, timezone, timedelta


class SubscriptionService:
    def __init__(self):
        self.plans_repo = SupabaseRepository("subscription_plans")
        self.codes_repo = SupabaseRepository("subscription_codes")
        self.subs_repo = SupabaseRepository("teacher_subscriptions")
        self.payments_repo = SupabaseRepository("payment_requests")

    async def list_active_plans(self):
        return await self.plans_repo.select({"is_active": True}, limit=100)

    async def get_plan_by_id(self, plan_id):
        return await self.plans_repo.select_one({"id": plan_id})

    async def get_teacher_subscription(self, teacher_id):
        subs = await self.subs_repo.select({"teacher_id": teacher_id, "is_active": True}, limit=1)
        return subs[0] if subs else None

    async def get_code_by_value(self, code):
        return await self.codes_repo.select_one({"code": code.upper().strip()})

    async def create_subscription(self, data):
        return await self.subs_repo.insert(data)

    async def activate_code(self, code_id):
        return await self.codes_repo.update(
            {"id": code_id},
            {"is_used": True, "used_at": datetime.now(timezone.utc).isoformat()},
        )

    async def create_payment_request(self, data):
        return await self.payments_repo.insert(data)


subscription_service = SubscriptionService()
