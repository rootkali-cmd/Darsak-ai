#!/usr/bin/env python3
"""
DarsakAI Multi-Agent System - Example Runner

Usage:
    python run_example.py                    # Run full workflow
    python run_example.py --level 1          # Run only Level 1
    python run_example.py --level 2          # Run only Level 2
    python run_example.py --level 3          # Run only Level 3
    python run_example.py --task "Add payment gateway"  # Custom task
"""
import asyncio
import argparse
import logging
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from shared.models import ProjectContext, DEFAULT_DARSAKAI_CONTEXT
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.llm import get_llm
from orchestrator.orchestrator import Orchestrator, WorkflowEngine
from orchestrator.state_machine import State

# Import level agents directly for partial runs
from level1.architect import ArchitectAgent
from level1.security import SecurityAuditorAgent
from level1.platform import PlatformEngineerAgent
from level2.backend import BackendExpertAgent
from level2.database import DatabaseOptimizerAgent
from level2.contract import APIContractAgent
from level3.code_review import CodeReviewerAgent
from level3.testing import UnitTesterAgent
from level3.contract_test import ContractTesterAgent


def setup_logging(verbose: bool = False):
    """Configure logging"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )
    # Suppress noisy libraries
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("openai").setLevel(logging.WARNING)
    logging.getLogger("langchain").setLevel(logging.WARNING)


async def run_full_workflow(task: str):
    """Run the complete multi-agent workflow"""
    print("\n" + "=" * 70)
    print("  DarsakAI Multi-Agent System - Full Workflow")
    print("=" * 70)
    
    context = DEFAULT_DARSAKAI_CONTEXT
    context.description = task
    
    engine = WorkflowEngine(context)
    summary = await engine.run(task)
    
    print("\n" + "=" * 70)
    print("  WORKFLOW COMPLETE")
    print("=" * 70)
    print(f"\n  Project: {summary['project']}")
    print(f"  Status:  {summary['status']}")
    print(f"  Artifacts: {len(summary['artifacts'])}")
    print(f"  Files Written: {len(summary['files_written'])}")
    print(f"  Feedback Loops: {summary['feedback_loops']}")
    
    if summary['artifacts']:
        print("\n  Artifacts Produced:")
        for art_type, info in summary['artifacts'].items():
            print(f"    - {art_type}: {info['size']} chars (v{info['version']})")
    
    if summary['files_written']:
        print("\n  Files Written:")
        for f in summary['files_written']:
            print(f"    - {f}")
    
    print()
    return summary


async def run_level(level: int, task: str):
    """Run a specific level"""
    print(f"\n{'=' * 70}")
    print(f"  DarsakAI Multi-Agent System - Level {level}")
    print(f"{'=' * 70}")
    
    workspace = WorkspaceManager()
    artifact_writer = ArtifactWriter(workspace)
    context = DEFAULT_DARSAKAI_CONTEXT
    
    if level == 1:
        print("\n[Level 1A] Running Architect Agent...")
        architect = ArchitectAgent(workspace, artifact_writer, context)
        arch_artifact = await architect.execute()
        print(f"  -> {len(arch_artifact.content)} chars written")
        
        print("\n[Level 1B] Running Security Auditor Agent...")
        security = SecurityAuditorAgent(workspace, artifact_writer, context)
        sec_artifacts = await security.execute({"arch": arch_artifact})
        for art in sec_artifacts:
            print(f"  -> {art.type.value}: {len(art.content)} chars")
        
        print("\n[Level 1C] Running Platform Engineer Agent...")
        platform = PlatformEngineerAgent(workspace, artifact_writer, context)
        infra_artifact = await platform.execute()
        print(f"  -> {len(infra_artifact.content)} chars written")
        
        print("\n[Level 1] Complete! Check workspace/docs/")
        
    elif level == 2:
        print("\n[Level 2A] Running Backend Expert Agent...")
        backend = BackendExpertAgent(workspace, artifact_writer, context)
        backend_artifact = await backend.execute()
        print(f"  -> {len(backend_artifact.content)} chars written")
        
        print("\n[Level 2B] Running Database Optimizer Agent...")
        database = DatabaseOptimizerAgent(workspace, artifact_writer, context)
        db_artifact = await database.execute()
        print(f"  -> {len(db_artifact.content)} chars written")
        
        print("\n[Level 2C] Running API Contract Agent...")
        contract = APIContractAgent(workspace, artifact_writer, context)
        contract_artifacts = await contract.execute()
        for art in contract_artifacts:
            print(f"  -> {art.type.value}: {len(art.content)} chars")
        
        print("\n[Level 2] Complete! Check workspace/code/ and workspace/docs/")
        
    elif level == 3:
        print("\n[Level 3A] Running Code Reviewer Agent...")
        reviewer = CodeReviewerAgent(workspace, artifact_writer, context)
        review_artifact = await reviewer.execute()
        print(f"  -> {len(review_artifact.content)} chars written")
        
        print("\n[Level 3B] Running Unit Tester Agent...")
        tester = UnitTesterAgent(workspace, artifact_writer, context)
        test_artifact = await tester.execute()
        print(f"  -> {len(test_artifact.content)} chars written")
        
        print("\n[Level 3C] Running Contract Tester Agent...")
        contract_tester = ContractTesterAgent(workspace, artifact_writer, context)
        contract_test_artifact = await contract_tester.execute()
        print(f"  -> {len(contract_test_artifact.content)} chars written")
        
        print("\n[Level 3] Complete! Check workspace/tests/")


def main():
    parser = argparse.ArgumentParser(
        description="DarsakAI Multi-Agent System Runner"
    )
    parser.add_argument(
        "--level", type=int, choices=[1, 2, 3],
        help="Run only specific level (1, 2, or 3)"
    )
    parser.add_argument(
        "--task", type=str,
        default="Add a new payment gateway integration with Stripe",
        help="Task description for the agents"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    setup_logging(args.verbose)
    
    if args.level:
        asyncio.run(run_level(args.level, args.task))
    else:
        asyncio.run(run_full_workflow(args.task))


if __name__ == "__main__":
    main()
