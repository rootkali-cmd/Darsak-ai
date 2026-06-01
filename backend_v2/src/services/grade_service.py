from src.repositories.supabase import SupabaseRepository


class GradeService:
    def __init__(self):
        self.repo = SupabaseRepository("grades")

    async def list_by_teacher(self, teacher_id, subject=None, student_id=None, limit=200):
        filters = {"teacher_id": teacher_id}
        if subject:
            filters["subject"] = subject
        if student_id:
            filters["student_id"] = student_id
        return await self.repo.select(filters, limit=limit)

    async def create(self, data):
        return await self.repo.insert(data)

    async def update(self, grade_id, data):
        return await self.repo.update({"id": grade_id}, data)

    async def delete(self, grade_id):
        return await self.repo.delete({"id": grade_id})


grade_service = GradeService()
