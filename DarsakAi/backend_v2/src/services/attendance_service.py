from src.repositories.supabase import SupabaseRepository
from datetime import date as date_type


class AttendanceService:
    def __init__(self):
        self.repo = SupabaseRepository("attendance")
        self.student_repo = SupabaseRepository("students")

    async def list_by_teacher(self, teacher_id: str, date: str = None, student_id: str = None) -> list[dict]:
        filters = {"teacher_id": teacher_id}
        if date:
            filters["date"] = date
        if student_id:
            filters["student_id"] = student_id
        return await self.repo.select(filters, limit=500)

    async def create(self, data: dict) -> dict:
        return await self.repo.insert(data)

    async def bulk_create(self, records: list[dict]) -> list[dict]:
        results = []
        for record in records:
            results.append(await self.repo.insert(record))
        return results

    async def get_today_stats(self, teacher_id: str) -> dict:
        today = date_type.today().isoformat()
        records = await self.repo.select({"teacher_id": teacher_id, "date": today}, limit=5000)
        total = len(records)
        present = sum(1 for r in records if r.get("status") == "present")
        return {"date": today, "total": total, "present": present, "absent": total - present}

    async def get_student_by_code(self, code: str) -> dict | None:
        return await self.student_repo.select_one({"code": code})


attendance_service = AttendanceService()
