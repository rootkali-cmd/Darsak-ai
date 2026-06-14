"""
Level 1B: Security Auditor Agent
Produces prompts for Threat Models and Security Constraints
"""
import logging
from typing import Optional, Dict, Any, List

from shared.state import Level, Artifact, ArtifactType
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import AgentTask, get_brain
from shared.models import ProjectContext

logger = logging.getLogger(__name__)


class SecurityAuditorAgent:
    """
    CyberSecurity Auditor Agent
    
    Responsibilities:
    - STRIDE threat modeling
    - OWASP Top 10 mitigations
    - Security constraints specification
    - JWT security design
    - RBAC permission matrix
    """
    
    ROLE = Level.SECURITY
    NAME = "Security Auditor"
    DESCRIPTION = "CyberSecurity Auditor - threat modeling & security constraints"
    
    def __init__(
        self,
        workspace: WorkspaceManager,
        artifact_writer: ArtifactWriter,
        context: ProjectContext,
    ):
        self.workspace = workspace
        self.artifact_writer = artifact_writer
        self.context = context
    
    def build_threat_model_prompt(self, workflow_artifacts: dict = None) -> str:
        """Build STRIDE threat model prompt"""
        arch_context = ""
        if workflow_artifacts:
            for art in workflow_artifacts.values():
                if art.type == ArtifactType.ARCH_DECISIONS:
                    arch_context = art.content[:3000]
                    break
        
        return f"""You are a CyberSecurity Auditor performing a threat assessment for "{self.context.project_name}".

ARCHITECTURE CONTEXT:
{arch_context or "No architecture document available - base on standard educational platform patterns."}

SECURITY REQUIREMENTS:
{chr(10).join(f"- {k}: {v}" for k, v in self.context.security_requirements.items())}

CONSTRAINTS:
{chr(10).join(f"- {c}" for c in self.context.constraints)}

TARGET MARKET: {self.context.target_market}
DATA RESIDENCY: {self.context.security_requirements.get('data_residency', 'Egypt')}

TASK: Perform a comprehensive security assessment using the STRIDE framework:

1. THREAT MODEL (STRIDE Framework)
   For each threat category, identify specific threats to DarsakAI:
   
   a) Spoofing Threats
      - Authentication bypass scenarios
      - Token theft/impersonation
      - QR code forgery (attendance)
      - Payment screenshot forgery
      
   b) Tampering Threats
      - Grade manipulation
      - Invoice amount tampering
      - Exam answer modification
      - Subscription status tampering
      
   c) Repudiation Threats
      - Payment denial
      - Attendance denial
      - Grade change disputes
      
   d) Information Disclosure Threats
      - Student PII leakage
      - Payment credentials exposure
      - API key exposure
      - Exam content before publication
      
   e) Denial of Service Threats
      - API flooding
      - Database exhaustion
      - File upload DoS
      - Exam submission surge
      
   f) Elevation of Privilege Threats
      - Student becoming teacher
      - Teacher accessing other teachers' data
      - Admin escalation

2. RISK ASSESSMENT MATRIX
   For each threat:
   - Likelihood (1-5)
   - Impact (1-5)
   - Risk Score (L x I)
   - Mitigation strategy

Format as a structured Markdown document.
Write in English.
Be specific to DarsakAI's features (subscriptions, AI exam generation, barcode attendance).
Return ONLY the Markdown content, no wrapper text."""

    def build_constraints_prompt(self, workflow_artifacts: dict = None) -> str:
        """Build security constraints prompt"""
        return f"""You are a CyberSecurity Auditor defining MANDATORY security constraints for "{self.context.project_name}".

This is an Egyptian educational platform handling:
- Student PII (names, grades, attendance)
- Payment data (Vodafone Cash, InstaPay, Cash)
- AI-generated content
- Teacher-student relationships
- Subscription management

TASK: Define detailed security constraints that MUST be enforced in code:

1. AUTHENTICATION CONSTRAINTS
   - JWT access token: structure, expiry, claims
   - Refresh token: rotation, expiry, revocation
   - Password hashing: algorithm, parameters
   - Multi-factor authentication requirements
   - Session management rules

2. AUTHORIZATION (RBAC) MATRIX
   Define exact permissions for each role:
   - Student: own data, own exams, own attendance
   - Teacher: own students, own groups, own exams, own invoices
   - Admin: all data with audit logging
   - Super Admin: system config, subscription management
   
   For each endpoint, specify: Method + Path + Required Roles

3. RATE LIMITING RULES
   - Global: X requests/minute
   - Per user: X requests/minute
   - Auth endpoints: X requests/minute
   - AI generation: X requests/minute
   - File upload: X requests/minute
   - Payment endpoints: X requests/minute

4. INPUT VALIDATION RULES
   - Max input length per field type
   - File upload constraints (size, type, content)
   - SQL injection prevention (parameterized queries only)
   - XSS prevention (output encoding)
   - CSRF protection

5. DATA PROTECTION RULES
   - Encryption at rest (algorithm, key management)
   - Encryption in transit (TLS version)
   - PII masking in logs
   - Audit logging requirements
   - Data retention periods

6. API SECURITY RULES
   - CORS whitelist
   - Content-Type enforcement
   - Request ID tracking
   - Error message sanitization
   - Health check endpoint protection

Format as a structured Markdown document with tables where appropriate.
Write in English.
Every constraint must be actionable and testable.
Return ONLY the Markdown content, no wrapper text."""

    async def execute(self, workflow_artifacts: dict = None) -> List[Artifact]:
        """Execute security auditor - produce threat model and constraints"""
        logger.info("[Level 1B] Security Auditor Agent starting...")
        
        brain = get_brain()
        artifacts = []
        
        # 1. Threat Model
        threat_prompt = self.build_threat_model_prompt(workflow_artifacts)
        threat_task = AgentTask(
            agent_name=f"{self.NAME}-ThreatModel",
            level="1B",
            task_type="generate",
            prompt=threat_prompt,
            context={"artifact_type": ArtifactType.THREAT_MODEL.value}
        )
        brain.receive_task(threat_task)
        threat_response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if threat_response:
            threat_artifact = await self.artifact_writer.write_markdown(
                artifact_type=ArtifactType.THREAT_MODEL,
                title=f"{self.context.project_name} Threat Model & Security Assessment",
                content=threat_response,
                metadata={"level": "1B", "agent": self.NAME, "framework": "STRIDE"},
                created_by=self.ROLE,
            )
            artifacts.append(threat_artifact)
            brain.store_artifact(ArtifactType.THREAT_MODEL.value, threat_response)
        
        # 2. Security Constraints
        constraints_prompt = self.build_constraints_prompt(workflow_artifacts)
        constraints_task = AgentTask(
            agent_name=f"{self.NAME}-Constraints",
            level="1B",
            task_type="generate",
            prompt=constraints_prompt,
            context={"artifact_type": ArtifactType.SEC_CONSTRAINTS.value}
        )
        brain.receive_task(constraints_task)
        constraints_response = await brain.execute_task(len(brain.state.tasks) - 1)
        
        if constraints_response:
            constraints_artifact = await self.artifact_writer.write_markdown(
                artifact_type=ArtifactType.SEC_CONSTRAINTS,
                title=f"{self.context.project_name} Security Constraints",
                content=constraints_response,
                metadata={"level": "1B", "agent": self.NAME, "version": "1.0"},
                created_by=self.ROLE,
            )
            artifacts.append(constraints_artifact)
            brain.store_artifact(ArtifactType.SEC_CONSTRAINTS.value, constraints_response)
        
        logger.info(f"[Level 1B] Security Auditor Agent complete - {len(artifacts)} artifacts")
        return artifacts
