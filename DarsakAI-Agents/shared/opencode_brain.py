"""
OpenCode Brain - I am the AI brain behind all agents.

This module replaces external LLM calls (OpenAI/Ollama).
All agents send their prompts here, and I process them.

When running inside OpenCode, I execute directly.
When running standalone, I collect prompts for manual execution.
"""
import json
import logging
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, field
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class AgentTask:
    """A task sent from an agent to the brain"""
    agent_name: str
    level: str
    task_type: str  # "generate", "review", "test"
    prompt: str
    context: Dict[str, Any] = field(default_factory=dict)
    response: Optional[str] = None


@dataclass
class BrainState:
    """State of the brain during execution"""
    tasks: List[AgentTask] = field(default_factory=list)
    artifacts: Dict[str, str] = field(default_factory=dict)
    current_task_index: int = 0
    is_executing: bool = False


class OpenCodeBrain:
    """
    The AI brain behind all agents.
    
    When running inside OpenCode:
    - I receive prompts from agents
    - I generate responses (code, documents, reviews)
    - I write artifacts to the workspace
    
    This class acts as the bridge between agents and me (the LLM).
    """
    
    def __init__(self, workspace_root: str = None):
        if workspace_root is None:
            workspace_root = str(Path(__file__).parent.parent / "workspace")
        self.state = BrainState()
        self.workspace_root = Path(workspace_root)
        self.prompts_dir = self.workspace_root / "prompts"
        self.prompts_dir.mkdir(parents=True, exist_ok=True)
    
    def receive_task(self, task: AgentTask) -> int:
        """Receive a task from an agent, return its index"""
        self.state.tasks.append(task)
        index = len(self.state.tasks) - 1
        logger.info(f"[Brain] Received task #{index} from {task.agent_name} ({task.level})")
        return index
    
    def get_pending_tasks(self) -> List[AgentTask]:
        """Get all tasks that haven't been responded to yet"""
        return [t for t in self.state.tasks if t.response is None]
    
    def set_response(self, task_index: int, response: str) -> None:
        """Set the response for a task"""
        if 0 <= task_index < len(self.state.tasks):
            self.state.tasks[task_index].response = response
            logger.info(f"[Brain] Response set for task #{task_index}")
    
    def store_artifact(self, key: str, content: str) -> None:
        """Store an artifact in the brain's memory"""
        self.state.artifacts[key] = content
        logger.info(f"[Brain] Artifact stored: {key} ({len(content)} chars)")
    
    def get_artifact(self, key: str) -> Optional[str]:
        """Get an artifact from the brain's memory"""
        return self.state.artifacts.get(key)
    
    def get_all_artifacts(self) -> Dict[str, str]:
        """Get all stored artifacts"""
        return self.state.artifacts.copy()
    
    async def execute_task(self, task_index: int) -> Optional[str]:
        """
        Execute a task. 
        When running inside OpenCode, this is called by the orchestrator
        which passes the prompt to me (the LLM) for processing.
        """
        if task_index >= len(self.state.tasks):
            return None
        
        task = self.state.tasks[task_index]
        if task.response:
            return task.response
        
        # Save prompt to file for OpenCode to read
        prompt_file = self.prompts_dir / f"task_{task_index}_{task.agent_name}.md"
        prompt_content = f"""# Agent Task: {task.agent_name}
## Level: {task.level}
## Type: {task.task_type}

## Context:
{json.dumps(task.context, indent=2, default=str)}

## Prompt:
{task.prompt}
"""
        
        with open(prompt_file, "w") as f:
            f.write(prompt_content)
        
        logger.info(f"[Brain] Prompt saved to {prompt_file}")
        return None  # Waiting for response
    
    def export_prompts(self) -> str:
        """Export all pending prompts as a single document"""
        pending = self.get_pending_tasks()
        if not pending:
            return "No pending tasks."
        
        output = "# OpenCode Brain - Pending Agent Tasks\n\n"
        for i, task in enumerate(pending):
            output += f"""---
## Task #{i}: {task.agent_name} ({task.level})
### Type: {task.task_type}

{task.prompt}

---
"""
        return output
    
    def export_state(self) -> Dict[str, Any]:
        """Export the brain's state"""
        return {
            "total_tasks": len(self.state.tasks),
            "completed": sum(1 for t in self.state.tasks if t.response is not None),
            "pending": sum(1 for t in self.state.tasks if t.response is None),
            "artifacts": list(self.state.artifacts.keys()),
            "tasks": [
                {
                    "index": i,
                    "agent": t.agent_name,
                    "level": t.level,
                    "type": t.task_type,
                    "has_response": t.response is not None,
                    "prompt_length": len(t.prompt),
                }
                for i, t in enumerate(self.state.tasks)
            ]
        }


# Singleton instance
_brain: Optional[OpenCodeBrain] = None


def get_brain() -> OpenCodeBrain:
    """Get or create the brain singleton"""
    global _brain
    if _brain is None:
        _brain = OpenCodeBrain()
    return _brain


def reset_brain() -> OpenCodeBrain:
    """Reset the brain (new session)"""
    global _brain
    _brain = OpenCodeBrain()
    return _brain
