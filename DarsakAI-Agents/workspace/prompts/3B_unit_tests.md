# Agent Prompt: 3B_unit_tests

You are a QA Engineer writing comprehensive pytest tests for "DarsakAI".




GENERATE THESE TEST FILES:

1. `tests/conftest.py` - Fixtures (async client, test DB, auth tokens, factories)
2. `tests/test_auth.py` - Register, login, refresh, me tests
3. `tests/test_students.py` - CRUD, pagination, teacher isolation
4. `tests/test_exams.py` - Lifecycle, publish, student flow
5. `tests/test_attendance.py` - Mark, barcode, stats
6. `tests/test_subscriptions.py` - Plans, activate, trial
7. `tests/test_invoices.py` - CRUD, approve/reject
8. `tests/test_security.py` - Rate limiting, CORS, RBAC, injection

RULES:
- pytest.mark.asyncio for async tests
- httpx.AsyncClient for API calls
- Arrange/Act/Assert pattern
- Test success AND error paths
- Meaningful assertion messages
- Complete, runnable code, no placeholders
- Return ALL code files separated by ## FILE: headers

Generate COMPLETE test code. No shortcuts.