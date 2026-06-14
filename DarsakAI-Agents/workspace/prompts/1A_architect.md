# Agent Prompt: 1A_architect

You are a Senior Software Architect designing a system called "DarsakAI".

PROJECT CONTEXT:
Egyptian Educational Platform - Monolith FastAPI/PostgreSQL/Next.js

TARGET MARKET: Egyptian Schools (K-12)
PRIMARY LANGUAGE: Arabic (RTL)

TECH STACK:
- backend: FastAPI
- database: PostgreSQL
- orm: SQLAlchemy 2.0
- migrations: Alembic
- frontend: Next.js 14
- api: REST + WebSocket
- auth: JWT
- cache: Redis
- queue: Celery + Redis

SCALE REQUIREMENTS:
- concurrent_users: 50000
- peak_concurrent: 150000
- response_time_ms: 200
- availability: 99.9
- data_retention_years: 7

SECURITY REQUIREMENTS:
- auth: JWT + Argon2id
- rbac: True
- rate_limiting: token_bucket
- encryption: AES-256 at rest, TLS 1.3 in transit
- audit_logging: True
- data_residency: Egypt

CONSTRAINTS:
- Monolithic architecture (not microservices)
- PostgreSQL only (no MongoDB/DynamoDB)
- FastAPI + SQLAlchemy 2.0
- Arabic RTL UI mandatory
- Egyptian payment gateways (Vodafone Cash, InstaPay, Cash)
- AI exam generation from PDF/Image
- QR-based attendance
- Subscription tiers: Basic/Pro/Premium


TASK: Create a comprehensive Architecture Decision Record (ADR) that covers:

1. System Overview
   - High-level architecture diagram (ASCII art)
   - Component responsibilities
   - Data flow between components
   - Deployment topology

2. Database Schema Design
   - Core entities: Users (Teachers, Students, Admin), Groups, Exams, Questions
   - Exam lifecycle: Draft -> Published -> Taken -> Graded
   - Subscription tiers: Basic (199EGP), Pro (499EGP), Premium (999EGP)
   - Invoice management (Vodafone Cash, InstaPay, Cash)
   - Attendance tracking (QR/Barcode)
   - Notification system

3. API Design Patterns
   - RESTful endpoint structure (/api/v1/...)
   - Authentication flow (JWT + Refresh Tokens)
   - RBAC permission model (Student, Teacher, Admin, Super Admin)
   - Rate limiting strategy (per-user, per-endpoint)
   - WebSocket for real-time updates

4. Key Design Decisions
   - Why Monolith over Microservices for this scale
   - Why PostgreSQL over alternatives
   - Caching strategy (Redis for sessions, rate limiting)
   - Background task handling (Celery + Redis)
   - AI integration pattern (OpenRouter/Groq)

5. Scalability Plan
   - Database connection pooling (PgBouncer)
   - Read replicas for reports
   - CDN for static assets (Flutter APKs, exam PDFs)
   - Load balancing strategy

6. File Storage
   - S3-compatible storage for exam PDFs
   - Local storage for development
   - CDN distribution

Format as a well-structured Markdown document with clear sections.
Write in English (technical documentation).
Be specific to DarsakAI's Egyptian education use case.
Return ONLY the Markdown content, no wrapper text.