import requests
import uuid

BASE_URL = "http://localhost:8000"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}
TIMEOUT = 30


def test_post_apiv1students_create_new_student():
    url = f"{BASE_URL}/api/v1/students/"
    # Prepare payload with required and optional fields
    payload = {
        "full_name": "Test Student " + str(uuid.uuid4()),  # Unique full_name to avoid duplicates
        "parent_phone": "+201001234567",
        # No group_id provided as optional, no code provided to test auto-generation
        "pin": "1234"  # Note: API expects bcrypt hashed pin, but test sending plain to cover hashing
    }

    created_student_id = None
    try:
        # POST to create new student
        response = requests.post(url, headers=HEADERS, json=payload, timeout=TIMEOUT)
        assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}: {response.text}"
        student = response.json()
        # Validate required fields in response
        assert "id" in student and student["id"], "Student ID missing in response"
        created_student_id = student["id"]
        assert student.get("full_name") == payload["full_name"], "Full_name mismatch"
        # Code should be auto-generated if not provided, and start with 'STU-'
        assert "code" in student and student["code"].startswith("STU-"), "Student code missing or invalid"
        # Pin should not be returned raw, assume hashed pin is returned or omitted
        # So verify pin field exists and is a non-empty string if present
        if "pin" in student:
            assert isinstance(student["pin"], str) and len(student["pin"]) > 0, "Pin field invalid"
        # Teacher ID should be present
        assert "teacher_id" in student and student["teacher_id"], "Teacher ID missing in response"
    finally:
        # Cleanup: delete the created student to maintain test isolation
        if created_student_id:
            del_url = f"{BASE_URL}/api/v1/students/{created_student_id}"
            try:
                del_response = requests.delete(del_url, headers=HEADERS, timeout=TIMEOUT)
                assert del_response.status_code == 200, f"Cleanup failed: delete student status {del_response.status_code}"
                deleted_result = del_response.json()
                assert deleted_result.get("deleted") is True, "Deleted flag not true on cleanup"
            except Exception as e:
                print(f"Failed to delete student during cleanup: {e}")


test_post_apiv1students_create_new_student()