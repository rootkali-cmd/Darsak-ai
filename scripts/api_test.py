import httpx, json

base = 'https://darsak-backend.fly.dev/api'

# Test app status
r = httpx.get(f'{base}/app-status', timeout=10)
print(f'1. App Status: {r.status_code}')
d = r.json()
print(f'   Student: v{d.get("student_version")} | Teacher: v{d.get("teacher_version")}')

# Test versions endpoints
r2 = httpx.get(f'{base}/versions/android', timeout=10)
print(f'2. Versions/android: {r2.status_code} {r2.text[:150]}')

r3 = httpx.get(f'{base}/versions/android-student', timeout=10)
print(f'3. Versions/android-student: {r3.status_code} {r3.text[:150]}')

# Test student login with bad code (should be 401)
r4 = httpx.post(f'{base}/students/login', json={'code': 'NONEXIST', 'pin': '123456'}, timeout=10)
print(f'4. Student login bad code: {r4.status_code} {r4.text[:100]}')

# Test teacher login with bad creds
r5 = httpx.post(f'{base}/auth/login', json={'email': 'nonexist@test.com', 'password': 'wrong'}, timeout=10)
print(f'5. Teacher login bad creds: {r5.status_code} {r5.text[:100]}')

# Test register + full flow
r6 = httpx.post(f'{base}/auth/register', json={
    'email': 'test_audit_flow2@example.com',
    'password': 'TestPass123!',
    'full_name': 'Audit Test 2',
    'role': 'teacher',
}, timeout=15)
print(f'6. Register: {r6.status_code}')

if r6.status_code == 201:
    r7 = httpx.post(f'{base}/auth/login', json={'email': 'test_audit_flow2@example.com', 'password': 'TestPass123!'}, timeout=10)
    print(f'7. Login: {r7.status_code}')
    if r7.status_code == 200:
        token = r7.json().get('access_token')
        headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

        # Test student create
        r8 = httpx.post(f'{base}/students/', json={'full_name': 'Test Student', 'pin': 'ABC123'}, headers=headers, timeout=10)
        print(f'8. Create student: {r8.status_code} {r8.text[:150]}')

        # Test get dashboard
        r9 = httpx.get(f'{base}/dashboard/stats', headers=headers, timeout=10)
        print(f'9. Dashboard stats: {r9.status_code} {r9.text[:150]}')

        # Test exams list
        r10 = httpx.get(f'{base}/exams', headers=headers, timeout=10)
        print(f'10. Exams list: {r10.status_code}')

        # Test subscriptions my
        r11 = httpx.get(f'{base}/subscriptions/my', headers=headers, timeout=10)
        print(f'11. Subscriptions/my: {r11.status_code} {r11.text[:150]}')

        # Test get me
        r12 = httpx.get(f'{base}/auth/me', headers=headers, timeout=10)
        print(f'12. Auth/me: {r12.status_code} {r12.text[:200]}')

        # Test invoices stats
        r13 = httpx.get(f'{base}/invoices/stats', headers=headers, timeout=10)
        print(f'13. Invoices stats: {r13.status_code}')

        # Test grades list
        r14 = httpx.get(f'{base}/grades', headers=headers, timeout=10)
        print(f'14. Grades list: {r14.status_code}')

        # Test attendance list
        r15 = httpx.get(f'{base}/attendance', headers=headers, timeout=10)
        print(f'15. Attendance list: {r15.status_code}')

        # Test students list
        r16 = httpx.get(f'{base}/students/', headers=headers, timeout=10)
        print(f'16. Students list: {r16.status_code}')
        print(f'    Students count: {len(r16.json()) if r16.status_code == 200 else "error"}')

        # Test available exams (student)
        r17 = httpx.get(f'{base}/exams/available', headers=headers, timeout=10)
        print(f'17. Exams available: {r17.status_code}')

        # Test verify teacher
        r18 = httpx.post(f'{base}/students/verify-teacher', json={'teacher_code': 'TEST'}, timeout=10)
        print(f'18. Verify teacher: {r18.status_code} {r18.text[:100]}')

        # Test CORS preflight
        r19 = httpx.options(f'{base}/auth/login', headers={
            'Origin': 'http://localhost:3000',
            'Access-Control-Request-Method': 'POST',
        }, timeout=10)
        print(f'19. CORS preflight: {r19.status_code}')

        # Test payments config
        r20 = httpx.get(f'{base}/payments/config', headers=headers, timeout=10)
        print(f'20. Payments config: {r20.status_code} {r20.text[:150]}')

print('\nDone!')
