import sys
import json
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from supabase import create_client
from src.core.config import get_settings
from src.core.security.auth import hash_password
import uuid

settings = get_settings()

print("🔌 Connecting to Supabase...")
client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

# Verify connection
try:
    result = client.table("users").select("*").limit(1).execute()
    print("✅ Connected to Supabase successfully!")
except Exception as e:
    print(f"❌ Connection failed: {e}")
    sys.exit(1)

# Create default admin user
admin_email = "admin@darsak.ai"
admin_password = "Admin@123456"
admin_code = "TCH-ADMIN001"

print(f"\n👤 Creating default admin user...")
print(f"   Email: {admin_email}")
print(f"   Password: {admin_password}")
print(f"   Code: {admin_code}")

# Check if admin already exists
existing = client.table("users").select("*").eq("email", admin_email).execute()
if existing.data:
    print("   ⏭️  Admin already exists, skipping...")
else:
    try:
        new_user = client.table("users").insert({
            "email": admin_email,
            "full_name": "System Administrator",
            "hashed_password": hash_password(admin_password),
            "role": "admin",
            "is_active": True,
            "teacher_code": admin_code,
            "encryption_salt": None,
        }).execute()
        print(f"   ✅ Admin created! ID: {new_user.data[0]['id']}")
    except Exception as e:
        print(f"   ⚠️  Could not create via REST: {e}")
        print("   ℹ️  You can create admin manually via SQL Editor:")
        print(f"""
INSERT INTO users (email, full_name, hashed_password, role, teacher_code, is_active)
VALUES (
    '{admin_email}',
    'System Administrator',
    '{hash_password(admin_password)}',
    'admin',
    '{admin_code}',
    true
);
""")

# Create sample teacher
teacher_email = "teacher@darsak.ai"
teacher_password = "Teacher@123456"
teacher_code = "TCH-SAMPLE01"

print(f"\n‍🏫 Creating sample teacher...")
print(f"   Email: {teacher_email}")
print(f"   Password: {teacher_password}")

existing = client.table("users").select("*").eq("email", teacher_email).execute()
if existing.data:
    print("   ⏭️  Teacher already exists, skipping...")
    teacher_id = existing.data[0]["id"]
else:
    try:
        new_teacher = client.table("users").insert({
            "email": teacher_email,
            "full_name": "أحمد محمد (مدرس تجريبي)",
            "hashed_password": hash_password(teacher_password),
            "role": "teacher",
            "is_active": True,
            "teacher_code": teacher_code,
        }).execute()
        teacher_id = new_teacher.data[0]["id"]
        print(f"   ✅ Teacher created! ID: {teacher_id}")
    except Exception as e:
        print(f"   ⚠️  Could not create via REST: {e}")
        teacher_id = None

# Create sample students if teacher was created
if teacher_id:
    print(f"\n👨‍ Creating sample students...")
    existing_students = client.table("students").select("*").eq("teacher_id", teacher_id).execute()
    if existing_students.data:
        print(f"   ⏭️  {len(existing_students.data)} students already exist, skipping...")
    else:
        students_data = [
            {"code": "STU-001", "full_name": "محمد أحمد", "phone": "01012345678", "grade_level": "3rd Prep"},
            {"code": "STU-002", "full_name": "فاطمة علي", "phone": "01098765432", "grade_level": "3rd Prep"},
            {"code": "STU-003", "full_name": "عمر حسن", "phone": "01055556666", "grade_level": "2nd Secondary"},
        ]
        try:
            for s in students_data:
                client.table("students").insert({
                    **s,
                    "teacher_id": teacher_id,
                    "pin_hash": hash_password("1234"),
                }).execute()
            print(f"   ✅ {len(students_data)} students created!")
        except Exception as e:
            print(f"   ⚠️  Could not create students: {e}")

# Create sample group
if teacher_id:
    print(f"\n📚 Creating sample group...")
    existing_groups = client.table("groups").select("*").eq("teacher_id", teacher_id).execute()
    if existing_groups.data:
        print(f"   ⏭️  {len(existing_groups.data)} groups already exist, skipping...")
    else:
        try:
            client.table("groups").insert({
                "teacher_id": teacher_id,
                "name": "مجموعة الرياضيات - مساء",
                "subject": "math",
                "level": "preparatory",
                "day_of_week": "Saturday",
                "time_slot": "18:00-20:00",
            }).execute()
            print("   ✅ Group created!")
        except Exception as e:
            print(f"   ️  Could not create group: {e}")

# Summary
print("\n" + "="*50)
print("📊 Database Summary:")
print("="*50)

for table in ["users", "students", "groups", "attendances", "grades", "invoices", "encrypted_payloads", "audit_logs"]:
    try:
        result = client.table(table).select("*", count="exact").execute()
        print(f"   {table}: {result.count} records")
    except Exception as e:
        print(f"   {table}: error - {str(e)[:50]}")

print("\n" + "="*50)
print("🔐 Login Credentials:")
print("="*50)
print(f"   Admin:    {admin_email} / {admin_password}")
print(f"   Teacher:  {teacher_email} / {teacher_password}")
print(f"   Student PIN: 1234 (for all sample students)")
print("\n⚠️  Change these passwords in production!")
print("="*50)
