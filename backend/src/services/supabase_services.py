from typing import Any
from uuid import UUID
from datetime import datetime, timezone, timedelta

from src.core.security.supabase_repo import SupabaseRepository
from src.core.security.auth import hash_password


class UserService:
    def __init__(self):
        self.repo = SupabaseRepository("users")

    async def create(self, email: str, full_name: str, password: str, role: str = "teacher") -> dict:
        existing = await self.repo.select_one({"email": email})
        if existing:
            raise ValueError("Email already registered")

        import uuid
        teacher_code = f"TCH-{uuid.uuid4().hex[:8].upper()}" if role in ("teacher", "admin") else None

        return await self.repo.insert({
            "email": email,
            "full_name": full_name,
            "hashed_password": hash_password(password),
            "role": role,
            "is_active": True,
            "teacher_code": teacher_code,
        })

    async def get_by_email(self, email: str) -> dict | None:
        return await self.repo.select_one({"email": email})

    async def get_by_id(self, user_id: str) -> dict | None:
        return await self.repo.select_one({"id": user_id})

    async def update(self, user_id: str, data: dict) -> dict:
        if "password" in data:
            data["hashed_password"] = hash_password(data.pop("password"))
        return await self.repo.update({"id": user_id}, data)


class StudentService:
    def __init__(self):
        self.repo = SupabaseRepository("students")

    async def create(self, teacher_id: str, full_name: str, **kwargs) -> dict:
        import uuid
        code = f"ST{uuid.uuid4().hex[:7].upper()}"
        pin_hash = hash_password(kwargs.pop("pin")) if kwargs.get("pin") else None

        return await self.repo.insert({
            "teacher_id": teacher_id,
            "code": code,
            "full_name": full_name,
            "pin_hash": pin_hash,
            **{k: v for k, v in kwargs.items() if v is not None},
        })

    async def get_by_id(self, student_id: str) -> dict | None:
        return await self.repo.select_one({"id": student_id})

    async def get_by_code(self, code: str) -> dict | None:
        return await self.repo.select_one({"code": code})

    async def list_by_teacher(self, teacher_id: str, search: str | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        filters = {"teacher_id": teacher_id}
        students = await self.repo.select(filters, limit=limit, offset=offset)
        if search:
            students = [s for s in students if search.lower() in s["full_name"].lower() or search.lower() in s["code"].lower()]
        return students

    async def update(self, student_id: str, data: dict) -> dict:
        if "pin" in data:
            data["pin_hash"] = hash_password(data.pop("pin"))
        return await self.repo.update({"id": student_id}, data)

    async def delete(self, student_id: str) -> bool:
        return await self.repo.delete({"id": student_id})

    async def count(self, teacher_id: str) -> int:
        return await self.repo.count({"teacher_id": teacher_id})


class GroupService:
    def __init__(self):
        self.repo = SupabaseRepository("groups")

    async def create(self, teacher_id: str, **kwargs) -> dict:
        return await self.repo.insert({"teacher_id": teacher_id, **kwargs})

    async def get_by_id(self, group_id: str) -> dict | None:
        return await self.repo.select_one({"id": group_id})

    async def list_by_teacher(self, teacher_id: str, limit: int = 50) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id}, limit=limit)

    async def update(self, group_id: str, data: dict) -> dict:
        return await self.repo.update({"id": group_id}, data)

    async def delete(self, group_id: str) -> bool:
        return await self.repo.delete({"id": group_id})


class AttendanceService:
    def __init__(self):
        self.repo = SupabaseRepository("attendances")

    async def create(self, **kwargs) -> dict:
        from datetime import date
        kwargs.setdefault("date", date.today().isoformat())
        kwargs.setdefault("status", "absent")
        return await self.repo.insert(kwargs)

    async def list(self, filters: dict | None = None, limit: int = 50) -> list[dict]:
        return await self.repo.select(filters, limit=limit)

    async def get_by_student_and_date(self, student_id: str, date: str) -> dict | None:
        records = await self.repo.select({"student_id": student_id, "date": date}, limit=1)
        return records[0] if records else None

    async def update(self, attendance_id: str, data: dict) -> dict:
        return await self.repo.update({"id": attendance_id}, data)

    async def get_stats(self, teacher_id: str, date: str | None = None) -> dict:
        filters = {"teacher_id": teacher_id}
        if date:
            filters["date"] = date
        records = await self.repo.select(filters, limit=500)
        return {
            "present": sum(1 for r in records if r["status"] == "present"),
            "absent": sum(1 for r in records if r["status"] == "absent"),
            "cancelled": sum(1 for r in records if r["status"] == "cancelled"),
            "total": len(records),
        }


class GradeService:
    def __init__(self):
        self.repo = SupabaseRepository("grades")

    async def create(self, **kwargs) -> dict:
        kwargs.setdefault("max_score", 100)
        return await self.repo.insert(kwargs)

    async def list(self, filters: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def get_stats(self, teacher_id: str, subject: str | None = None) -> dict:
        filters = {"teacher_id": teacher_id}
        if subject:
            filters["subject"] = subject
        grades = await self.repo.select(filters, limit=500)
        if not grades:
            return {"average": 0, "highest": 0, "lowest": 0, "total": 0}
        percentages = [(g["score"] / g["max_score"]) * 100 for g in grades]
        return {
            "average": sum(percentages) / len(percentages),
            "highest": max(percentages),
            "lowest": min(percentages),
            "total": len(grades),
        }

    async def delete(self, grade_id: str) -> bool:
        return await self.repo.delete({"id": grade_id})


class InvoiceService:
    def __init__(self):
        self.repo = SupabaseRepository("invoices")

    async def create(self, **kwargs) -> dict:
        kwargs.setdefault("paid", False)
        return await self.repo.insert(kwargs)

    async def list(self, filters: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def update(self, invoice_id: str, data: dict) -> dict:
        return await self.repo.update({"id": invoice_id}, data)

    async def delete(self, invoice_id: str) -> bool:
        return await self.repo.delete({"id": invoice_id})

    async def get_stats(self, teacher_id: str) -> dict:
        invoices = await self.repo.select({"teacher_id": teacher_id}, limit=500)
        total_amount = sum(i["amount"] for i in invoices)
        paid_amount = sum(i["amount"] for i in invoices if i.get("paid"))
        return {
            "total_amount": total_amount,
            "total_count": len(invoices),
            "paid_amount": paid_amount,
            "unpaid_amount": total_amount - paid_amount,
        }


VALID_ACTOR_TYPES = {"student", "teacher", "assistant", "system"}

class SubscriptionPlanService:
    def __init__(self):
        self.repo = SupabaseRepository("subscription_plans")

    async def list_active(self) -> list[dict]:
        return await self.repo.select({"is_active": True}, limit=50)

    async def get_by_id(self, plan_id: str) -> dict | None:
        return await self.repo.select_one({"id": plan_id})

    async def get_by_name(self, name: str) -> dict | None:
        return await self.repo.select_one({"name": name})


class SubscriptionCodeService:
    def __init__(self):
        self.repo = SupabaseRepository("subscription_codes")

    async def create(self, code: str, plan_id: str, expires_at: str | None = None) -> dict:
        return await self.repo.insert({
            "code": code,
            "plan_id": plan_id,
            "expires_at": expires_at,
        })

    async def get_by_code(self, code: str) -> dict | None:
        return await self.repo.select_one({"code": code})

    async def mark_used(self, code_id: str, teacher_id: str) -> dict:
        return await self.repo.update(
            {"id": code_id},
            {
                "is_used": True,
                "used_by_teacher_id": teacher_id,
                "used_at": datetime.now(timezone.utc).isoformat(),
            },
        )

    async def list_all(self, limit: int = 100) -> list[dict]:
        return await self.repo.select({}, limit=limit)

    async def count_by_used(self, is_used: bool) -> int:
        return await self.repo.count({"is_used": is_used})


class TeacherSubscriptionService:
    def __init__(self):
        self.repo = SupabaseRepository("teacher_subscriptions")

    async def create(self, teacher_id: str, plan_id: str, code_id: str, expires_at: str) -> dict:
        return await self.repo.insert({
            "teacher_id": teacher_id,
            "plan_id": plan_id,
            "code_id": code_id,
            "expires_at": expires_at,
            "is_active": True,
        })

    async def get_by_teacher(self, teacher_id: str) -> dict | None:
        return await self.repo.select_one({"teacher_id": teacher_id})

    async def update(self, subscription_id: str, data: dict) -> dict:
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        return await self.repo.update({"id": subscription_id}, data)

    async def get_active_subscription(self, teacher_id: str) -> dict | None:
        sub = await self.repo.select_one({"teacher_id": teacher_id, "is_active": True})
        if not sub:
            return None
        expires = sub.get("expires_at")
        if expires:
            if isinstance(expires, str):
                expires_dt = datetime.fromisoformat(expires.replace("Z", "+00:00"))
            else:
                expires_dt = expires
            if expires_dt < datetime.now(timezone.utc):
                await self.update(sub["id"], {"is_active": False})
                return None
        return sub


class AuditService:
    def __init__(self):
        self.repo = SupabaseRepository("audit_logs")

    async def log(self, **kwargs) -> dict:
        kwargs.setdefault("timestamp", datetime.now(timezone.utc).isoformat())
        at = kwargs.get("actor_type")
        if at and at not in VALID_ACTOR_TYPES:
            kwargs["actor_type"] = "system"
        return await self.repo.insert(kwargs)

    async def search(self, filters: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        query = self.repo.client.table("audit_logs").select("*")
        if filters:
            if filters.get("actor_id"):
                query = query.eq("actor_id", filters["actor_id"])
            if filters.get("resource_type"):
                query = query.eq("resource_type", filters["resource_type"])
            if filters.get("action"):
                query = query.eq("action", filters["action"])
            if filters.get("from_date"):
                query = query.gte("created_at", filters["from_date"])
            if filters.get("to_date"):
                query = query.lte("created_at", filters["to_date"])
        query = query.order("created_at", desc=True).range(offset, offset + limit - 1)
        result = await query.execute()
        return result.data if result.data else []

    async def export_range(self, from_date: str, to_date: str, limit: int = 10000) -> list[dict]:
        query = (
            self.repo.client.table("audit_logs")
            .select("*")
            .gte("created_at", from_date)
            .lte("created_at", to_date)
            .order("created_at", desc=True)
            .limit(limit)
        )
        result = await query.execute()
        return result.data if result.data else []


class PaymentRequestService:
    def __init__(self):
        self.repo = SupabaseRepository("payment_requests")

    async def create(self, teacher_id: str, plan_id: str, phone_number: str, amount: float, screenshot: str | None = None) -> dict:
        return await self.repo.insert({
            "teacher_id": teacher_id,
            "plan_id": plan_id,
            "phone_number": phone_number,
            "amount": amount,
            "screenshot": screenshot,
            "status": "pending",
        })

    async def get_by_id(self, payment_id: str) -> dict | None:
        return await self.repo.select_one({"id": payment_id})

    async def get_by_teacher(self, teacher_id: str, limit: int = 10) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id}, limit=limit, order="created_at desc")

    async def get_pending(self, limit: int = 50) -> list[dict]:
        return await self.repo.select({"status": "pending"}, limit=limit, order="created_at asc")

    async def approve(self, payment_id: str) -> dict:
        return await self.repo.update({"id": payment_id}, {
            "status": "approved",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })

    async def reject(self, payment_id: str, message: str) -> dict:
        return await self.repo.update({"id": payment_id}, {
            "status": "rejected",
            "admin_message": message,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })


class NotificationService:
    def __init__(self):
        self.repo = SupabaseRepository("notifications")

    async def create(self, teacher_id: str, title: str, body: str, type: str = "info") -> dict:
        return await self.repo.insert({
            "teacher_id": teacher_id,
            "title": title,
            "body": body,
            "type": type,
        })

    async def get_unread(self, teacher_id: str) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id, "read": False}, limit=50, order="created_at desc")

    async def mark_read(self, notification_id: str) -> dict:
        return await self.repo.update({"id": notification_id}, {"read": True})

    async def mark_all_read(self, teacher_id: str) -> None:
        await self.repo.update({"teacher_id": teacher_id, "read": False}, {"read": True})


class ExamService:
    def __init__(self):
        self.repo = SupabaseRepository("exams")
        self.question_repo = SupabaseRepository("questions")

    async def create(self, teacher_id: str, title: str, duration_minutes: int = 30, description: str | None = None) -> dict:
        return await self.repo.insert({
            "teacher_id": teacher_id,
            "title": title,
            "description": description,
            "duration_minutes": duration_minutes,
            "status": "draft",
        })

    async def get_by_id(self, exam_id: str) -> dict | None:
        return await self.repo.select_one({"id": exam_id})

    async def get_by_teacher(self, teacher_id: str) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id}, limit=100)

    async def update(self, exam_id: str, data: dict) -> dict:
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        return await self.repo.update({"id": exam_id}, data)

    async def delete(self, exam_id: str) -> bool:
        return await self.repo.delete({"id": exam_id})

    async def get_questions(self, exam_id: str) -> list[dict]:
        return await self.question_repo.select({"exam_id": exam_id}, limit=200, order="order_index asc")

    async def add_question(self, exam_id: str, question_type: str, question_text: str,
                           points: int = 1, options: list | None = None,
                           correct_answer: str | None = None, order_index: int = 1,
                           page_number: int = 1) -> dict:
        return await self.question_repo.insert({
            "exam_id": exam_id,
            "type": question_type,
            "question_text": question_text,
            "options": options,
            "correct_answer": correct_answer,
            "points": points,
            "order_index": order_index,
            "page_number": page_number,
        })

    async def update_question(self, question_id: str, data: dict) -> dict:
        return await self.question_repo.update({"id": question_id}, data)

    async def delete_question(self, question_id: str) -> bool:
        return await self.question_repo.delete({"id": question_id})

    async def bulk_add_questions(self, exam_id: str, questions: list[dict]) -> list[dict]:
        created = []
        for i, q in enumerate(questions, 1):
            q.setdefault("order_index", i)
            q["exam_id"] = exam_id
            created.append(await self.question_repo.insert(q))
        return created

    async def publish(self, exam_id: str) -> dict:
        total = await self.question_repo.count({"exam_id": exam_id})
        return await self.update(exam_id, {"status": "published", "total_points": total * 10})

    async def get_published_for_student(self, student_id: str) -> list[dict]:
        exams = await self.repo.select({"status": "published"}, limit=100)
        return exams


class StudentExamService:
    def __init__(self):
        self.repo = SupabaseRepository("student_exams")
        self.answers_repo = SupabaseRepository("student_answers")
        self.results_repo = SupabaseRepository("exam_results")

    async def start(self, exam_id: str, student_id: str) -> dict:
        existing = await self.repo.select_one({"exam_id": exam_id, "student_id": student_id})
        if existing:
            return existing
        return await self.repo.insert({
            "exam_id": exam_id,
            "student_id": student_id,
            "status": "in_progress",
        })

    async def save_answer(self, student_exam_id: str, question_id: str, answer: str) -> dict:
        existing = await self.answers_repo.select_one({
            "student_exam_id": student_exam_id,
            "question_id": question_id,
        })
        if existing:
            return await self.answers_repo.update({"id": existing["id"]}, {"answer": answer})
        return await self.answers_repo.insert({
            "student_exam_id": student_exam_id,
            "question_id": question_id,
            "answer": answer,
        })

    async def submit(self, student_exam_id: str, answers: list[dict]) -> dict:
        for a in answers:
            await self.save_answer(student_exam_id, a["question_id"], a["answer"])
        se = await self.repo.update({"id": student_exam_id}, {
            "status": "submitted",
            "submitted_at": datetime.now(timezone.utc).isoformat(),
        })
        return se

    async def grade_mc_questions(self, student_exam_id: str) -> dict:
        se = await self.repo.select_one({"id": student_exam_id})
        if not se:
            raise ValueError("Student exam not found")
        answers = await self.answers_repo.select({"student_exam_id": student_exam_id})
        questions = await SupabaseRepository("questions").select({"exam_id": se["exam_id"]}, limit=200)
        questions_map = {q["id"]: q for q in questions}
        total = 0
        max_score = 0
        correct = 0
        wrong = 0
        essay_score = 0.0
        for a in answers:
            q = questions_map.get(a.get("question_id"))
            if not q:
                continue
            pts = q.get("points", 1)
            max_score += pts
            if q["type"] == "multiple_choice":
                if a.get("answer") == q.get("correct_answer"):
                    total += pts
                    correct += 1
                    self.answers_repo.update({"id": a["id"]}, {"is_correct": True, "score": pts})
                else:
                    wrong += 1
                    self.answers_repo.update({"id": a["id"]}, {"is_correct": False, "score": 0})
            else:
                essay_score += pts
        total += essay_score
        await self.repo.update({"id": student_exam_id}, {
            "total_score": total,
            "max_score": max_score,
            "status": "graded",
        })
        return {
            "total_score": total,
            "max_score": max_score,
            "correct_count": correct,
            "wrong_count": wrong,
            "essay_score": essay_score,
        }

    async def get_result(self, student_exam_id: str) -> dict | None:
        return await self.results_repo.select_one({"student_exam_id": student_exam_id})

    async def save_ai_analysis(self, student_exam_id: str, analysis: dict) -> dict:
        result = await self.results_repo.select_one({"student_exam_id": student_exam_id})
        if result:
            return await self.results_repo.update({"id": result["id"]}, analysis)
        se = await self.repo.select_one({"id": student_exam_id})
        return await self.results_repo.insert({
            "student_exam_id": student_exam_id,
            **analysis,
        })

    async def get_student_exams(self, student_id: str) -> list[dict]:
        return await self.repo.select({"student_id": student_id}, limit=50)

    async def get_by_id(self, student_exam_id: str) -> dict | None:
        return await self.repo.select_one({"id": student_exam_id})

    async def get_answers(self, student_exam_id: str) -> list[dict]:
        return await self.answers_repo.select({"student_exam_id": student_exam_id})

    async def get_class_results(self, exam_id: str) -> list[dict]:
        return await self.repo.select({"exam_id": exam_id}, limit=200)
