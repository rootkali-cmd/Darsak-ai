import sys
import json
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from supabase import create_client
from src.core.config import get_settings

settings = get_settings()

print("🔌 Connecting to Supabase via REST API...")
client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

SQL_STATEMENTS = [
    """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    """,
    """
    CREATE TYPE user_role AS ENUM ('admin', 'teacher', 'assistant');
    """,
    """
    CREATE TYPE education_level AS ENUM ('preparatory', 'secondary');
    """,
    """
    CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'cancelled');
    """,
    """
    CREATE TYPE payload_type AS ENUM ('grade', 'attendance', 'invoice', 'ai_report', 'student', 'group');
    """,
    """
    CREATE TYPE sync_status AS ENUM ('pending', 'synced', 'failed');
    """,
    """
    CREATE TYPE actor_type AS ENUM ('student', 'teacher', 'assistant', 'system');
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_users_teacher_code ON users(teacher_code);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_students_teacher_id ON students(teacher_id);
    CREATE INDEX IF NOT EXISTS idx_students_code ON students(code);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_groups_teacher_id ON groups(teacher_id);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON attendances(student_id);
    CREATE INDEX IF NOT EXISTS idx_attendance_group_id ON attendances(group_id);
    CREATE INDEX IF NOT EXISTS idx_attendance_teacher_id ON attendances(teacher_id);
    CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendances(date);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
    CREATE INDEX IF NOT EXISTS idx_grades_teacher_id ON grades(teacher_id);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_invoices_teacher_id ON invoices(teacher_id);
    CREATE INDEX IF NOT EXISTS idx_invoices_student_id ON invoices(student_id);
    """,
    """
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
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_encrypted_payloads_teacher_id ON encrypted_payloads(teacher_id);
    CREATE INDEX IF NOT EXISTS idx_encrypted_payloads_sync_status ON encrypted_payloads(sync_status);
    """,
    """
    CREATE TABLE IF NOT EXISTS audit_logs (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        actor_type actor_type NOT NULL,
        actor_id UUID,
        action VARCHAR(100) NOT NULL,
        resource_type VARCHAR(50),
        resource_id UUID,
        ip_address VARCHAR(45),
        user_agent VARCHAR(500),
        "metadata" JSONB,
        timestamp TIMESTAMPTZ DEFAULT NOW()
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_type, actor_id);
    """,
    """
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE students ENABLE ROW LEVEL SECURITY;
    ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
    ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;
    ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
    ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
    ALTER TABLE encrypted_payloads ENABLE ROW LEVEL SECURITY;
    ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
    """,
    """
    DROP POLICY IF EXISTS "Allow service role full access" ON users;
    CREATE POLICY "Allow service role full access" ON users
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON students;
    CREATE POLICY "Allow service role full access" ON students
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON groups;
    CREATE POLICY "Allow service role full access" ON groups
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON attendances;
    CREATE POLICY "Allow service role full access" ON attendances
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON grades;
    CREATE POLICY "Allow service role full access" ON grades
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON invoices;
    CREATE POLICY "Allow service role full access" ON invoices
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON encrypted_payloads;
    CREATE POLICY "Allow service role full access" ON encrypted_payloads
        FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow service role full access" ON audit_logs;
    CREATE POLICY "Allow service role full access" ON audit_logs
        FOR ALL USING (true) WITH CHECK (true);
    """,
    """
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
    """,
]


def execute_sql(sql: str):
    clean = sql.strip()
    if not clean:
        return
    print(f"   Executing: {clean[:80]}...")
    try:
        response = client.postgrest.session.post(
            f"{settings.SUPABASE_URL}/rest/v1/",
            headers={
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                "Content-Type": "application/json",
                "Prefer": "params=single-object",
            },
        )
    except Exception as e:
        print(f"   ⚠️  Note: {e}")


print("\n📋 Creating database schema...")

for i, sql in enumerate(SQL_STATEMENTS):
    print(f"\n[{i+1}/{len(SQL_STATEMENTS)}] {sql.strip()[:100]}...")
    try:
        result = client.rpc(
            "exec_sql",
            {"query": sql.strip()},
        ).execute()
        print(f"   ✅ Done")
    except Exception as e:
        error_str = str(e)
        if "already exists" in error_str.lower() or "duplicate" in error_str.lower():
            print(f"   ⏭️  Already exists, skipping")
        elif "function exec_sql" in error_str or "does not exist" in error_str:
            print(f"   ⚠️  RPC not available, using direct SQL via REST")
            try:
                from supabase.lib.client_options import ClientOptions
                session = client.postgrest.session
                response = session.post(
                    f"{settings.SUPABASE_URL}/rest/v1/rpc/exec_sql",
                    json={"query": sql.strip()},
                    headers={
                        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                        "Content-Type": "application/json",
                    },
                )
            except Exception as e2:
                print(f"   ⚠️  Will use SQL via Supabase Dashboard")
        else:
            print(f"   ⚠️  {error_str[:200]}")

print("\n✅ Schema creation attempted!")
print("\n📊 Verifying tables...")
try:
    result = client.table("users").select("*").limit(1).execute()
    print("   ✓ users table accessible")
except Exception as e:
    print(f"   ✗ users: {e}")

for table in ["students", "groups", "attendances", "grades", "invoices", "encrypted_payloads", "audit_logs"]:
    try:
        result = client.table(table).select("*").limit(1).execute()
        print(f"   ✓ {table} table accessible")
    except Exception as e:
        print(f"   ✗ {table}: {str(e)[:100]}")
