import requests
import uuid

BASE_URL = "http://localhost:8000"
API_PREFIX = "/api/v1"
TIMEOUT = 30
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def test_get_apiv1students_list_students():
    """
    Test listing all students for the authenticated teacher with optional search and pagination parameters.
    Verify response returns an array of student objects.
    If no student exists, create one and delete after test.
    """
    student_id = None
    created_student = None

    # Helper: Create a student
    def create_student():
        url = f"{BASE_URL}{API_PREFIX}/students/"
        payload = {
            "full_name": "Test Student for List",
        }
        try:
            resp = requests.post(url, json=payload, headers=HEADERS, timeout=TIMEOUT)
        except Exception as e:
            raise AssertionError(f"Failed to create student: {e}")
        assert resp.status_code == 200, f"Failed to create student: {resp.status_code} {resp.text}"
        data = resp.json()
        assert isinstance(data, dict), f"Create student response not an object: {data}"
        assert "id" in data, "Create student response missing 'id'"
        return data

    # Helper: Delete a student by id
    def delete_student(student_id: str):
        url = f"{BASE_URL}{API_PREFIX}/students/{student_id}"
        try:
            resp = requests.delete(url, headers=HEADERS, timeout=TIMEOUT)
        except Exception as e:
            raise AssertionError(f"Failed to delete student {student_id}: {e}")
        assert resp.status_code == 200, f"Failed to delete student {student_id}: {resp.status_code} {resp.text}"
        data = resp.json()
        # The delete student response schema: {"deleted": boolean}
        assert "deleted" in data, "Delete student response missing 'deleted'"
        assert data["deleted"] is True, f"Delete student returned deleted={data['deleted']}"

    # Step 1: Try to list students first
    url = f"{BASE_URL}{API_PREFIX}/students/"
    params = {
        "limit": 10,
        "offset": 0,
    }
    try:
        resp = requests.get(url, headers=HEADERS, params=params, timeout=TIMEOUT)
    except Exception as e:
        raise AssertionError(f"Failed to list students: {e}")

    # If unauthorized or forbidden, raise error
    if resp.status_code == 401:
        raise AssertionError("Unauthorized: Invalid or expired token")
    if resp.status_code == 403:
        raise AssertionError("Forbidden: Access denied")

    if resp.status_code == 200:
        json_data = resp.json()
        # Expect response_schema: 200: { "data": array of student objects }
        assert "data" in json_data, "'data' key not in response"
        students_list = json_data["data"]
        assert isinstance(students_list, list), f"'data' is not a list: {type(students_list)}"

        # If the list is empty, create one student for testing
        if not students_list:
            created_student = create_student()
            student_id = created_student["id"]

            # After create, call list students again with search, limit, offset
            try:
                resp = requests.get(url, headers=HEADERS, params=params, timeout=TIMEOUT)
            except Exception as e:
                # Cleanup before raising
                delete_student(student_id)
                raise AssertionError(f"Failed to list students after creating one: {e}")

            assert resp.status_code == 200, f"List students failed after create: {resp.status_code} {resp.text}"
            json_data = resp.json()
            assert "data" in json_data, "'data' key missing after create"
            students_list = json_data["data"]
            assert isinstance(students_list, list), "'data' not a list after create"

        # Validate the contents of returned student objects
        for student in students_list:
            assert isinstance(student, dict), f"Student item is not an object: {student}"
            # Validate expected keys presence, minimal keys as per PRD e.g., id, full_name, code, teacher_id may exist
            assert "id" in student, "Student object missing 'id'"
            assert isinstance(student["id"], str), "'id' is not a string"
            # full_name should be present and a string of length >= 2 (per create student validation)
            assert "full_name" in student, "Student object missing 'full_name'"
            assert isinstance(student["full_name"], str), "'full_name' is not a string"
            assert len(student["full_name"]) >= 2, "'full_name' too short"

        # Test pagination and search param by filtering with a substring of full_name if any students returned
        if students_list:
            first_student = students_list[0]
            search_term = first_student["full_name"][:3]
            params_search = {
                "search": search_term,
                "limit": 5,
                "offset": 0,
            }
            try:
                resp_search = requests.get(url, headers=HEADERS, params=params_search, timeout=TIMEOUT)
            except Exception as e:
                if created_student:
                    delete_student(student_id)
                raise AssertionError(f"Failed to list students with search params: {e}")
            assert resp_search.status_code == 200, f"List students search failed: {resp_search.status_code} {resp_search.text}"
            json_search = resp_search.json()
            assert "data" in json_search, "'data' missing in search response"
            search_results = json_search["data"]
            assert isinstance(search_results, list), "'data' not list in search response"
            # Assert that each student's full_name contains the search term (case-insensitive)
            for s in search_results:
                assert "full_name" in s and isinstance(s["full_name"], str)
                assert search_term.lower() in s["full_name"].lower()

    else:
        raise AssertionError(f"Unexpected status code on list students: {resp.status_code} {resp.text}")

    # Cleanup - delete created student if exists
    if created_student and student_id:
        delete_student(student_id)


test_get_apiv1students_list_students()