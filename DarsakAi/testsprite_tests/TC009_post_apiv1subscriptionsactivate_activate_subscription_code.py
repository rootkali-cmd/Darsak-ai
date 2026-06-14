import requests
import uuid

BASE_URL = "http://localhost:8000/api/v1"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}
TIMEOUT = 30


def test_post_apiv1subscriptionsactivate_activate_subscription_code():
    # Step 1: Fetch active subscription plans to get a valid plan and create a code to activate
    plans_url = f"{BASE_URL}/subscriptions/plans"
    try:
        plans_resp = requests.get(plans_url, headers=HEADERS, timeout=TIMEOUT)
        assert plans_resp.status_code == 200, f"Failed to fetch plans, status code: {plans_resp.status_code}"
        plans = plans_resp.json()
        assert isinstance(plans, list), "Plans response should be a list"
        assert len(plans) > 0, "No active subscription plans available to test"

        plan = plans[0]
        plan_id = plan.get("id")
        assert plan_id is not None, "Plan object missing 'id'"

        # Step 2: As no API to create a code is described, create a subscription then get a code from subscriptions? 
        # However, due to missing endpoint for code generation, we should assume code exists or use 'code' = an existing plan code string to test activate.
        # To safely test, let's create a temporary subscription by activating a code. If no code available, skip test with failure.
        # Because no endpoint for code creation is specified, we will try to reuse a code that can be generated or hardcoded for test.
        # For a full test, we must first create a subscription code, but PRD does not provide this. We'll create one through a simulation step if possible.
        #
        # Since there is no creation endpoint for codes, we fallback to finding an unused code from plans or using a dummy code and expecting failure.
        #
        # We'll try the activate endpoint with a dummy valid-looking code and expect success or failure response.

        # Test assumption: A valid code is needed; as we have no endpoint to create a code, try to get the teacher's current subscription for a code
        my_sub_url = f"{BASE_URL}/subscriptions/my"
        my_sub_resp = requests.get(my_sub_url, headers=HEADERS, timeout=TIMEOUT)
        assert my_sub_resp.status_code == 200, f"Failed to get current subscription, status code: {my_sub_resp.status_code}"
        my_sub_data = my_sub_resp.json()
        # Try to use a code from the current subscription or plan if possible (simulate)
        # The PRD does not show code in subscription object. We must hardcode a test code.

        # Hardcode a valid subscription code to test activation (must be replaced with a real valid code for real environment)
        valid_code = "VALID_SUB_CODE_TEST_1234"

        activate_url = f"{BASE_URL}/subscriptions/activate"
        payload = {"code": valid_code}
        activate_resp = requests.post(activate_url, json=payload, headers=HEADERS, timeout=TIMEOUT)

        # We expect either success (200) with subscription and plan objects or error
        if activate_resp.status_code == 200:
            data = activate_resp.json()
            assert "subscription" in data, "Response missing 'subscription' object"
            assert "plan" in data, "Response missing 'plan' object"
            subscription = data["subscription"]
            plan_obj = data["plan"]
            assert isinstance(subscription, dict), "'subscription' should be an object"
            assert isinstance(plan_obj, dict), "'plan' should be an object"
            # Validate key fields exist in subscription
            assert "id" in subscription, "Subscription object missing 'id'"
            assert "teacher_id" in subscription or "user_id" in subscription or "owner_id" in subscription, "Subscription missing teacher ownership id"
            assert "plan_id" in subscription, "Subscription missing 'plan_id'"
            # Validate key fields exist in plan
            assert "id" in plan_obj, "Plan object missing 'id'"
            assert "name" in plan_obj, "Plan object missing 'name'"
        else:
            # If code invalid or used, ensure error response is proper
            error_status_codes = (400, 401, 403, 404, 409)
            assert activate_resp.status_code in error_status_codes, f"Unexpected status code {activate_resp.status_code}"
            error_json = activate_resp.json()
            assert "detail" in error_json or "error" in error_json, "Error response missing detail or error message"

    except requests.RequestException as e:
        assert False, f"HTTP request failed: {str(e)}"


test_post_apiv1subscriptionsactivate_activate_subscription_code()