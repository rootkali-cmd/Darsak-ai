# Agent Prompt: 2B_database

You are a Database Expert designing PostgreSQL schema for "DarsakAI".



TASK: Generate complete SQLAlchemy 2.0 models and Alembic migration files.

SCHEMA REQUIREMENTS:

1. USERS TABLE - id(UUID), email(VARCHAR255 UNIQUE), password_hash, full_name, role(ENUM), is_active, phone, created_at, updated_at
2. TEACHER_PROFILES - user_id(FK), school_name, subject, subscription_plan_id(FK), subscription_expires_at
3. STUDENT_PROFILES - user_id(FK), teacher_id(FK), grade_level, parent_phone
4. GROUPS - name, teacher_id(FK), created_at, updated_at
5. GROUP_STUDENTS - group_id(FK), student_id(FK) - composite PK
6. EXAMS - title, description, teacher_id(FK), group_id(FK), status(ENUM), duration_minutes, total_marks, created_at, updated_at
7. QUESTIONS - exam_id(FK), question_text, question_type(ENUM), marks, order_index
8. OPTIONS - question_id(FK), option_text, is_correct, order_index
9. STUDENT_EXAMS - student_id(FK), exam_id(FK), status(ENUM), score, started_at, submitted_at, graded_at
10. STUDENT_ANSWERS - student_exam_id(FK), question_id(FK), selected_option_id(FK), essay_answer, marks_awarded, is_correct
11. ATTENDANCE - student_id(FK), teacher_id(FK), group_id(FK), date, status(ENUM), barcode_data, UNIQUE(student_id, date, teacher_id)
12. PLANS - name(VARCHAR50 UNIQUE), price_egp, max_students, max_ai_requests, max_grades, max_invoices, features_json(JSONB), is_active
13. TEACHER_SUBSCRIPTIONS - teacher_id(FK), plan_id(FK), activated_at, expires_at, is_trial, status(ENUM)
14. SUBSCRIPTION_CODES - code(VARCHAR20 UNIQUE), plan_id(FK), max_uses, used_count, expires_at, is_active
15. INVOICES - teacher_id(FK), student_id(FK), title, amount_egp, payment_method(ENUM), status(ENUM), screenshot_url, admin_notes
16. NOTIFICATIONS - user_id(FK), title, message, type(ENUM), is_read, created_at

GENERATE:
1. `src/models/base.py` - SQLAlchemy Base + mixins
2. `src/models/user.py` - User, TeacherProfile, StudentProfile
3. `src/models/group.py` - Group, GroupStudent
4. `src/models/exam.py` - Exam, Question, Option, StudentExam, StudentAnswer
5. `src/models/attendance.py` - Attendance
6. `src/models/subscription.py` - Plan, TeacherSubscription, SubscriptionCode
7. `src/models/invoice.py` - Invoice
8. `src/models/notification.py` - Notification
9. `alembic.ini` - Alembic configuration
10. `alembic/env.py` - Async Alembic environment
11. `migrations/versions/001_initial.py` - Initial migration

RULES:
- UUID primary keys (server_default=gen_random_uuid())
- Proper foreign keys with ON DELETE CASCADE/SET NULL
- Indexes on frequently queried columns
- JSONB for features_json
- Check constraints for enums
- created_at/updated_at with server defaults
- Use SQLAlchemy 2.0 mapped_column style
- Async compatible (AsyncSession)
- Return ALL code files separated by clear file path headers (e.g., ## FILE: src/models/base.py)

Generate COMPLETE Python code. No placeholders.