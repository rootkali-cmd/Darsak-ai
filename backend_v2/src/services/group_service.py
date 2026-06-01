from src.repositories.supabase import SupabaseRepository


class GroupService:
    def __init__(self):
        self.repo = SupabaseRepository("groups")

    async def list_by_teacher(self, teacher_id: str) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id}, limit=200)

    async def get_by_id(self, group_id: str) -> dict | None:
        return await self.repo.select_one({"id": group_id})

    async def create(self, data: dict) -> dict:
        return await self.repo.insert(data)

    async def update(self, group_id: str, data: dict) -> dict:
        return await self.repo.update({"id": group_id}, data)

    async def delete(self, group_id: str) -> bool:
        return await self.repo.delete({"id": group_id})


group_service = GroupService()
