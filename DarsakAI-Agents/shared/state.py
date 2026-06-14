"""
State management for the multi-agent workflow
"""
from enum import Enum
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
import uuid


class Level(str, Enum):
    """Agent hierarchy levels"""
    ORCHESTRATOR = "level_0_orchestrator"
    ARCHITECT = "level_1a_architect"
    SECURITY = "level_1b_security"
    PLATFORM = "level_1c_platform"
    BACKEND = "level_2a_backend"
    DATABASE = "level_2b_database"
    CONTRACT = "level_2c_contract"
    CODE_REVIEW = "level_3a_code_review"
    TESTING = "level_3b_testing"
    CONTRACT_TEST = "level_3c_contract_test"


class ArtifactType(str, Enum):
    """Types of artifacts produced"""
    ARCH_DECISIONS = "arch_decisions"
    THREAT_MODEL = "threat_model"
    API_CONTRACT = "api_contract"
    SEC_CONSTRAINTS = "sec_constraints"
    INFRA_SPEC = "infra_spec"
    BACKEND_CODE = "backend_code"
    DB_MIGRATIONS = "db_migrations"
    OPENAPI_SPEC = "openapi_spec"
    CODE_REVIEW = "code_review"
    UNIT_TESTS = "unit_tests"
    CONTRACT_TESTS = "contract_tests"


class WorkflowStatus(str, Enum):
    """Workflow execution status"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    WAITING_FEEDBACK = "waiting_feedback"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


@dataclass
class Artifact:
    """Represents a produced artifact"""
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    type: ArtifactType = ArtifactType.ARCH_DECISIONS
    content: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_by: Level = Level.ORCHESTRATOR
    created_at: datetime = field(default_factory=datetime.utcnow)
    version: int = 1
    file_path: Optional[str] = None


@dataclass
class AgentMessage:
    """Message between agents"""
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    from_level: Level = Level.ORCHESTRATOR
    to_level: Level = Level.ORCHESTRATOR
    content: str = ""
    artifact_refs: List[str] = field(default_factory=list)
    requires_response: bool = False
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class WorkflowState:
    """Global workflow state"""
    project_id: str
    project_name: str
    description: str
    status: WorkflowStatus = WorkflowStatus.PENDING
    current_level: Level = Level.ORCHESTRATOR
    artifacts: Dict[str, Artifact] = field(default_factory=dict)
    messages: List[AgentMessage] = field(default_factory=list)
    feedback_loop_count: int = 0
    max_feedback_loops: int = 3
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    context: Dict[str, Any] = field(default_factory=dict)

    def add_artifact(self, artifact: Artifact) -> None:
        self.artifacts[artifact.id] = artifact
        self.updated_at = datetime.utcnow()

    def get_artifacts_by_type(self, artifact_type: ArtifactType) -> List[Artifact]:
        return [a for a in self.artifacts.values() if a.type == artifact_type]

    def get_latest_artifact(self, artifact_type: ArtifactType) -> Optional[Artifact]:
        artifacts = self.get_artifacts_by_type(artifact_type)
        return max(artifacts, key=lambda a: a.version) if artifacts else None