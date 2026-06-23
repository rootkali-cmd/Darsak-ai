# CYBER-AGENT-3: Data Exposure & Privacy Audit

## Severity: HIGH
## Date: 2026-06-23
## Scope: Full-stack DarsakAI (Backend, Web Portal, Schemas, Security)

---

## Summary

This audit examines all data flows in DarsakAI for PII leakage, over-exposure, CORS misconfigurations, missing security headers, Sentry data leakage, frontend console.log exposure, and database queries returning excessive data. **12 findings** identified across the stack.

---

## Findings

### Finding 1: `SELECT *` on All Tables Returns Excessive Data Including Sensitive Fields

- **Location:** `backend/src/core/security/supabase_repo.py:109`
- **Data exposed:** `hashed_password`, `pin_hash`, `assistants_password_hash`, `parent_phone`, `phone`, `screenshot` (base64), `payment_transactions.phone_number`
- **Who can see it:** Any authenticated teacher via `list_students`, `get_student`, or any repo `.select()` call
- **Risk:** MEDIUM — `SupabaseRepository.select()` uses `SELECT *` universally. The `StudentResponse` Pydantic model does filter the output in most API endpoints, BUT the raw DB rows include `hashed_password`, `pin_hash`, `parent_phone`, and `phone`. Any code path that returns raw dicts (e.g. `_serialize_student()` in `students.py:84` includes `pin_hash` directly) leaks password hashes.
- **Fix:** Change `select()` to explicitly list columns, or add a `safe_columns` allowlist per table. Remove `pin_hash` from `_serialize_student()` output (line 92).

### Finding 2: `pin_hash` Leaked in Student API Responses

- **Location:** `backend/src/api/students.py:92`
- **Data exposed:** `pin_hash` (bcrypt hash of student PIN)
- **Who can see it:** Any authenticated teacher calling `GET /students/` or `GET /students/{id}`
- **Risk:** HIGH — The `_serialize_student()` function on line 84-97 explicitly includes `"pin_hash": s.get("pin_hash")`. While the `StudentResponse` model has `has_pin: bool` instead, the `_serialize_student()` dict is returned directly on `PUT /{student_id}` (line 201) bypassing the Pydantic model. This exposes bcrypt password hashes to the client.
- **Fix:** Remove `"pin_hash": s.get("pin_hash")` from `_serialize_student()`. The `has_pin` boolean is sufficient.

### Finding 3: Student Login Logs Leaked Student Codes in Plaintext

- **Location:** `backend/src/api/students.py:291,298,303,309`
- **Data exposed:** Student login codes (e.g., `ST1234567`)
- **Who can see it:** Server logs — accessible to anyone with log access (Fly.io dashboard, Sentry)
- **Risk:** MEDIUM — The student login endpoint logs `code=%s` with the sanitized code on every login attempt (success and failure). Student codes are authentication credentials. Logging them creates an attack surface if logs are compromised or forwarded to third-party services (Sentry, etc.).
- **Fix:** Remove or mask student codes from login log messages. Replace with `code=***` or a truncated hash.

### Finding 4: `Content-Security-Policy` Header Missing

- **Location:** `backend/src/main.py:573-582` (security headers middleware)
- **Data exposed:** N/A (defense-in-depth)
- **Who can see it:** Browser-based attackers
- **Risk:** MEDIUM — The security headers middleware sets HSTS, X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy, and Permissions-Policy, but **does NOT set `Content-Security-Policy`**. This allows XSS attacks to load external scripts, exfiltrate data via image beacons, or inject inline scripts.
- **Fix:** Add `response.headers["Content-Security-Policy"]` with at minimum `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://darsak-backend.fly.dev https://api.groq.com https://openrouter.ai`.

### Finding 5: Sentry Initialized Without Data Scrubbing Configuration

- **Location:** `backend/src/main.py:12-17`
- **Data exposed:** Full exception tracebacks including request bodies, headers, local variables
- **Who can see it:** Sentry dashboard (anyone with DSN access)
- **Risk:** HIGH — Sentry is initialized with `traces_sample_rate=1.0` (100% of traces) but zero scrubbing configuration. Sentry's default behavior captures full request/response bodies, headers (including `Authorization`), and local variables in stack traces. This means:
  - JWT tokens in `Authorization` headers
  - Student PINs submitted during login
  - Payment screenshots (base64-encoded)
  - Teacher passwords during registration
  - All API request/response bodies
- **Fix:** Add `before_send` callback to scrub PII, set `send_default_pii=False`, add `event_scrubbing=True`, and configure `before_send` to redact sensitive fields. Example:
  ```python
  sentry_sdk.init(
      ...,
      send_default_pii=False,
      event_scrubbing=True,
      before_send=lambda event: scrub_pii(event),
  )
  ```

### Finding 6: Web Portal Sentry Captures Client Errors Without PII Scrubbing

- **Location:** `web-portal/sentry.client.config.ts:1-7`
- **Data exposed:** Client-side errors, user context, localStorage data (which contains JWT tokens)
- **Who can see it:** Sentry dashboard
- **Risk:** MEDIUM — The web portal Sentry client config is minimal with no scrubbing. Sentry client SDKs automatically capture breadcrumbs and localStorage data. Since the web portal stores `access_token` and `refresh_token` in `localStorage` (see `web-portal/src/lib/auth.ts:13-14`), Sentry may capture these in error reports.
- **Fix:** Add `sendDefaultPii: false`, configure `denyUrls` for third-party scripts, and add `beforeSend` to scrub tokens from error contexts.

### Finding 7: CORS Allows `allow_credentials=True` with Explicit Origins

- **Location:** `backend/src/main.py:558-566`
- **Data exposed:** N/A (misconfiguration risk)
- **Who can see it:** Cross-origin attackers
- **Risk:** LOW (currently) — CORS is configured with `allow_credentials=True` and explicit origin list. The origins include `http://localhost:3000` and `http://localhost:8000` which are HTTP (not HTTPS). While the production domains use HTTPS, the localhost origins allow credential theft on local development networks. More importantly, any future origin additions without HTTPS could expose credentials.
- **Fix:** Remove HTTP localhost origins from production CORS list. Only allow HTTPS origins. Consider using environment-based CORS configuration.

### Finding 8: `answer_key` Field on Exams Table Exposes Correct Answers

- **Location:** `backend/src/main.py:96` (migration), `backend/src/services/supabase_services.py:486` (`get_by_id`)
- **Data exposed:** `answer_key` (TEXT column on `exams` table)
- **Who can see it:** Any teacher who owns the exam, and potentially students if the raw exam dict is returned
- **Risk:** MEDIUM — The `exams` table has an `answer_key TEXT` column. `ExamService.get_by_id()` returns the raw row including `answer_key`. The `ExamResponse` Pydantic model does NOT include `answer_key`, but `_to_exam_response()` in `exams.py` does not filter it either. If any code path returns the raw dict without Pydantic serialization, the answer key is exposed. Additionally, the student endpoint `get_exam_questions_student` properly strips `correct_answer` from questions, but the `exam` object returned in `start_exam` and `submit_exam` goes through `_to_exam_response()` which does not include `answer_key` (so currently safe). However, the underlying data is still fetched with `SELECT *`.
- **Fix:** Explicitly exclude `answer_key` and `source_data` from all exam queries/serializations. Use `.select("id, title, description, ...")` instead of `SELECT *` for exam queries.

### Finding 9: Payment Config Endpoint Exposes Financial PII Publicly

- **Location:** `backend/src/api/payments.py:172-178`
- **Data exposed:** `vodafone_cash_number`, `instapay_username`, `whatsapp_link`
- **Who can see it:** Any unauthenticated visitor
- **Risk:** MEDIUM — `GET /payments/config` has no authentication decorator (`Depends(get_current_teacher)` or `Depends(get_current_admin)` is absent). This exposes the teacher's Vodafone Cash number and Instapay username to anyone. This is financial PII.
- **Fix:** Add `Depends(get_current_teacher)` authentication, or move these to the admin-only section.

### Finding 10: Admin Login Uses Plaintext Password Comparison

- **Location:** `backend/src/api/admin.py:39`
- **Data exposed:** Admin password compared in plaintext
- **Who can see it:** Server logs (if password is logged during errors)
- **Risk:** MEDIUM — The admin login at `POST /admin/login` compares `password != settings.ADMIN_PASSWORD` using direct string comparison rather than bcrypt hash verification. While the password itself is stored in environment variables (not DB), this means:
  1. The admin password is stored in plaintext in the environment
  2. If any error trace includes the `password` variable, it would be logged
  3. The comparison is not timing-safe (vulnerable to timing attacks)
- **Fix:** Hash the admin password with bcrypt on startup and compare using `verify_password()`. Or store a bcrypt hash in the environment variable.

### Finding 11: `_serialize_student()` Returns Unfiltered Data Bypassing Pydantic

- **Location:** `backend/src/api/students.py:84-97,201`
- **Data exposed:** `pin_hash`, `parent_phone`, `is_active` — raw DB fields
- **Who can see it:** Authenticated teachers
- **Risk:** MEDIUM — The `_serialize_student()` function creates a dict with all fields including `pin_hash`. This dict is returned directly on `PUT /{student_id}` (line 201) as `{"ok": True, "student": _serialize_student(updated)}`. This bypasses the `StudentResponse` Pydantic model that would normally filter the output. The `pin_hash` field leaks a bcrypt hash of the student's PIN.
- **Fix:** Replace `_serialize_student(updated)` with `StudentResponse(**updated).model_dump()` on line 201, or remove `pin_hash` from the serializer.

### Finding 12: AI Chat Conversation History Stored Unencrypted in Database

- **Location:** `backend/src/api/student_me.py:217-239`
- **Data exposed:** Full conversation text between student and AI (stored as JSONB)
- **Who can see it:** Database administrators, anyone with Supabase dashboard access
- **Risk:** LOW — The `_save_conversation()` function stores the full user question and AI response in the `ai_conversations` table as plaintext JSONB. This could contain student names, homework answers, personal questions, or sensitive academic information. While the table is not exposed via any API endpoint (students cannot read other students' conversations), Supabase dashboard access or a DB breach would expose all conversation content.
- **Fix:** Encrypt conversation content before storing using the existing `encrypt_payload()` from `crypto_utils.py`, or at minimum add row-level security policies in Supabase.

---

## Positive Findings (Good Security Practices)

1. **SensitiveDataFilter** (`backend/src/core/logging.py:5-15`): Logs filter Bearer tokens and long base64 strings (>100 chars) — effective for API tokens and encrypted payloads.
2. **JWT tokens set as HttpOnly cookies** (`backend/src/api/auth.py:160-177`): Tokens are set with `httponly=True`, `secure=True`, `samesite=lax`.
3. **Rate limiting** on student login with progressive bans (`backend/src/api/students.py:23-77`).
4. **Input sanitization** via `sanitize_text`, `sanitize_student_code`, `sanitize_pin` functions.
5. **bcrypt password hashing** for teacher and student PINs.
6. **AES-256-GCM encryption** available for sensitive payloads (`encryption.py`, `crypto_utils.py`).
7. **Pydantic models** for API responses generally filter sensitive fields (e.g., `StudentResponse` uses `has_pin: bool` instead of `pin_hash`).
8. **No `console.log` statements** found in the web-portal frontend code.
9. **Token refresh rotation** with blacklist (`backend/src/api/auth.py:18-33`).
10. **CORS origin list** is explicit (no wildcards).

---

## Risk Score: 7/10

**Rationale:** The codebase has solid security foundations (bcrypt, AES encryption, rate limiting, input sanitization, CORS whitelisting). However, several high-severity findings create real exposure vectors:

- `pin_hash` leaking via `_serialize_student()` (Finding 2) is a direct credential exposure
- Sentry capturing 100% of traces with full request/response bodies (Finding 5) is a systemic PII leak
- `SELECT *` everywhere (Finding 1) means the attack surface is larger than necessary
- Missing CSP header (Finding 4) weakens XSS defense
- Public payment config endpoint (Finding 9) exposes financial PII

The combination of these issues means a motivated attacker with log access, Sentry access, or network interception could obtain student PIN hashes, teacher passwords, payment information, and full conversation histories.

---

## Recommendations (Priority Order)

1. **CRITICAL:** Remove `pin_hash` from `_serialize_student()` immediately
2. **CRITICAL:** Configure Sentry with `send_default_pii=False` and `before_send` scrubbing
3. **HIGH:** Replace `SELECT *` in `SupabaseRepository` with explicit column lists
4. **HIGH:** Add `Content-Security-Policy` header to security middleware
5. **HIGH:** Authenticate `GET /payments/config` endpoint
6. **MEDIUM:** Remove student codes from login log messages
7. **MEDIUM:** Hash admin password with bcrypt instead of plaintext comparison
8. **MEDIUM:** Configure web-portal Sentry with PII scrubbing
9. **MEDIUM:** Encrypt AI conversation content before DB storage
10. **LOW:** Remove HTTP localhost origins from production CORS
