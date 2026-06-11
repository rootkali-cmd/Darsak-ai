import requests
import datetime

BASE_URL = "http://localhost:8000"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}
TIMEOUT = 30

def test_post_apiv1attendancebarcode_mark_attendance_by_barcode():
    student_id = None
    student_code = None
    try:
        # Step 1: Create a new student to get a valid barcode (assuming barcode = code)
        # Create student with at least full_name; code is optional, lets provide to guarantee barcode
        student_data = {
            "full_name": "Test Student Barcode",
            "code": None  # Let backend generate code; read code from response
        }
        resp_create = requests.post(
            f"{BASE_URL}/api/v1/students/",
            json=student_data,
            headers=HEADERS,
            timeout=TIMEOUT
        )
        assert resp_create.status_code == 200, f"Failed to create student: {resp_create.text}"
        student = resp_create.json()
        student_id = student.get("id")
        assert student_id, "Created student has no id"
        student_code = student.get("code")
        assert student_code, "Created student has no student code for barcode"

        # Step 2: Use the student_code as barcode to mark attendance via barcode
        resp_attendance = requests.post(
            f"{BASE_URL}/api/v1/attendance/barcode",
            json={"barcode": student_code},
            headers=HEADERS,
            timeout=TIMEOUT
        )
        assert resp_attendance.status_code == 200, f"Failed to mark attendance by barcode: {resp_attendance.text}"
        attendance_record = resp_attendance.json()
        # Validate attendance record fields
        # Must include at least: student_id matches, date is today, status is "present"
        assert attendance_record.get("student_id") == student_id, "Attendance record student_id mismatch"
        date_str = attendance_record.get("date")
        assert date_str, "Attendance record missing date field"
        today_str = datetime.date.today().isoformat()
        assert date_str == today_str, f"Attendance date {date_str} is not today {today_str}"
        status = attendance_record.get("status")
        assert status == "present", f"Attendance status is not 'present', got '{status}'"

        # Optional: Verify attendance can be listed by student_id and matches this record
        resp_list = requests.get(
            f"{BASE_URL}/api/v1/attendance/",
            params={"student_id": student_id},
            headers=HEADERS,
            timeout=TIMEOUT
        )
        assert resp_list.status_code == 200, f"Failed to list attendance by student_id: {resp_list.text}"
        attendance_list = resp_list.json().get("data")
        assert attendance_list and any(
            rec.get("date") == today_str and rec.get("status") == "present" for rec in attendance_list
        ), "Today's attendance record with 'present' status not found in attendance list"

        # Additional backend coverage: call other backend endpoints to check errors/security/missing validation:

        # Auth Me endpoint
        resp_me = requests.get(f"{BASE_URL}/api/v1/auth/me", headers=HEADERS, timeout=TIMEOUT)
        assert resp_me.status_code == 200, "Auth/me endpoint failed"
        me_data = resp_me.json()
        assert "email" in me_data, "Auth/me missing email in profile"

        # List students
        resp_students = requests.get(f"{BASE_URL}/api/v1/students/", headers=HEADERS, timeout=TIMEOUT)
        assert resp_students.status_code == 200, "List students endpoint failed"
        students_data = resp_students.json().get("data")
        assert isinstance(students_data, list), "Students data is not a list"

        # List groups (coverage)
        resp_groups = requests.get(f"{BASE_URL}/api/v1/groups/", headers=HEADERS, timeout=TIMEOUT)
        assert resp_groups.status_code == 200, "List groups endpoint failed"
        groups_data = resp_groups.json().get("data")
        assert isinstance(groups_data, list), "Groups data is not a list"

        # Attendance stats
        resp_stats = requests.get(f"{BASE_URL}/api/v1/attendance/stats", headers=HEADERS, timeout=TIMEOUT)
        assert resp_stats.status_code == 200, "Attendance stats endpoint failed"
        stats_data = resp_stats.json()
        assert all(k in stats_data for k in ("present", "absent", "late")), "Attendance stats missing keys"

        # Grades list with limit 10 (coverage)
        resp_grades = requests.get(f"{BASE_URL}/api/v1/grades/", headers=HEADERS, params={"limit": 10}, timeout=TIMEOUT)
        assert resp_grades.status_code == 200, "Grades list endpoint failed"
        grades_data = resp_grades.json().get("data")
        assert isinstance(grades_data, list), "Grades data is not a list"

        # Invoices stats (coverage)
        resp_inv_stats = requests.get(f"{BASE_URL}/api/v1/invoices/stats", headers=HEADERS, timeout=TIMEOUT)
        assert resp_inv_stats.status_code == 200, "Invoices stats endpoint failed"

        # Exams list (coverage)
        resp_exams = requests.get(f"{BASE_URL}/api/v1/exams/", headers=HEADERS, timeout=TIMEOUT)
        assert resp_exams.status_code == 200, "Exams list endpoint failed"
        exams_data = resp_exams.json().get("data")
        assert isinstance(exams_data, list), "Exams data is not a list"

        # Lessons list (coverage)
        resp_lessons = requests.get(f"{BASE_URL}/api/v1/lessons/", headers=HEADERS, timeout=TIMEOUT)
        assert resp_lessons.status_code == 200, "Lessons list endpoint failed"

        # Subscriptions plans (coverage)
        resp_sub_plans = requests.get(f"{BASE_URL}/api/v1/subscriptions/plans", headers=HEADERS, timeout=TIMEOUT)
        assert resp_sub_plans.status_code == 200, "Subscriptions plans endpoint failed"

        # Dashboard stats (coverage)
        resp_dash = requests.get(f"{BASE_URL}/api/v1/dashboard/stats", headers=HEADERS, timeout=TIMEOUT)
        assert resp_dash.status_code == 200, "Dashboard stats endpoint failed"
        dash_data = resp_dash.json()
        required_keys = {"students", "groups", "today_attendance", "pending_invoices", "active_exams"}
        assert all(k in dash_data for k in required_keys), "Dashboard stats missing keys"

    finally:
        # Cleanup - delete created student
        if student_id:
            resp_del = requests.delete(
                f"{BASE_URL}/api/v1/students/{student_id}",
                headers=HEADERS,
                timeout=TIMEOUT
            )
            # Deletion may return 200 with deleted true or 404 if already gone - ignore errors but report if failed
            if resp_del.status_code != 200:
                print(f"Warning: Failed to delete student {student_id}: {resp_del.status_code} {resp_del.text}")
            else:
                resp_json = resp_del.json()
                if not resp_json.get("deleted", False):
                    print(f"Warning: Student deletion returned deleted=false: {resp_del.text}")

test_post_apiv1attendancebarcode_mark_attendance_by_barcode()