"""
Level 1C: Platform Engineer Agent
Produces prompts for Infrastructure Specification
"""
import logging
from typing import Optional, Dict, Any

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class PlatformEngineerAgent:
    """
    Platform/Infrastructure Engineer Agent
    
    Responsibilities:
    - Deployment architecture
    - CI/CD pipeline design
    - Monitoring & observability
    - Scaling strategy
    - Disaster recovery
    """
    
    ROLE = Level.PLATFORM
    NAME = "Platform Engineer"
    DESCRIPTION = "Platform Engineer - infrastructure, DevOps & deployment"
    
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
        """Build the platform engineer prompt"""
        return f"""You are a Platform/Infrastructure Engineer for "{self.context.project_name}".

PROJECT CONTEXT:
- Type: Educational Platform (Egyptian K-12 Schools)
- Architecture: Monolith (FastAPI)
- Backend: FastAPI + PostgreSQL + Redis
- Frontend: Next.js 14 (Web Portal)
- Mobile: Flutter (Student + Teacher apps)
- Expected Users: {self.context.scale_requirements.get('concurrent_users', 50000)} concurrent ({self.context.scale_requirements.get('peak_concurrent', 150000)} peak)
- Location: Egypt (data residency requirement)
- Hosting: {self.context.tech_stack.get('hosting', 'AWS/GCP')}

TASK: Create a comprehensive Infrastructure Specification:

1. DEPLOYMENT ARCHITECTURE
   - Container design (Docker)
   - Service breakdown (web, api, worker, beat)
   - Database deployment (PostgreSQL managed service)
   - Redis deployment (ElastiCache/Managed)
   - File storage (S3-compatible for exam PDFs)
   - CDN configuration (CloudFront/Cloudflare)

2. CI/CD PIPELINE (GitHub Actions)
   - Build stages: Lint -> Type Check -> Test -> Build -> Deploy
   - Environment strategy:
     * Dev: auto-deploy on push to develop
     * Staging: auto-deploy on push to main
     * Production: manual approval gate
   - Database migration strategy (Alembic)
   - Rollback procedures
   - Artifact versioning (Flutter APK versioning)

3. MONITORING & OBSERVABILITY
   - Prometheus metrics configuration
   - Grafana dashboards (API latency, error rates, DB connections)
   - Sentry error tracking
   - Structured logging (JSON format)
   - Health check endpoints (/health, /ready)
   - Alerting rules

4. SCALING STRATEGY
   - Horizontal Pod Autoscaler (HPA) configuration
   - Database connection pooling (PgBouncer)
   - Redis caching strategy (sessions, rate limiting, exam results)
   - CDN for static assets (APK files, exam PDFs)
   - Load balancer setup (ALB/NLB)
   - Database read replicas for reports

5. DISASTER RECOVERY
   - Database backup strategy (hourly/daily/weekly)
   - RPO: 1 hour, RTO: 4 hours
   - Failover procedures
   - Incident response checklist
   - Data export procedures

6. DEVELOPMENT ENVIRONMENT
   - Docker Compose setup (api, db, redis, worker)
   - Local development workflow
   - Database seeding scripts
   - Environment variables template (.env.example)
   - IDE configuration recommendations

7. SECURITY INFRASTRUCTURE
   - Secret management (AWS Secrets Manager / Vault)
   - SSL/TLS certificate management
   - WAF configuration
   - DDoS protection
   - Network segmentation

Format as a structured Markdown document with code examples where helpful.
Write in English.
Include actual config file examples (docker-compose.yml, .github/workflows/main.yml).
Return ONLY the Markdown content, no wrapper text."""

    async def execute(self, workflow_artifacts: dict = None) -> Artifact:
        """Execute platform engineer - send prompt to brain"""
        logger.info("[Level 1C] Platform Engineer Agent starting...")
        
        prompt = self.build_prompt(workflow_artifacts)
        
        brain = get_brain()
        task = AgentTask(
            agent_name=self.NAME,
            level="1C",
            task_type="generate",
            prompt=prompt,
            context={"artifact_type": ArtifactType.INFRA_SPEC.value}
        )
        brain.receive_task(task)
        response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if response is None:
            logger.warning("[Level 1C] Brain has not responded yet.")
            return Artifact(
                type=ArtifactType.INFRA_SPEC,
                content="",
                metadata={"status": "pending"},
                created_by=self.ROLE,
            )
        
        artifact = await self.artifact_writer.write_markdown(
            artifact_type=ArtifactType.INFRA_SPEC,
            title=f"{self.context.project_name} Infrastructure Specification",
            content=response,
            metadata={"level": "1C", "agent": self.NAME, "version": "1.0"},
            created_by=self.ROLE,
        )
        
        brain.store_artifact(ArtifactType.INFRA_SPEC.value, response)
        logger.info(f"[Level 1C] Platform Engineer Agent complete - {len(response)} chars")
        return artifact
