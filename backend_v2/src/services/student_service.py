from src.repositories.supabase import SupabaseRepository
import uuid
from src.core.security.auth import hash_password


class StudentService:
    def __init__(self):
        self.repo = SupabaseRepository("students")
        self.attendance_repo = SupabaseRepository("attendance")
        self.grades_repo = SupabaseRepository("grades")

    async def list_by_teacher(self, teacher_id: str, search: str = None, limit: int = 100, offset: int = 0) -> list[dict]:
        filters = {"teacher_id": teacher_id}
        if search:
            return await self.repo.search(filters, text_search={"full_name": search, "code": search}, limit=limit, offset=offset)
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def get_by_id(self, student_id: str) -> dict | None:
        return await self.repo.select_one({"id": student_id})

    async def get_by_code(self, code: str) -> dict | None:
        return await self.repo.select_one({"code": code})

    async def create(self, data: dict) -> dict:
        return await self.repo.insert(data)

    async def update(self, student_id: str, data: dict) -> dict:
        return await self.repo.update({"id": student_id}, data)

    async def delete(self, student_id: str) -> bool:
        return await self.repo.delete({"id": student_id})

    async def count_by_teacher(self, teacher_id: str) -> int:
        return await self.repo.count({"teacher_id": teacher_id})

    async def get_attendance(self, student_id: str) -> list[dict]:
        return await self.attendance_repo.select({"student_id": student_id}, limit=500)

    async def get_grades(self, student_id: str) -> list[dict]:
        return await self.grades_repo.select({"student_id": student_id}, limit=500)


student_service = StudentService()
