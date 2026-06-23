import asyncio
import logging
from typing import Any
from uuid import UUID
from datetime import datetime, timezone, timedelta

from src.core.security.supabase_repo import SupabaseRepository
from src.core.security.auth import hash_password

logger = logging.getLogger("darsak")


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
        from src.core.security.sanitizer import sanitize_student_code

        custom_code = kwargs.pop("code", None)
        if custom_code:
            code = sanitize_student_code(custom_code)
        else:
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
        return await self.repo.select_one_ilike({"code": code})

    async def list_by_teacher(self, teacher_id: str, search: str | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        filters = {"teacher_id": teacher_id}
        if search:
            # Use Supabase text search for efficiency
            students = await self.repo.search(
                filters,
                text_search={"full_name": search, "code": search},
                limit=limit,
                offset=offset,
            )
        else:
            students = await self.repo.select(filters, limit=limit, offset=offset)
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

    async def get_by_id(self, attendance_id: str) -> dict | None:
        return await self.repo.select_one({"id": attendance_id})

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

    async def get_by_id(self, grade_id: str) -> dict | None:
        return await self.repo.select_one({"id": grade_id})

    async def update(self, grade_id: str, data: dict) -> dict:
        return await self.repo.update({"id": grade_id}, data)

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

    async def get_by_id(self, invoice_id: str) -> dict | None:
        return await self.repo.select_one({"id": invoice_id})

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
        plans = await self.repo.select({"is_active": True}, limit=50)
        plan_names = {p.get("name") for p in plans}
        expected = {"Basic", "Pro", "Premium"}
        missing = expected - plan_names
        if missing:
            logger.warning("Subscription plan service: missing plans from DB: %s", missing)
        return plans

    async def get_by_id(self, plan_id: str) -> dict | None:
        return await self.repo.select_one({"id": plan_id})

    async def get_by_name(self, name: str) -> dict | None:
        return await self.repo.select_one({"name": name})

    async def get_plan_storage_limit(self, plan_name: str) -> int:
        from src.core.config import get_settings
        s = get_settings()
        if "unlimited" in plan_name.lower() or "enterprise" in plan_name.lower() or "premium" in plan_name.lower() or "متكاملة" in plan_name:
            return s.PLAN_ENTERPRISE_STORAGE_LIMIT
        if "pro" in plan_name.lower() or "احترافية" in plan_name:
            return s.PLAN_PRO_STORAGE_LIMIT
        return s.PLAN_BASIC_STORAGE_LIMIT

    async def get_plan_ai_limit(self, plan_name: str) -> int:
        from src.core.config import get_settings
        s = get_settings()
        if "unlimited" in plan_name.lower() or "enterprise" in plan_name.lower() or "premium" in plan_name.lower() or "متكاملة" in plan_name:
            return s.PLAN_PREMIUM_AI_LIMIT
        if "pro" in plan_name.lower() or "احترافية" in plan_name:
            return s.PLAN_PRO_AI_LIMIT
        return s.PLAN_BASIC_AI_LIMIT

    async def get_plan_student_limit(self, plan_name: str) -> int:
        from src.core.config import get_settings
        s = get_settings()
        if "unlimited" in plan_name.lower() or "enterprise" in plan_name.lower() or "premium" in plan_name.lower() or "متكاملة" in plan_name:
            return s.PLAN_PREMIUM_MAX_STUDENTS
        if "pro" in plan_name.lower() or "احترافية" in plan_name:
            return s.PLAN_PRO_MAX_STUDENTS
        return s.PLAN_BASIC_MAX_STUDENTS

    async def get_teacher_ai_usage_this_month(self, teacher_id: str) -> int:
        from datetime import datetime, timezone
        audit_repo = SupabaseRepository("audit_logs")
        now = datetime.now(timezone.utc)
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).isoformat()
        records = await audit_repo.select(
            {"actor_id": teacher_id, "action": "ai_request"},
            limit=10000
        )
        count = sum(1 for r in records if r.get("created_at", "") >= start_of_month)
        return count


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

    async def create(self, teacher_id: str, plan_id: str, code_id: str, expires_at: str, is_trial: bool = False) -> dict:
        data = {
            "teacher_id": teacher_id,
            "plan_id": plan_id,
            "expires_at": expires_at,
            "is_active": True,
            "is_trial": is_trial,
        }
        if code_id:
            data["code_id"] = code_id
        return await self.repo.insert(data)

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

    async def upsert_by_teacher(self, teacher_id: str, plan_id: str, code_id: str | None, expires_at: str, is_trial: bool = False) -> dict:
        existing = await self.repo.select_one({"teacher_id": teacher_id})
        now = datetime.now(timezone.utc).isoformat()
        data = {
            "plan_id": plan_id,
            "expires_at": expires_at,
            "is_active": True,
            "is_trial": is_trial,
            "updated_at": now,
        }
        if existing:
            if not existing.get("activated_at"):
                data["activated_at"] = now
            return await self.repo.update({"teacher_id": teacher_id}, data)
        data["teacher_id"] = teacher_id
        data["activated_at"] = now
        return await self.repo.insert(data)

    async def has_ever_had_subscription(self, teacher_id: str) -> bool:
        """Check if teacher ever had any subscription (active or expired)."""
        count = await self.repo.count({"teacher_id": teacher_id})
        return count > 0

    async def has_used_trial(self, teacher_id: str) -> bool:
        """Check if teacher already used their free trial."""
        subs = await self.repo.select({"teacher_id": teacher_id}, limit=100)
        for sub in subs:
            if sub.get("is_trial"):
                return True
        return False


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
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def export_range(self, from_date: str, to_date: str, limit: int = 10000) -> list[dict]:
        return await self.repo.select({}, limit=limit)


class PaymentRequestService:
    def __init__(self):
        self.repo = SupabaseRepository("payment_requests")

    async def create(self, teacher_id: str, plan_id: str, phone_number: str, amount: float, screenshot: str | None = None, billing_period: str = "monthly") -> dict:
        return await self.repo.insert({
            "teacher_id": teacher_id,
            "plan_id": plan_id,
            "phone_number": phone_number,
            "amount": amount,
            "screenshot": screenshot,
            "status": "pending",
            "billing_period": billing_period,
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

    async def create(self, teacher_id: str, title: str, duration_minutes: int = 30, description: str | None = None, deadline_at: str | None = None, show_results_at: str | None = None) -> dict:
        data = {
            "teacher_id": teacher_id,
            "title": title,
            "description": description,
            "duration_minutes": duration_minutes,
            "status": "draft",
        }
        if deadline_at:
            data["deadline_at"] = deadline_at
        if show_results_at:
            data["show_results_at"] = show_results_at
        return await self.repo.insert(data)

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
        field_map = {"question_type": "type", "question_text": "question_text",
                     "options": "options", "correct_answer": "correct_answer",
                     "points": "points", "order_index": "order_index", "page_number": "page_number"}
        for i, q in enumerate(questions, 1):
            q.setdefault("order_index", i)
            q["exam_id"] = exam_id
            for old_key, new_key in field_map.items():
                if old_key != new_key and old_key in q and new_key not in q:
                    q[new_key] = q.pop(old_key)
            created.append(await self.question_repo.insert(q))
        return created

    async def publish(self, exam_id: str) -> dict:
        try:
            questions = await self.question_repo.select({"exam_id": exam_id}, limit=200)
            total_points = sum(q.get("points", 1) for q in questions) if questions else 0
        except Exception:
            total_points = 0
        update_data = {"status": "published", "updated_at": datetime.now(timezone.utc).isoformat()}
        try:
            update_data["total_points"] = total_points
            return await self.repo.update({"id": exam_id}, update_data)
        except Exception:
            update_data.pop("total_points", None)
            return await self.repo.update({"id": exam_id}, update_data)

    async def get_published_for_student(self, student_id: str) -> list[dict]:
        """Get published exams for a specific student (filtered by teacher relationship)."""
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            
            stu_res = await client.table("students").select("teacher_id, group_id").eq("id", student_id).execute()
            student = (stu_res.data or [{}])[0] if stu_res.data else {}
            teacher_id = student.get("teacher_id")
            group_id = student.get("group_id")
            
            if not teacher_id and group_id:
                grp_res = await client.table("groups").select("teacher_id").eq("id", group_id).execute()
                if grp_res.data:
                    teacher_id = grp_res.data[0].get("teacher_id")
            
            filters = {"status": "published"}
            if teacher_id:
                filters["teacher_id"] = teacher_id
            
            exams = await self.repo.select(filters, limit=100)
            
            # Exclude exams the student has already started/submitted
            started_res = await client.table("student_exams").select("exam_id").eq("student_id", student_id).execute()
            started_ids = {r["exam_id"] for r in (started_res.data or [])}
            return [e for e in exams if e["id"] not in started_ids]
        except Exception as e:
            logger.warning("get_published_for_student fallback: %s", e)
            return await self.repo.select({"status": "published"}, limit=100)


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
        batch_updates = []
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
                    batch_updates.append(self.answers_repo.update({"id": a["id"]}, {"is_correct": True, "score": pts}))
                else:
                    wrong += 1
                    batch_updates.append(self.answers_repo.update({"id": a["id"]}, {"is_correct": False, "score": 0}))
            else:
                essay_score += pts
        # Execute all answer updates concurrently
        if batch_updates:
            await asyncio.gather(*batch_updates, return_exceptions=True)
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
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        result = await client.table("student_exams").select("*").eq("exam_id", exam_id).in_("status", ["submitted", "graded"]).limit(200).execute()
        submissions = result.data or []
        # Attach student names
        student_ids = list({s["student_id"] for s in submissions if s.get("student_id")})
        if student_ids:
            stu_res = await client.table("students").select("id, full_name, code").in_("id", student_ids).execute()
            student_map = {s["id"]: s for s in (stu_res.data or [])}
            for s in submissions:
                student_data = student_map.get(s.get("student_id"), {})
                s["student_name"] = student_data.get("full_name", "غير معروف")
                s["student_code"] = student_data.get("code", "")
        return submissions


class LessonService:
    def __init__(self):
        self.repo = SupabaseRepository("lessons")

    async def create(self, **kwargs) -> dict:
        kwargs.setdefault("is_published", False)
        return await self.repo.insert(kwargs)

    async def list_all(self, filters: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def get_by_id(self, lesson_id: str) -> dict | None:
        return await self.repo.select_one({"id": lesson_id})

    async def update(self, lesson_id: str, data: dict) -> dict:
        return await self.repo.update({"id": lesson_id}, data)

    async def delete(self, lesson_id: str) -> bool:
        return await self.repo.delete({"id": lesson_id})

    async def get_by_group(self, group_id: str, published_only: bool = True) -> list[dict]:
        filters = {"group_id": group_id}
        if published_only:
            filters["is_published"] = True
        return await self.repo.select(filters, limit=200)


class VideoAnalyticsService:
    def __init__(self):
        self.repo = SupabaseRepository("video_analytics")

    async def upsert(self, student_id: str, video_id: str, teacher_id: str, **kwargs) -> dict:
        existing = await self.repo.select_one({"student_id": student_id, "video_id": video_id})
        if existing:
            return await self.repo.update({"student_id": student_id, "video_id": video_id}, kwargs)
        kwargs.update({
            "student_id": student_id,
            "video_id": video_id,
            "teacher_id": teacher_id,
        })
        return await self.repo.insert(kwargs)

    async def list_all(self, filters: dict | None = None, limit: int = 100, offset: int = 0) -> list[dict]:
        return await self.repo.select(filters, limit=limit, offset=offset)

    async def get_by_id(self, analytics_id: str) -> dict | None:
        return await self.repo.select_one({"id": analytics_id})

    async def get_by_video(self, video_id: str) -> list[dict]:
        return await self.repo.select({"video_id": video_id}, limit=500)

    async def get_delayed_students(self, group_id: str, video_id: str) -> list[dict]:
        students_in_group = await SupabaseRepository("students").select({"group_id": group_id}, limit=500)
        watched_records = await self.repo.select({"video_id": video_id, "is_completed": True}, limit=500)
        watched_ids = {r["student_id"] for r in watched_records}
        delayed = []
        for s in students_in_group:
            if s["id"] not in watched_ids:
                delayed.append({
                    "student_id": s["id"],
                    "full_name": s.get("full_name", ""),
                    "code": s.get("code", ""),
                    "parent_phone": s.get("parent_phone", ""),
                })
        return delayed

    async def get_student_stats(self, student_id: str) -> dict:
        records = await self.repo.select({"student_id": student_id}, limit=1000)
        total = len(records)
        completed = sum(1 for r in records if r.get("is_completed"))
        flagged = sum(1 for r in records if r.get("is_flagged_cheated"))
        delayed = sum(1 for r in records if r.get("is_delayed"))
        total_minutes = sum(int(r.get("max_watched_duration", 0)) for r in records) / 60
        return {
            "total_videos": total,
            "completed": completed,
            "flagged_cheated": flagged,
            "delayed": delayed,
            "total_watched_minutes": total_minutes,
        }


class AssistantService:
    def __init__(self):
        self.repo = SupabaseRepository("assistants")

    async def create(self, teacher_id: str, **kwargs) -> dict:
        return await self.repo.insert({"teacher_id": teacher_id, **kwargs})

    async def get_by_id(self, assistant_id: str) -> dict | None:
        return await self.repo.select_one({"id": assistant_id})

    async def list_by_teacher(self, teacher_id: str, limit: int = 100) -> list[dict]:
        return await self.repo.select({"teacher_id": teacher_id, "is_active": True}, limit=limit)

    async def update(self, assistant_id: str, data: dict) -> dict:
        return await self.repo.update({"id": assistant_id}, data)

    async def delete(self, assistant_id: str) -> bool:
        await self.repo.delete({"id": assistant_id})
        return True
