"""
Level 0: Orchestrator for OpenCode
The brain (me) IS the LLM — agents send prompts, I process them.

This orchestrator:
1. Collects all agent prompts
2. Presents them to OpenCode (me) one by one
3. I process each prompt and write artifacts
4. State machine validates transitions
"""
import asyncio
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime

from shared.state import (
    Level, WorkflowState, Artifact, ArtifactType, 
    AgentMessage, WorkflowStatus
)
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.models import ProjectContext, DarsakAIConfig, DEFAULT_DARSAKAI_CONTEXT
from shared.opencode_brain import get_brain, reset_brain, AgentTask

from .state_machine import (
    WorkflowStateMachine, State, 
    LEVEL_TO_STATE, STATE_TO_LEVEL
)

logger = logging.getLogger(__name__)


class Orchestrator:
    """
    Level 0: The CEO/Router Agent
    
    With OpenCode as the brain:
    - Agents produce prompts (not responses)
    - Prompts are queued in the brain
    - OpenCode (me) processes them
    - Artifacts are written to workspace
    """
    
    def __init__(self, context: Optional[ProjectContext] = None):
        self.context = context or DEFAULT_DARSAKAI_CONTEXT
        self.config = self.context.get_config()
        
        self.state_machine = WorkflowStateMachine()
        self.workspace = WorkspaceManager()
        self.artifact_writer = ArtifactWriter(self.workspace)
        self.workflow_state = WorkflowState(
            project_id=self.context.project_id,
            project_name=self.context.project_name,
            description=self.context.description,
        )
        
        # Initialize brain
        self.brain = reset_brain()
        
        # Level execution flags
        self._level_executed: Dict[State, bool] = {
            state: False for state in State
        }
        
        self._setup_callbacks()
    
    def _setup_callbacks(self) -> None:
        """Register state entry callbacks"""
        self.state_machine.register_callback(State.LEVEL1_ARCHITECT, lambda ctx: logger.info("[Level 1] Architect executing..."))
        self.state_machine.register_callback(State.LEVEL1_SECURITY, lambda ctx: logger.info("[Level 1] Security Auditor executing..."))
        self.state_machine.register_callback(State.LEVEL1_PLATFORM, lambda ctx: logger.info("[Level 1] Platform Engineer executing..."))
        self.state_machine.register_callback(State.LEVEL1_REVIEW, lambda ctx: logger.info("[Level 1] Review Gate..."))
        self.state_machine.register_callback(State.LEVEL2_BACKEND, lambda ctx: logger.info("[Level 2] Backend Expert executing..."))
        self.state_machine.register_callback(State.LEVEL2_DATABASE, lambda ctx: logger.info("[Level 2] Database Optimizer executing..."))
        self.state_machine.register_callback(State.LEVEL2_CONTRACT, lambda ctx: logger.info("[Level 2] API Contract executing..."))
        self.state_machine.register_callback(State.LEVEL2_INTEGRATION, lambda ctx: logger.info("[Level 2] Integration..."))
        self.state_machine.register_callback(State.LEVEL3_CODE_REVIEW, lambda ctx: logger.info("[Level 3] Code Review executing..."))
        self.state_machine.register_callback(State.LEVEL3_TESTING, lambda ctx: logger.info("[Level 3] Unit Testing executing..."))
        self.state_machine.register_callback(State.LEVEL3_CONTRACT_TEST, lambda ctx: logger.info("[Level 3] Contract Testing executing..."))
        self.state_machine.register_callback(State.COMPLETED, lambda ctx: logger.info("[Workflow] COMPLETED!"))
        self.state_machine.register_callback(State.FAILED, lambda ctx: logger.error(f"[Workflow] FAILED: {ctx}"))
    
    async def collect_prompts(self) -> Dict[str, Any]:
        """
        Collect all agent prompts WITHOUT executing them.
        This is used when OpenCode needs to see all tasks first.
        """
        logger.info("Collecting all agent prompts...")
        
        # Import agents
        from level1.architect import ArchitectAgent
        from level1.security import SecurityAuditorAgent
        from level1.platform import PlatformEngineerAgent
        from level2.backend import BackendExpertAgent
        from level2.database import DatabaseOptimizerAgent
        from level2.contract import APIContractAgent
        from level3.code_review import CodeReviewerAgent
        from level3.testing import UnitTesterAgent
        from level3.contract_test import ContractTesterAgent
        
        prompts = {}
        
        # Level 1
        architect = ArchitectAgent(self.workspace, self.artifact_writer, self.context)
        prompts["1A_architect"] = architect.build_prompt()
        
        security = SecurityAuditorAgent(self.workspace, self.artifact_writer, self.context)
        prompts["1B_threat_model"] = security.build_threat_model_prompt()
        prompts["1B_constraints"] = security.build_constraints_prompt()
        
        platform = PlatformEngineerAgent(self.workspace, self.artifact_writer, self.context)
        prompts["1C_platform"] = platform.build_prompt()
        
        # Level 2 (these depend on Level 1 artifacts, but we collect the base prompts)
        backend = BackendExpertAgent(self.workspace, self.artifact_writer, self.context)
        prompts["2A_backend"] = backend.build_prompt()
        
        database = DatabaseOptimizerAgent(self.workspace, self.artifact_writer, self.context)
        prompts["2B_database"] = database.build_prompt()
        
        contract = APIContractAgent(self.workspace, self.artifact_writer, self.context)
        prompts["2C_contract"] = contract.build_prompt()
        
        # Level 3
        reviewer = CodeReviewerAgent(self.workspace, self.artifact_writer, self.context)
        prompts["3A_code_review"] = reviewer.build_prompt()
        
        tester = UnitTesterAgent(self.workspace, self.artifact_writer, self.context)
        prompts["3B_unit_tests"] = tester.build_prompt()
        
        contract_tester = ContractTesterAgent(self.workspace, self.artifact_writer, self.context)
        prompts["3C_contract_tests"] = contract_tester.build_prompt()
        
        logger.info(f"Collected {len(prompts)} agent prompts")
        return prompts
    
    async def execute_level1(self) -> bool:
        """Execute Level 1 agents and collect their prompts"""
        from level1.architect import ArchitectAgent
        from level1.security import SecurityAuditorAgent
        from level1.platform import PlatformEngineerAgent
        
        logger.info("\n" + "="*60)
        logger.info("PHASE 1: LEVEL 1 - Planning & Security")
        logger.info("="*60)
        
        # 1A: Architect
        self.state_machine.transition(State.LEVEL1_ARCHITECT, self.workflow_state.artifacts)
        architect = ArchitectAgent(self.workspace, self.artifact_writer, self.context)
        architect_artifact = await architect.execute()
        self.workflow_state.add_artifact(architect_artifact)
        self._level_executed[State.LEVEL1_ARCHITECT] = True
        
        # 1B: Security
        self.state_machine.transition(State.LEVEL1_SECURITY, self.workflow_state.artifacts)
        security = SecurityAuditorAgent(self.workspace, self.artifact_writer, self.context)
        sec_artifacts = await security.execute(self.workflow_state.artifacts)
        for art in sec_artifacts:
            self.workflow_state.add_artifact(art)
        self._level_executed[State.LEVEL1_SECURITY] = True
        
        # 1C: Platform
        self.state_machine.transition(State.LEVEL1_PLATFORM, self.workflow_state.artifacts)
        platform = PlatformEngineerAgent(self.workspace, self.artifact_writer, self.context)
        infra_artifact = await platform.execute()
        self.workflow_state.add_artifact(infra_artifact)
        self._level_executed[State.LEVEL1_PLATFORM] = True
        
        return True
    
    async def execute_level2(self) -> bool:
        """Execute Level 2 agents (parallel)"""
        from level2.backend import BackendExpertAgent
        from level2.database import DatabaseOptimizerAgent
        from level2.contract import APIContractAgent
        
        logger.info("\n" + "="*60)
        logger.info("PHASE 2: LEVEL 2 - Implementation")
        logger.info("="*60)
        
        self.state_machine.transition(State.LEVEL2_BACKEND, self.workflow_state.artifacts)
        
        # Run in parallel
        backend = BackendExpertAgent(self.workspace, self.artifact_writer, self.context)
        database = DatabaseOptimizerAgent(self.workspace, self.artifact_writer, self.context)
        contract = APIContractAgent(self.workspace, self.artifact_writer, self.context)
        
        backend_task, db_task, contract_task = await asyncio.gather(
            backend.execute(self.workflow_state.artifacts),
            database.execute(self.workflow_state.artifacts),
            contract.execute(self.workflow_state.artifacts),
            return_exceptions=True,
        )
        
        if not isinstance(backend_task, Exception) and backend_task:
            self.workflow_state.add_artifact(backend_task)
            self._level_executed[State.LEVEL2_BACKEND] = True
        
        if not isinstance(db_task, Exception) and db_task:
            self.workflow_state.add_artifact(db_task)
            self._level_executed[State.LEVEL2_DATABASE] = True
        
        if not isinstance(contract_task, Exception):
            if isinstance(contract_task, list):
                for art in contract_task:
                    self.workflow_state.add_artifact(art)
            elif contract_task:
                self.workflow_state.add_artifact(contract_task)
            self._level_executed[State.LEVEL2_CONTRACT] = True
        
        self.state_machine.transition(State.LEVEL2_INTEGRATION, self.workflow_state.artifacts)
        return True
    
    async def execute_level3(self) -> bool:
        """Execute Level 3 agents"""
        from level3.code_review import CodeReviewerAgent
        from level3.testing import UnitTesterAgent
        from level3.contract_test import ContractTesterAgent
        
        logger.info("\n" + "="*60)
        logger.info("PHASE 3: LEVEL 3 - Quality Assurance")
        logger.info("="*60)
        
        self.state_machine.transition(State.LEVEL3_CODE_REVIEW, self.workflow_state.artifacts)
        reviewer = CodeReviewerAgent(self.workspace, self.artifact_writer, self.context)
        review_artifact = await reviewer.execute(self.workflow_state.artifacts)
        self.workflow_state.add_artifact(review_artifact)
        self._level_executed[State.LEVEL3_CODE_REVIEW] = True
        
        self.state_machine.transition(State.LEVEL3_TESTING, self.workflow_state.artifacts)
        tester = UnitTesterAgent(self.workspace, self.artifact_writer, self.context)
        test_artifact = await tester.execute(self.workflow_state.artifacts)
        self.workflow_state.add_artifact(test_artifact)
        self._level_executed[State.LEVEL3_TESTING] = True
        
        self.state_machine.transition(State.LEVEL3_CONTRACT_TEST, self.workflow_state.artifacts)
        contract_tester = ContractTesterAgent(self.workspace, self.artifact_writer, self.context)
        contract_test_artifact = await contract_tester.execute(self.workflow_state.artifacts)
        self.workflow_state.add_artifact(contract_test_artifact)
        self._level_executed[State.LEVEL3_CONTRACT_TEST] = True
        
        return True
    
    async def execute(self) -> WorkflowState:
        """Execute the full workflow"""
        logger.info(f"{'='*60}")
        logger.info(f"Starting Workflow: {self.context.project_name}")
        logger.info(f"{'='*60}")
        
        self.workflow_state.status = WorkflowStatus.IN_PROGRESS
        
        try:
            await self.execute_level1()
            await self.execute_level2()
            await self.execute_level3()
            
            self.state_machine.transition(State.COMPLETED, self.workflow_state.artifacts)
            self.workflow_state.status = WorkflowStatus.COMPLETED
            
        except Exception as e:
            logger.error(f"Workflow failed: {e}", exc_info=True)
            self.state_machine.transition(State.FAILED, self.workflow_state.artifacts, str(e))
            self.workflow_state.status = WorkflowStatus.FAILED
        
        return self.workflow_state


class WorkflowEngine:
    """High-level workflow engine"""
    
    def __init__(self, context: Optional[ProjectContext] = None):
        self.orchestrator = Orchestrator(context)
    
    async def run(self, task_description: str) -> Dict[str, Any]:
        """Run the full workflow"""
        self.orchestrator.context.description = task_description
        final_state = await self.orchestrator.execute()
        
        summary = {
            "project": final_state.project_name,
            "status": final_state.status.value,
            "artifacts": {},
            "files_written": [],
            "feedback_loops": final_state.feedback_loop_count,
            "total_messages": len(final_state.messages),
        }
        
        for artifact_id, artifact in final_state.artifacts.items():
            summary["artifacts"][artifact.type.value] = {
                "id": artifact.id,
                "version": artifact.version,
                "size": len(artifact.content),
                "file_path": artifact.file_path,
                "created_by": artifact.created_by.value,
            }
            if artifact.file_path:
                summary["files_written"].append(artifact.file_path)
        
        return summary
