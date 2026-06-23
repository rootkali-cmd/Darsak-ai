# CYBER-AGENT-2: API Security Audit

> **Auditor:** CYBER-AGENT-2 (API Security Specialist)
> **Date:** 2026-06-23
> **Scope:** All API endpoints in `backend/src/api/`
> **Backend:** FastAPI on Fly.io (https://darsak-backend.fly.dev)

---

## Executive Summary

After a deep audit of 10 API modules (admin, exams, students, grades, payments, invoices, subscriptions, analytics, assistants, student_me), I identified **14 security findings** across multiple severity levels. The codebase shows good security awareness in some areas (authorization checks, input sanitization, rate limiting, security headers) but has significant gaps in others (mass assignment, unauthenticated endpoints, plaintext credentials, IDOR risks).

---

## Severity: CRITICAL

### CRIT-01: Admin Login Compares Plaintext Passwords from Environment

- **Location:** `backend/src/api/admin.py:39`
- **Issue:** The admin login endpoint compares `password` directly against `settings.ADMIN_PASSWORD` in plaintext. No hashing, no bcrypt. If the env var is compromised (e.g., via Sentry, logs, or leaked `.env`), the admin account is instantly compromised.
- **Risk:** Full admin account takeover. Admin has access to student deletion, code generation, transaction management, and all admin operations.
- **Fix:** Store a bcrypt hash of the admin password in the environment variable and use `verify_password()` (already imported on line 8) for comparison:
  ```python
  if not verify_password(password, settings.ADMIN_PASSWORD_HASH):
      raise HTTPException(401, "Invalid credentials")
  ```

### CRIT-02: Unauthenticated Analytics Event Ingestion Endpoint

- **Location:** `backend/src/api/analytics.py:15-38`
- **Issue:** `POST /analytics/event` has **NO authentication**. Anyone can submit arbitrary analytics events, including crafted payloads. The endpoint writes directly to `analytics.jsonl` on disk.
- **Risk:** Disk exhaustion DoS (append unlimited entries to `analytics.jsonl`), data poisoning of analytics dashboards, log injection. An attacker can flood the analytics pipeline with millions of fake events.
- **Fix:** Either add authentication (admin or API key), or implement strict rate limiting + payload size limits for this specific endpoint. Consider writing to a database instead of a flat file.

### CRIT-03: Unauthenticated Payment Config Endpoint Leaks Financial Info

- **Location:** `backend/src/api/payments.py:172-178`
- **Issue:** `GET /payments/config` is **completely unauthenticated** and returns the Vodafone Cash number, WhatsApp link, and Instapay username.
- **Risk:** PII/financial account details exposed to any internet user. Could be used for social engineering, phishing, or targeted attacks on the payment accounts.
- **Fix:** Move this behind authentication or at minimum behind a teacher auth check.

---

## Severity: HIGH

### HIGH-01: Mass Assignment Vulnerability in Admin Update Endpoints

- **Location:** `backend/src/api/admin.py:131-133` and `backend/src/api/admin.py:154-156`
- **Issue:** `update_template()` and `update_transaction()` pass the raw request `body` directly to `SupabaseRepository.update()` with **no field filtering**. An attacker can set any column including `id`, `created_at`, `teacher_id`, or other system fields.
- **Risk:** An admin could overwrite critical fields in `payment_transactions` or `admin_templates`, potentially changing transaction statuses, altering template content, or corrupting referential integrity.
- **Fix:** Define an explicit allowlist of updatable fields for each endpoint:
  ```python
  ALLOWED_TEMPLATE_FIELDS = {"name", "content", "type"}
  update_data = {k: v for k, v in body.items() if k in ALLOWED_TEMPLATE_FIELDS}
  ```

### HIGH-02: Mass Assignment in Student Update

- **Location:** `backend/src/api/students.py:196-197`
- **Issue:** `update_student()` filters out `id` and `teacher_id` but allows **any other field** to be set. An attacker could set `pin_hash` directly, `is_active`, `daily_requests_count`, `last_request_date`, or any other column.
- **Risk:** A teacher could escalate privileges by setting `is_active` to False on other students, or bypass PIN requirements by setting `pin_hash` to a known value.
- **Fix:** Use a whitelist approach:
  ```python
  ALLOWED_UPDATE_FIELDS = {"full_name", "code", "phone", "parent_phone", "grade_level", "group_id"}
  ```

### HIGH-03: Mass Assignment in Grade Update

- **Location:** `backend/src/api/grades.py:187-188`
- **Issue:** `update_grade()` filters only `id`, `teacher_id`, and `type` but allows arbitrary other fields. An attacker could set `student_id` to a different student, or modify `score`/`max_score` to manipulate grades.
- **Risk:** Grade manipulation, data integrity compromise, potentially changing which student a grade belongs to.
- **Fix:** Whitelist grade-specific fields: `{"exam_name", "subject", "score", "max_score", "wrong_questions", "notes"}`.

### HIGH-04: IDOR in Teacher Subscription Status

- **Location:** `backend/src/api/payments.py:206-242`
- **Issue:** `GET /payments/{teacher_id}/status` accepts a `teacher_id` path parameter but uses `get_current_teacher` (not `get_current_admin`). Any authenticated teacher can query **any other teacher's subscription status** by passing a different `teacher_id`.
- **Risk:** Information disclosure — any teacher can enumerate all other teachers' subscription plans, expiration dates, and payment status.
- **Fix:** Either remove the `teacher_id` parameter and use `current_user["id"]`, or add an ownership check:
  ```python
  if teacher_id != current_user["id"] and current_user.get("role") != "admin":
      raise HTTPException(status_code=403, detail="Access denied")
  ```

### HIGH-05: No Authorization Check on mark_notification_read (Student)

- **Location:** `backend/src/api/student_me.py:32-38`
- **Issue:** `mark_notification_read()` accepts a `notification_id` but never verifies that the notification **belongs to the current student**. Any student can mark any other student's notifications as read.
- **Risk:** Privacy violation — student A can manipulate student B's notification state.
- **Fix:** Verify `notification.teacher_id == current_student["id"]` before marking.

### HIGH-06: No Authorization Check on Teacher mark_notification_read

- **Location:** `backend/src/api/subscriptions.py:376-386`
- **Issue:** Same issue as HIGH-05. `mark_notification_read()` for teachers accepts `notification_id` without verifying ownership.
- **Risk:** Any teacher can mark any other teacher's notifications as read.
- **Fix:** Verify `notification.teacher_id == current_user["id"]` before marking.

---

## Severity: MEDIUM

### MED-01: Student Login Rate Limiter is Process-Local

- **Location:** `backend/src/api/students.py:24-77`
- **Issue:** The student login rate limiter (`_student_login_attempts`) is a plain Python dictionary. On Fly.io with multiple workers/processes, each worker has its own state. An attacker can brute-force PINs by distributing requests across workers.
- **Risk:** The 4-attempt window + ban system is effectively bypassed in multi-worker deployments. Fly.io runs multiple processes.
- **Fix:** Move the rate limiter to Redis (the `rate_limiter` infrastructure already supports Redis). Use a Redis-backed store for login attempts:
  ```python
  await rate_limiter.is_allowed(("login", sanitized_code), max_requests=LOGIN_ATTEMPTS_PER_WINDOW)
  ```

### MED-02: Missing Rate Limiting on Admin Login

- **Location:** `backend/src/api/admin.py:30-44`
- **Issue:** The admin login endpoint has **no rate limiting at all**. An attacker can brute-force the admin password without any throttling (the global middleware only limits to 120 req/min per IP, which is generous for brute-force).
- **Risk:** Admin password brute-force. Combined with CRIT-01 (plaintext comparison), this is particularly dangerous.
- **Fix:** Add specific rate limiting for admin login (e.g., 5 attempts per minute per IP) either in the middleware or the endpoint itself.

### MED-03: Sensitive Data in Error Messages

- **Location:** Multiple files (e.g., `exams.py:106`, `students.py:183`, `grades.py:100`)
- **Issue:** Error messages include generic internal error text, but the exception is often logged with `exc_info=True`. While the HTTP response is sanitized, the logs may contain sensitive details about the database structure or user data.
- **Risk:** If logs are accessible (Sentry is configured with `traces_sample_rate=1.0`), sensitive data could leak through error reporting.
- **Fix:** Ensure Sentry is configured to scrub sensitive data before sending. Review all `logger.error` calls that include user data.

### MED-04: No CSRF Protection

- **Location:** `backend/src/main.py:558-566` (CORS configuration)
- **Issue:** CORS allows `allow_credentials=True` with a list of specific origins. However, there is no CSRF token validation. The `X-CSRF-Token` header is listed in allowed headers but never validated.
- **Risk:** Cross-site request forgery attacks against authenticated endpoints. While Bearer tokens mitigate most CSRF (they're not automatically included by browsers), the `allow_credentials=True` setting could be exploited in combination with subdomain takeover.
- **Fix:** Either remove `allow_credentials=True` (if not needed) or implement CSRF token validation.

### MED-05: Unprotected Subscription Plans Endpoint

- **Location:** `backend/src/api/subscriptions.py:75-82`
- **Issue:** `GET /subscriptions/plans` is **completely unauthenticated**. It returns all plan details including pricing, limits, and features.
- **Risk:** Business intelligence disclosure. Competitors can enumerate all subscription plans, prices, and feature matrices.
- **Fix:** This may be intentional (public pricing page). If so, document it. Otherwise, add teacher authentication.

### MED-06: Notification Service Uses Wrong Field Name

- **Location:** `backend/src/api/exams.py:458-463`
- **Issue:** In `publish_exam()`, notifications are created with `teacher_id=student_id` — this sets the `teacher_id` column to the **student's** ID, not the actual teacher's ID. Notifications will appear to be from the student, not the teacher.
- **Risk:** Notifications are delivered to the wrong user context. The `notifications` table's `teacher_id` column is being used as `recipient_id` here, which is semantically incorrect.
- **Fix:** This appears to be a naming confusion. If `teacher_id` in the notifications table means "recipient", this should be documented. Otherwise, create a separate `recipient_id` column or fix the logic.

### MED-07: Missing Input Validation on Code Generation

- **Location:** `backend/src/api/admin.py:85-98`
- **Issue:** `quantity` parameter in `generate_code` is not validated for maximum. An admin (or attacker with admin access) can generate millions of codes in one request, causing DB overload.
- **Risk:** Database flooding, resource exhaustion.
- **Fix:** Add `max_length` validation: `quantity = min(body.get("quantity", 1), 1000)`.

---

## Severity: LOW

### LOW-01: PIN Hints Leak Existence Information

- **Location:** `backend/src/api/students.py:209-224`
- **Issue:** `GET /students/{student_id}/pin` reveals whether a PIN has been set for a student. While this is behind teacher auth, it still leaks information that could be useful for targeted attacks.
- **Risk:** Minor information disclosure. An attacker with teacher-level access can enumerate which students have PINs set.
- **Fix:** Consider returning a generic response regardless of PIN status, or document this as intentional behavior.

### LOW-02: Refresh Token Rotation Without Revocation

- **Location:** `backend/src/api/students.py:330-348`
- **Issue:** `POST /students/refresh` creates new access + refresh tokens but does not revoke the old refresh token. If a refresh token is stolen, it remains valid indefinitely until expiration.
- **Risk:** Stolen refresh tokens can be used indefinitely (until they expire).
- **Fix:** Implement refresh token rotation with revocation of the old token on each use.

### LOW-03: OpenAPI Docs Exposed in Production

- **Location:** `backend/src/main.py:542`
- **Issue:** `docs_url="/docs"` is enabled in production. While the API is behind auth, the documentation exposes all endpoint details, parameter names, and data models.
- **Risk:** Attackers can use the OpenAPI documentation to map out the entire API surface for targeted attacks.
- **Fix:** Disable docs in production: `docs_url="/docs" if settings.ENVIRONMENT == "development" else None`.

---

## Findings Per Endpoint (Detailed)

### admin.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /admin/login | None | N/A | **CRIT-01** Plaintext password comparison. **MED-02** No rate limiting |
| GET | /admin/students | Admin | Admin role | OK |
| PUT | /admin/students/{id}/status | Admin | Admin role | **HIGH-01** Mass assignment |
| DELETE | /admin/students/{id} | Admin | Admin role | OK |
| POST | /admin/codes/generate | Admin | Admin role | **MED-07** No quantity limit |
| GET | /admin/codes | Admin | Admin role | OK |
| GET | /admin/templates | Admin | Admin role | OK |
| PUT | /admin/templates/{id} | Admin | Admin role | **HIGH-01** Mass assignment |
| GET | /admin/transactions | Admin | Admin role | OK |
| PUT | /admin/transactions/{id} | Admin | Admin role | **HIGH-01** Mass assignment |
| GET | /admin/stats | Admin | Admin role | OK |

### exams.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /exams | Teacher | teacher_id ownership | OK |
| POST | /exams/ai-generate | Teacher | teacher_id ownership | OK (file validation present) |
| GET | /exams | Teacher | teacher_id filter | OK |
| GET | /exams/available | Student | student_id filter | OK |
| POST | /exams/{id}/start | Student | Deadline check | OK |
| GET | /exams/{id}/questions-student | Student | Published check | OK |
| POST | /exams/{id}/submit | Student | Deadline check | OK |
| GET | /exams/my-results | Student | student_id filter | OK |
| GET | /exams/my-result/{id} | Student | student_id ownership | OK |
| GET | /exams/{id} | Teacher | teacher_id ownership | OK |
| PUT | /exams/{id} | Teacher | teacher_id ownership | OK |
| DELETE | /exams/{id} | Teacher | teacher_id ownership | OK |
| POST | /exams/{id}/publish | Teacher | teacher_id ownership | OK |
| GET | /exams/{id}/questions | Teacher | teacher_id ownership | OK |
| POST | /exams/{id}/questions | Teacher | teacher_id ownership | OK |
| PUT | /exams/{id}/questions/{qid} | Teacher | teacher_id ownership | OK |
| DELETE | /exams/{id}/questions/{qid} | Teacher | teacher_id ownership | OK |
| GET | /exams/{id}/results | Teacher | teacher_id ownership | OK |
| GET | /exams/result/{id} | Teacher | teacher_id ownership (via exam) | OK |
| GET | /exams/check-new/{sid} | Student | student_id match | OK |
| POST | /exams/analyze/{id} | Teacher | teacher_id ownership | OK |

### students.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /students/ | Teacher | teacher_id ownership | OK |
| GET | /students/ | Teacher | teacher_id filter | OK |
| GET | /students/count | Teacher | teacher_id filter | OK |
| GET | /students/{id} | Teacher | teacher_id ownership | OK |
| PUT | /students/{id} | Teacher | teacher_id ownership | **HIGH-02** Mass assignment |
| GET | /students/{id}/pin | Teacher | teacher_id ownership | **LOW-01** Info leak |
| PATCH | /students/{id}/pin | Teacher | teacher_id ownership | OK |
| DELETE | /students/{id} | Teacher | teacher_id ownership | OK |
| POST | /students/verify-teacher | None | N/A | OK (returns teacher info by code) |
| POST | /students/login | None | N/A | OK (has rate limiter, but **MED-01** process-local) |
| POST | /students/refresh | None | Token validation | **LOW-02** No revocation |
| POST | /students/analyze | Teacher | teacher_id ownership | OK |
| GET | /students/{id}/report/pdf | Teacher | teacher_id ownership | OK |

### grades.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /grades/ | Teacher | teacher_id ownership | OK |
| POST | /grades/bulk | Teacher | teacher_id ownership (per student) | OK |
| GET | /grades/ | Teacher | teacher_id filter | OK |
| GET | /grades/stats | Teacher | teacher_id filter | OK |
| GET | /grades/{id} | Teacher | teacher_id ownership | OK |
| PUT | /grades/{id} | Teacher | teacher_id ownership | **HIGH-03** Mass assignment |
| DELETE | /grades/{id} | Teacher | teacher_id ownership | OK |

### payments.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /payments/request | Teacher | teacher_id | OK |
| POST | /payments/callback | Admin | Admin role | OK |
| GET | /payments/config | **NONE** | N/A | **CRIT-03** Leaks financial info |
| POST | /payments/test-telegram | Admin | Admin role | OK |
| GET | /payments/{teacher_id}/status | Teacher | None (any teacher) | **HIGH-04** IDOR |

### invoices.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /invoices/create | Student | student_id match | OK |
| POST | /invoices/teacher-create | Teacher | student ownership | OK |
| GET | /invoices/my/{student_id} | User (student or teacher) | student_id check | OK |
| POST | /invoices/upload-proof | Student | student_id ownership | OK |
| GET | /invoices/pending | Teacher | teacher_id filter | OK |
| GET | /invoices/teacher | Teacher | teacher_id filter | OK |
| POST | /invoices/{id}/approve | Teacher | teacher_id ownership | OK |
| POST | /invoices/{id}/reject | Teacher | teacher_id ownership | OK |

### subscriptions.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| GET | /subscriptions/plans | **NONE** | N/A | **MED-05** Business info disclosure |
| POST | /subscriptions/activate-trial | Teacher | teacher_id | OK |
| POST | /subscriptions/activate | Teacher | teacher_id | OK |
| GET | /subscriptions/my | Teacher | teacher_id | OK |
| POST | /subscriptions/check | Teacher | teacher_id | OK |
| POST | /subscriptions/payment-request | Teacher | teacher_id | OK |
| GET | /subscriptions/payment-requests | Teacher | teacher_id | OK |
| GET | /subscriptions/notifications | Teacher | teacher_id | OK |
| POST | /subscriptions/notifications/{id}/read | Teacher | None | **HIGH-06** No ownership check |
| GET | /subscriptions/admin/codes | Admin | Admin role | OK |
| POST | /subscriptions/admin/codes/generate | Admin | Admin role | OK |

### analytics.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /analytics/event | **NONE** | N/A | **CRIT-02** Unauthenticated, disk DoS |
| GET | /analytics/overview | Admin | Admin role | OK |
| GET | /analytics/updates | Admin | Admin role | OK |
| GET | /analytics/crashes | Admin | Admin role | OK |
| GET | /analytics/platforms | Admin | Admin role | OK |
| GET | /analytics/events | Admin | Admin role | OK |
| GET | /analytics/versions-usage | Admin | Admin role | OK |
| GET | /analytics/channels | Admin | Admin role | OK |

### assistants.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| POST | /assistants | Teacher | teacher_id | OK |
| GET | /assistants | Teacher | teacher_id filter | OK |
| GET | /assistants/{id} | Teacher | teacher_id ownership | OK |
| PATCH | /assistants/{id} | Teacher | teacher_id ownership | OK |
| DELETE | /assistants/{id} | Teacher | teacher_id ownership | OK |
| POST | /assistants/set-password | Teacher | teacher_id | OK |
| POST | /assistants/verify-password | Teacher | teacher_id | OK |

### student_me.py

| Method | Path | Auth | AuthZ Check | Issues |
|--------|------|------|-------------|--------|
| GET | /students/me/notifications | Student | student_id | OK |
| POST | /students/me/notifications/{id}/read | Student | None | **HIGH-05** No ownership check |
| GET | /students/me | Student | student_id | OK |
| GET | /students/me/grades | Student | student_id | OK |
| GET | /students/me/attendance | Student | student_id | OK |
| GET | /students/me/invoices | Student | student_id | OK |
| PATCH | /students/me/pin | Student | old PIN verified | OK |
| POST | /students/me/ai-chat | Student | student_id + daily limit | OK |
| GET | /students/me/ai-usage | Student | student_id | OK |
| GET | /students/me/stats | Student | student_id | OK |
| GET | /students/me/teacher-subscription | Student | student's teacher_id | OK |

---

## Summary Table

| ID | Severity | Category | Finding | File:Line |
|----|----------|----------|---------|-----------|
| CRIT-01 | CRITICAL | Auth | Admin plaintext password comparison | admin.py:39 |
| CRIT-02 | CRITICAL | Auth | Unauthenticated analytics event ingestion | analytics.py:15 |
| CRIT-03 | CRITICAL | Info Leak | Unauthenticated payment config leaks financial PII | payments.py:172 |
| HIGH-01 | HIGH | Mass Assignment | Admin template/transaction update accepts arbitrary fields | admin.py:131,154 |
| HIGH-02 | HIGH | Mass Assignment | Student update accepts arbitrary fields | students.py:196 |
| HIGH-03 | HIGH | Mass Assignment | Grade update accepts arbitrary fields | grades.py:187 |
| HIGH-04 | HIGH | IDOR | Any teacher can query other teachers' subscription status | payments.py:206 |
| HIGH-05 | HIGH | AuthZ | Student notification read lacks ownership check | student_me.py:32 |
| HIGH-06 | HIGH | AuthZ | Teacher notification read lacks ownership check | subscriptions.py:376 |
| MED-01 | MEDIUM | Rate Limit | Student login rate limiter is process-local | students.py:24 |
| MED-02 | MEDIUM | Rate Limit | Admin login has no rate limiting | admin.py:30 |
| MED-03 | MEDIUM | Info Leak | Sensitive data in error logs / Sentry | Multiple files |
| MED-04 | MEDIUM | CSRF | No CSRF protection despite allow_credentials | main.py:558 |
| MED-05 | MEDIUM | Info Leak | Subscription plans publicly accessible | subscriptions.py:75 |
| MED-06 | MEDIUM | Logic | Notification uses wrong field (teacher_id=student_id) | exams.py:458 |
| MED-07 | MEDIUM | DoS | Code generation has no quantity limit | admin.py:85 |
| LOW-01 | LOW | Info Leak | PIN hint reveals PIN existence | students.py:209 |
| LOW-02 | LOW | Session | Refresh token not revoked on rotation | students.py:330 |
| LOW-03 | LOW | Info Leak | OpenAPI docs exposed in production | main.py:542 |

---

## Positive Security Observations

The codebase also demonstrates several good security practices:

1. **Authorization checks present on most endpoints** — Teacher ownership checks are consistently applied on exam, grade, student, and invoice operations.
2. **Input sanitization** — `sanitizer.py` strips dangerous characters from student codes, PINs, teacher codes, and text.
3. **Security headers middleware** — HSTS, X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy are all set.
4. **JWT-based auth** — Uses bcrypt for password hashing (except admin), proper JWT decode with expiry.
5. **File upload validation** — AI exam generation validates MIME types and file sizes.
6. **Rate limiting infrastructure** — Redis-backed distributed rate limiter exists (just not used for all critical paths).
7. **Audit logging** — Sensitive operations (student create/delete, grade changes, PIN resets) are logged with actor ID and IP.
8. **Global exception handler** — Unhandled exceptions return generic error messages without stack traces.

---

## Risk Score: 7/10

**Justification:** The 3 critical findings (plaintext admin password, unauthenticated analytics endpoint, leaked financial PII) represent immediate exploitation risks. The mass assignment vulnerabilities (3 findings) could allow significant data corruption if any teacher account is compromised. The IDOR on subscription status and missing authorization on notification read are exploitable by any authenticated user. However, the overall auth framework is solid, most endpoints have proper authorization, and input sanitization is present throughout.

**Priority Remediation Order:**
1. CRIT-01 → Hash admin password (30 min fix)
2. CRIT-02 → Add auth to analytics event endpoint (15 min fix)
3. CRIT-03 → Add auth to payment config (10 min fix)
4. HIGH-01/02/03 → Add field whitelists to all update endpoints (1 hour total)
5. HIGH-04 → Add ownership check on subscription status (15 min fix)
6. HIGH-05/06 → Add ownership checks on notification read (30 min fix)
7. MED-01 → Move login rate limiter to Redis (1 hour fix)
8. MED-02 → Add rate limiting to admin login (30 min fix)

---

*Report generated by CYBER-AGENT-2 | DarsakAI Agent Swarm*
