from src.repositories.supabase import SupabaseRepository


class LessonService:
    def __init__(self):
        self.repo = SupabaseRepository("lessons")

    async def list_by_teacher(self, teacher_id, group_id=None, is_published=None, limit=50, offset=0):
        filters = {"teacher_id": teacher_id}
        if group_id:
            filters["group_id"] = group_id
        if is_published is not None:
            filters["is_published"] = is_published
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def get_by_id(self, lesson_id):
        return await self.repo.select_one({"id": lesson_id})

    async def create(self, data):
        return await self.repo.insert(data)

    async def update(self, lesson_id, data):
        return await self.repo.update({"id": lesson_id}, data)

    async def delete(self, lesson_id):
        return await self.repo.delete({"id": lesson_id})


lesson_service = LessonService()
