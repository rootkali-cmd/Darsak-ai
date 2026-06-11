import requests

def test_post_apiv1_auth_login_with_valid_credentials():
    base_url = "http://localhost:8000"
    url = f"{base_url}/api/v1/auth/login"
    payload = {
        "email": "user@example.com",
        "password": "correctpassword"
    }
    headers = {
        "Content-Type": "application/json"
    }
    timeout = 30
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=timeout)
        assert response.status_code == 200, f"Unexpected status code: {response.status_code}, Response: {response.text}"
        json_response = response.json()
        assert "access_token" in json_response, "access_token missing in response"
        assert isinstance(json_response["access_token"], str) and json_response["access_token"], "Invalid access_token"
        assert "refresh_token" in json_response, "refresh_token missing in response"
        assert isinstance(json_response["refresh_token"], str) and json_response["refresh_token"], "Invalid refresh_token"
        assert "token_type" in json_response, "token_type missing in response"
        assert json_response["token_type"].lower() == "bearer", f"token_type is not 'bearer': {json_response['token_type']}"
    except requests.RequestException as e:
        raise AssertionError(f"Request failed: {e}")

test_post_apiv1_auth_login_with_valid_credentials()