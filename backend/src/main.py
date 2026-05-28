import os
import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from collections import defaultdict
from typing import Tuple

import sentry_sdk

sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN", ""),
    traces_sample_rate=1.0,
    environment=os.environ.get("ENVIRONMENT", "development"),
    release=f"darsakai-backend@{os.environ.get('VERSION', '1.0.0')}",
)

from src.core.config import get_settings
from src.core.logging import setup_logging
from src.services import sync_buffer, start_scheduler, stop_scheduler
from src.api import (
    auth_router, students_router, groups_router, attendance_router,
    grades_router, invoices_router, qr_router, sync_router,
    student_me_router, subscriptions_router, versions_router,
    webhook_router, exams_router, analytics_router, audit_router,
)

settings = get_settings()
logger = setup_logging(settings.LOG_LEVEL)

_rate_limit_store: dict[Tuple[str, str], list[float]] = defaultdict(list)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting DarsakAI Hub with Supabase...")

    # Auto-migrate
    try:
        from sqlalchemy import text
        from src.utils.database import engine
        async with engine.connect() as conn:
            await conn.execute(text("ALTER TABLE students ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);"))

            # Payment requests table
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
            # Exam system tables
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

    if not os.environ.get("VERCEL"):
        await sync_buffer.connect()
        start_scheduler()

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
        # Start Telegram bot (local polling)
        try:
            from src.bot.telegram_bot import start_bot, stop_bot
            await start_bot()
        except Exception as e:
            logger.warning("Telegram bot startup skipped: %s", e)

    logger.info("DarsakAI Hub started successfully")
    yield

    if not os.environ.get("VERCEL"):
        stop_scheduler()

    # Stop Telegram bot (local only)
    if not os.environ.get("VERCEL"):
        try:
            from src.bot.telegram_bot import stop_bot
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


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

    now = time.time()
    window = 60
    max_requests = 120
    if request.url.path in ("/api/auth/login", "/api/auth/register", "/api/students/login"):
        max_requests = 10

    requests_in_window = [t for t in _rate_limit_store[key] if now - t < window]
    _rate_limit_store[key] = requests_in_window

    if len(requests_in_window) >= max_requests:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"detail": "Too many requests. Try again later."},
        )

    _rate_limit_store[key].append(now)
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


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "database": "supabase",
    }


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
