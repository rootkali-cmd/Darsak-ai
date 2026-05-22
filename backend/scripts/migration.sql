-- =====================================================
-- DarsakAI Database Schema - Supabase Migration
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ENUM Types
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'teacher', 'assistant');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE education_level AS ENUM ('preparatory', 'secondary');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'cancelled');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payload_type AS ENUM ('grade', 'attendance', 'invoice', 'ai_report', 'student', 'group');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE sync_status AS ENUM ('pending', 'synced', 'failed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE actor_type AS ENUM ('student', 'teacher', 'assistant', 'system');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- =====================================================
-- TABLES
-- =====================================================

-- Users (Teachers, Admins, Assistants)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'teacher',
    is_active BOOLEAN DEFAULT true,
    teacher_code VARCHAR(50) UNIQUE,
    encryption_salt VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Students
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    parent_phone VARCHAR(20),
    grade_level VARCHAR(50),
    pin_hash VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Groups (Study groups/classes)
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    level education_level NOT NULL,
    day_of_week VARCHAR(20) NOT NULL,
    time_slot VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Attendance records
CREATE TABLE IF NOT EXISTS attendances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status attendance_status NOT NULL DEFAULT 'absent',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes VARCHAR(500),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grades
CREATE TABLE IF NOT EXISTS grades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_name VARCHAR(255) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    score FLOAT NOT NULL,
    max_score FLOAT NOT NULL DEFAULT 100,
    wrong_questions JSONB,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoices/Payments
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    amount FLOAT NOT NULL,
    description VARCHAR(500),
    paid BOOLEAN DEFAULT false,
    payment_date DATE,
    signature VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Encrypted sync payloads (E2E encrypted data)
CREATE TABLE IF NOT EXISTS encrypted_payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payload_type payload_type NOT NULL,
    ciphertext TEXT NOT NULL,
    iv TEXT NOT NULL,
    auth_tag TEXT NOT NULL,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_type actor_type NOT NULL,
    actor_id UUID,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    metadata JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_teacher_code ON users(teacher_code);
CREATE INDEX IF NOT EXISTS idx_students_teacher_id ON students(teacher_id);
CREATE INDEX IF NOT EXISTS idx_students_code ON students(code);
CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON groups(teacher_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON attendances(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_group_id ON attendances(group_id);
CREATE INDEX IF NOT EXISTS idx_attendance_teacher_id ON attendances(teacher_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendances(date);
CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
CREATE INDEX IF NOT EXISTS idx_grades_teacher_id ON grades(teacher_id);
CREATE INDEX IF NOT EXISTS idx_invoices_teacher_id ON invoices(teacher_id);
CREATE INDEX IF NOT EXISTS idx_invoices_student_id ON invoices(student_id);
CREATE INDEX IF NOT EXISTS idx_encrypted_payloads_teacher_id ON encrypted_payloads(teacher_id);
CREATE INDEX IF NOT EXISTS idx_encrypted_payloads_sync_status ON encrypted_payloads(sync_status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_type, actor_id);

-- =====================================================
-- TRIGGERS (auto-update updated_at)
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_students_updated_at ON students;
CREATE TRIGGER update_students_updated_at
    BEFORE UPDATE ON students
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_groups_updated_at ON groups;
CREATE TRIGGER update_groups_updated_at
    BEFORE UPDATE ON groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE encrypted_payloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Service role full access policies
DROP POLICY IF EXISTS "service_role_full_access_users" ON users;
CREATE POLICY "service_role_full_access_users" ON users
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_students" ON students;
CREATE POLICY "service_role_full_access_students" ON students
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_groups" ON groups;
CREATE POLICY "service_role_full_access_groups" ON groups
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_attendances" ON attendances;
CREATE POLICY "service_role_full_access_attendances" ON attendances
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_grades" ON grades;
CREATE POLICY "service_role_full_access_grades" ON grades
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_invoices" ON invoices;
CREATE POLICY "service_role_full_access_invoices" ON invoices
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_encrypted_payloads" ON encrypted_payloads;
CREATE POLICY "service_role_full_access_encrypted_payloads" ON encrypted_payloads
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_audit_logs" ON audit_logs;
CREATE POLICY "service_role_full_access_audit_logs" ON audit_logs
    FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- VERIFICATION
-- =====================================================

SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name AND c.table_schema = 'public') as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
