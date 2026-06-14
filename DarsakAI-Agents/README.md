# DarsakAI Multi-Agent System

A hierarchical multi-agent system for automated code generation, security auditing, and quality assurance for the DarsakAI educational platform.

## Architecture

```
Level 0: Orchestrator (CEO Agent)
    │
    ├── Level 1: Planning & Security
    │   ├── 1A: Architect Agent (ADRs, system design)
    │   ├── 1B: Security Auditor (STRIDE threat model, OWASP)
    │   └── 1C: Platform Engineer (infrastructure, CI/CD)
    │
    ├── Level 2: Implementation
    │   ├── 2A: Backend Expert (FastAPI code)
    │   ├── 2B: Database Optimizer (SQLAlchemy + Alembic)
    │   └── 2C: API Contract Specialist (OpenAPI 3.1)
    │
    └── Level 3: Quality Assurance
        ├── 3A: Code Reviewer (security + quality audit)
        ├── 3B: Unit Tester (pytest test suites)
        └── 3C: Contract Tester (API contract tests)
```

## Features

- **4-Level Hierarchy**: Orchestrator → Planning/Security → Implementation → QA
- **Immutable Artifacts**: Each agent produces versioned artifacts
- **Feedback Loops**: Up to 3 retry loops per level boundary
- **Parallel Execution**: Level 2 agents run in parallel
- **State Machine**: Validated state transitions with artifact requirements
- **OpenCode Integration**: Artifacts written to workspace directory
- **LLM Fallback**: OpenAI → Ollama local fallback

## Quick Start

```bash
# Install dependencies
cd /home/ahmed/Documents/DarsakAI-Agents
pip install -e .

# Set environment variables
export OPENAI_API_KEY="your-key-here"

# Run full workflow
python run_example.py

# Run specific level
python run_example.py --level 1
python run_example.py --level 2
python run_example.py --level 3

# Custom task
python run_example.py --task "Add WebSocket support for real-time notifications"

# Verbose logging
python run_example.py -v
```

## Project Structure

```
DarsakAI-Agents/
├── shared/                  # Shared utilities
│   ├── state.py            # AgentState, Artifact, ArtifactType enums
│   ├── file_io.py          # WorkspaceManager, ArtifactWriter
│   ├── llm.py              # LLM config (OpenAI + Ollama fallback)
│   └── models.py           # ProjectContext, DarsakAIConfig
├── orchestrator/            # Level 0: Orchestrator
│   ├── state_machine.py    # WorkflowStateMachine
│   └── orchestrator.py     # Orchestrator + WorkflowEngine
├── level1/                  # Level 1: Planning & Security
│   ├── architect.py        # ArchitectAgent
│   ├── security.py         # SecurityAuditorAgent
│   └── platform.py         # PlatformEngineerAgent
├── level2/                  # Level 2: Implementation
│   ├── backend.py          # BackendExpertAgent
│   ├── database.py         # DatabaseOptimizerAgent
│   └── contract.py         # APIContractAgent
├── level3/                  # Level 3: Quality Assurance
│   ├── code_review.py      # CodeReviewerAgent
│   ├── testing.py          # UnitTesterAgent
│   └── contract_test.py    # ContractTesterAgent
├── workspace/               # Output directory
│   ├── artifacts/
│   ├── code/
│   ├── tests/
│   └── docs/
├── run_example.py           # Example runner script
├── pyproject.toml           # Project configuration
└── README.md                # This file
```

## Agents

| Level | Agent | Role | Output |
|-------|-------|------|--------|
| 0 | Orchestrator | CEO/Router | Workflow coordination |
| 1A | Architect | System Design | ADR (Markdown) |
| 1B | Security Auditor | Threat Modeling | STRIDE + Constraints |
| 1C | Platform Engineer | Infrastructure | Infra Spec (Markdown) |
| 2A | Backend Expert | FastAPI Code | Python modules |
| 2B | Database Optimizer | Schema Design | SQLAlchemy + Alembic |
| 2C | API Contract | OpenAPI Spec | YAML specification |
| 3A | Code Reviewer | Quality Audit | Review Report |
| 3B | Unit Tester | Test Suites | pytest code |
| 3C | Contract Tester | API Testing | Contract tests |

## State Machine

```
INIT → L1_ARCHITECT → L1_SECURITY → L1_PLATFORM → L1_REVIEW
                                                        │
    ┌───────────────────────────────────────────────────┘
    │
    ▼
L2_BACKEND ──┐
L2_DATABASE ──┼──→ L2_INTEGRATION → L3_CODE_REVIEW → L3_TESTING → L3_CONTRACT_TEST → COMPLETED
L2_CONTRACT ──┘         │                              │                              │
    │                   └──────────────────────────────┴──────────────────────────────┘
    │                                    FEEDBACK LOOP (max 3)
    └──────────────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

```bash
# OpenAI (primary LLM)
OPENAI_API_KEY=sk-...

# Ollama (fallback)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=codellama:13b
```

### Project Context

Edit `shared/models.py` to customize:
- Tech stack
- Scale requirements
- Security requirements
- Constraints

## Workspace Output

Artifacts are written to `workspace/`:

```
workspace/
├── docs/
│   ├── architecture/      # ADR, Infra Spec, Code Review
│   ├── security/          # Threat Model, Security Constraints
│   └── api/               # OpenAPI Spec, API Contract
├── code/
│   ├── backend/           # FastAPI Python modules
│   └── database/          # SQLAlchemy models + migrations
├── tests/
│   ├── unit/              # pytest test suites
│   └── contract/          # API contract tests
└── artifacts/             # Raw artifact storage
```

## Feedback Loops

When a level review fails, the system can:
1. Send feedback to the failed level
2. Re-execute with corrected context
3. Retry up to 3 times before failing

## Dependencies

- Python 3.11+
- CrewAI 0.28+
- LangChain (OpenAI + Community)
- Pydantic v2
- aiofiles
- Rich (for pretty output)

## License

Internal use for DarsakAI project.
