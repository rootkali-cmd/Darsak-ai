"""
State Machine for the Multi-Agent Workflow
Defines valid states and transitions
"""
from enum import Enum
from typing import Dict, List, Optional, Set, Callable, Any
from dataclasses import dataclass, field
from datetime import datetime
import asyncio
import logging

from shared.state import Level, WorkflowStatus, ArtifactType, AgentMessage, Artifact

logger = logging.getLogger(__name__)


class State(str, Enum):
    """Workflow states"""
    INIT = "init"
    LEVEL1_ARCHITECT = "level1_architect"
    LEVEL1_SECURITY = "level1_security"
    LEVEL1_PLATFORM = "level1_platform"
    LEVEL1_REVIEW = "level1_review"
    LEVEL2_BACKEND = "level2_backend"
    LEVEL2_DATABASE = "level2_database"
    LEVEL2_CONTRACT = "level2_contract"
    LEVEL2_INTEGRATION = "level2_integration"
    LEVEL3_CODE_REVIEW = "level3_code_review"
    LEVEL3_TESTING = "level3_testing"
    LEVEL3_CONTRACT_TEST = "level3_contract_test"
    FEEDBACK_LOOP = "feedback_loop"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class Transition:
    """State transition definition"""
    from_state: State
    to_state: State
    condition: Optional[Callable[[Any], bool]] = None
    action: Optional[Callable[[Any], Any]] = None
    description: str = ""


class WorkflowStateMachine:
    """
    Manages workflow state transitions with validation
    """
    
    # Valid transitions between states
    VALID_TRANSITIONS: Dict[State, Set[State]] = {
        State.INIT: {State.LEVEL1_ARCHITECT},
        State.LEVEL1_ARCHITECT: {State.LEVEL1_SECURITY, State.FAILED},
        State.LEVEL1_SECURITY: {State.LEVEL1_PLATFORM, State.FAILED},
        State.LEVEL1_PLATFORM: {State.LEVEL1_REVIEW, State.FAILED},
        State.LEVEL1_REVIEW: {
            State.LEVEL2_BACKEND, 
            State.LEVEL2_DATABASE, 
            State.LEVEL2_CONTRACT,
            State.FEEDBACK_LOOP,
            State.FAILED
        },
        State.LEVEL2_BACKEND: {State.LEVEL2_INTEGRATION, State.FEEDBACK_LOOP, State.FAILED},
        State.LEVEL2_DATABASE: {State.LEVEL2_INTEGRATION, State.FEEDBACK_LOOP, State.FAILED},
        State.LEVEL2_CONTRACT: {State.LEVEL2_INTEGRATION, State.FEEDBACK_LOOP, State.FAILED},
        State.LEVEL2_INTEGRATION: {
            State.LEVEL3_CODE_REVIEW, 
            State.FEEDBACK_LOOP, 
            State.FAILED
        },
        State.LEVEL3_CODE_REVIEW: {State.LEVEL3_TESTING, State.FEEDBACK_LOOP, State.FAILED},
        State.LEVEL3_TESTING: {State.LEVEL3_CONTRACT_TEST, State.FEEDBACK_LOOP, State.FAILED},
        State.LEVEL3_CONTRACT_TEST: {State.COMPLETED, State.FEEDBACK_LOOP, State.FAILED},
        State.FEEDBACK_LOOP: {
            State.LEVEL1_ARCHITECT,
            State.LEVEL1_SECURITY,
            State.LEVEL1_PLATFORM,
            State.LEVEL2_BACKEND,
            State.LEVEL2_DATABASE,
            State.LEVEL2_CONTRACT,
            State.LEVEL3_CODE_REVIEW,
            State.LEVEL3_TESTING,
        },
        State.COMPLETED: set(),
        State.FAILED: {State.INIT},  # Allow restart
    }
    
    # Artifacts required for each state transition
    REQUIRED_ARTIFACTS: Dict[State, List[ArtifactType]] = {
        State.LEVEL1_SECURITY: [ArtifactType.ARCH_DECISIONS],
        State.LEVEL1_PLATFORM: [ArtifactType.ARCH_DECISIONS, ArtifactType.THREAT_MODEL],
        State.LEVEL1_REVIEW: [
            ArtifactType.ARCH_DECISIONS, 
            ArtifactType.THREAT_MODEL, 
            ArtifactType.SEC_CONSTRAINTS,
            ArtifactType.INFRA_SPEC
        ],
        State.LEVEL2_BACKEND: [
            ArtifactType.API_CONTRACT,
            ArtifactType.SEC_CONSTRAINTS,
        ],
        State.LEVEL2_DATABASE: [
            ArtifactType.API_CONTRACT,
            ArtifactType.ARCH_DECISIONS,
        ],
        State.LEVEL2_CONTRACT: [ArtifactType.API_CONTRACT],
        State.LEVEL2_INTEGRATION: [
            ArtifactType.BACKEND_CODE,
            ArtifactType.DB_MIGRATIONS,
            ArtifactType.OPENAPI_SPEC,
        ],
        State.LEVEL3_CODE_REVIEW: [
            ArtifactType.BACKEND_CODE,
            ArtifactType.DB_MIGRATIONS,
            ArtifactType.OPENAPI_SPEC,
            ArtifactType.SEC_CONSTRAINTS,
        ],
        State.LEVEL3_TESTING: [
            ArtifactType.BACKEND_CODE,
            ArtifactType.CODE_REVIEW,
        ],
        State.LEVEL3_CONTRACT_TEST: [
            ArtifactType.OPENAPI_SPEC,
            ArtifactType.BACKEND_CODE,
        ],
        State.COMPLETED: [
            ArtifactType.BACKEND_CODE,
            ArtifactType.DB_MIGRATIONS,
            ArtifactType.OPENAPI_SPEC,
            ArtifactType.CODE_REVIEW,
            ArtifactType.UNIT_TESTS,
            ArtifactType.CONTRACT_TESTS,
        ],
    }
    
    def __init__(self):
        self.current_state = State.INIT
        self.transition_history: List[Dict[str, Any]] = []
        self._state_callbacks: Dict[State, List[Callable]] = {}
    
    def can_transition(self, to_state: State, artifacts: Dict[str, Artifact]) -> tuple[bool, str]:
        """Check if transition is valid and required artifacts exist"""
        # Check if transition is allowed
        if to_state not in self.VALID_TRANSITIONS.get(self.current_state, set()):
            return False, f"Invalid transition: {self.current_state} -> {to_state}"
        
        # Check required artifacts
        required = self.REQUIRED_ARTIFACTS.get(to_state, [])
        for artifact_type in required:
            artifact = self._find_latest_artifact(artifacts, artifact_type)
            if not artifact or not artifact.content.strip():
                return False, f"Missing required artifact: {artifact_type.value}"
        
        return True, "OK"
    
    def _find_latest_artifact(self, artifacts: Dict[str, Artifact], artifact_type: ArtifactType) -> Optional[Artifact]:
        """Find latest artifact of given type"""
        matching = [a for a in artifacts.values() if a.type == artifact_type]
        if not matching:
            return None
        return max(matching, key=lambda a: a.version)
    
    def transition(self, to_state: State, artifacts: Dict[str, Artifact], context: Any = None) -> bool:
        """Execute state transition"""
        can_transition, reason = self.can_transition(to_state, artifacts)
        if not can_transition:
            logger.error(f"Transition blocked: {reason}")
            return False
        
        from_state = self.current_state
        self.current_state = to_state
        
        # Record transition
        self.transition_history.append({
            "from": from_state.value,
            "to": to_state.value,
            "timestamp": datetime.utcnow().isoformat(),
            "context": str(context) if context else None,
        })
        
        logger.info(f"State transition: {from_state.value} -> {to_state.value}")
        
        # Execute callbacks
        for callback in self._state_callbacks.get(to_state, []):
            try:
                callback(context)
            except Exception as e:
                logger.error(f"Callback error for {to_state.value}: {e}")
        
        return True
    
    def register_callback(self, state: State, callback: Callable) -> None:
        """Register callback for state entry"""
        if state not in self._state_callbacks:
            self._state_callbacks[state] = []
        self._state_callbacks[state].append(callback)
    
    def get_possible_next_states(self) -> List[State]:
        """Get valid next states from current state"""
        return list(self.VALID_TRANSITIONS.get(self.current_state, set()))
    
    def is_terminal(self) -> bool:
        """Check if in terminal state"""
        return self.current_state in {State.COMPLETED, State.FAILED}
    
    def reset(self) -> None:
        """Reset to initial state"""
        self.current_state = State.INIT
        self.transition_history.clear()


# Level to State mapping
LEVEL_TO_STATE = {
    Level.ARCHITECT: State.LEVEL1_ARCHITECT,
    Level.SECURITY: State.LEVEL1_SECURITY,
    Level.PLATFORM: State.LEVEL1_PLATFORM,
    Level.BACKEND: State.LEVEL2_BACKEND,
    Level.DATABASE: State.LEVEL2_DATABASE,
    Level.CONTRACT: State.LEVEL2_CONTRACT,
    Level.CODE_REVIEW: State.LEVEL3_CODE_REVIEW,
    Level.TESTING: State.LEVEL3_TESTING,
    Level.CONTRACT_TEST: State.LEVEL3_CONTRACT_TEST,
}

STATE_TO_LEVEL = {v: k for k, v in LEVEL_TO_STATE.items()}