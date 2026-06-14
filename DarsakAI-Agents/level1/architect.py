"""
Level 1A: Architect Agent
Produces prompts for Architecture Decision Records
The brain (OpenCode) processes the prompt and returns the artifact.
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class ArchitectAgent:
    """
    Senior Software Architect Agent
    
    Responsibilities:
    - System architecture design
    - Database schema planning
    - API design patterns
    - Key design decisions (ADR)
    - Scalability planning
    
    Flow:
    1. Agent produces a PROMPT
    2. Brain (OpenCode) processes the prompt
    3. Agent writes the response as an artifact
    """
    
    ROLE = Level.ARCHITECT
    NAME = "Architect"
    DESCRIPTION = "Software Architect - designs system architecture and ADRs"
    
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
        """Build the architect prompt - this is what the brain will process"""
        prior_context = ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type in (ArtifactType.ARCH_DECISIONS, ArtifactType.THREAT_MODEL):
                    prior_context += f"\n--- {art.type.value} ---\n{art.content[:1500]}\n"
        
        prior_section = ""
        if prior_context:
            prior_section = f"\nEXISTING CONTEXT FROM PREVIOUS RUNS:\n{prior_context}\n"
        
        return f"""You are a Senior Software Architect designing a system called "{self.context.project_name}".

PROJECT CONTEXT:
{self.context.description}

TARGET MARKET: {self.context.target_market}
PRIMARY LANGUAGE: {self.context.primary_language}

TECH STACK:
{chr(10).join(f"- {k}: {v}" for k, v in self.context.tech_stack.items())}

SCALE REQUIREMENTS:
{chr(10).join(f"- {k}: {v}" for k, v in self.context.scale_requirements.items())}

SECURITY REQUIREMENTS:
{chr(10).join(f"- {k}: {v}" for k, v in self.context.security_requirements.items())}

CONSTRAINTS:
{chr(10).join(f"- {c}" for c in self.context.constraints)}

{prior_section}
TASK: Create a comprehensive Architecture Decision Record (ADR) that covers:

1. System Overview
   - High-level architecture diagram (ASCII art)
   - Component responsibilities
   - Data flow between components
   - Deployment topology

2. Database Schema Design
   - Core entities: Users (Teachers, Students, Admin), Groups, Exams, Questions
   - Exam lifecycle: Draft -> Published -> Taken -> Graded
   - Subscription tiers: Basic (199EGP), Pro (499EGP), Premium (999EGP)
   - Invoice management (Vodafone Cash, InstaPay, Cash)
   - Attendance tracking (QR/Barcode)
   - Notification system

3. API Design Patterns
   - RESTful endpoint structure (/api/v1/...)
   - Authentication flow (JWT + Refresh Tokens)
   - RBAC permission model (Student, Teacher, Admin, Super Admin)
   - Rate limiting strategy (per-user, per-endpoint)
   - WebSocket for real-time updates

4. Key Design Decisions
   - Why Monolith over Microservices for this scale
   - Why PostgreSQL over alternatives
   - Caching strategy (Redis for sessions, rate limiting)
   - Background task handling (Celery + Redis)
   - AI integration pattern (OpenRouter/Groq)

5. Scalability Plan
   - Database connection pooling (PgBouncer)
   - Read replicas for reports
   - CDN for static assets (Flutter APKs, exam PDFs)
   - Load balancing strategy

6. File Storage
   - S3-compatible storage for exam PDFs
   - Local storage for development
   - CDN distribution

Format as a well-structured Markdown document with clear sections.
Write in English (technical documentation).
Be specific to DarsakAI's Egyptian education use case.
Return ONLY the Markdown content, no wrapper text."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute architect agent - send prompt to brain and write artifact"""
        logger.info("[Level 1A] Architect Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        # Send to brain
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="1A",
            task_type="generate",
            prompt=prompt,
            context={
                "project_name": self.context.project_name,
                "artifact_type": ArtifactType.ARCH_DECISIONS.value,
            }
        )
        brain.receive_task(task)
        
        # Process via brain
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            # Brain hasn't responded yet - save prompt and wait
            logger.warning("[Level 1A] Brain has not responded yet. Prompt saved.")
            return Artifact(
                type=ArtifactType.ARCH_DECISIONS,
                content="",
                metadata={"status": "pending", "prompt_index": len(brain.state.tasks) - 1},
                created_by=self.ROLE,
            )
        
        artifact = await self.artifact_writer.write_markdown(
            artifact_type=ArtifactType.ARCH_DECISIONS,
            title=f"{self.context.project_name} Architecture Decision Record",
            content=response,
            metadata={
                "level": "1A",
                "agent": self.NAME,
                "version": "1.0",
                "project_id": self.context.project_id,
            },
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.ARCH_DECISIONS.value, response)
        logger.info(f"[Level 1A] Architect Agent complete - {len(response)} chars")
        return artifact
