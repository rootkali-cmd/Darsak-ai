import os
import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from collections import defaultdict

from src.core.config import get_settings
from src.core.logging import setup_logging
from src.services import sync_buffer, start_scheduler, stop_scheduler
from src.api import (
    auth_router, students_router, groups_router, attendance_router,
    grades_router, invoices_router, qr_router, sync_router,
    student_me_router, subscriptions_router, versions_router,
    webhook_router,
)

settings = get_settings()
logger = setup_logging(settings.LOG_LEVEL)

_rate_limit_store: dict[str, list[float]] = defaultdict(list)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting DarsakAI Hub with Supabase...")

    # Auto-migrate: ensure pin_hash column exists
    try:
        from sqlalchemy import text
        from src.utils.database import engine
        async with engine.connect() as conn:
            await conn.execute(text("ALTER TABLE students ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);"))
            await conn.commit()
            logger.info("Schema check: pin_hash column OK")
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
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    path = request.url.path

    if path in ("/docs", "/openapi.json", "/health"):
        return await call_next(request)

    now = time.time()
    window = 60
    max_requests = 120

    requests_in_window = [t for t in _rate_limit_store[client_ip] if now - t < window]
    _rate_limit_store[client_ip] = requests_in_window

    if len(requests_in_window) >= max_requests:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"detail": "Too many requests. Try again later."},
        )

    _rate_limit_store[client_ip].append(now)
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
