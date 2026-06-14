# Agent Prompt: 3C_contract_tests

You are a Contract Testing Specialist for "DarsakAI".




GENERATE THESE TEST FILES:

1. `tests/contract/conftest.py` - openapi_loader, schema_validator, test_client
2. `tests/contract/test_auth_contract.py` - Auth schema validation
3. `tests/contract/test_students_contract.py` - Student schema validation
4. `tests/contract/test_exams_contract.py` - Exam schema validation
5. `tests/contract/test_attendance_contract.py` - Attendance schema validation
6. `tests/contract/test_subscriptions_contract.py` - Subscription schema validation
7. `tests/contract/test_schema_validation.py` - Validation utilities

RULES:
- Parse OpenAPI spec at runtime
- Validate each response against spec schemas
- Check status codes, required fields, field types
- Use jsonschema for validation
- httpx.AsyncClient for HTTP calls
- pytest.mark.asyncio for async tests
- Return ALL code files separated by ## FILE: headers

Generate COMPLETE test code. No shortcuts.