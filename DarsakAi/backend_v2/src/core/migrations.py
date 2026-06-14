import logging
from sqlalchemy import text
from src.core.database import get_engine

logger = logging.getLogger("darsak.migrations")


async def run_migrations() -> None:
    try:
        engine = get_engine()
        async with engine.begin() as conn:
            # 1. users
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS users (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    email VARCHAR(255) UNIQUE NOT NULL,
                    full_name VARCHAR(255) NOT NULL,
                    hashed_password VARCHAR(255) NOT NULL,
                    role VARCHAR(20) DEFAULT 'teacher',
                    teacher_code VARCHAR(50) UNIQUE,
                    telegram_channel_id VARCHAR(100),
                    is_active BOOLEAN DEFAULT TRUE,
                    onboarding_completed BOOLEAN DEFAULT FALSE,
                    subjects TEXT[] DEFAULT '{}',
                    levels TEXT[] DEFAULT '{}',
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 2. students
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS students (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    full_name VARCHAR(255) NOT NULL,
                    code VARCHAR(50) UNIQUE NOT NULL,
                    parent_phone VARCHAR(20),
                    group_id UUID,
                    pin_hash VARCHAR(255),
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_students_teacher_id ON students(teacher_id)
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_students_code ON students(code)
            """))

            # 3. groups
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS groups (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    name VARCHAR(255) NOT NULL,
                    subject VARCHAR(100),
                    level TEXT,
                    day_of_week VARCHAR(20),
                    time_slot VARCHAR(50),
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON groups(teacher_id)
            """))

            # 4. attendance
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS attendance (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    date DATE NOT NULL,
                    time TIME NOT NULL,
                    status VARCHAR(20) DEFAULT 'present',
                    method VARCHAR(20) DEFAULT 'barcode',
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_attendance_teacher_date ON attendance(teacher_id, date)
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON attendance(student_id)
            """))

            # 5. grades
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS grades (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    subject VARCHAR(100),
                    score DECIMAL(5,2),
                    max_score DECIMAL(5,2),
                    type VARCHAR(20) DEFAULT 'exam',
                    notes TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_grades_teacher_id ON grades(teacher_id)
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id)
            """))

            # 6. invoices
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS invoices (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    amount DECIMAL(10,2),
                    description TEXT,
                    status VARCHAR(20) DEFAULT 'unpaid',
                    due_date DATE,
                    paid_date DATE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_invoices_teacher_id ON invoices(teacher_id)
            """))

            # 7. exams
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS exams (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    duration_minutes INT DEFAULT 30,
                    total_points INT DEFAULT 0,
                    status VARCHAR(20) DEFAULT 'draft',
                    source_type VARCHAR(20),
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_exams_teacher_id ON exams(teacher_id)
            """))

            # 8. exam_questions
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS exam_questions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
                    question_text TEXT NOT NULL,
                    options JSONB DEFAULT '[]',
                    correct_answer TEXT,
                    points INT DEFAULT 1,
                    order_num INT DEFAULT 0
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_exam_questions_exam_id ON exam_questions(exam_id)
            """))

            # 9. student_exams
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS student_exams (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
                    answers JSONB DEFAULT '{}',
                    score DECIMAL(5,2),
                    is_completed BOOLEAN DEFAULT FALSE,
                    started_at TIMESTAMPTZ,
                    completed_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 10. subscription_plans
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS subscription_plans (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name VARCHAR(100) NOT NULL,
                    price_egp DECIMAL(10,2),
                    max_students INT DEFAULT -1,
                    max_ai_requests INT DEFAULT 5,
                    features_json JSONB DEFAULT '[]',
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 11. subscription_codes
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS subscription_codes (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    code VARCHAR(50) UNIQUE NOT NULL,
                    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
                    is_used BOOLEAN DEFAULT FALSE,
                    expires_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_subscription_codes_code ON subscription_codes(code)
            """))

            # 12. teacher_subscriptions
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS teacher_subscriptions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
                    code_id UUID REFERENCES subscription_codes(id),
                    expires_at TIMESTAMPTZ,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 13. payment_requests
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS payment_requests (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id),
                    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
                    phone_number VARCHAR(20) NOT NULL,
                    amount DECIMAL(10,2),
                    screenshot TEXT,
                    status VARCHAR(20) DEFAULT 'pending',
                    admin_message TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 14. lessons
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS lessons (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_lessons_teacher_id ON lessons(teacher_id)
            """))

            # 15. video_analytics
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS video_analytics (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
                    video_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
                    teacher_id UUID NOT NULL REFERENCES users(id),
                    last_position INT DEFAULT 0,
                    max_watched_duration INT DEFAULT 0,
                    current_speed FLOAT DEFAULT 1.0,
                    is_completed BOOLEAN DEFAULT FALSE,
                    is_flagged_cheated BOOLEAN DEFAULT FALSE,
                    is_delayed BOOLEAN DEFAULT FALSE,
                    delay_reason VARCHAR(100),
                    last_event_type VARCHAR(50),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 16. notifications
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    title VARCHAR(255) NOT NULL,
                    body TEXT NOT NULL,
                    type VARCHAR(50) DEFAULT 'info',
                    read BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 17. audit_logs
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    actor_type VARCHAR(50),
                    actor_id UUID,
                    action VARCHAR(100),
                    resource_type VARCHAR(50),
                    resource_id UUID,
                    ip_address VARCHAR(50),
                    metadata JSONB DEFAULT '{}',
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))

            # 18. sessions
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    title VARCHAR(255) NOT NULL,
                    date DATE NOT NULL,
                    start_time TIME,
                    end_time TIME,
                    group_id UUID REFERENCES groups(id),
                    notes TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """))
            await conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_sessions_teacher_id ON sessions(teacher_id)
            """))

            # --- Alter statements for column additions from old schema ---

            await conn.execute(text("""
                ALTER TABLE students ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255)
            """))

            await conn.execute(text("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_channel_id VARCHAR(100)
            """))

            await conn.execute(text("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE
            """))

            await conn.execute(text("""
                DO $$
                BEGIN
                    ALTER TABLE groups ALTER COLUMN level TYPE TEXT USING level::TEXT;
                EXCEPTION
                    WHEN others THEN
                        NULL;
                END
                $$
            """))

            await conn.execute(text("""
                DROP TYPE IF EXISTS education_level
            """))

        logger.info("All migrations completed successfully")

    except Exception as e:
        logger.error("Migration failed: %s", repr(e))
        raise
