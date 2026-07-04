import os
import time
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from src.utils.dependencies import get_current_teacher

import sentry_sdk
import re


def _sentry_scrub_pii(event, hint):
    """Scrub PII (email, name, phone, tokens) from Sentry events before sending."""
    import json

    def _scrub_value(val):
        if not isinstance(val, str):
            return val
        # Mask email addresses
        val = re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]', val)
        # Mask phone numbers (Egyptian: +20/0 followed by 10-11 digits)
        val = re.sub(r'(?:\+20|0)?1[0125]\d{8}', '[PHONE]', val)
        # Mask JWT tokens
        val = re.sub(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+', '[TOKEN]', val)
        # Mask Bearer tokens
        val = re.sub(r'Bearer\s+[a-zA-Z0-9._-]+', 'Bearer [TOKEN]', val)
        return val

    def _scrub_dict(d):
        for key in list(d.keys()):
            if key.lower() in ('email', 'phone', 'password', 'pin', 'pin_hash',
                               'access_token', 'refresh_token', 'secret_key',
                               'supabase_service_role_key', 'authorization'):
                d[key] = '[SCRUBBED]'
            elif isinstance(d[key], str):
                d[key] = _scrub_value(d[key])
            elif isinstance(d[key], dict):
                _scrub_dict(d[key])
            elif isinstance(d[key], list):
                for item in d[key]:
                    if isinstance(item, dict):
                        _scrub_dict(item)

    try:
        # Scrub request data
        if 'request' in event:
            if 'headers' in event['request']:
                _scrub_dict(event['request']['headers'])
            if 'data' in event['request']:
                if isinstance(event['request']['data'], dict):
                    _scrub_dict(event['request']['data'])
        # Scrub extra data
        if 'extra' in event:
            _scrub_dict(event['extra'])
        # Scrub breadcrumbs
        if 'breadcrumbs' in event and 'values' in event['breadcrumbs']:
            for bc in event['breadcrumbs']['values']:
                if 'data' in bc and isinstance(bc['data'], dict):
                    _scrub_dict(bc['data'])
    except Exception:
        pass

    return event


sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN", ""),
    traces_sample_rate=0.1,
    environment=os.environ.get("ENVIRONMENT", "development"),
    release=f"darsakai-backend@{os.environ.get('VERSION', '1.0.0')}",
    before_send=_sentry_scrub_pii,
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
    assistants_router,
    teacher_contacts_router,
    app_status_router,
    fcm_router,
    error_reporter_router,
    ai_classroom_router,
)
from src.modules.admission.routes import router as admission_router
from src.modules.wallet.routes import router as wallet_router
from src.modules.finance.routes import router as finance_router
from src.modules.support_links.routes import router as support_links_router
from src.modules.storage.routes import router as storage_router
from src.modules.courses.routes import router as courses_router

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
            price_monthly DECIMAL(10,2) DEFAULT 0,
            price_yearly DECIMAL(10,2) DEFAULT 0,
            max_students INT DEFAULT 100,
            max_assistants INT DEFAULT 0,
            ai_requests_per_day INT DEFAULT 5,
            max_ai_exams_per_month INT DEFAULT 5,
            max_ai_grading_per_month INT DEFAULT 100,
            storage_limit_gb INT DEFAULT 2,
            features_json JSONB DEFAULT '[]'::jsonb,
            is_active BOOLEAN DEFAULT TRUE,
            sort_order INT DEFAULT 0,
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
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS price_monthly DECIMAL(10,2) DEFAULT 0;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS price_yearly DECIMAL(10,2) DEFAULT 0;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS max_assistants INT DEFAULT 0;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS ai_requests_per_day INT DEFAULT 5;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS max_ai_exams_per_month INT DEFAULT 5;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS max_ai_grading_per_month INT DEFAULT 100;",
        "ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;",
        """DELETE FROM subscription_plans WHERE name NOT IN ('Basic', 'Pro', 'Premium', 'Golden');""",
        """INSERT INTO subscription_plans (name, description, price_egp, price_monthly, price_yearly, max_students, max_assistants, ai_requests_per_day, max_ai_exams_per_month, max_ai_grading_per_month, storage_limit_gb, features_json, sort_order)
         VALUES
            ('Basic', 'ظبط مجموعتك', 350.00, 350.00, 3000.00, 100, 0, 5, 5, 100, 15, '["حضور وغياب QR","درجات الطلاب","تقارير بسيطة","5 اختبارات AI شهرياً","100 تصحيح AI شهرياً","15GB تخزين","دعم فني"]'::jsonb, 1),
            ('Pro', 'إدارة السنتر الذكية', 750.00, 750.00, 7800.00, 400, 2, 10, 15, 500, 60, '["كل ميزات Basic","كورسات مشتركة","15 اختبار AI شهرياً","500 تصحيح AI شهرياً","60GB تخزين","2 مساعدين","تقارير AI","دعم فني سريع"]'::jsonb, 2),
            ('Premium', 'نظام السعر المرن', 1400.00, 1250.00, 13500.00, 1000, 5, 20, 20, 2000, 200, '["كل ميزات Pro","تحضير اختبارات AI","20 اختبار AI شهرياً","2000 تصحيح AI شهرياً","200GB تخزين","5 مساعدين","دعم VIP"]'::jsonb, 3),
            ('Golden', 'الباقة الذهبية', 20000.00, 20000.00, 80000.00, 40000, 25, 20, 20, 25000, 2000, '["كل ميزات Premium","40,000 طالب","25 مساعد","25,000 تصحيح AI شهرياً","2TB تخزين","دعم VIP مخصص","الدفع عبر إنستاباي فقط"]'::jsonb, 4)
         ON CONFLICT (name) DO UPDATE SET
            price_egp = EXCLUDED.price_egp,
            price_monthly = EXCLUDED.price_monthly,
            price_yearly = EXCLUDED.price_yearly,
            max_students = EXCLUDED.max_students,
            max_assistants = EXCLUDED.max_assistants,
            ai_requests_per_day = EXCLUDED.ai_requests_per_day,
            max_ai_exams_per_month = EXCLUDED.max_ai_exams_per_month,
            max_ai_grading_per_month = EXCLUDED.max_ai_grading_per_month,
            storage_limit_gb = EXCLUDED.storage_limit_gb,
            description = EXCLUDED.description,
            features_json = EXCLUDED.features_json,
            sort_order = EXCLUDED.sort_order;""",
        "ALTER TABLE exams ADD COLUMN IF NOT EXISTS deadline_at TIMESTAMP WITH TIME ZONE;",
        """CREATE TABLE IF NOT EXISTS instapay_config (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            barcode_url TEXT,
            username VARCHAR(255),
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """INSERT INTO instapay_config (barcode_url, username, is_active)
         SELECT 'https://example.com/instapay-barcode.png', '', TRUE
         WHERE NOT EXISTS (SELECT 1 FROM instapay_config WHERE is_active = TRUE);""",
        "UPDATE instapay_config SET barcode_url='https://api.darsak-backend.fly.dev/api/instapay-barcode' WHERE barcode_url IS NULL;",
        """UPDATE subscription_plans SET price_monthly=350, price_yearly=3000, max_students=100, max_assistants=0, ai_requests_per_day=5, max_ai_exams_per_month=5, max_ai_grading_per_month=100, storage_limit_gb=15, features_json='["حضور وغياب QR","درجات الطلاب","تقارير بسيطة","5 اختبارات AI شهرياً","100 تصحيح AI شهرياً","15GB تخزين","دعم فني"]'::jsonb, sort_order=1 WHERE name='Basic';""",
        """UPDATE subscription_plans SET price_monthly=750, price_yearly=7800, max_students=400, max_assistants=2, ai_requests_per_day=10, max_ai_exams_per_month=15, max_ai_grading_per_month=500, storage_limit_gb=60, features_json='["كل ميزات Basic","كورسات مشتركة","15 اختبار AI شهرياً","500 تصحيح AI شهرياً","60GB تخزين","2 مساعدين","تقارير AI","دعم فني سريع"]'::jsonb, sort_order=2 WHERE name='Pro';""",
        """UPDATE subscription_plans SET price_monthly=1250, price_yearly=13500, max_students=1000, max_assistants=5, ai_requests_per_day=20, max_ai_exams_per_month=20, max_ai_grading_per_month=2000, storage_limit_gb=200, features_json='["كل ميزات Pro","تحضير اختبارات AI","20 اختبار AI شهرياً","2000 تصحيح AI شهرياً","200GB تخزين","5 مساعدين","دعم VIP"]'::jsonb, sort_order=3 WHERE name='Premium';""",
        """UPDATE subscription_plans SET price_monthly=20000, price_yearly=80000, max_students=40000, max_assistants=25, ai_requests_per_day=20, max_ai_exams_per_month=20, max_ai_grading_per_month=25000, storage_limit_gb=2000, features_json='["كل ميزات Premium","40,000 طالب","25 مساعد","25,000 تصحيح AI شهرياً","2TB تخزين","دعم VIP مخصص","الدفع عبر إنستاباي فقط"]'::jsonb, sort_order=4 WHERE name='Golden';""",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) CHECK (payment_method IN ('vodafone_cash', 'instapay', 'cash'));",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS screenshot_url TEXT;",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS billing_period VARCHAR(20) DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly'));",
        "ALTER TABLE payment_requests ADD COLUMN IF NOT EXISTS max_students INT DEFAULT 0;",
        "ALTER TABLE teacher_subscriptions ADD COLUMN IF NOT EXISTS custom_max_students INT DEFAULT 0;",
        # ─── Platform capital & revenue distribution ────────────────
        """CREATE TABLE IF NOT EXISTS platform_capital (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            category VARCHAR(50) NOT NULL UNIQUE,
            name_ar VARCHAR(100) NOT NULL,
            percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
            current_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
            total_inflow DECIMAL(12,2) NOT NULL DEFAULT 0,
            description TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """INSERT INTO platform_capital (category, name_ar, percentage, description)
         VALUES
            ('platform', 'نفقات المنصة', 35.00, 'الاستضافة، السيرفرات، التراخيص، الصيانة'),
            ('operations', 'التشغيل', 25.00, 'الرواتب الإدارية، الم办公، المرافق'),
            ('emergency', 'الاحتياطي', 20.00, 'الطوارئ والmuxtarن'),
            ('labor', 'العمالة', 15.00, 'فريق الدعم والتطوير'),
            ('marketing', 'التسويق', 5.00, 'إعلانات وحملات تسويقية')
         ON CONFLICT (category) DO NOTHING;""",
        """CREATE TABLE IF NOT EXISTS subscription_revenue (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            subscription_id UUID REFERENCES teacher_subscriptions(id) ON DELETE SET NULL,
            plan_name VARCHAR(50) NOT NULL,
            billing_period VARCHAR(20) NOT NULL,
            total_amount DECIMAL(10,2) NOT NULL,
            platform_share DECIMAL(10,2) NOT NULL,
            operations_share DECIMAL(10,2) NOT NULL,
            emergency_share DECIMAL(10,2) NOT NULL,
            labor_share DECIMAL(10,2) NOT NULL,
            marketing_share DECIMAL(10,2) NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'distributed', 'held')),
            distributed_at TIMESTAMPTZ,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS deposit_revenue (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            deposit_id UUID REFERENCES student_deposit_requests(id) ON DELETE SET NULL,
            student_id UUID REFERENCES students(id) ON DELETE SET NULL,
            tax_amount DECIMAL(10,2) NOT NULL,
            platform_share DECIMAL(10,2) NOT NULL,
            operations_share DECIMAL(10,2) NOT NULL,
            emergency_share DECIMAL(10,2) NOT NULL,
            labor_share DECIMAL(10,2) NOT NULL,
            marketing_share DECIMAL(10,2) NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'distributed', 'held')),
            distributed_at TIMESTAMPTZ,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS commission_revenue (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            payout_id UUID REFERENCES payout_requests(id) ON DELETE SET NULL,
            teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
            commission_amount DECIMAL(10,2) NOT NULL,
            platform_share DECIMAL(10,2) NOT NULL,
            operations_share DECIMAL(10,2) NOT NULL,
            emergency_share DECIMAL(10,2) NOT NULL,
            labor_share DECIMAL(10,2) NOT NULL,
            marketing_share DECIMAL(10,2) NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'distributed', 'held')),
            distributed_at TIMESTAMPTZ,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
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
        # ─── Assistants table ────────────────────────────────────────
        """CREATE TABLE IF NOT EXISTS assistants (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            full_name VARCHAR(255) NOT NULL,
            phone VARCHAR(20),
            salary DECIMAL(10,2) DEFAULT 0,
            incentives DECIMAL(10,2) DEFAULT 0,
            payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'partial')),
            notes TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );""",
        # ─── Assistants password column on users table ──────────────
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS assistants_password_hash VARCHAR(255);",
        # ─── Phase 1: Student Segregation & Admission ──────────────────
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS registration_type VARCHAR(20) DEFAULT 'center' CHECK (registration_type IN ('center', 'online'));""",
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS admission_status VARCHAR(20) DEFAULT 'approved' CHECK (admission_status IN ('pending', 'approved', 'rejected'));""",
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);""",
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;""",
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS rejection_reason TEXT;""",
        """ALTER TABLE students ADD COLUMN IF NOT EXISTS telegram_chat_id VARCHAR(100);""",
        """CREATE INDEX IF NOT EXISTS idx_students_admission_status ON students(teacher_id, admission_status) WHERE admission_status = 'pending';""",
        """CREATE TABLE IF NOT EXISTS student_admission_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            full_name VARCHAR(255) NOT NULL,
            phone VARCHAR(20),
            parent_phone VARCHAR(20),
            grade_level VARCHAR(50),
            email VARCHAR(255),
            birth_date DATE,
            address TEXT,
            parent_name VARCHAR(255),
            school_name VARCHAR(255),
            registration_type VARCHAR(20) DEFAULT 'online' CHECK (registration_type IN ('center', 'online')),
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
            student_id UUID REFERENCES students(id) ON DELETE SET NULL,
            approved_by UUID REFERENCES users(id),
            approved_at TIMESTAMPTZ,
            rejection_reason TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE INDEX IF NOT EXISTS idx_admission_teacher_status ON student_admission_requests(teacher_id, status);""",
        """CREATE INDEX IF NOT EXISTS idx_admission_created ON student_admission_requests(created_at DESC);""",
        # ─── Phase 2: Wallet & Payout (Financial Ledger) ──────────────
        """CREATE TABLE IF NOT EXISTS teacher_wallets (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
            available_balance DECIMAL(12,2) DEFAULT 0.00 CHECK (available_balance >= 0),
            pending_balance DECIMAL(12,2) DEFAULT 0.00 CHECK (pending_balance >= 0),
            total_earned DECIMAL(12,2) DEFAULT 0.00,
            total_withdrawn DECIMAL(12,2) DEFAULT 0.00,
            currency VARCHAR(10) DEFAULT 'EGP',
            version INT DEFAULT 1,
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE INDEX IF NOT EXISTS idx_wallet_teacher ON teacher_wallets(teacher_id);""",
        """CREATE TABLE IF NOT EXISTS payout_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            requested_amount DECIMAL(12,2) NOT NULL CHECK (requested_amount > 0),
            commission_rate DECIMAL(5,2) NOT NULL,
            commission_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            net_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            payout_method VARCHAR(20) NOT NULL CHECK (payout_method IN ('vodafone_cash', 'instapay', 'bank_transfer', 'cash')),
            payout_phone VARCHAR(20),
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'failed')),
            telegram_message_id VARCHAR(100),
            admin_response TEXT,
            processed_by UUID REFERENCES users(id),
            processed_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE INDEX IF NOT EXISTS idx_payout_teacher_status ON payout_requests(teacher_id, status);""",
        """CREATE INDEX IF NOT EXISTS idx_payout_created ON payout_requests(created_at DESC);""",
        """CREATE INDEX IF NOT EXISTS idx_payout_telegram_msg ON payout_requests(telegram_message_id) WHERE telegram_message_id IS NOT NULL;""",
        """CREATE TABLE IF NOT EXISTS wallet_transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            wallet_id UUID NOT NULL REFERENCES teacher_wallets(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('credit', 'debit', 'commission', 'refund')),
            amount DECIMAL(12,2) NOT NULL,
            balance_after DECIMAL(12,2) NOT NULL,
            reference_type VARCHAR(20),
            reference_id UUID,
            description TEXT,
            created_at TIMESTAMPTZ(3) DEFAULT NOW()
        );""",
        """CREATE INDEX IF NOT EXISTS idx_wallet_tx_teacher ON wallet_transactions(teacher_id, created_at DESC);""",
        """CREATE INDEX IF NOT EXISTS idx_wallet_tx_reference ON wallet_transactions(reference_type, reference_id);""",
        # ─── Phase 4: Telegram Deep Linking ───────────────────────────
        """CREATE TABLE IF NOT EXISTS student_telegram_links (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID REFERENCES students(id) ON DELETE CASCADE,
            teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
            phone VARCHAR(20),
            telegram_chat_id VARCHAR(100) NOT NULL,
            telegram_user_id VARCHAR(100),
            telegram_username VARCHAR(100),
            deep_link_token VARCHAR(255) UNIQUE,
            linked_at TIMESTAMPTZ DEFAULT NOW(),
            is_active BOOLEAN DEFAULT TRUE
        );""",
        """CREATE INDEX IF NOT EXISTS idx_telegram_chat_id ON student_telegram_links(telegram_chat_id);""",
        """CREATE INDEX IF NOT EXISTS idx_telegram_teacher ON student_telegram_links(teacher_id);""",
        """CREATE INDEX IF NOT EXISTS idx_telegram_phone ON student_telegram_links(phone);""",
        # ─── Phase 5: Teacher Support Links ───────────────────────────
        """CREATE TABLE IF NOT EXISTS teacher_support_links (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            platform VARCHAR(20) NOT NULL CHECK (platform IN ('whatsapp', 'telegram', 'instagram', 'facebook', 'youtube', 'website', 'other')),
            label VARCHAR(100),
            url TEXT NOT NULL,
            icon_name VARCHAR(50),
            is_active BOOLEAN DEFAULT TRUE,
            sort_order INT DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE INDEX IF NOT EXISTS idx_support_teacher_active ON teacher_support_links(teacher_id, is_active, sort_order);""",
        # ─── PostgreSQL RPC: Atomic Payout ────────────────────────────
        """CREATE OR REPLACE FUNCTION request_payout_atomic(
            p_teacher_id UUID, p_amount DECIMAL(12,2)
        ) RETURNS TABLE (id UUID, available_balance DECIMAL(12,2), pending_balance DECIMAL(12,2))
        LANGUAGE plpgsql SECURITY DEFINER AS $$
        BEGIN
            UPDATE teacher_wallets
            SET available_balance = available_balance - p_amount,
                pending_balance = pending_balance + p_amount,
                updated_at = NOW(),
                version = version + 1
            WHERE teacher_id = p_teacher_id AND available_balance >= p_amount
            RETURNING id, available_balance, pending_balance;
        END;
        $$;""",
        # ─── Course Management System ───────────────────────────────
        """CREATE TABLE IF NOT EXISTS courses (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            subject VARCHAR(100),
            level VARCHAR(50),
            cover_image_r2_key TEXT,
            is_published BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_courses_teacher ON courses(teacher_id);",
        """CREATE TABLE IF NOT EXISTS course_chapters (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            sort_order INT DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_chapters_course ON course_chapters(course_id, sort_order);",
        """CREATE TABLE IF NOT EXISTS course_lessons (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            chapter_id UUID NOT NULL REFERENCES course_chapters(id) ON DELETE CASCADE,
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            video_url TEXT,
            r2_video_key TEXT,
            video_duration_seconds INT,
            has_exam BOOLEAN DEFAULT FALSE,
            has_homework BOOLEAN DEFAULT FALSE,
            is_free BOOLEAN DEFAULT FALSE,
            sort_order INT DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_lessons_chapter ON course_lessons(chapter_id, sort_order);",
        "CREATE INDEX IF NOT EXISTS idx_lessons_course ON course_lessons(course_id);",
        """CREATE TABLE IF NOT EXISTS course_files (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            lesson_id UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            file_name VARCHAR(500) NOT NULL,
            file_size_bytes BIGINT,
            mime_type VARCHAR(100),
            r2_key TEXT NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_course_files_lesson ON course_files(lesson_id);",
        """CREATE TABLE IF NOT EXISTS course_pricing (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            course_id UUID NOT NULL UNIQUE REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            center_price DECIMAL(10,2) DEFAULT 0.00,
            platform_price DECIMAL(10,2) DEFAULT 0.00,
            is_free_for_center BOOLEAN DEFAULT TRUE,
            currency VARCHAR(10) DEFAULT 'EGP',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        """CREATE TABLE IF NOT EXISTS content_locks (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            lesson_id UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            requires_exam_id UUID REFERENCES exams(id) ON DELETE SET NULL,
            lock_type VARCHAR(20) DEFAULT 'exam' CHECK (lock_type IN ('exam', 'payment', 'both')),
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_content_locks_lesson ON content_locks(lesson_id);",
        """CREATE TABLE IF NOT EXISTS student_course_progress (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            lesson_id UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            is_completed BOOLEAN DEFAULT FALSE,
            video_position_seconds INT DEFAULT 0,
            completed_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(student_id, lesson_id)
        );""",
        "CREATE INDEX IF NOT EXISTS idx_progress_student_course ON student_course_progress(student_id, course_id);",
        # ─── Student Wallet & Finance ────────────────────────────────
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS fcm_token TEXT;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;",
        """CREATE TABLE IF NOT EXISTS student_wallets (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
            balance DECIMAL(12,2) DEFAULT 0.00 CHECK (balance >= 0),
            total_deposited DECIMAL(12,2) DEFAULT 0.00,
            total_spent DECIMAL(12,2) DEFAULT 0.00,
            version INT DEFAULT 1,
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_student_wallet ON student_wallets(student_id);",
        """CREATE TABLE IF NOT EXISTS student_deposit_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
            amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
            tax_rate DECIMAL(5,2) NOT NULL DEFAULT 1.50,
            tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            screenshot TEXT,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
            telegram_message_id VARCHAR(100),
            admin_response TEXT,
            processed_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_deposit_requests_student ON student_deposit_requests(student_id, status);",
        """CREATE TABLE IF NOT EXISTS student_transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            wallet_id UUID NOT NULL REFERENCES student_wallets(id) ON DELETE CASCADE,
            transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('deposit', 'purchase', 'refund')),
            amount DECIMAL(12,2) NOT NULL,
            balance_after DECIMAL(12,2) NOT NULL,
            reference_type VARCHAR(50),
            reference_id UUID,
            description TEXT,
            created_at TIMESTAMPTZ(3) DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_student_tx ON student_transactions(student_id, created_at DESC);",
        # ─── Course Enrollments ──────────────────────────────────────
        """CREATE TABLE IF NOT EXISTS student_course_enrollments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            paid_amount DECIMAL(12,2) DEFAULT 0.00,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(student_id, course_id)
        );""",
        "CREATE INDEX IF NOT EXISTS idx_enrollment_student ON student_course_enrollments(student_id, course_id);",
        "CREATE INDEX IF NOT EXISTS idx_enrollment_teacher ON student_course_enrollments(teacher_id);",
        # ─── Phase 7: Payment Config ─────────────────────────────────
        "ALTER TABLE instapay_config ADD COLUMN IF NOT EXISTS vodafone_cash_number VARCHAR(20) DEFAULT '01031524947';",
        "UPDATE instapay_config SET vodafone_cash_number='01031524947' WHERE vodafone_cash_number IS NULL;",
        # ─── Phase 8: Deposit request fields ──────────────────────────
        "ALTER TABLE student_deposit_requests ADD COLUMN IF NOT EXISTS sender_phone VARCHAR(30);",
        "ALTER TABLE student_deposit_requests ADD COLUMN IF NOT EXISTS method VARCHAR(30) DEFAULT 'vodafone_cash';",
        # ─── Phase 9: Storage expansion ─────────────────────────────────
        "ALTER TABLE teacher_subscriptions ADD COLUMN IF NOT EXISTS extra_storage_gb INT DEFAULT 0;",
        """CREATE TABLE IF NOT EXISTS storage_expansion_requests (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL,
            type VARCHAR(30) DEFAULT 'storage_expansion',
            amount DECIMAL(10,2) DEFAULT 50,
            extra_gb INT DEFAULT 10,
            status VARCHAR(20) DEFAULT 'pending',
            created_at TIMESTAMPTZ DEFAULT now(),
            confirmed_at TIMESTAMPTZ
        );""",
        # ─── Phase 10: Ensure all course columns exist ─────────────────
        "ALTER TABLE courses ADD COLUMN IF NOT EXISTS cover_image_r2_key TEXT;",
        "ALTER TABLE courses ADD COLUMN IF NOT EXISTS subject VARCHAR(100);",
        "ALTER TABLE courses ADD COLUMN IF NOT EXISTS level VARCHAR(50);",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS video_url TEXT;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS r2_video_key TEXT;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS video_duration_seconds INT;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS has_exam BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS has_homework BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;",
        # ─── Phase 11: Admin password hash ────────────────────────────────────
        """CREATE TABLE IF NOT EXISTS admin_config (
            key VARCHAR(100) PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        # ─── Phase 12: Teacher contacts ────────────────────────────────────────
        """CREATE TABLE IF NOT EXISTS teacher_contacts (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            platform VARCHAR(30) NOT NULL CHECK (platform IN ('whatsapp', 'telegram', 'instagram', 'facebook', 'tiktok', 'messenger', 'phone', 'email')),
            label VARCHAR(200) NOT NULL,
            url VARCHAR(500) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            sort_order INT DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        # ─── Phase 13: Shared lectures across groups ──────────────────────────
        """CREATE TABLE IF NOT EXISTS shared_lectures (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            group_ids JSONB DEFAULT '[]'::jsonb,
            video_url TEXT,
            r2_video_key TEXT,
            is_free BOOLEAN DEFAULT FALSE,
            has_exam BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_shared_lectures_course ON shared_lectures(course_id);",
        "CREATE INDEX IF NOT EXISTS idx_shared_lectures_teacher ON shared_lectures(teacher_id);",
        # ─── Phase 14: Video progress tracking ─────────────────────────
        """CREATE TABLE IF NOT EXISTS video_progress (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
            position_seconds FLOAT DEFAULT 0,
            duration_seconds FLOAT,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(student_id, lesson_id)
        );""",
        # ─── Phase 16: teacher_media table ─────────────────────────────
        """CREATE TABLE IF NOT EXISTS teacher_media (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
            file_key TEXT,
            file_size_bytes BIGINT DEFAULT 0,
            mime_type TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_teacher_media_teacher ON teacher_media(teacher_id);",
        # ─── Phase 17: AI Classroom sessions ────────────────────────────
        """CREATE TABLE IF NOT EXISTS ai_lesson_sessions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
            classroom_url TEXT NOT NULL,
            title VARCHAR(255) DEFAULT 'درس AI',
            rate_per_minute DECIMAL(6,2) DEFAULT 0.42,
            min_balance DECIMAL(10,2) DEFAULT 10.00,
            started_at TIMESTAMPTZ DEFAULT NOW(),
            ended_at TIMESTAMPTZ,
            duration_seconds INT DEFAULT 0,
            cost DECIMAL(10,2) DEFAULT 0,
            balance_before DECIMAL(12,2),
            balance_after DECIMAL(12,2),
            status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'ended', 'force_ended')),
            heartbeat_at TIMESTAMPTZ DEFAULT NOW(),
            warning_sent_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );""",
        "CREATE INDEX IF NOT EXISTS idx_ai_sessions_student ON ai_lesson_sessions(student_id, created_at DESC);",
        """DO $$
        BEGIN
            ALTER TABLE student_transactions DROP CONSTRAINT IF EXISTS student_transactions_transaction_type_check;
        EXCEPTION WHEN others THEN NULL;
        END $$;""",
        """ALTER TABLE student_transactions ADD CONSTRAINT student_transactions_transaction_type_check
            CHECK (transaction_type IN ('deposit', 'purchase', 'refund', 'lesson_consumption'));""",
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

        # ─── Phase 18: AI classroom chat_token column ───────────────────
        for sql in [
            "ALTER TABLE ai_lesson_sessions ADD COLUMN IF NOT EXISTS chat_token VARCHAR(64);",
            "CREATE INDEX IF NOT EXISTS idx_ai_sessions_chat_token ON ai_lesson_sessions(chat_token) WHERE chat_token IS NOT NULL;",
        ]:
            try:
                async with httpx.AsyncClient(timeout=30.0) as http:
                    resp = await http.post(
                        f"{url}/rest/v1/rpc/exec_sql",
                        json={"query": sql.strip()},
                        headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                    )
                if resp.status_code == 200:
                    created += 1
                else:
                    skipped += 1
            except Exception:
                skipped += 1

        # Ensure Premium plan exists
        try:
            client2 = await get_supabase()
            existing = await client2.table("subscription_plans").select("name").in_("name", ["Premium", "Golden"]).execute()
            existing_names = {p["name"] for p in (existing.data or [])}
            if "Premium" not in existing_names:
                await client2.table("subscription_plans").insert({
                    "name": "Premium",
                    "description": "نظام السعر المرن",
                    "price_egp": 1400.00,
                    "price_monthly": 1100.00,
                    "price_yearly": 13500.00,
                    "max_students": 5000,
                    "max_assistants": 5,
                    "ai_requests_per_day": 20,
                    "max_ai_exams_per_month": 20,
                    "max_ai_grading_per_month": 2000,
                    "storage_limit_gb": 200,
                    "features_json": ["كل ميزات Pro", "تحضير اختبارات AI", "20 اختبار AI شهرياً", "2000 تصحيح AI شهرياً", "200GB تخزين", "5 مساعدين", "دعم VIP"],
                    "sort_order": 3,
                    "is_active": True,
                }).execute()
                logger.info("Premium plan created via direct insert")
            if "Golden" not in existing_names:
                await client2.table("subscription_plans").insert({
                    "name": "Golden",
                    "description": "الباقة الذهبية",
                    "price_egp": 20000.00,
                    "price_monthly": 20000.00,
                    "price_yearly": 80000.00,
                    "max_students": 40000,
                    "max_assistants": 25,
                    "ai_requests_per_day": 20,
                    "max_ai_exams_per_month": 20,
                    "max_ai_grading_per_month": 25000,
                    "storage_limit_gb": 2000,
                    "features_json": ["كل ميزات Premium", "40,000 طالب", "25 مساعد", "25,000 تصحيح AI شهرياً", "2TB تخزين", "دعم VIP مخصص", "الدفع عبر إنستاباي فقط"],
                    "sort_order": 4,
                    "is_active": True,
                }).execute()
                logger.info("Golden plan created via direct insert")
        except Exception as pre_ex:
            logger.warning("Premium plan insert check: %s", pre_ex)

        logger.info("Schema migration done: %d created, %d skipped", created, skipped)

        # Ensure Supabase storage bucket exists for course images
        try:
            client3 = await get_supabase()
            try:
                client3.storage.create_bucket("darsak-media", {"public": True})
                logger.info("Created Supabase storage bucket: darsak-media")
            except Exception as be:
                if "already exists" in str(be).lower() or "duplicate" in str(be).lower():
                    logger.info("Supabase storage bucket darsak-media already exists")
                else:
                    logger.warning("Storage bucket creation: %s", str(be)[:200])
        except Exception as sbe:
            logger.warning("Could not ensure storage bucket: %s", sbe)

        # Initialize admin password hash
        if settings.ADMIN_PASSWORD:
            from src.core.security.auth import hash_password as _hash_admin_pw
            admin_pw_hash = _hash_admin_pw(settings.ADMIN_PASSWORD)
            await client.table("admin_config").upsert(
                {"key": "admin_password_hash", "value": admin_pw_hash},
                on_conflict="key",
            ).execute()
    except Exception as e:
        logger.warning("Schema migration skipped: %s", e)


async def _ensure_plans():
    """Ensure all 4 subscription plans exist in DB.
    DB columns: id, name, price_egp, max_students, features_json, is_active, etc.
    Only creates missing plans - never overwrites existing data.
    """
    try:
        from src.core.security.supabase_repo import get_supabase
        client = await get_supabase()
        
        PLANS = [
            {"name": "Basic", "price_egp": 350.00, "price_monthly": 350.00, "price_yearly": 3000.00, "max_students": 100, "max_assistants": 0, "ai_requests_per_day": 5, "max_ai_exams_per_month": 5, "max_ai_grading_per_month": 100, "storage_limit_gb": 15, "sort_order": 1, "features_json": ["حضور وغياب QR", "درجات الطلاب", "تقارير بسيطة", "5 اختبارات AI شهرياً", "100 تصحيح AI شهرياً", "15GB تخزين", "دعم فني"]},
            {"name": "Pro", "price_egp": 750.00, "price_monthly": 750.00, "price_yearly": 7800.00, "max_students": 400, "max_assistants": 2, "ai_requests_per_day": 10, "max_ai_exams_per_month": 15, "max_ai_grading_per_month": 500, "storage_limit_gb": 60, "sort_order": 2, "features_json": ["كل ميزات Basic", "كورسات مشتركة", "15 اختبار AI شهرياً", "500 تصحيح AI شهرياً", "60GB تخزين", "2 مساعدين", "تقارير AI", "دعم فني سريع"]},
            {"name": "Premium", "price_egp": 1400.00, "price_monthly": 1250.00, "price_yearly": 13500.00, "max_students": 1000, "max_assistants": 5, "ai_requests_per_day": 20, "max_ai_exams_per_month": 20, "max_ai_grading_per_month": 2000, "storage_limit_gb": 200, "sort_order": 3, "features_json": ["كل ميزات Pro", "تحضير اختبارات AI", "20 اختبار AI شهرياً", "2000 تصحيح AI شهرياً", "200GB تخزين", "5 مساعدين", "دعم VIP"]},
            {"name": "Golden", "price_egp": 20000.00, "price_monthly": 20000.00, "price_yearly": 80000.00, "max_students": 40000, "max_assistants": 25, "ai_requests_per_day": 20, "max_ai_exams_per_month": 20, "max_ai_grading_per_month": 25000, "storage_limit_gb": 2000, "sort_order": 4, "features_json": ["كل ميزات Premium", "40,000 طالب", "25 مساعد", "25,000 تصحيح AI شهرياً", "2TB تخزين", "دعم VIP مخصص", "الدفع عبر إنستاباي فقط"]},
        # ─── Phase 15: Fix is_active NULL values — backfill + NOT NULL ─────
        """DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM students WHERE is_active IS NULL) THEN
                UPDATE students SET is_active = TRUE WHERE is_active IS NULL;
            END IF;
        END $$;""",
        """DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name='students' AND column_name='is_active' AND is_nullable='YES'
            ) THEN
                ALTER TABLE students ALTER COLUMN is_active SET NOT NULL;
            END IF;
        END $$;""",

        # ─── Phase 17: course_lessons exam_id column ─────────────────────
        "ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS exam_id UUID REFERENCES exams(id) ON DELETE SET NULL;",
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
    
    # Initialize rate limiter with Redis URL (Upstash) for distributed safety
    if settings.REDIS_URL:
        rate_limiter.set_redis_url(settings.REDIS_URL)
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
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    )
    return response


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if request.url.path in ("/docs", "/openapi.json", "/health", "/health/deep"):
        return await call_next(request)

    client_ip = request.client.host if request.client else "unknown"
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()

    path = request.url.path
    method = request.method

    # Tiered rate limits: stricter for auth/admin, normal for general API
    if path in ("/api/auth/login", "/api/auth/register", "/api/students/login", "/api/admin/login"):
        max_requests = 10
    elif method in ("POST", "PUT", "PATCH", "DELETE"):
        max_requests = 30
    else:
        max_requests = 120

    allowed = await rate_limiter.is_allowed((client_ip, path), max_requests)
    if not allowed:
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"detail": "Too many requests. Try again later."},
        )

    response = await call_next(request)
    response.headers["X-RateLimit-Limit"] = str(max_requests)
    return response


@app.middleware("http")
async def csrf_middleware(request: Request, call_next):
    """CSRF protection: validate Origin/Referer on state-changing requests using cookie auth.

    Mobile apps and API clients using Authorization header are exempt.
    Only enforced when auth is carried via cookies (browser sessions).
    """
    if request.method in ("GET", "HEAD", "OPTIONS"):
        return await call_next(request)
    if request.url.path in ("/docs", "/openapi.json", "/health", "/health/deep"):
        return await call_next(request)

    # If Authorization header is present (mobile/API client), skip CSRF check
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        return await call_next(request)

    # If no cookies are present, no session to protect
    cookies = request.cookies
    if "access_token" not in cookies:
        return await call_next(request)

    # Cookie-based session detected on state-changing request: validate origin
    origin = request.headers.get("origin", "")
    referer = request.headers.get("referer", "")

    source_url = origin or referer
    if not source_url:
        # Direct API call without origin/referer from cookie session — allow (e.g. curl, Postman)
        return await call_next(request)

    # Extract origin from source_url
    from urllib.parse import urlparse
    try:
        parsed = urlparse(source_url)
        source_origin = f"{parsed.scheme}://{parsed.netloc}"
    except Exception:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "CSRF validation failed: invalid origin"},
        )

    allowed_origins = set(_cors_origins)
    if source_origin not in allowed_origins:
        logger.warning("CSRF blocked: origin=%s not in allowed=%s", source_origin, allowed_origins)
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "CSRF validation failed: origin not allowed"},
        )

    return await call_next(request)


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
        content={"detail": "حدث خطأ في الخادم. حاول مرة أخرى."},
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
async def deep_health(request: Request):
    """Deep health check - admin only. Verifies DB, cache, and circuit breaker states."""
    from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

    security = HTTPBearer(auto_error=False)
    credentials: HTTPAuthorizationCredentials | None = await security(request)

    if not credentials:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Not authenticated"},
        )

    from src.utils.dependencies import decode_token
    token_data = decode_token(credentials.credentials)
    if not token_data or token_data.get("role") != "admin":
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "Admin access required"},
        )

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
    except Exception:
        checks["database"] = False

    # Check cache stats
    try:
        stats = await cache.stats
        checks["cache"] = stats
    except Exception:
        checks["cache"] = False

    overall_healthy = all(v is True or isinstance(v, dict) for v in checks.values())
    status_code = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return JSONResponse(
        status_code=status_code,
        content={"status": "healthy" if overall_healthy else "degraded", "checks": checks},
    )


@app.get("/api/teacher/storage-usage")
async def teacher_storage_usage(
    current_user: dict = Depends(get_current_teacher),
):
    from src.modules.storage.routes import _compute_storage_usage
    return await _compute_storage_usage(current_user["id"])


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
app.include_router(lessons_router, prefix=settings.API_V1_PREFIX)
# ─── DISABLED FOR OFFLINE-FIRST LAUNCH ───────────────────────────────
# app.include_router(video_analytics_router, prefix=settings.API_V1_PREFIX)
# app.include_router(whatsapp_router, prefix=settings.API_V1_PREFIX)
# app.include_router(quiz_router, prefix=settings.API_V1_PREFIX)
# ─────────────────────────────────────────────────────────────────────
app.include_router(admin_router, prefix=settings.API_V1_PREFIX)
app.include_router(subjects_router, prefix=settings.API_V1_PREFIX)
app.include_router(payments_router, prefix=settings.API_V1_PREFIX)
app.include_router(reports_router, prefix=settings.API_V1_PREFIX)
app.include_router(assistants_router, prefix=settings.API_V1_PREFIX)
app.include_router(admission_router, prefix=settings.API_V1_PREFIX)
app.include_router(wallet_router, prefix=settings.API_V1_PREFIX)
app.include_router(finance_router, prefix=settings.API_V1_PREFIX)
app.include_router(support_links_router, prefix=settings.API_V1_PREFIX)
app.include_router(storage_router, prefix=settings.API_V1_PREFIX)
app.include_router(courses_router, prefix=settings.API_V1_PREFIX)
app.include_router(teacher_contacts_router, prefix=settings.API_V1_PREFIX)
app.include_router(app_status_router, prefix=settings.API_V1_PREFIX)
app.include_router(fcm_router, prefix=settings.API_V1_PREFIX)
app.include_router(error_reporter_router, prefix=settings.API_V1_PREFIX)
app.include_router(ai_classroom_router, prefix=settings.API_V1_PREFIX)
