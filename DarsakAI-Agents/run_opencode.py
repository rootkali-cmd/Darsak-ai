#!/usr/bin/env python3
"""
OpenCode Agent Runner
Collects all agent prompts → feeds them to OpenCode (me) as the brain.

Usage:
    python run_opencode.py              # Collect all prompts
    python run_opencode.py --level 1    # Collect Level 1 only
    python run_opencode.py --level 2    # Collect Level 2 only
    python run_opencode.py --level 3    # Collect Level 3 only

The prompts are saved to workspace/prompts/ as individual files.
OpenCode (the brain) reads these and processes them.
"""
import asyncio
import argparse
import json
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from shared.models import DEFAULT_DARSAKAI_CONTEXT
from shared.file_io import WorkspaceManager, ArtifactWriter
from shared.opencode_brain import get_brain, reset_brain
from orchestrator.orchestrator import Orchestrator


def setup_logging(verbose: bool = False):
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)


async def collect_all_prompts(level: int = None):
    """Collect all agent prompts and save them for OpenCode"""
    print("\n" + "=" * 70)
    print("  OpenCode Agent System - Prompt Collector")
    print("=" * 70)
    
    orchestrator = Orchestrator(DEFAULT_DARSAKAI_CONTEXT)
    
    if level is None:
        prompts = await orchestrator.collect_prompts()
    else:
        # Collect specific level
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
        ws = WorkspaceManager()
        aw = ArtifactWriter(ws)
        ctx = DEFAULT_DARSAKAI_CONTEXT
        
        if level == 1:
            prompts["1A_architect"] = ArchitectAgent(ws, aw, ctx).build_prompt()
            prompts["1B_threat_model"] = SecurityAuditorAgent(ws, aw, ctx).build_threat_model_prompt()
            prompts["1B_constraints"] = SecurityAuditorAgent(ws, aw, ctx).build_constraints_prompt()
            prompts["1C_platform"] = PlatformEngineerAgent(ws, aw, ctx).build_prompt()
        elif level == 2:
            prompts["2A_backend"] = BackendExpertAgent(ws, aw, ctx).build_prompt()
            prompts["2B_database"] = DatabaseOptimizerAgent(ws, aw, ctx).build_prompt()
            prompts["2C_contract"] = APIContractAgent(ws, aw, ctx).build_prompt()
        elif level == 3:
            prompts["3A_code_review"] = CodeReviewerAgent(ws, aw, ctx).build_prompt()
            prompts["3B_unit_tests"] = UnitTesterAgent(ws, aw, ctx).build_prompt()
            prompts["3C_contract_tests"] = ContractTesterAgent(ws, aw, ctx).build_prompt()
    
    # Save prompts to files
    prompts_dir = Path(__file__).parent / "workspace" / "prompts"
    prompts_dir.mkdir(parents=True, exist_ok=True)
    
    manifest = {"prompts": [], "total": len(prompts)}
    
    for name, prompt in prompts.items():
        filename = f"{name}.md"
        filepath = prompts_dir / filename
        
        with open(filepath, "w") as f:
            f.write(f"# Agent Prompt: {name}\n\n")
            f.write(prompt)
        
        manifest["prompts"].append({
            "name": name,
            "file": filename,
            "size": len(prompt),
        })
        
        print(f"  ✓ {name} ({len(prompt)} chars) → {filename}")
    
    # Save manifest
    with open(prompts_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"\n  Total prompts: {len(prompts)}")
    print(f"  Saved to: {prompts_dir}")
    print(f"  Manifest: {prompts_dir / 'manifest.json'}")
    
    return prompts


def main():
    parser = argparse.ArgumentParser(description="OpenCode Agent Prompt Collector")
    parser.add_argument("--level", type=int, choices=[1, 2, 3], help="Collect only specific level")
    parser.add_argument("--verbose", "-v", action="store_true")
    
    args = parser.parse_args()
    setup_logging(args.verbose)
    
    asyncio.run(collect_all_prompts(args.level))


if __name__ == "__main__":
    main()
