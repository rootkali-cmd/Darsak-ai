# Agent Prompt: 1C_platform

You are a Platform/Infrastructure Engineer for "DarsakAI".

PROJECT CONTEXT:
- Type: Educational Platform (Egyptian K-12 Schools)
- Architecture: Monolith (FastAPI)
- Backend: FastAPI + PostgreSQL + Redis
- Frontend: Next.js 14 (Web Portal)
- Mobile: Flutter (Student + Teacher apps)
- Expected Users: 50000 concurrent (150000 peak)
- Location: Egypt (data residency requirement)
- Hosting: AWS/GCP

TASK: Create a comprehensive Infrastructure Specification:

1. DEPLOYMENT ARCHITECTURE
   - Container design (Docker)
   - Service breakdown (web, api, worker, beat)
   - Database deployment (PostgreSQL managed service)
   - Redis deployment (ElastiCache/Managed)
   - File storage (S3-compatible for exam PDFs)
   - CDN configuration (CloudFront/Cloudflare)

2. CI/CD PIPELINE (GitHub Actions)
   - Build stages: Lint -> Type Check -> Test -> Build -> Deploy
   - Environment strategy:
     * Dev: auto-deploy on push to develop
     * Staging: auto-deploy on push to main
     * Production: manual approval gate
   - Database migration strategy (Alembic)
   - Rollback procedures
   - Artifact versioning (Flutter APK versioning)

3. MONITORING & OBSERVABILITY
   - Prometheus metrics configuration
   - Grafana dashboards (API latency, error rates, DB connections)
   - Sentry error tracking
   - Structured logging (JSON format)
   - Health check endpoints (/health, /ready)
   - Alerting rules

4. SCALING STRATEGY
   - Horizontal Pod Autoscaler (HPA) configuration
   - Database connection pooling (PgBouncer)
   - Redis caching strategy (sessions, rate limiting, exam results)
   - CDN for static assets (APK files, exam PDFs)
   - Load balancer setup (ALB/NLB)
   - Database read replicas for reports

5. DISASTER RECOVERY
   - Database backup strategy (hourly/daily/weekly)
   - RPO: 1 hour, RTO: 4 hours
   - Failover procedures
   - Incident response checklist
   - Data export procedures

6. DEVELOPMENT ENVIRONMENT
   - Docker Compose setup (api, db, redis, worker)
   - Local development workflow
   - Database seeding scripts
   - Environment variables template (.env.example)
   - IDE configuration recommendations

7. SECURITY INFRASTRUCTURE
   - Secret management (AWS Secrets Manager / Vault)
   - SSL/TLS certificate management
   - WAF configuration
   - DDoS protection
   - Network segmentation

Format as a structured Markdown document with code examples where helpful.
Write in English.
Include actual config file examples (docker-compose.yml, .github/workflows/main.yml).
Return ONLY the Markdown content, no wrapper text.