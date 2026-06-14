"""
Level 2A: Backend Expert Agent
Produces prompts for FastAPI backend code
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class BackendExpertAgent:
    """
    Senior Backend Developer Agent
    
    Responsibilities:
    - FastAPI endpoint implementation
    - SQLAlchemy 2.0 async models
    - Pydantic v2 schemas
    - JWT authentication
    - RBAC enforcement
    """
    
    ROLE = Level.BACKEND
    NAME = "Backend Expert"
    DESCRIPTION = "Backend Expert - FastAPI implementation with SQLAlchemy 2.0"
    
    def __init__(
        self,
        workspace: WorkspaceManager,
        artifact_writer: ArtifactWriter,
        context: ProjectContext,
    ):
        self.workspace = workspace
        self.artifact_writer = artifact_writer
        self.context = context
    
    def build_prompt(self, workflow_artifacts: dict = None) -> str:
        """Build the backend expert prompt"""
        arch_context, sec_context, contract_context = "", "", ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.ARCH_DECISIONS:
                    arch_context = art.content[:3000]
                elif art.type == ArtifactType.SEC_CONSTRAINTS:
                    sec_context = art.content[:2000]
                elif art.type == ArtifactType.API_CONTRACT:
                    contract_context = art.content[:2000]
        
        arch_section = f"\nARCHITECTURE REFERENCE:\n{arch_context}\n" if arch_context else ""
        sec_section = f"\nSECURITY CONSTRAINTS:\n{sec_context}\n" if sec_context else ""
        contract_section = f"\nAPI CONTRACT:\n{contract_context}\n" if contract_context else ""
        
        return f"""You are a Senior Backend Developer implementing FastAPI code for "{self.context.project_name}".

{arch_section}
{sec_section}
{contract_section}

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

Generate COMPLETE Python code for each file. No shortcuts."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute backend expert"""
        logger.info("[Level 2A] Backend Expert Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="2A",
            task_type="generate",
            prompt=prompt,
            context={"artifact_type": ArtifactType.BACKEND_CODE.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 2A] Brain has not responded yet.")
            return Artifact(type=ArtifactType.BACKEND_CODE, content="", metadata={"status": "pending"}, created_by=self.ROLE)
        
        artifact = await self.artifact_writer.write_python(
            artifact_type=ArtifactType.BACKEND_CODE,
            content=response,
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.BACKEND_CODE.value, response)
        logger.info(f"[Level 2A] Backend Expert Agent complete - {len(response)} chars")
        return artifact
