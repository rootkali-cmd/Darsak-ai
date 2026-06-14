import requests
import uuid
import random
import string

BASE_URL = "https://darsak-backend.fly.dev"
REGISTER_ENDPOINT = "/api/v1/auth/register"
LOGIN_ENDPOINT = "/api/v1/auth/login"
SUBSCRIPTIONS_MY_ENDPOINT = "/api/v1/subscriptions/my"

TIMEOUT = 30


def test_post_apiv1authregister_with_valid_data():
    # Generate unique test data
    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    email = f"testteacher_{random_suffix}@example.com"
    full_name = "Test Teacher"
    password = "TestPass123!"

    register_payload = {
        "email": email,
        "full_name": full_name,
        "password": password
    }
    try:
        # Register new teacher account
        register_response = requests.post(
            f"{BASE_URL}{REGISTER_ENDPOINT}",
            json=register_payload,
            timeout=TIMEOUT
        )
        assert register_response.status_code == 200, f"Expected 200 OK, got {register_response.status_code}"
        register_data = register_response.json()

        # Validate expected fields in registration response
        required_fields = ["id", "email", "full_name", "role", "teacher_code", "is_active", "onboarding_completed"]
        for field in required_fields:
            assert field in register_data, f"Missing '{field}' in registration response"

        assert register_data["email"] == email, "Returned email does not match input"
        assert isinstance(register_data["teacher_code"], str) and register_data["teacher_code"].startswith("TCH-"), "Invalid teacher_code format"
        assert isinstance(register_data["onboarding_completed"], bool), "onboarding_completed should be boolean"

        # Login with the registered teacher credentials to get tokens
        login_payload = {
            "email": email,
            "password": password
        }
        login_response = requests.post(
            f"{BASE_URL}{LOGIN_ENDPOINT}",
            json=login_payload,
            timeout=TIMEOUT
        )
        assert login_response.status_code == 200, f"Expected 200 OK on login, got {login_response.status_code}"
        login_data = login_response.json()

        # Validate login response tokens
        token_fields = ["access_token", "refresh_token", "token_type"]
        for field in token_fields:
            assert field in login_data, f"Missing '{field}' in login response"
        assert login_data["token_type"].lower() == "bearer", "token_type should be 'bearer'"

        access_token = login_data["access_token"]
        headers = {"Authorization": f"Bearer {access_token}"}

        # Check current subscription for the newly registered user to confirm 30-day trial subscription created
        subscription_response = requests.get(
            f"{BASE_URL}{SUBSCRIPTIONS_MY_ENDPOINT}",
            headers=headers,
            timeout=TIMEOUT
        )
        assert subscription_response.status_code == 200, f"Expected 200 OK on subscription check, got {subscription_response.status_code}"
        subscription_data = subscription_response.json()

        # Validate subscription and plan presence
        assert "subscription" in subscription_data, "Missing 'subscription' key in subscription response"
        assert "plan" in subscription_data, "Missing 'plan' key in subscription response"

        # The subscription should not be None (30-day trial created)
        assert subscription_data["subscription"] is not None, "Expected a trial subscription to be created upon registration"

    except requests.RequestException as e:
        assert False, f"Request failed: {e}"


test_post_apiv1authregister_with_valid_data()
