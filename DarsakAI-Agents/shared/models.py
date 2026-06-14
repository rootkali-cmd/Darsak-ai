"""
Data models for DarsakAI project context and configuration
"""
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
from pydantic import BaseModel, Field


class UserRole(str, Enum):
    STUDENT = "student"
    TEACHER = "teacher"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


class SubscriptionTier(str, Enum):
    BASIC = "basic"
    PRO = "pro"
    PREMIUM = "premium"


class ExamStatus(str, Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


@dataclass
class DarsakAIConfig:
    """DarsakAI platform configuration"""
    project_name: str = "DarsakAI"
    description: str = "Educational Platform for Egyptian Schools"
    
    # Technical Stack
    backend_framework: str = "FastAPI"
    database: str = "PostgreSQL"
    orm: str = "SQLAlchemy 2.0 + Alembic"
    frontend_framework: str = "Next.js 14"
    api_style: str = "REST + WebSocket"
    
    # Scale Requirements
    expected_concurrent_users: int = 50000
    peak_concurrent_users: int = 150000  # During exams
    target_response_time_ms: int = 200
    target_availability: float = 99.9
    
    # Features
    core_features: List[str] = field(default_factory=lambda: [
        "student_management",
        "teacher_dashboard",
        "exam_creation_ai",
        "exam_taking",
        "attendance_qr",
        "grades_reporting",
        "subscription_billing",
        "notifications",
        "ai_reports",
    ])
    
    # Security Requirements
    auth_method: str = "JWT + Refresh Tokens"
    password_hashing: str = "Argon2id"
    rate_limiting: str = "Token Bucket (100 req/min per user)"
    encryption_at_rest: bool = True
    encryption_in_transit: bool = True
    
    # Compliance
    data_residency: str = "Egypt"
    gdpr_compliance: bool = False
    local_privacy_law: bool = True
    
    # Infrastructure
    hosting: str = "AWS/GCP (Cairo region preferred)"
    container_orchestration: str = "Kubernetes (EKS/GKE)"
    ci_cd: str = "GitHub Actions"
    monitoring: str = "Prometheus + Grafana + Sentry"
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            k: v for k, v in self.__dict__.items()
            if not k.startswith("_")
        }


class ProjectContext(BaseModel):
    """Complete project context passed to all agents"""
    project_id: str
    project_name: str = "DarsakAI"
    description: str = ""
    
    # Business Context
    target_market: str = "Egyptian Schools (K-12)"
    primary_language: str = "Arabic (RTL)"
    supported_languages: List[str] = ["ar", "en"]
    
    # Technical Requirements
    tech_stack: Dict[str, str] = Field(default_factory=lambda: {
        "backend": "FastAPI",
        "database": "PostgreSQL",
        "orm": "SQLAlchemy 2.0",
        "migrations": "Alembic",
        "frontend": "Next.js 14",
        "api": "REST + WebSocket",
        "auth": "JWT",
        "cache": "Redis",
        "queue": "Celery + Redis",
    })
    
    # Scale & Performance
    scale_requirements: Dict[str, Any] = Field(default_factory=lambda: {
        "concurrent_users": 50000,
        "peak_concurrent": 150000,
        "response_time_ms": 200,
        "availability": 99.9,
        "data_retention_years": 7,
    })
    
    # Security & Compliance
    security_requirements: Dict[str, Any] = Field(default_factory=lambda: {
        "auth": "JWT + Argon2id",
        "rbac": True,
        "rate_limiting": "token_bucket",
        "encryption": "AES-256 at rest, TLS 1.3 in transit",
        "audit_logging": True,
        "data_residency": "Egypt",
    })
    
    # Existing artifacts (for feedback loops)
    existing_artifacts: Dict[str, str] = Field(default_factory=dict)
    
    # Constraints
    constraints: List[str] = Field(default_factory=lambda: [
        "Monolithic architecture (not microservices)",
        "PostgreSQL only (no MongoDB/DynamoDB)",
        "FastAPI + SQLAlchemy 2.0",
        "Arabic RTL UI mandatory",
        "Egyptian payment gateways (Vodafone Cash, InstaPay, Cash)",
        "AI exam generation from PDF/Image",
        "QR-based attendance",
        "Subscription tiers: Basic/Pro/Premium",
    ])
    
    def get_config(self) -> DarsakAIConfig:
        return DarsakAIConfig()
    
    class Config:
        arbitrary_types_allowed = True


# Default DarsakAI context for quick start
DEFAULT_DARSAKAI_CONTEXT = ProjectContext(
    project_id="darsakai-001",
    project_name="DarsakAI",
    description="Egyptian Educational Platform - Monolith FastAPI/PostgreSQL/Next.js"
)