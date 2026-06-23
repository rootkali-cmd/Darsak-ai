# Agent Chief — Unified Decision Report

**Date:** 2026-06-23
**Auditors:** CYBER-AGENT-1 through CYBER-AGENT-5
**Debate Chief:** CHIEF-DECISION

---

## Conflicts Found

### Conflict 1: Admin Plaintext Password — Severity Disagreement
- **Agent 2 (API Security):** CRITICAL — "Full admin account takeover. Plaintext comparison, no hashing."
- **Agent 3 (Data Exposure):** MEDIUM — "Stored in env var, not DB. Comparison not timing-safe."
- **CHIEF RULING:** **CRITICAL**. Agent 2 is correct — admin has full access (student deletion, code generation, transaction management). Plaintext comparison + no rate limiting on admin login = trivial brute force. Environment variable exposure via Sentry/logs makes this worse than Agent 3 assessed.

### Conflict 2: localStorage Token Storage — Severity Disagreement
- **Agent 1 (Auth/JWT):** HIGH — "Any XSS vulnerability can steal tokens."
- **Agent 5 (Web Portal):** CRITICAL — "Full account takeover via any XSS."
- **CHIEF RULING:** **CRITICAL**. Agent 5 is correct — token theft via XSS = full impersonation of any teacher. Combined with Agent 5's Finding 4 (CSP allows `unsafe-inline` scripts), the attack surface is wider than Agent 1 assumed.

### Conflict 3: Sentry PII Capture — Severity Disagreement
- **Agent 3 (Data Exposure):** HIGH — "Full request/response bodies, headers including Authorization, student PINs, payment screenshots all captured."
- **Agent 4 (Infrastructure):** MEDIUM — "High bandwidth cost, sensitive data could be captured."
- **CHIEF RULING:** **HIGH**. Agent 3's analysis is more thorough — `traces_sample_rate=1.0` + no scrubbing = every JWT, PIN, and payment screenshot is sent to Sentry. This is a systemic PII leak.

### Conflict 4: Login Brute Force — Severity Disagreement
- **Agent 1 (Auth/JWT):** HIGH — "10,000 passwords/day/IP with distributed proxies."
- **Agent 5 (Web Portal):** MEDIUM — "No client-side rate limiting."
- **CHIEF RULING:** **HIGH**. These are related but distinct issues. Agent 1's backend concern is more critical — the existing 10 req/60s limit is insufficient, and there's zero account lockout.

### Conflict 5: CORS/CSRF Risk — Severity Disagreement
- **Agent 2 (API Security):** MEDIUM — "No CSRF token validation."
-- **Agent 3 (Data Exposure):** LOW — "Currently low risk."
- **Agent 4 (Infrastructure):** LOW — "Dev origins in production."
- **Agent 5 (Web Portal):** MEDIUM — "Combined with non-HttpOnly cookies, CSRF attacks possible."
- **CHIEF RULING:** **MEDIUM**. Agent 5 is correct — non-HttpOnly cookies + `withCredentials: true` + no CSRF tokens = exploitable CSRF. The Bearer token provides partial mitigation, but the cookie-based auth path is vulnerable.

### Conflict 6: Hardcoded Instapay Username — Agent Coverage Gap
- **Agent 1-3, 5:** Did not find this.
- **Agent 4 (Infrastructure):** CRITICAL — "Hardcoded PII in SQL migration that runs on every startup."
- **CHIEF RULING:** **CRITICAL**. Agent 4 is correct. Financial PII (`ahmed-mahmoud-1@instapay`) is committed to source control and overwritten on every deploy. This is a real credential leak.

### Conflict 7: Missing CI/CD — Agent Coverage Gap
- **Agent 1-3, 5:** Did not address this.
- **Agent 4 (Infrastructure):** HIGH — "No automated testing, linting, security scanning, or deployment gates."
- **CHIEF RULING:** **HIGH**. Correct — this is a process-level vulnerability that enables all other issues to reach production.

---

## Merged Findings (Deduplicated)

### P0 — Fix NOW (CRITICAL, Immediately Exploitable)

| # | Finding | Reported By | Location | Exploitability |
|---|---------|-------------|----------|----------------|
| 1 | Access token expiry 30 days | Agent 1, Agent 4 | `config.py:47` | Stolen token valid 30 days |
| 2 | Refresh token expiry 1 year | Agent 1 | `config.py:48` | Stolen refresh = 1-year access |
| 3 | Admin plaintext password comparison | Agent 2, Agent 3 | `admin.py:39` | Trivial brute force (no rate limit) |
| 4 | Unauthenticated analytics event ingestion | Agent 2 | `analytics.py:15` | Disk exhaustion DoS, data poisoning |
| 5 | Unauthenticated payment config leaks financial PII | Agent 2, Agent 3 | `payments.py:172` | Public Vodafone Cash + Instapay |
| 6 | localStorage token storage (XSS-vulnerable) | Agent 1, Agent 5 | `web-portal/src/lib/auth.ts:13` | Any XSS = full account takeover |
| 7 | Hardcoded SECRET_KEY default value | Agent 4 | `config.py:45` | JWT forgery if env misconfigured |
| 8 | Hardcoded Instapay username in migrations | Agent 4 | `main.py:295` | Financial PII in source control |
| 9 | SERVICE_ROLE_KEY sent in HTTP headers | Agent 4 | `main.py:352` | Full DB access if logged/exposed |
| 10 | pin_hash leaked in student API responses | Agent 3 | `students.py:92` | bcrypt hash exposed to teachers |

### P1 — Fix This Session (HIGH)

| # | Finding | Reported By | Location |
|---|---------|-------------|----------|
| 11 | No brute force protection / account lockout | Agent 1, Agent 5 | `auth.py`, `students.py` |
| 12 | In-memory token blacklist not persistent | Agent 1 | `auth.py:19` |
| 13 | Mass assignment in admin update endpoints | Agent 2 | `admin.py:131,154` |
| 14 | Mass assignment in student update | Agent 2 | `students.py:196` |
| 15 | Mass assignment in grade update | Agent 2 | `grades.py:187` |
| 16 | IDOR in teacher subscription status | Agent 2 | `payments.py:206` |
| 17 | No authorization on student notification read | Agent 2 | `student_me.py:32` |
| 18 | No authorization on teacher notification read | Agent 2 | `subscriptions.py:376` |
| 19 | Weak password policy (min 6 chars, no complexity) | Agent 1 | `schemas/user.py:10` |
| 20 | Bcrypt default salt rounds (10, should be 12+) | Agent 1 | `security/auth.py:12` |
| 21 | Cookies set via document.cookie (not HttpOnly) | Agent 5 | `web-portal/src/lib/auth.ts:1` |
| 22 | Sentry captures 100% traces with full PII | Agent 3, Agent 4 | `main.py:12` |
| 23 | No CI/CD pipeline | Agent 4 | `.github/workflows/` |
| 24 | Unbounded dependency versions (no lock file) | Agent 4 | `requirements.txt` |
| 25 | Docker runs as root | Agent 4 | `Dockerfile` |
| 26 | No .dockerignore | Agent 4 | `backend/` |
| 27 | CSP header missing (backend) | Agent 3 | `main.py:573` |
| 28 | CSP allows unsafe-inline scripts (web portal) | Agent 5 | `next.config.js:19` |
| 29 | Missing allowBackup=false (both Android apps) | Agent 4 | `build.gradle.kts` |
| 30 | Teacher app missing isDebuggable=false | Agent 4 | `teacher_mobile_v2/build.gradle.kts` |
| 31 | Hardcoded admin email in config | Agent 4 | `config.py:62` |

### P2 — Fix Soon (MEDIUM)

| # | Finding | Reported By | Location |
|---|---------|-------------|----------|
| 32 | Student login rate limiter is process-local | Agent 2 | `students.py:24` |
| 33 | Admin login has no rate limiting | Agent 2 | `admin.py:30` |
| 34 | Sensitive data in error logs / Sentry | Agent 2 | Multiple files |
| 35 | No CSRF protection | Agent 2, Agent 5 | `main.py:558`, `web-portal` |
| 36 | Subscription plans publicly accessible | Agent 2 | `subscriptions.py:75` |
| 37 | Notification uses wrong field (teacher_id=student_id) | Agent 2 | `exams.py:458` |
| 38 | Code generation has no quantity limit | Agent 2 | `admin.py:85` |
| 39 | Cookie SameSite policy too permissive (lax→strict) | Agent 1 | `auth.py:165` |
| 40 | No jti claim for token tracking | Agent 1 | `security/auth.py:21` |
| 41 | No token revocation on password change | Agent 1 | `auth.py:330` |
| 42 | KDF iteration discrepancy (100K vs 600K) | Agent 4 | `encryption.py:21` |
| 43 | AES key derivation with random salt | Agent 4 | `crypto_utils.py:22` |
| 44 | Rate limiter fails open when Redis down | Agent 4 | `rate_limiter.py:103` |
| 45 | SQL migrations run on every startup | Agent 4 | `main.py:49` |
| 46 | HS256 JWT (symmetric) algorithm | Agent 4 | `config.py:46` |
| 47 | No server-side middleware (web portal) | Agent 5 | No `middleware.ts` |
| 48 | Health endpoints expose infrastructure details | Agent 4 | `main.py:636` |
| 49 | No client-side rate limiting on login/register | Agent 5 | `login/page.tsx` |
| 50 | Web portal Sentry without PII scrubbing | Agent 3 | `sentry.client.config.ts` |

### P3 — Track for Later (LOW)

| # | Finding | Reported By | Location |
|---|---------|-------------|----------|
| 51 | Refresh token not revoked on rotation | Agent 1, Agent 2 | `students.py:330` |
| 52 | OpenAPI docs exposed in production | Agent 2 | `main.py:542` |
| 53 | PIN hints leak existence info | Agent 2 | `students.py:209` |
| 54 | Debug log level in production Dockerfile | Agent 4 | `Dockerfile:28` |
| 55 | Single Gunicorn worker | Agent 4 | `Dockerfile:21` |
| 56 | Keystore not in .gitignore | Agent 4 | `build.gradle.kts` |
| 57 | CORS with dev origins in production | Agent 4 | `main.py:558` |
| 58 | Vercel missing security headers | Agent 4 | `vercel.json` |
| 59 | Supabase singleton no health check | Agent 4 | `supabase_repo.py:21` |
| 60 | Download API no authentication | Agent 5 | `api/download/[file]/route.ts` |
| 61 | Hardcoded plan IDs in client bundle | Agent 5 | `subscription/page.tsx` |
| 62 | Error messages may leak backend details | Agent 5 | `login/page.tsx` |
| 63 | Sentry without source map protection | Agent 5 | `ErrorBoundary.tsx` |
| 64 | AI conversations stored unencrypted | Agent 3 | `student_me.py:217` |
| 65 | Error messages leak user existence | Agent 1 | `auth.py:144` |
| 66 | Rate limiter key collisions | Agent 1 | `main.py:592` |

---

## Priority List (P0/P1/P2/P3)

### P0 — Fix NOW (10 items, estimated 3-4 hours)

1. **Reduce access token expiry to 30 minutes** — `config.py:47` — `ACCESS_TOKEN_EXPIRE_MINUTES = 30`
2. **Reduce refresh token expiry to 30 days** — `config.py:48` — `REFRESH_TOKEN_EXPIRE_DAYS = 30`
3. **Hash admin password with bcrypt** — `admin.py:39` — Use `verify_password()` instead of `==`
4. **Add auth to analytics event endpoint** — `analytics.py:15` — Add `Depends(get_current_admin)`
5. **Add auth to payment config endpoint** — `payments.py:172` — Add `Depends(get_current_teacher)`
6. **Remove localStorage token storage in web portal** — `auth.ts:13-21` — Server-set HttpOnly cookies only
7. **Remove SECRET_KEY default value** — `config.py:45` — Set to empty string, rely on validation
8. **Remove hardcoded Instapay username** — `main.py:295` — Move to env var or DB config
9. **Remove pin_hash from _serialize_student()** — `students.py:92` — Delete the pin_hash line
10. **Secure SERVICE_ROLE_KEY usage** — `main.py:352` — Ensure no logging of auth headers

### P1 — Fix This Session (21 items, estimated 6-8 hours)

11. **Add account lockout after 5 failed attempts** — `auth.py` — Redis-backed with 15-min window
12. **Move token blacklist to Redis** — `auth.py:19` — Replace in-memory set with Redis keys
13. **Add field whitelists to admin update endpoints** — `admin.py:131,154` — `ALLOWED_TEMPLATE_FIELDS`, `ALLOWED_TRANSACTION_FIELDS`
14. **Add field whitelist to student update** — `students.py:196` — `ALLOWED_UPDATE_FIELDS`
15. **Add field whitelist to grade update** — `grades.py:187` — `ALLOWED_GRADE_FIELDS`
16. **Add ownership check on subscription status** — `payments.py:206` — `if teacher_id != current_user["id"]`
17. **Add ownership check on student notification read** — `student_me.py:32` — Verify notification belongs to student
18. **Add ownership check on teacher notification read** — `subscriptions.py:376` — Verify notification belongs to teacher
19. **Enforce password complexity (8+ chars, upper, lower, digit)** — `schemas/user.py:10`
20. **Increase bcrypt rounds to 12** — `security/auth.py:12`
21. **Set HttpOnly cookies server-side in web portal** — `auth.ts:1-5` — Remove `document.cookie` usage
22. **Configure Sentry with PII scrubbing** — `main.py:12` — `send_default_pii=False`, `before_send` callback
23. **Create CI/CD pipeline** — `.github/workflows/` — Add ruff, mypy, pip-audit, deployment gates
24. **Pin dependency versions** — `requirements.txt` — Generate lock file with `pip-compile`
25. **Add non-root user to Dockerfile** — `Dockerfile` — `USER appuser`
26. **Create .dockerignore** — `backend/` — Exclude .env, __pycache__, .git
27. **Add CSP header to backend** — `main.py:573` — `default-src 'self'; script-src 'self'`
28. **Remove unsafe-inline from web portal CSP** — `next.config.js:19` — Use nonces
29. **Add allowBackup=false to both Android apps** — `build.gradle.kts`
30. **Add isDebuggable=false to teacher app release** — `teacher_mobile_v2/build.gradle.kts`
31. **Remove hardcoded admin email** — `config.py:62` — Use env var only

### P2 — Fix Soon (19 items, estimated 4-6 hours)

32-50: See merged findings table above.

### P3 — Track for Later (16 items)

51-66: See merged findings table above.

---

## Execution Plan (Who Does What)

### Agent 1 (Auth/JWT Specialist) — P0 + P1 Auth Fixes
| Priority | Fix | Files | Est. Time |
|----------|-----|-------|-----------|
| P0 | Reduce access token expiry to 30 min | `backend/src/core/config.py:47` | 5 min |
| P0 | Reduce refresh token expiry to 30 days | `backend/src/core/config.py:48` | 5 min |
| P0 | Remove SECRET_KEY default | `backend/src/core/config.py:45` | 5 min |
| P1 | Add account lockout (5 attempts / 15 min) | `backend/src/api/auth.py` (login endpoint) | 45 min |
| P1 | Move token blacklist to Redis | `backend/src/api/auth.py:19` | 30 min |
| P1 | Enforce password complexity | `backend/src/schemas/user.py:10` | 20 min |
| P1 | Increase bcrypt rounds to 12 | `backend/src/core/security/auth.py:12` | 5 min |
| P2 | Add jti claim to JWTs | `backend/src/core/security/auth.py:21` | 15 min |
| P2 | Token revocation on password change | `backend/src/api/auth.py:330` | 20 min |
| P2 | Change SameSite to strict | `backend/src/api/auth.py:165` | 5 min |

### Agent 2 (API Security Specialist) — P0 + P1 API Fixes
| Priority | Fix | Files | Est. Time |
|----------|-----|-------|-----------|
| P0 | Hash admin password with bcrypt | `backend/src/api/admin.py:39` | 30 min |
| P0 | Add auth to analytics endpoint | `backend/src/api/analytics.py:15` | 15 min |
| P0 | Add auth to payment config | `backend/src/api/payments.py:172` | 10 min |
| P1 | Whitelist admin update fields | `backend/src/api/admin.py:131,154` | 30 min |
| P1 | Whitelist student update fields | `backend/src/api/students.py:196` | 15 min |
| P1 | Whitelist grade update fields | `backend/src/api/grades.py:187` | 15 min |
| P1 | Add ownership check on subscription status | `backend/src/api/payments.py:206` | 10 min |
| P1 | Add ownership checks on notification reads | `backend/src/api/student_me.py:32`, `backend/src/api/subscriptions.py:376` | 30 min |
| P2 | Add admin login rate limiting | `backend/src/api/admin.py:30` | 20 min |
| P2 | Move student login rate limiter to Redis | `backend/src/api/students.py:24` | 45 min |
| P2 | Fix notification field name confusion | `backend/src/api/exams.py:458` | 15 min |
| P2 | Add code generation quantity limit | `backend/src/api/admin.py:85` | 10 min |

### Agent 3 (Data Exposure Specialist) — P0 + P1 Data Fixes
| Priority | Fix | Files | Est. Time |
|----------|-----|-------|-----------|
| P0 | Remove pin_hash from _serialize_student() | `backend/src/api/students.py:92` | 5 min |
| P0 | Secure SERVICE_ROLE_KEY in migration calls | `backend/src/main.py:352` | 15 min |
| P1 | Configure Sentry PII scrubbing | `backend/src/main.py:12` | 30 min |
| P1 | Add CSP header to backend | `backend/src/main.py:573` | 15 min |
| P2 | Configure web portal Sentry scrubbing | `web-portal/sentry.client.config.ts` | 15 min |
| P2 | Remove student codes from login logs | `backend/src/api/students.py:291` | 10 min |
| P3 | Encrypt AI conversation content | `backend/src/api/student_me.py:217` | 30 min |

### Agent 4 (Infrastructure Specialist) — P0 + P1 Infrastructure Fixes
| Priority | Fix | Files | Est. Time |
|----------|-----|-------|-----------|
| P0 | Remove hardcoded Instapay username | `backend/src/main.py:295` | 10 min |
| P0 | Remove hardcoded admin email | `backend/src/core/config.py:62` | 5 min |
| P1 | Create .dockerignore | `backend/.dockerignore` | 5 min |
| P1 | Add non-root user to Dockerfile | `backend/Dockerfile` | 10 min |
| P1 | Pin dependency versions | `backend/requirements.txt` | 30 min |
| P1 | Create CI/CD pipeline | `.github/workflows/ci.yml` | 60 min |
| P1 | Add allowBackup=false to both apps | `mobile-app/android/app/build.gradle.kts`, `teacher_mobile_v2/android/app/build.gradle.kts` | 15 min |
| P1 | Add isDebuggable=false to teacher app | `teacher_mobile_v2/android/app/build.gradle.kts` | 5 min |
| P2 | Standardize KDF iterations to 600K | `backend/src/core/security/encryption.py:21` | 10 min |
| P2 | Fix AES key derivation (deterministic salt) | `backend/src/core/security/crypto_utils.py:22` | 15 min |
| P2 | Rate limiter fail-open → fallback to memory | `backend/src/infrastructure/rate_limiter.py:103` | 20 min |
| P3 | Add Vercel security headers | `vercel.json` | 10 min |
| P3 | Change Dockerfile log level to info | `backend/Dockerfile:28` | 5 min |
| P3 | Add key.properties to .gitignore | `mobile-app/.gitignore`, `teacher_mobile_v2/.gitignore` | 5 min |

### Agent 5 (Web Portal Specialist) — P0 + P1 Web Portal Fixes
| Priority | Fix | Files | Est. Time |
|----------|-----|-------|-----------|
| P0 | Move tokens to server-set HttpOnly cookies | `web-portal/src/lib/auth.ts:1-21` | 60 min |
| P1 | Remove unsafe-inline from CSP script-src | `web-portal/next.config.js:19` | 15 min |
| P2 | Add middleware.ts for route protection | `web-portal/middleware.ts` (new file) | 45 min |
| P2 | Add CSRF token mechanism | `web-portal/src/lib/api.ts` | 45 min |
| P2 | Add client-side rate limiting on login | `web-portal/src/app/login/page.tsx` | 15 min |
| P3 | Sanitize backend error messages | `web-portal/src/app/login/page.tsx` | 10 min |
| P3 | Move hardcoded plan IDs to API | `web-portal/src/app/dashboard/subscription/page.tsx` | 30 min |

---

## Risk Assessment

### Current Risk Score: 9/10 (Before Fixes)

**Justification:**
- 10 CRITICAL findings — several immediately exploitable (unauthenticated endpoints, plaintext admin password, 30-day tokens, hardcoded secrets, pin_hash leak)
- No CI/CD means fixes can be bypassed or rolled back
- Sentry is actively exfiltrating PII to a third-party service
- Financial PII is publicly accessible and hardcoded in source

### Target Risk Score After P0 Fixes: 5/10

**What P0 eliminates:**
- Token theft window shrinks from 30 days to 30 minutes
- Admin account no longer trivially compromisable
- Financial PII no longer publicly exposed
- pin_hash no longer leaked to teachers
- Sentry stops capturing PII
- Hardcoded secrets removed from source control

### Target Risk Score After P0+P1 Fixes: 3/10

**What P1 additionally eliminates:**
- Mass assignment vulnerabilities closed
- Brute force protection in place
- Docker container no longer runs as root
- Dependencies pinned against supply chain attacks
- Basic CI/CD security gates operational

### Residual Risk (P2/P3 — Accepted for Now):
- HS256 JWT (acceptable for single-server deployment)
- SQL migrations on startup (acceptable with IF NOT EXISTS)
- Missing middleware on web portal (low impact since backend validates tokens)
- AI conversations unencrypted (Supabase RLS provides access control)

---

## Execution Order (Recommended)

1. **Phase 1 — Emergency (P0, 3-4 hours):** All 10 P0 items. These are exploitable right now.
2. **Phase 2 — Hardening (P1, 6-8 hours):** All 21 P1 items. These close privilege escalation and data corruption vectors.
3. **Phase 3 — Defense in Depth (P2, 4-6 hours):** Medium-severity items that reduce attack surface.
4. **Phase 4 — Cleanup (P3, 2-3 hours):** Low-severity items, best-practice improvements.

### Deployment After Each Phase
After Phase 1: `flyctl deploy --app darsak-backend`
After Phase 2: `flyctl deploy --app darsak-backend` + rebuild both mobile apps
After Phase 3: `flyctl deploy --app darsak-backend` + rebuild web portal
After Phase 4: Final deployment + verification

---

*Generated by CHIEF-DECISION | DarsakAI Agent Swarm | 2026-06-23*
