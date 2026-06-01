from src.repositories.supabase import SupabaseRepository


class UserService:
    def __init__(self):
        self.repo = SupabaseRepository("users")

    async def get_by_id(self, user_id: str) -> dict | None:
        return await self.repo.select_one({"id": user_id})

    async def get_by_email(self, email: str) -> dict | None:
        return await self.repo.select_one({"email": email})

    async def create(self, data: dict) -> dict:
        return await self.repo.insert(data)

    async def update(self, user_id: str, data: dict) -> dict:
        return await self.repo.update({"id": user_id}, data)


user_service = UserService()
