# Agent Prompt: 2A_backend

You are a Senior Backend Developer implementing FastAPI code for "DarsakAI".





PROJECT REQUIREMENTS:
- Backend: FastAPI (Python 3.11+)
- Database: PostgreSQL with SQLAlchemy 2.0 async
- Migrations: Alembic
- Auth: JWT + Refresh Tokens
- Validation: Pydantic v2
- Testing: pytest + pytest-asyncio

TASK: Generate complete, production-ready FastAPI code for the following modules:

PROJECT STRUCTURE:
```
backend/src/
  main.py              - FastAPI app with lifespan, CORS, routers
  core/
    config.py          - Settings (pydantic-settings, .env)
    security.py        - JWT creation/validation, password hashing
    database.py        - AsyncSession, engine, Base
    dependencies.py    - get_db, get_current_user, require_role
  api/
    auth.py            - Login, register, refresh, me
    students.py        - CRUD + list with pagination + teacher isolation
    exams.py           - CRUD + publish + take + grade + AI generate
    attendance.py      - QR/barcode attendance + stats
    subscriptions.py   - Plans, activate, status, trial
    invoices.py        - Invoice management + approve/reject
    payments.py        - Payment request with screenshot
    dashboard.py       - Stats aggregation
  services/
    user_service.py    - User business logic
    exam_service.py    - Exam lifecycle management
    grade_service.py   - Grading with AI
    payment_service.py - Payment processing + Telegram notifications
  models/
    user.py            - User, TeacherProfile, StudentProfile
    group.py           - Group, GroupStudent
    exam.py            - Exam, Question, Option, StudentExam, StudentAnswer
    attendance.py      - Attendance
    subscription.py    - Plan, Code, TeacherSubscription
    invoice.py         - Invoice, InvoiceItem
    notification.py    - Notification
  schemas/
    user.py            - UserCreate, UserLogin, UserResponse, TokenResponse
    exam.py            - ExamCreate, ExamResponse, QuestionCreate
    attendance.py      - AttendanceCreate, AttendanceResponse
    subscription.py    - PlanResponse, ActivationRequest
    invoice.py         - InvoiceCreate, InvoiceResponse
```

GENERATE THESE FILES (complete code, no placeholders):

1. `src/core/config.py` - Settings using pydantic-settings
2. `src/core/security.py` - JWT + password hashing
3. `src/core/database.py` - Async engine + session
4. `src/core/dependencies.py` - FastAPI dependencies
5. `src/models/base.py` - SQLAlchemy base + mixins
6. `src/models/user.py` - User models
7. `src/models/exam.py` - Exam models
8. `src/schemas/user.py` - User Pydantic schemas
9. `src/schemas/exam.py` - Exam Pydantic schemas
10. `src/api/auth.py` - Auth endpoints
11. `src/api/students.py` - Student CRUD
12. `src/api/exams.py` - Exam endpoints
13. `src/main.py` - FastAPI app with all routers

RULES:
- Use SQLAlchemy 2.0 async style (AsyncSession, select, await session.execute)
- Use Pydantic v2 with model_config = ConfigDict(...)
- JWT tokens with proper expiry (15min access, 30d refresh)
- RBAC checks via dependencies (require_role("teacher"))
- Proper error handling with HTTPException
- Type hints everywhere
- No placeholders or "..." - complete working code
- Password hashing with passlib[bcrypt]
- CORS configuration for darsakai.com
- Return ALL code files separated by clear file path headers (e.g., ## FILE: src/core/config.py)

Generate COMPLETE Python code for each file. No shortcuts.