import json
import logging
from datetime import datetime, timezone, timedelta

from src.core.security.supabase_repo import SupabaseRepository
from src.services.exam_ai import exam_ai_service

logger = logging.getLogger("darsak.quiz")


class QuizService:
    def __init__(self):
        self.repo = SupabaseRepository("quizzes")
        self.questions_repo = SupabaseRepository("quiz_questions")

    async def count_today_quizzes(self, student_id: str, date_str: str) -> int:
        records = await self.repo.select({"student_id": student_id}, limit=100)
        return sum(1 for r in records if str(r.get("created_at", "")).startswith(date_str))

    async def generate_quiz(self, transcript: str, title: str) -> list[dict]:
        try:
            messages = [{
                "role": "system",
                "content": "أنت خبير تعليمي. اقرأ النص التالي واستخرج 20 سؤال اختيار من متعدد (MCQ) تغطي أهم النقاط. رجّع الأسئلة بصيغة JSON فقط."
            }, {
                "role": "user",
                "content": f"عنوان الدرس: {title}\n\nالنص:\n{transcript}\n\nاستخرج 20 سؤال MCQ بصيغة JSON: [{{\"question\":\"...\", \"options\":[\"A\",\"B\",\"C\",\"D\"], \"correct\":0}}]"
            }]

            result = await exam_ai_service._call_best(messages)
            if isinstance(result, list):
                return result
            if isinstance(result, dict) and "questions" in result:
                return result["questions"]
            return result if isinstance(result, list) else []
        except Exception as exc:
            logger.error("Quiz generation failed: %s", exc)
            return []

    async def save_quiz(self, student_id: str, lesson_id: str, questions: list[dict]) -> dict:
        quiz = await self.repo.insert({
            "student_id": student_id,
            "lesson_id": lesson_id,
            "total_questions": len(questions),
        })
        for q in questions:
            await self.questions_repo.insert({
                "quiz_id": quiz["id"],
                "question_text": q["question"],
                "options": json.dumps(q["options"]),
                "correct_answer": q["correct"],
            })
        return quiz

    async def get_quiz(self, quiz_id: str, student_id: str) -> dict | None:
        quiz = await self.repo.select_one({"id": quiz_id, "student_id": student_id})
        if quiz:
            questions = await self.questions_repo.select({"quiz_id": quiz_id}, limit=50)
            quiz["questions"] = questions
        return quiz

    async def get_history(self, student_id: str, days: int = 30) -> list[dict]:
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
        return await self.repo.select({"student_id": student_id}, limit=200)

    async def get_history_with_questions(self, student_id: str, days: int = 30) -> list[dict]:
        quizzes = await self.get_history(student_id, days)
        for q in quizzes:
            questions = await self.questions_repo.select({"quiz_id": q["id"]}, limit=50)
            q["questions"] = questions
        return quizzes


quiz_service = QuizService()
