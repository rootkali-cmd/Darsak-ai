"""
Level 3C: Contract Tester Agent
Produces prompts for API contract tests
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class ContractTesterAgent:
    """
    Contract Testing Specialist Agent
    
    Responsibilities:
    - OpenAPI spec validation
    - Response schema verification
    - Status code compliance
    - API contract drift detection
    """
    
    ROLE = Level.CONTRACT_TEST
    NAME = "Contract Tester"
    DESCRIPTION = "Contract Tester - API contract testing vs OpenAPI spec"
    
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
        """Build the contract tester prompt"""
        openapi_spec, backend_code = "", ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.OPENAPI_SPEC:
                    openapi_spec = art.content[:4000]
                elif art.type == ArtifactType.BACKEND_CODE:
                    backend_code = art.content[:3000]
        
        spec_section = f"\nOPENAPI SPEC:\n```yaml\n{openapi_spec}\n```\n" if openapi_spec else ""
        code_section = f"\nBACKEND CODE:\n```\n{backend_code}\n```\n" if backend_code else ""
        
        return f"""You are a Contract Testing Specialist for "{self.context.project_name}".

{spec_section}
{code_section}

GENERATE THESE TEST FILES:

1. `tests/contract/conftest.py` - openapi_loader, schema_validator, test_client
2. `tests/contract/test_auth_contract.py` - Auth schema validation
3. `tests/contract/test_students_contract.py` - Student schema validation
4. `tests/contract/test_exams_contract.py` - Exam schema validation
5. `tests/contract/test_attendance_contract.py` - Attendance schema validation
6. `tests/contract/test_subscriptions_contract.py` - Subscription schema validation
7. `tests/contract/test_schema_validation.py` - Validation utilities

RULES:
- Parse OpenAPI spec at runtime
- Validate each response against spec schemas
- Check status codes, required fields, field types
- Use jsonschema for validation
- httpx.AsyncClient for HTTP calls
- pytest.mark.asyncio for async tests
- Return ALL code files separated by ## FILE: headers

Generate COMPLETE test code. No shortcuts."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute contract tester"""
        logger.info("[Level 3C] Contract Tester Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="3C",
            task_type="test",
            prompt=prompt,
            context={"artifact_type": ArtifactType.CONTRACT_TESTS.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 3C] Brain has not responded yet.")
            return Artifact(type=ArtifactType.CONTRACT_TESTS, content="", metadata={"status": "pending"}, created_by=self.ROLE)
        
        artifact = await self.artifact_writer.write_python(
            artifact_type=ArtifactType.CONTRACT_TESTS,
            content=response,
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.CONTRACT_TESTS.value, response)
        logger.info(f"[Level 3C] Contract Tester Agent complete - {len(response)} chars")
        return artifact
