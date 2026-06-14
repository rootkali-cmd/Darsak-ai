import requests
from requests.exceptions import RequestException

BASE_URL = "https://darsak-backend.fly.dev"
REFRESH_ENDPOINT = "/api/v1/auth/refresh"
LOGIN_ENDPOINT = "/api/v1/auth/login"
ME_ENDPOINT = "/api/v1/auth/me"

TIMEOUT = 30


def test_post_apiv1authrefresh_with_valid_refresh_token():
    # Test user registration and login to obtain a valid refresh token
    register_url = BASE_URL + "/api/v1/auth/register"
    login_url = BASE_URL + LOGIN_ENDPOINT
    refresh_url = BASE_URL + REFRESH_ENDPOINT
    me_url = BASE_URL + ME_ENDPOINT

    test_email = "testuser_tc004@example.com"
    test_full_name = "Test User TC004"
    test_password = "StrongP@ssword123"

    headers_json = {"Content-Type": "application/json"}

    # Register user
    register_payload = {
        "email": test_email,
        "full_name": test_full_name,
        "password": test_password
    }

    try:
        register_resp = requests.post(
            register_url, json=register_payload, headers=headers_json, timeout=TIMEOUT
        )
        # It may be that user already exists from previous run, so accept 200 or 409 or similar
        assert register_resp.status_code in (200, 400, 409), f"Unexpected status code on register: {register_resp.status_code}"
        if register_resp.status_code == 200:
            reg_data = register_resp.json()
            assert isinstance(reg_data.get("id"), str), "Expected id in registration response"
            # Registration success

        # Login to get tokens
        login_payload = {
            "email": test_email,
            "password": test_password
        }
        login_resp = requests.post(login_url, json=login_payload, headers=headers_json, timeout=TIMEOUT)
        assert login_resp.status_code == 200, f"Login failed with status {login_resp.status_code}"
        login_data = login_resp.json()
        assert "access_token" in login_data and isinstance(login_data["access_token"], str)
        assert "refresh_token" in login_data and isinstance(login_data["refresh_token"], str)
        assert login_data.get("token_type", "").lower() == "bearer"

        valid_refresh_token = login_data["refresh_token"]

        # Use refresh token to get new tokens
        refresh_payload = {
            "refresh_token": valid_refresh_token
        }
        refresh_resp = requests.post(refresh_url, json=refresh_payload, headers=headers_json, timeout=TIMEOUT)
        assert refresh_resp.status_code == 200, f"Refresh token failed with status {refresh_resp.status_code}"
        refresh_data = refresh_resp.json()
        assert "access_token" in refresh_data and isinstance(refresh_data["access_token"], str)
        assert "refresh_token" in refresh_data and isinstance(refresh_data["refresh_token"], str)
        assert refresh_data.get("token_type", "").lower() == "bearer"

        new_access_token = refresh_data["access_token"]

        # Use new access token to get current user profile
        me_headers = {"Authorization": f"Bearer {new_access_token}"}
        me_resp = requests.get(me_url, headers=me_headers, timeout=TIMEOUT)
        assert me_resp.status_code == 200, f"/auth/me failed with status {me_resp.status_code}"
        me_data = me_resp.json()
        # Validate expected fields in profile
        expected_fields = [
            "id", "email", "full_name", "role", "teacher_code", "is_active",
            "onboarding_completed", "subjects", "levels", "created_at", "telegram_channel_id"
        ]
        for field in expected_fields:
            assert field in me_data, f"Missing '{field}' in /auth/me response"

        assert me_data["email"].lower() == test_email.lower()

    except RequestException as e:
        raise AssertionError(f"HTTP request failed: {e}") from e


test_post_apiv1authrefresh_with_valid_refresh_token()
