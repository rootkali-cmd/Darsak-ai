import asyncio
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from src.core.config import get_settings
from src.core.exceptions import AppException

settings = get_settings()
logger = logging.getLogger("darsak.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing services...")
    logger.info(f"{settings.PROJECT_NAME} v{settings.VERSION} started")

    from src.core.migrations import run_migrations

    asyncio.create_task(run_migrations())

    yield

    logger.info("Shutting down...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from src.api.v1.auth import router as auth_router
from src.api.v1.students import router as students_router
from src.api.v1.groups import router as groups_router
from src.api.v1.attendance import router as attendance_router
from src.api.v1.grades import router as grades_router
from src.api.v1.invoices import router as invoices_router
from src.api.v1.exams import router as exams_router
from src.api.v1.lessons import router as lessons_router
from src.api.v1.subscriptions import router as subscriptions_router
from src.api.v1.dashboard import router as dashboard_router

app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
app.include_router(students_router, prefix=settings.API_V1_PREFIX)
app.include_router(groups_router, prefix=settings.API_V1_PREFIX)
app.include_router(attendance_router, prefix=settings.API_V1_PREFIX)
app.include_router(lessons_router, prefix=settings.API_V1_PREFIX)
app.include_router(subscriptions_router, prefix=settings.API_V1_PREFIX)
app.include_router(dashboard_router, prefix=settings.API_V1_PREFIX)
app.include_router(grades_router, prefix=settings.API_V1_PREFIX)
app.include_router(invoices_router, prefix=settings.API_V1_PREFIX)
app.include_router(exams_router, prefix=settings.API_V1_PREFIX)


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "DarsakAI Hub v2",
        "version": "2.0.0",
        "database": "supabase",
    }


@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", repr(exc))
    return JSONResponse(status_code=500, content={"detail": str(exc)})


sentry_dsn = os.getenv("SENTRY_DSN")
if sentry_dsn:
    import sentry_sdk

    sentry_sdk.init(
        dsn=sentry_dsn,
        environment=settings.ENVIRONMENT,
        traces_sample_rate=0.1,
    )
