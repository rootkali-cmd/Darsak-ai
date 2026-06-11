import requests

BASE_URL = "http://localhost:8000"
ACCESS_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
TIMEOUT = 30

def test_get_apiv1authme_with_valid_access_token():
    url = f"{BASE_URL}/api/v1/auth/me"
    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}"
    }
    try:
        response = requests.get(url, headers=headers, timeout=TIMEOUT)
    except requests.RequestException as e:
        assert False, f"Request failed: {e}"

    assert response.status_code == 200, f"Expected status code 200, got {response.status_code}"
    try:
        data = response.json()
    except ValueError:
        assert False, "Response is not valid JSON"

    # Check required fields presence and types
    expected_fields = {
        "id": str,
        "email": str,
        "full_name": str,
        "role": str,
        "teacher_code": str,
        "is_active": bool,
        "onboarding_completed": bool,
        "subjects": list,
        "levels": list,
        "created_at": str,
        "telegram_channel_id": (str, type(None))
    }

    for field, field_type in expected_fields.items():
        assert field in data, f"Missing field '{field}' in response"
        value = data[field]
        if isinstance(field_type, tuple):
            assert any(isinstance(value, t) for t in field_type), f"Field '{field}' expected types {field_type}, got {type(value)}"
        else:
            assert isinstance(value, field_type), f"Field '{field}' expected type {field_type}, got {type(value)}"

test_get_apiv1authme_with_valid_access_token()