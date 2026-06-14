"""
Level 2C: API Contract Specialist Agent
Produces prompts for OpenAPI 3.1 specifications
"""
import logging
from typing import Optional, Dict, Any, List

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class APIContractAgent:
    """
    API Contract Specialist Agent
    
    Responsibilities:
    - OpenAPI 3.1 specification
    - Request/response schemas
    - Authentication documentation
    - Error response standards
    """
    
    ROLE = Level.CONTRACT
    NAME = "API Contract Specialist"
    DESCRIPTION = "API Contract Specialist - OpenAPI specs & API design"
    
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
        """Build the contract specialist prompt"""
        arch_context, sec_context = "", ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.ARCH_DECISIONS:
                    arch_context = art.content[:2000]
                elif art.type == ArtifactType.SEC_CONSTRAINTS:
                    sec_context = art.content[:1500]
        
        arch_section = f"\nARCHITECTURE:\n{arch_context}\n" if arch_context else ""
        sec_section = f"\nSECURITY:\n{sec_context}\n" if sec_context else ""
        
        return f"""You are an API Contract Specialist creating OpenAPI 3.1 specification for "{self.context.project_name}".

PROJECT: {self.context.project_name} - Egyptian Educational Platform
STACK: {', '.join(f'{k}: {v}' for k, v in self.context.tech_stack.items())}

{arch_section}
{sec_section}

TASK: Generate a complete OpenAPI 3.1 specification for ALL API endpoints.

BASE URL: https://darsak-backend.fly.dev/api/v1

ENDPOINTS TO DOCUMENT:

1. AUTH (/api/v1/auth) - register, login, refresh, me
2. STUDENTS (/api/v1/students) - CRUD + list + count
3. GROUPS (/api/v1/groups) - CRUD + students management
4. EXAMS (/api/v1/exams) - CRUD + publish + AI generate + student flow
5. ATTENDANCE (/api/v1/attendance) - manual + barcode + stats
6. SUBSCRIPTIONS (/api/v1/subscriptions) - plans + activate + trial
7. INVOICES (/api/v1/invoices) - CRUD + approve/reject
8. PAYMENTS (/api/v1/payments) - request + status
9. DASHBOARD (/api/v1/dashboard) - stats

FOR EACH ENDPOINT: summary, request body schema, response schemas (200, 201, 400, 401, 403, 404, 422, 429), auth requirements, rate limiting headers, tags.

SECURITY: BearerAuth (JWT), RateLimitHeaders.

Generate COMPLETE OpenAPI YAML (not JSON), version 3.1.0.
Return ONLY the YAML content, no wrapper text."""

    async def execute(self, workflow_artifacts: dict = None) -> List[Artifact]:
        """Execute contract specialist"""
        logger.info("[Level 2C] API Contract Specialist Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="2C",
            task_type="generate",
            prompt=prompt,
            context={"artifact_type": ArtifactType.OPENAPI_SPEC.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        artifacts = []
        if response:
            openapi_artifact = await self.artifact_writer.write_yaml(
                artifact_type=ArtifactType.OPENAPI_SPEC,
                content=response,
                created_by=self.ROLE,
            )
            artifacts.append(openapi_artifact)
            brain.store_artifact(ArtifactType.OPENAPI_SPEC.value, response)
            
            # Also write as API Contract
            await self.artifact_writer.write_yaml(
                artifact_type=ArtifactType.API_CONTRACT,
                content=response,
                created_by=self.ROLE,
            )
        
        logger.info(f"[Level 2C] API Contract Specialist Agent complete - {len(artifacts)} artifacts")
        return artifacts
