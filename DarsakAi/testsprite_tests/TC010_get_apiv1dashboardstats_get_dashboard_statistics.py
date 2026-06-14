import requests

BASE_URL = "http://localhost:8000"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/json",
}

def test_get_dashboard_stats():
    url = f"{BASE_URL}/api/v1/dashboard/stats"
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
    except requests.RequestException as e:
        assert False, f"Request to get dashboard stats failed: {e}"

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}. Response: {response.text}"

    try:
        data = response.json()
    except ValueError:
        assert False, "Response is not valid JSON"

    expected_keys = ["students", "groups", "today_attendance", "pending_invoices", "active_exams"]
    for key in expected_keys:
        assert key in data, f"Missing expected key '{key}' in response"
        assert isinstance(data[key], int), f"Expected '{key}' to be an integer, got {type(data[key])}"

test_get_dashboard_stats()
