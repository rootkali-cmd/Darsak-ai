"""
Level 3B: Unit Tester Agent
Produces prompts for pytest test suites
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class UnitTesterAgent:
    """
    QA Engineer Agent
    
    Responsibilities:
    - pytest test suites
    - API endpoint testing
    - Auth flow testing
    - RBAC permission testing
    """
    
    ROLE = Level.TESTING
    NAME = "Unit Tester"
    DESCRIPTION = "Unit Tester - pytest test suites for all endpoints"
    
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
        """Build the unit tester prompt"""
        backend_code, review_notes = "", ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.BACKEND_CODE:
                    backend_code = art.content[:4000]
                elif art.type == ArtifactType.CODE_REVIEW:
                    review_notes = art.content[:2000]
        
        code_section = f"\nCODE BEING TESTED:\n```\n{backend_code}\n```\n" if backend_code else ""
        review_section = f"\nREVIEW NOTES:\n{review_notes}\n" if review_notes else ""
        
        return f"""You are a QA Engineer writing comprehensive pytest tests for "{self.context.project_name}".

{code_section}
{review_section}

GENERATE THESE TEST FILES:

1. `tests/conftest.py` - Fixtures (async client, test DB, auth tokens, factories)
2. `tests/test_auth.py` - Register, login, refresh, me tests
3. `tests/test_students.py` - CRUD, pagination, teacher isolation
4. `tests/test_exams.py` - Lifecycle, publish, student flow
5. `tests/test_attendance.py` - Mark, barcode, stats
6. `tests/test_subscriptions.py` - Plans, activate, trial
7. `tests/test_invoices.py` - CRUD, approve/reject
8. `tests/test_security.py` - Rate limiting, CORS, RBAC, injection

RULES:
- pytest.mark.asyncio for async tests
- httpx.AsyncClient for API calls
- Arrange/Act/Assert pattern
- Test success AND error paths
- Meaningful assertion messages
- Complete, runnable code, no placeholders
- Return ALL code files separated by ## FILE: headers

Generate COMPLETE test code. No shortcuts."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute unit tester"""
        logger.info("[Level 3B] Unit Tester Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="3B",
            task_type="test",
            prompt=prompt,
            context={"artifact_type": ArtifactType.UNIT_TESTS.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 3B] Brain has not responded yet.")
            return Artifact(type=ArtifactType.UNIT_TESTS, content="", metadata={"status": "pending"}, created_by=self.ROLE)
        
        artifact = await self.artifact_writer.write_python(
            artifact_type=ArtifactType.UNIT_TESTS,
            content=response,
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.UNIT_TESTS.value, response)
        logger.info(f"[Level 3B] Unit Tester Agent complete - {len(response)} chars")
        return artifact
