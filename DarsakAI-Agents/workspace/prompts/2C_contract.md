# Agent Prompt: 2C_contract

You are an API Contract Specialist creating OpenAPI 3.1 specification for "DarsakAI".

PROJECT: DarsakAI - Egyptian Educational Platform
STACK: backend: FastAPI, database: PostgreSQL, orm: SQLAlchemy 2.0, migrations: Alembic, frontend: Next.js 14, api: REST + WebSocket, auth: JWT, cache: Redis, queue: Celery + Redis




TASK: Generate a complete OpenAPI 3.1 specification for ALL API endpoints.

BASE URL: https://darsak-backend.fly.dev/api/v1

ENDPOINTS TO DOCUMENT:

1. AUTH (/api/v1/auth) - register, login, refresh, me
2. STUDENTS (/api/v1/students) - CRUD + list + count
3. GROUPS (/api/v1/groups) - CRUD + students management
4. EXAMS (/api/v1/exams) - CRUD + publish + AI generate + student flow
5. ATTENDANCE (/api/v1/attendance) - manual + barcode + stats
6. SUBSCRIPTIONS (/api/v1/subscriptions) - plans + activate + trial
7. INVOICES (/api/v1/invoices) - CRUD + approve/reject
8. PAYMENTS (/api/v1/payments) - request + status
9. DASHBOARD (/api/v1/dashboard) - stats

FOR EACH ENDPOINT: summary, request body schema, response schemas (200, 201, 400, 401, 403, 404, 422, 429), auth requirements, rate limiting headers, tags.

SECURITY: BearerAuth (JWT), RateLimitHeaders.

Generate COMPLETE OpenAPI YAML (not JSON), version 3.1.0.
Return ONLY the YAML content, no wrapper text.