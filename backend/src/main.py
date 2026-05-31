import os
import time
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

import sentry_sdk

sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN", ""),
    traces_sample_rate=1.0,
    environment=os.environ.get("ENVIRONMENT", "development"),
    release=f"darsakai-backend@{os.environ.get('VERSION', '1.0.0')}",
)

from src.core.config import get_settings
from src.core.logging import setup_logging
from src.core.security.supabase_repo import get_supabase
from src.infrastructure.rate_limiter import rate_limiter
from src.infrastructure.audit_events import audit as audit_publisher
from src.infrastructure.cache import user_cache, student_cache, cache
from src.services import sync_buffer, start_scheduler, stop_scheduler, audit_service
from src.api import (
    auth_router, students_router, groups_router, attendance_router,
    grades_router, invoices_router, qr_router, sync_router,
    student_me_router, subscriptions_router, versions_router,
    webhook_router, exams_router, analytics_router, audit_router,
)

settings = get_settings()
logger = setup_logging(settings.LOG_LEVEL)


# ── Startup Tasks ──

async def _run_schema_migrations():
    """Run auto-migrations in background. Non-blocking startup."""
    try:
        from sqlalchemy import text
        from src.utils.database import get_engine
        engine = get_engine()
        async with engine.connect() as conn:
            await conn.execute(text("ALTER TABLE students ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);"))

            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS payment_requests (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
                    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
                    phone_number VARCHAR(20) NOT NULL,
                    amount DECIMAL(10,2) NOT NULL,
                    screenshot TEXT,
                    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
                    admin_message TEXT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
                    title VARCHAR(255) NOT NULL,
                    body TEXT NOT NULL,
                    type VARCHAR(50) DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error')),
                    read BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS exams (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    duration_minutes INT NOT NULL DEFAULT 30,
                    total_points INT DEFAULT 0,
                    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'closed')),
                    source_type VARCHAR(20) CHECK (source_type IN ('pdf', 'images')),
                    source_data JSONB,
                    answer_key TEXT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS questions (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
                    type VARCHAR(20) NOT NULL CHECK (type IN ('multiple_choice', 'essay')),
                    question_text TEXT NOT NULL,
                    options JSONB,
                    correct_answer TEXT,
                    points INT DEFAULT 1,
                    order_index INT NOT NULL,
                    page_number INT DEFAULT 1,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS student_exams (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    submitted_at TIMESTAMP WITH TIME ZONE,
                    duration_seconds INT,
                    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'graded')),
                    total_score DECIMAL(10,2),
                    max_score DECIMAL(10,2),
                    UNIQUE(exam_id, student_id)
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS student_answers (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    student_exam_id UUID NOT NULL REFERENCES student_exams(id) ON DELETE CASCADE,
                    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
                    answer TEXT,
                    is_correct BOOLEAN,
                    score DECIMAL(10,2),
                    feedback TEXT,
                    UNIQUE(student_exam_id, question_id)
                );
            """))
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS exam_results (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    student_exam_id UUID NOT NULL REFERENCES student_exams(id) ON DELETE CASCADE UNIQUE,
                    total_score DECIMAL(10,2),
                    max_score DECIMAL(10,2),
                    correct_count INT DEFAULT 0,
                    wrong_count INT DEFAULT 0,
                    essay_score DECIMAL(10,2),
                    strengths TEXT,
                    weaknesses TEXT,
                    recommendations TEXT,
                    ai_analysis_raw JSONB,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            """))
            await conn.commit()
            logger.info("Schema check: all tables OK")
    except Exception as e:
        logger.warning("Schema migration skipped: %s", e)


async def _keep_alive():
    """Self-ping every 5 minutes to keep Fly.io machine warm."""
    while True:
        try:
            import httpx
            async with httpx.AsyncClient(timeout=10.0) as client:
                await client.get(f"http://localhost:{os.environ.get('PORT', '8000')}/health")
        except Exception:
            pass
        await asyncio.sleep(300)  # 5 minutes


async def _init_services():
    """Initialize Redis sync buffer and rate limiter."""
    if not os.environ.get("VERCEL"):
        await sync_buffer.connect()
        start_scheduler()
    
    # Initialize rate limiter (Redis-backed if available)
    await rate_limiter.connect()
    
    # Wire audit publisher to the audit service repo
    from src.services import audit_service
    audit_publisher.set_repo(audit_service)
    
    # Start async audit publisher
    await audit_publisher.start()


# ── Lifecycle ──

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting DarsakAI Hub with Supabase...")
    
    # Init services (non-blocking on schema migrations)
    await _init_services()
    
    # Run schema migrations in background (don't block startup)
    asyncio.create_task(_run_schema_migrations())

    # Start self-keepalive to prevent Fly.io from suspending
    asyncio.create_task(_keep_alive())
    
    # Set Telegram webhook on Vercel
    if os.environ.get("VERCEL"):
        try:
            from src.api.webhook import _setup_webhook
            ok, detail = await _setup_webhook()
            if ok:
                logger.info("Telegram webhook set up")
            else:
                logger.warning("Telegram webhook setup: %s", detail)
        except Exception as e:
            logger.warning("Telegram webhook setup skipped: %s", e)
    else:
        try:
            from src.bot.telegram_bot import start_bot
            await start_bot()
        except Exception as e:
            logger.warning("Telegram bot startup skipped: %s", e)
    
    logger.info("DarsakAI Hub started successfully")
    yield
    
    # Shutdown
    await audit_publisher.stop()
    if not os.environ.get("VERCEL"):
        stop_scheduler()
        from src.bot.telegram_bot import stop_bot
        try:
            await stop_bot()
        except Exception as e:
            logger.warning("Telegram bot shutdown skipped: %s", e)
    
    logger.info("Shutting down DarsakAI Hub...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url=None,
    lifespan=lifespan,
)

# ── CORS ──
_cors_origins = settings.CORS_ORIGINS.copy()
_cors_origins = [o.rstrip("/") for o in _cors_origins]
_darsak_domains = [
    "https://darsakai.com", "https://www.darsakai.com",
    "https://darsak-ai.vercel.app", "https://darsak-web.vercel.app",
]
for d in _darsak_domains:
    if d not in _cors_origins:
        _cors_origins.append(d)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=["Authorization", "Content-Type", "X-Requested-With", "Accept", "Origin", "X-CSRF-Token", "Cache-Control"],
    expose_headers=["X-Total-Count", "X-Page", "X-Per-Page"],
    max_age=86400,
)

logger.info("CORS configured for origins: %s", _cors_origins)


# ── Middleware ──

@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return response


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if request.url.path in ("/docs", "/openapi.json", "/health"):
        return await call_next(request)

    client_ip = request.client.host if request.client else "unknown"
    auth_header = request.headers.get("authorization", "")
    user_key = client_ip + auth_header[:20]
    key = (user_key, request.url.path)

    max_requests = 120
    if request.url.path in ("/api/auth/login", "/api/auth/register", "/api/students/login"):
        max_requests = 10

    allowed = await rate_limiter.is_allowed(key, max_requests)
    if not allowed:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"detail": "Too many requests. Try again later."},
        )

    response = await call_next(request)
    return response


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logger.info(
        "%s %s - %s - %.3fs",
        request.method,
        request.url.path,
        response.status_code,
        duration,
    )
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", str(exc), exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"},
    )


# ── Health & Monitoring ──

@app.get("/health")
async def health_check():
    """Lightweight health check - returns immediately."""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "database": "supabase",
    }


@app.get("/health/deep")
async def deep_health():
    """Deep health check - verifies DB, cache, and circuit breaker states."""
    checks = {
        "app": True,
        "database": False,
        "cache": False,
        "rate_limiter": "redis" if hasattr(rate_limiter, '_use_redis') and rate_limiter._use_redis else "memory",
    }
    
    # Check Supabase connectivity
    try:
        from src.core.security.supabase_repo import get_supabase
        await get_supabase()
        checks["database"] = True
    except Exception as e:
        checks["database_error"] = str(e)[:200]
        checks["database"] = False
    
    # Check cache stats
    try:
        stats = await cache.stats
        checks["cache"] = stats
    except Exception as e:
        checks["cache_error"] = str(e)
    
    overall_healthy = all(v is True or isinstance(v, dict) for v in checks.values())
    status_code = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE
    
    return JSONResponse(
        status_code=status_code,
        content={"status": "healthy" if overall_healthy else "degraded", "checks": checks},
    )


@app.get("/health/cache")
async def cache_stats():
    """Return cache hit rates and sizes."""
    user_stats = await user_cache.stats
    student_stats = await student_cache.stats
    general_stats = await cache.stats
    return {
        "user_cache": user_stats,
        "student_cache": student_stats,
        "general_cache": general_stats,
    }


@app.get("/config/cors")
async def cors_debug(request: Request):
    """Debug endpoint to verify CORS headers are sent correctly."""
    origin = request.headers.get("origin", "")
    return {
        "origin_received": origin,
        "cors_origins_configured": _cors_origins,
        "origin_allowed": origin in _cors_origins or "*" in _cors_origins,
    }


# ── Router Registration ──

app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
app.include_router(students_router, prefix=settings.API_V1_PREFIX)
app.include_router(groups_router, prefix=settings.API_V1_PREFIX)
app.include_router(attendance_router, prefix=settings.API_V1_PREFIX)
app.include_router(grades_router, prefix=settings.API_V1_PREFIX)
app.include_router(invoices_router, prefix=settings.API_V1_PREFIX)
app.include_router(qr_router, prefix=settings.API_V1_PREFIX)
app.include_router(sync_router, prefix=settings.API_V1_PREFIX)
app.include_router(student_me_router, prefix=settings.API_V1_PREFIX)
app.include_router(subscriptions_router, prefix=settings.API_V1_PREFIX)
app.include_router(versions_router, prefix=settings.API_V1_PREFIX)
app.include_router(webhook_router, prefix=settings.API_V1_PREFIX)
app.include_router(exams_router, prefix=settings.API_V1_PREFIX)
app.include_router(analytics_router, prefix=settings.API_V1_PREFIX)
app.include_router(audit_router, prefix=settings.API_V1_PREFIX)
