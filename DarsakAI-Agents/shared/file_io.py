"""
Workspace file I/O management for OpenCode integration
"""
import os
import json
import aiofiles
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

from .state import Artifact, ArtifactType, Level


class WorkspaceManager:
    """Manages the OpenCode workspace directory structure"""
    
    def __init__(self, workspace_root: str = None):
        if workspace_root is None:
            workspace_root = str(Path(__file__).parent.parent / "workspace")
        self.workspace_root = Path(workspace_root)
        self.artifacts_dir = self.workspace_root / "artifacts"
        self.code_dir = self.workspace_root / "code"
        self.tests_dir = self.workspace_root / "tests"
        self.docs_dir = self.workspace_root / "docs"
        
        # Create directory structure
        for dir_path in [
            self.artifacts_dir,
            self.code_dir / "backend",
            self.code_dir / "frontend",
            self.code_dir / "database",
            self.tests_dir / "unit",
            self.tests_dir / "integration",
            self.tests_dir / "contract",
            self.docs_dir / "architecture",
            self.docs_dir / "security",
            self.docs_dir / "api",
        ]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    def get_artifact_path(self, artifact: Artifact) -> Path:
        """Get the file path for an artifact"""
        type_dirs = {
            ArtifactType.ARCH_DECISIONS: self.docs_dir / "architecture",
            ArtifactType.THREAT_MODEL: self.docs_dir / "security",
            ArtifactType.API_CONTRACT: self.docs_dir / "api",
            ArtifactType.SEC_CONSTRAINTS: self.docs_dir / "security",
            ArtifactType.INFRA_SPEC: self.docs_dir / "architecture",
            ArtifactType.BACKEND_CODE: self.code_dir / "backend",
            ArtifactType.DB_MIGRATIONS: self.code_dir / "database",
            ArtifactType.OPENAPI_SPEC: self.docs_dir / "api",
            ArtifactType.CODE_REVIEW: self.docs_dir / "architecture",
            ArtifactType.UNIT_TESTS: self.tests_dir / "unit",
            ArtifactType.CONTRACT_TESTS: self.tests_dir / "contract",
        }
        
        base_dir = type_dirs.get(artifact.type, self.artifacts_dir)
        ext = self._get_extension(artifact.type)
        filename = f"{artifact.type.value}_v{artifact.version}{ext}"
        return base_dir / filename
    
    def _get_extension(self, artifact_type: ArtifactType) -> str:
        extensions = {
            ArtifactType.API_CONTRACT: ".yaml",
            ArtifactType.OPENAPI_SPEC: ".yaml",
            ArtifactType.BACKEND_CODE: ".py",
            ArtifactType.DB_MIGRATIONS: ".py",
            ArtifactType.UNIT_TESTS: ".py",
            ArtifactType.CONTRACT_TESTS: ".py",
        }
        return extensions.get(artifact_type, ".md")
    
    async def write_artifact(self, artifact: Artifact) -> Path:
        """Write artifact to workspace"""
        file_path = self.get_artifact_path(artifact)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        async with aiofiles.open(file_path, "w", encoding="utf-8") as f:
            await f.write(artifact.content)
        
        artifact.file_path = str(file_path)
        return file_path
    
    async def read_artifact(self, artifact: Artifact) -> str:
        """Read artifact from workspace"""
        file_path = self.get_artifact_path(artifact)
        if file_path.exists():
            async with aiofiles.open(file_path, "r", encoding="utf-8") as f:
                return await f.read()
        return ""
    
    def list_artifacts(self, artifact_type: Optional[ArtifactType] = None) -> List[Path]:
        """List all artifacts in workspace"""
        if artifact_type:
            base_dir = self.get_artifact_path(Artifact(
                type=artifact_type, 
                content="", 
                created_by=Level.ORCHESTRATOR
            )).parent
            return list(base_dir.glob(f"*{self._get_extension(artifact_type)}"))
        
        all_files = []
        for dir_path in [self.docs_dir, self.code_dir, self.tests_dir]:
            if dir_path.exists():
                all_files.extend(dir_path.rglob("*"))
        return [f for f in all_files if f.is_file()]


class ArtifactWriter:
    """High-level artifact writing with templating"""
    
    def __init__(self, workspace: WorkspaceManager):
        self.workspace = workspace
    
    async def write_markdown(
        self, 
        artifact_type: ArtifactType, 
        title: str, 
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
        created_by: Level = Level.ORCHESTRATOR
    ) -> Artifact:
        """Write a markdown artifact"""
        full_content = f"# {title}\n\n{content}"
        if metadata:
            meta_str = "\n".join([f"- **{k}**: {v}" for k, v in metadata.items()])
            full_content = f"{full_content}\n\n---\n## Metadata\n{meta_str}\n"
        
        artifact = Artifact(
            type=artifact_type,
            content=full_content,
            metadata=metadata or {},
            created_by=created_by,
        )
        await self.workspace.write_artifact(artifact)
        return artifact
    
    async def write_yaml(
        self, 
        artifact_type: ArtifactType, 
        content: str,
        created_by: Level = Level.ORCHESTRATOR
    ) -> Artifact:
        """Write a YAML artifact"""
        artifact = Artifact(
            type=artifact_type,
            content=content,
            created_by=created_by,
        )
        await self.workspace.write_artifact(artifact)
        return artifact
    
    async def write_python(
        self, 
        artifact_type: ArtifactType, 
        content: str,
        created_by: Level = Level.ORCHESTRATOR
    ) -> Artifact:
        """Write a Python file artifact"""
        artifact = Artifact(
            type=artifact_type,
            content=content,
            created_by=created_by,
        )
        await self.workspace.write_artifact(artifact)
        return artifact