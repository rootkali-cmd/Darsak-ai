"""
Level 3A: Code Reviewer Agent
Produces prompts for Code Review Reports
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class CodeReviewerAgent:
    """
    Senior Code Reviewer Agent
    
    Responsibilities:
    - Security vulnerability detection
    - Code quality assessment
    - FastAPI best practices verification
    - RBAC enforcement review
    """
    
    ROLE = Level.CODE_REVIEW
    NAME = "Code Reviewer"
    DESCRIPTION = "Code Reviewer - security & quality audit"
    
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
        """Build the code reviewer prompt"""
        backend_code, sec_constraints = "", ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.BACKEND_CODE:
                    backend_code = art.content[:4000]
                elif art.type == ArtifactType.SEC_CONSTRAINTS:
                    sec_constraints = art.content[:2000]
        
        code_section = f"\nCODE TO REVIEW:\n```\n{backend_code}\n```\n" if backend_code else "\nNo code available for review.\n"
        sec_section = f"\nSECURITY CONSTRAINTS TO VERIFY:\n{sec_constraints}\n" if sec_constraints else ""
        
        return f"""You are a Senior Code Reviewer performing a security and quality audit for "{self.context.project_name}".

{code_section}
{sec_section}

REVIEW CATEGORIES:

1. SECURITY AUDIT (Critical/High/Medium/Low)
   - SQL injection, XSS, broken access control, insecure JWT, password exposure, rate limiting gaps, CORS misconfiguration

2. CODE QUALITY (Critical/High/Medium/Low)
   - Type hints, error handling, async/await correctness, resource cleanup, DRY violations

3. FASTAPI BEST PRACTICES (High/Medium/Low)
   - Dependencies, response models, status codes, router organization

4. SPECIFIC ISSUES FOUND
   For each: Location, Severity, Category, Description, Impact, Fix (with code)

5. POSITIVE FINDINGS

6. APPROVAL VERDICT: APPROVED / CONDITIONAL / REJECTED

Format as structured Markdown.
Be thorough and specific. Point out actual code issues.
Return ONLY the Markdown content, no wrapper text."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute code reviewer"""
        logger.info("[Level 3A] Code Reviewer Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="3A",
            task_type="review",
            prompt=prompt,
            context={"artifact_type": ArtifactType.CODE_REVIEW.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 3A] Brain has not responded yet.")
            return Artifact(type=ArtifactType.CODE_REVIEW, content="", metadata={"status": "pending"}, created_by=self.ROLE)
        
        artifact = await self.artifact_writer.write_markdown(
            artifact_type=ArtifactType.CODE_REVIEW,
            title=f"{self.context.project_name} Code Review Report",
            content=response,
            metadata={"level": "3A", "agent": self.NAME, "review_type": "Security + Quality"},
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.CODE_REVIEW.value, response)
        logger.info(f"[Level 3A] Code Reviewer Agent complete - {len(response)} chars")
        return artifact
