from src.repositories.supabase import SupabaseRepository


class ExamService:
    def __init__(self):
        self.repo = SupabaseRepository("exams")
        self.q_repo = SupabaseRepository("exam_questions")

    async def list_by_teacher(self, teacher_id, limit=100):
        return await self.repo.select({"teacher_id": teacher_id}, limit=limit)

    async def get_by_id(self, exam_id):
        exam = await self.repo.select_one({"id": exam_id})
        if exam:
            exam["questions"] = await self.q_repo.select({"exam_id": exam_id}, limit=200)
        return exam

    async def create(self, data):
        return await self.repo.insert(data)

    async def update(self, exam_id, data):
        return await self.repo.update({"id": exam_id}, data)

    async def delete(self, exam_id):
        return await self.repo.delete({"id": exam_id})

    async def add_question(self, exam_id, data):
        data["exam_id"] = exam_id
        return await self.q_repo.insert(data)

    async def get_question_by_id(self, q_id):
        return await self.q_repo.select_one({"id": q_id})

    async def update_question(self, q_id, data):
        return await self.q_repo.update({"id": q_id}, data)

    async def delete_question(self, q_id):
        return await self.q_repo.delete({"id": q_id})


exam_service = ExamService()
