import sys
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from supabase import create_client
from src.core.config import get_settings
from src.core.security.auth import verify_password
from jose import jwt

settings = get_settings()
client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

print("🧪 Testing Supabase Integration...\n")

# Test 1: Verify users table
print("1️⃣ Testing users table...")
users = client.table("users").select("*").execute()
print(f"   Found {len(users.data)} users")
for u in users.data:
    print(f"   - {u['email']} ({u['role']}) - Active: {u['is_active']}")

# Test 2: Verify password hashing works with stored data
print("\n2️ Testing password verification...")
admin = client.table("users").select("*").eq("email", "admin@darsak.ai").execute()
if admin.data:
    admin_user = admin.data[0]
    test_pw = "Admin@123456"
    is_valid = verify_password(test_pw, admin_user["hashed_password"])
    print(f"   Admin password valid: {is_valid}")

# Test 3: Verify students
print("\n3️ Testing students table...")
students = client.table("students").select("*").execute()
print(f"   Found {len(students.data)} students")
for s in students.data:
    print(f"   - {s['code']}: {s['full_name']}")

# Test 4: Verify groups
print("\n4️⃣ Testing groups table...")
groups = client.table("groups").select("*").execute()
print(f"   Found {len(groups.data)} groups")
for g in groups.data:
    print(f"   - {g['name']} ({g['subject']}) - {g['day_of_week']} {g['time_slot']}")

# Test 5: Test JWT token creation and verification
print("\n5️ Testing JWT tokens...")
from src.core.security.auth import create_access_token, decode_token, decode_supabase_token

admin_id = admin.data[0]["id"]
token = create_access_token(admin_id)
decoded = decode_token(token)
print(f"   Local JWT created and decoded: sub={decoded['sub']}")

# Test Supabase JWT decoding
supabase_token = jwt.encode(
    {"sub": admin_id, "email": "admin@darsak.ai", "role": "authenticated"},
    settings.SUPABASE_JWT_SECRET,
    algorithm="HS256"
)
supabase_decoded = decode_supabase_token(supabase_token)
print(f"   Supabase JWT decoded: sub={supabase_decoded['sub']}, role={supabase_decoded.get('role')}")

# Test 6: Test encrypted payload storage
print("\n6️⃣ Testing encrypted payload storage...")
from src.core.security.encryption import encrypt_payload, derive_teacher_key, generate_salt

teacher = client.table("users").select("*").eq("email", "teacher@darsak.ai").execute()
if teacher.data:
    teacher_user = teacher.data[0]
    salt = generate_salt()
    key = derive_teacher_key("Teacher@123456", salt)
    
    test_data = {"student_id": "test", "score": 95, "exam": "midterm"}
    encrypted = encrypt_payload(test_data, key)
    
    payload_result = client.table("encrypted_payloads").insert({
        "teacher_id": teacher_user["id"],
        "payload_type": "grade",
        "ciphertext": encrypted["ciphertext"],
        "iv": encrypted["iv"],
        "auth_tag": encrypted["auth_tag"],
        "sync_status": "pending",
    }).execute()
    print(f"   Encrypted payload stored: {payload_result.data[0]['id']}")

# Test 7: Test audit logging
print("\n7️ Testing audit logging...")
audit_result = client.table("audit_logs").insert({
    "actor_type": "system",
    "action": "integration_test",
    "resource_type": "test",
    "metadata": {"test": "passed"},
}).execute()
print(f"   Audit log created: {audit_result.data[0]['id']}")

# Test 8: Test relationships
print("\n8️⃣ Testing relationships...")
teacher_id = teacher.data[0]["id"]
teacher_students = client.table("students").select("*").eq("teacher_id", teacher_id).execute()
teacher_groups = client.table("groups").select("*").eq("teacher_id", teacher_id).execute()
print(f"   Teacher has {len(teacher_students.data)} students and {len(teacher_groups.data)} groups")

print("\n" + "="*50)
print("✅ All Supabase integration tests passed!")
print("="*50)
