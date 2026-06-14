"""
Level 2B: Database Optimizer Agent
Produces prompts for SQLAlchemy models and Alembic migrations
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class DatabaseOptimizerAgent:
    """
    Database Expert Agent
    
    Responsibilities:
    - SQLAlchemy 2.0 model design
    - Alembic migration files
    - Index optimization
    - Constraint definitions
    """
    
    ROLE = Level.DATABASE
    NAME = "Database Optimizer"
    DESCRIPTION = "Database Optimizer - PostgreSQL schema & migrations"
    
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
        """Build the database optimizer prompt"""
        arch_context = ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.ARCH_DECISIONS:
                    arch_context = art.content[:3000]
                    break
        
        arch_section = f"\nARCHITECTURE REFERENCE:\n{arch_context}\n" if arch_context else ""
        
        return f"""You are a Database Expert designing PostgreSQL schema for "{self.context.project_name}".

{arch_section}

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

Generate COMPLETE Python code. No placeholders."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute database optimizer"""
        logger.info("[Level 2B] Database Optimizer Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="2B",
            task_type="generate",
            prompt=prompt,
            context={"artifact_type": ArtifactType.DB_MIGRATIONS.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 2B] Brain has not responded yet.")
            return Artifact(type=ArtifactType.DB_MIGRATIONS, content="", metadata={"status": "pending"}, created_by=self.ROLE)
        
        artifact = await self.artifact_writer.write_python(
            artifact_type=ArtifactType.DB_MIGRATIONS,
            content=response,
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.DB_MIGRATIONS.value, response)
        logger.info(f"[Level 2B] Database Optimizer Agent complete - {len(response)} chars")
        return artifact
