import sys
import asyncio
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from httpx import AsyncClient, ASGITransport
from src.main import app

async def test_api():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        print("🧪 Testing DarsakAI API with Supabase...\n")

        # Test 1: Health check
        print("1️⃣ Health check...")
        r = await client.get("/health")
        assert r.status_code == 200
        print(f"   ✅ {r.json()}")

        # Test 2: Login as teacher
        print("\n2️ Teacher login...")
        r = await client.post("/api/auth/login", json={
            "email": "teacher@darsak.ai",
            "password": "Teacher@123456",
        })
        assert r.status_code == 200
        tokens = r.json()
        token = tokens["access_token"]
        print(f"   ✅ Logged in successfully")

        # Test 3: Get current user
        print("\n3️⃣ Get current user...")
        r = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        user = r.json()
        print(f"   ✅ User: {user['full_name']} ({user['role']})")

        # Test 4: List students
        print("\n4️⃣ List students...")
        r = await client.get("/api/students/", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        students = r.json()
        print(f"   ✅ Found {len(students)} students")
        for s in students:
            print(f"      - {s['code']}: {s['full_name']}")

        # Test 5: List groups
        print("\n5️⃣ List groups...")
        r = await client.get("/api/groups/", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        groups = r.json()
        print(f"   ✅ Found {len(groups)} groups")
        for g in groups:
            print(f"      - {g['name']} ({g['subject']})")

        # Test 6: Create a new grade
        print("\n6️ Create grade...")
        if students:
            r = await client.post("/api/grades/", json={
                "student_id": students[0]["id"],
                "exam_name": "اختبار تجريبي",
                "subject": "math",
                "score": 85,
                "max_score": 100,
            }, headers={"Authorization": f"Bearer {token}"})
            assert r.status_code == 201
            grade = r.json()
            print(f"   ✅ Grade created: {grade['exam_name']} - {grade['score']}/{grade['max_score']}")

        # Test 7: Grade stats
        print("\n7️⃣ Grade stats...")
        r = await client.get("/api/grades/stats?subject=math", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        stats = r.json()
        print(f"   ✅ Average: {stats['average']:.1f}%, Total: {stats['total']} grades")

        # Test 8: AI Analysis
        print("\n8️ AI Analysis...")
        if students:
            r = await client.post("/api/students/analyze", json={
                "student_id": students[0]["id"],
                "subject": "math",
                "grades": [
                    {"exam": "quiz1", "score": 85, "max_score": 100, "wrong_questions": [3, 7]},
                    {"exam": "quiz2", "score": 72, "max_score": 100, "wrong_questions": [1, 5, 9]},
                ],
            }, headers={"Authorization": f"Bearer {token}"})
            assert r.status_code == 200
            analysis = r.json()
            print(f"   ✅ AI Analysis completed")
            print(f"      Strengths: {len(analysis['strengths'])} items")
            print(f"      Weaknesses: {len(analysis['weaknesses'])} items")
            print(f"      Focus: {len(analysis['recommended_focus'])} items")

        # Test 9: QR Generation
        print("\n9️⃣ QR Generation...")
        r = await client.get(f"/api/qr/generate/{user['id']}", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        qr = r.json()
        print(f"   ✅ QR generated for {qr['teacher_code']}")
        print(f"      QR size: {len(qr['qr_base64'])} bytes")

        # Test 10: Attendance
        print("\n🔟 Mark attendance...")
        if students:
            r = await client.post("/api/attendance/", json={
                "student_id": students[0]["id"],
                "status": "present",
            }, headers={"Authorization": f"Bearer {token}"})
            assert r.status_code == 201
            attendance = r.json()
            print(f"   ✅ Attendance marked: {attendance['status']}")

        # Test 11: Attendance stats
        print("\n1️⃣1️ Attendance stats...")
        r = await client.get("/api/attendance/stats", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        stats = r.json()
        print(f"   ✅ Present: {stats['present']}, Absent: {stats['absent']}, Total: {stats['total']}")

        # Test 12: Invoice stats
        print("\n1️⃣2️ Invoice stats...")
        r = await client.get("/api/invoices/stats", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        stats = r.json()
        print(f"   ✅ Total: {stats['total_amount']}, Paid: {stats['paid_amount']}, Unpaid: {stats['unpaid_amount']}")

        # Test 13: Unauthorized access
        print("\n1️⃣3️⃣ Unauthorized access test...")
        r = await client.get("/api/students/")
        assert r.status_code in (401, 403)
        print(f"   ✅ Correctly blocked unauthorized access")

        print("\n" + "="*50)
        print("✅ All API integration tests passed!")
        print("="*50)

asyncio.run(test_api())
