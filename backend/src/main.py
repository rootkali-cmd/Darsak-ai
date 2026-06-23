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
    dashboard_router, lessons_router, video_analytics_router,
    whatsapp_router,
    quiz_router,
    admin_router,
    subjects_router,
    payments_router,
    reports_router,
)

settings = get_settings()
logger = setup_logging(settings.LOG_LEVEL)


# ── Startup Tasks ──

async def _run_schema_migrations():
    """Run auto-migrations via Supabase RPC. Non-blocking startup."""
    SQL_STATEMENTS = [
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE SET NULL;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;",
        """DO $$ BEGIN
            ALTER TABLE groups ALTER COLUMN level TYPE TEXT USING level::TEXT;
        EXCEPTION WHEN others THEN NULL; END $$;""",
        """DO $$ BEGIN
            DROP TYPE IF EXISTS education_level;
        EXCEPTION WHEN others THEN NULL; END $$;""",
        """DO $$ BEGIN
            ALTER TABLE teacher_subscriptions ALTER COLUMN code_id TYPE VARCHAR(255);
        EXCEPTION WHEN others THEN NULL; END $$;""",
        """DO $$ BEGIN
            ALTER TABLE teacher_subscriptions ADD COLUMN IF NOT EXISTS is_trial BOOLEAN DEFAULT FALSE;
        EXCEPTION WHEN others THEN NULL; END $$;""",
        """CREATE TABLE IF NOT EXISTS payment_requests (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
            phone_number VARCHAR(20) NOT NULL,
            amount DECIMAL(10,2) NOT NULL,
            screenshot TEXT,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
            admin_message TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS notifications (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            type VARCHAR(50) DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error')),
            read BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS exams (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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
        );""",
        """CREATE TABLE IF NOT EXISTS questions (
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
        );""",
        """CREATE TABLE IF NOT EXISTS student_exams (
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
        );""",
        """CREATE TABLE IF NOT EXISTS student_answers (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_exam_id UUID NOT NULL REFERENCES student_exams(id) ON DELETE CASCADE,
            question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
            answer TEXT,
            is_correct BOOLEAN,
            score DECIMAL(10,2),
            feedback TEXT,
            UNIQUE(student_exam_id, question_id)
        );""",
        """CREATE TABLE IF NOT EXISTS exam_results (
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
        );""",
        """CREATE TABLE IF NOT EXISTS lessons (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            subject VARCHAR(100),
            week_number INT,
            duration_seconds INT,
            video_url TEXT,
            tg_message_id VARCHAR(100),
            tg_file_id TEXT,
            is_published BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS video_analytics (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            video_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            last_position INT DEFAULT 0,
            max_watched_duration INT DEFAULT 0,
            current_speed FLOAT DEFAULT 1.0,
            is_completed BOOLEAN DEFAULT FALSE,
            is_flagged_cheated BOOLEAN DEFAULT FALSE,
            is_delayed BOOLEAN DEFAULT FALSE,
            delay_reason VARCHAR(100),
            last_event_type VARCHAR(50),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_channel_id VARCHAR(100);",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS subjects JSONB DEFAULT '[]'::jsonb;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS levels JSONB DEFAULT '[]'::jsonb;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_teacher_id_fkey;",
        "ALTER TABLE notifications ALTER COLUMN teacher_id DROP NOT NULL;",
        "ALTER TABLE student_answers ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();",
        "ALTER TABLE student_exams ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();",
        "ALTER TABLE quiz_questions ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();",
        "ALTER TABLE exams ADD COLUMN IF NOT EXISTS show_results_at TIMESTAMP WITH TIME ZONE;",
        """CREATE TABLE IF NOT EXISTS quizzes (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
            total_questions INT DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS quiz_questions (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
            question_text TEXT NOT NULL,
            options JSONB DEFAULT '[]',
            correct_answer INT DEFAULT 0
        );""",
        """CREATE TABLE IF NOT EXISTS admin_users (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            full_name VARCHAR(255) NOT NULL,
            hashed_password VARCHAR(255) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS admin_templates (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            type VARCHAR(50) NOT NULL,
            name VARCHAR(255) NOT NULL,
            pattern TEXT,
            template TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS payment_transactions (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID REFERENCES students(id) ON DELETE SET NULL,
            phone_number VARCHAR(20),
            amount DECIMAL(10,2),
            method VARCHAR(20),
            reference TEXT,
            status VARCHAR(20) DEFAULT 'pending',
            matched_by VARCHAR(50),
            approved_at TIMESTAMPTZ,
            rejected_at TIMESTAMPTZ,
            notes TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS subscription_plans (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            name VARCHAR(100) NOT NULL UNIQUE,
            description TEXT,
            price_egp DECIMAL(10,2) DEFAULT 0,
            max_students INT DEFAULT 100,
            ai_requests_per_month INT DEFAULT 10,
            storage_limit_gb INT DEFAULT 2,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS subscription_codes (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            code VARCHAR(100) NOT NULL UNIQUE,
            plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
            is_used BOOLEAN DEFAULT FALSE,
            used_by_teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
            used_at TIMESTAMPTZ,
            expires_at TIMESTAMPTZ,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS teacher_subscriptions (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
            code_id VARCHAR(255),
            is_active BOOLEAN DEFAULT TRUE,
            expires_at TIMESTAMPTZ,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS features_json JSONB DEFAULT '[]'::jsonb;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS description TEXT;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS storage_limit_gb INT DEFAULT 2;",
        """DELETE FROM subscription_plans WHERE name NOT IN ('Basic', 'Pro', 'Premium');""",
        """INSERT INTO subscription_plans (name, description, price_egp, max_students, max_ai_requests, storage_limit_gb, features_json)
         VALUES
            ('Basic', 'الأساسية - 250ج/شهر', 250.00, 100, 10, 5, '["حضور وغياب","درجات الطلاب","تقارير بسيطة","دعم فني"]'::jsonb),
            ('Pro', 'الاحترافية - 600ج/شهر - الأكثر شعبية', 600.00, 400, 50, 10, '["حضور وغياب","درجات الطلاب","تقارير AI","دروس مشتركة","تحضير اختبارات بالـ AI","دعم فني"]'::jsonb),
            ('Premium', 'المتكاملة - 1100ج/شهر - بدون حدود', 1100.00, -1, -1, -1, '["حضور وغياب","درجات الطلاب","تقارير AI","دروس مشتركة","تحضير اختبارات بالـ AI","طلاب غير محدود","دعم فني أولوية"]'::jsonb)
         ON CONFLICT (name) DO UPDATE SET
            price_egp = EXCLUDED.price_egp,
            max_students = EXCLUDED.max_students,
            max_ai_requests = EXCLUDED.max_ai_requests,
            storage_limit_gb = EXCLUDED.storage_limit_gb,
            description = EXCLUDED.description,
            features_json = EXCLUDED.features_json;""",
        "ALTER TABLE exams ADD COLUMN IF NOT EXISTS deadline_at TIMESTAMP WITH TIME ZONE;",
        """CREATE TABLE IF NOT EXISTS instapay_config (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            barcode_url TEXT NOT NULL,
            username VARCHAR(255) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """INSERT INTO instapay_config (barcode_url, username, is_active)
         SELECT 'https://example.com/instapay-barcode.png', 'ahmed_instapay', TRUE
         WHERE NOT EXISTS (SELECT 1 FROM instapay_config WHERE is_active = TRUE);""",
        "UPDATE instapay_config SET barcode_url='https://api.darsak-backend.fly.dev/api/instapay-barcode', username='ahmed-mahmoud-1@instapay' WHERE is_active=TRUE;",
        """UPDATE subscription_plans SET price_egp=250, max_students=100, max_ai_requests=10, storage_limit_gb=5, features_json='["حضور وغياب","درجات الطلاب","تقارير بسيطة","دعم فني"]'::jsonb WHERE name='Basic';""",
        """UPDATE subscription_plans SET price_egp=600, max_students=400, max_ai_requests=50, storage_limit_gb=10, features_json='["حضور وغياب","درجات الطلاب","تقارير AI","دروس مشتركة","تحضير اختبارات بالـ AI","دعم فني"]'::jsonb WHERE name='Pro';""",
        """UPDATE subscription_plans SET price_egp=1100, max_students=-1, max_ai_requests=-1, storage_limit_gb=-1, features_json='["حضور وغياب","درجات الطلاب","تقارير AI","دروس مشتركة","تحضير اختبارات بالـ AI","طلاب غير محدود","دعم فني أولوية"]'::jsonb WHERE name='Premium';""",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) CHECK (payment_method IN ('vodafone_cash', 'instapay', 'cash'));",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS screenshot_url TEXT;",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS billing_period VARCHAR(20) DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly'));",
        """CREATE TABLE IF NOT EXISTS invoices (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            lesson_id UUID REFERENCES lessons(id) ON DELETE SET NULL,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            amount DECIMAL(10,2) NOT NULL,
            currency VARCHAR(10) DEFAULT 'EGP',
            payment_method VARCHAR(20) CHECK (payment_method IN ('vodafone_cash', 'instapay', 'bank_transfer', 'cash')),
            screenshot_url TEXT,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'rejected')),
            teacher_note TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        # ─── Daily AI message limit enforcement ────────────────────
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS daily_requests_count INT DEFAULT 0;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS last_request_date DATE DEFAULT CURRENT_DATE;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES users(id) ON DELETE SET NULL;",
        # ─── AI conversations table (multi-turn chat) ──────────────
        """CREATE TABLE IF NOT EXISTS ai_conversations (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            messages JSONB DEFAULT '[]'::jsonb,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
    ]

    try:
        from src.core.security.supabase_repo import get_supabase
        import httpx

        client = await get_supabase()
        url = settings.SUPABASE_URL.rstrip("/")
        key = settings.SUPABASE_SERVICE_ROLE_KEY

        created = 0
        skipped = 0

        for i, sql in enumerate(SQL_STATEMENTS):
            try:
                async with httpx.AsyncClient(timeout=30.0) as http:
                    resp = await http.post(
                        f"{url}/rest/v1/rpc/exec_sql",
                        json={"query": sql.strip()},
                        headers={
                            "apikey": key,
                            "Authorization": f"Bearer {key}",
                            "Content-Type": "application/json",
                        },
                    )
                if resp.status_code == 200:
                    created += 1
                elif "already exists" in resp.text.lower() or "duplicate" in resp.text.lower():
                    skipped += 1
                else:
                    logger.warning("Migration [%d] warning: %s", i, resp.text[:200])
                    skipped += 1
            except Exception as e:
                logger.warning("Migration [%d] failed: %s", i, str(e)[:200])
                skipped += 1

        # Ensure Premium plan exists
        try:
            client2 = await get_supabase()
            existing = await client2.table("subscription_plans").select("name").eq("name", "Premium").execute()
            if not existing.data:
                await client2.table("subscription_plans").insert({
                    "name": "Premium",
                    "price_egp": 1100.00,
                    "max_students": 15,
                    "max_ai_requests": 100,
                    "features_json": ["15 اختبار شهرياً","حضور وغياب","درجات الطلاب","تقارير AI","دروس مشتركة","تحضير اختبارات بالـ AI","دعم فني أولوية"],
                    "is_active": True,
                }).execute()
                logger.info("Premium plan created via direct insert")
        except Exception as pre_ex:
            logger.warning("Premium plan insert check: %s", pre_ex)

        logger.info("Schema migration done: %d created, %d skipped", created, skipped)
    except Exception as e:
        logger.warning("Schema migration skipped: %s", e)


async def _ensure_plans():
    """Ensure all 3 subscription plans exist in DB.
    DB columns: id, name, price_egp, max_students, max_ai_requests, features_json, is_active, created_at, updated_at
    Only creates missing plans - never overwrites existing data.
    """
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        
        PLANS = [
            {"name": "Basic", "price_egp": 250.00, "max_students": 100, "max_ai_requests": 10, "storage_limit_gb": 5, "features_json": ["حضور وغياب", "درجات الطلاب", "تقارير بسيطة", "دعم فني"]},
            {"name": "Pro", "price_egp": 600.00, "max_students": 400, "max_ai_requests": 50, "storage_limit_gb": 10, "features_json": ["حضور وغياب", "درجات الطلاب", "تقارير AI", "دروس مشتركة", "تحضير اختبارات بالـ AI", "دعم فني"]},
            {"name": "Premium", "price_egp": 1100.00, "max_students": -1, "max_ai_requests": -1, "storage_limit_gb": -1, "features_json": ["حضور وغياب", "درجات الطلاب", "تقارير AI", "دروس مشتركة", "تحضير اختبارات بالـ AI", "طلاب غير محدود", "دعم فني أولوية"]},
        ]
        
        existing = await client.table("subscription_plans").select("name,id").execute()
        existing_names = {p["name"] for p in (existing.data or [])}
        
        # Remove duplicate plans (keep oldest, delete newer)
        name_counts = {}
        for p in (existing.data or []):
            n = p["name"]
            if n not in name_counts:
                name_counts[n] = []
            name_counts[n].append(p["id"])
        for n, ids in name_counts.items():
            if len(ids) > 1:
                for dup_id in ids[1:]:
                    await client.table("subscription_plans").delete().eq("id", dup_id).execute()
                    logger.info("Removed duplicate plan %s id=%s", n, dup_id)
        
        # Re-fetch after dedup
        existing = await client.table("subscription_plans").select("name").execute()
        existing_names = {p["name"] for p in (existing.data or [])}
        
        for plan in PLANS:
            if plan["name"] not in existing_names:
                await client.table("subscription_plans").insert(plan).execute()
                logger.info("Created missing plan: %s", plan["name"])
            # Do NOT update existing plans - let admin manage pricing
        
        logger.info("Plans ensure done. Existing: %s", existing_names)
    except Exception as e:
        logger.warning("Plans ensure failed: %s", e, exc_info=True)


async def _keep_alive():
    """Self-ping every 5 minutes to keep Fly.io machine warm."""
    import httpx
    external_url = None
    try:
        import os
        fly_app = os.environ.get("FLY_APP_NAME", "")
        external_url = f"https://{fly_app}.fly.dev/health" if fly_app else None
    except Exception:
        pass

    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            try:
                await client.get(f"http://localhost:{os.environ.get('PORT', '8000')}/health")
                if external_url:
                    await client.get(external_url)
            except Exception:
                pass
            await asyncio.sleep(300)


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
    
    # Ensure subscription plans exist (critical, run in background)
    asyncio.create_task(_ensure_plans())

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
            asyncio.create_task(start_bot())
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
    logger.error("Unhandled exception on %s %s: %s", request.method, request.url.path, str(exc), exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": f"حدث خطأ في الخادم: {str(exc)[:200]}"},
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
app.include_router(student_me_router, prefix=settings.API_V1_PREFIX)
app.include_router(students_router, prefix=settings.API_V1_PREFIX)
app.include_router(groups_router, prefix=settings.API_V1_PREFIX)
app.include_router(attendance_router, prefix=settings.API_V1_PREFIX)
app.include_router(grades_router, prefix=settings.API_V1_PREFIX)
app.include_router(invoices_router, prefix=settings.API_V1_PREFIX)
app.include_router(qr_router, prefix=settings.API_V1_PREFIX)
app.include_router(sync_router, prefix=settings.API_V1_PREFIX)
app.include_router(subscriptions_router, prefix=settings.API_V1_PREFIX)
app.include_router(versions_router, prefix=settings.API_V1_PREFIX)
app.include_router(webhook_router, prefix=settings.API_V1_PREFIX)
app.include_router(exams_router, prefix=settings.API_V1_PREFIX)
app.include_router(analytics_router, prefix=settings.API_V1_PREFIX)
app.include_router(audit_router, prefix=settings.API_V1_PREFIX)
app.include_router(dashboard_router, prefix=settings.API_V1_PREFIX)
# ─── DISABLED FOR OFFLINE-FIRST LAUNCH ───────────────────────────────
# FUTURE ROADMAP: Video/Live Streaming features - will be re-enabled for online mode
# app.include_router(lessons_router, prefix=settings.API_V1_PREFIX)
# app.include_router(video_analytics_router, prefix=settings.API_V1_PREFIX)
# app.include_router(whatsapp_router, prefix=settings.API_V1_PREFIX)
# app.include_router(quiz_router, prefix=settings.API_V1_PREFIX)
# ─────────────────────────────────────────────────────────────────────
app.include_router(admin_router, prefix=settings.API_V1_PREFIX)
app.include_router(subjects_router, prefix=settings.API_V1_PREFIX)
app.include_router(payments_router, prefix=settings.API_V1_PREFIX)
app.include_router(reports_router, prefix=settings.API_V1_PREFIX)
