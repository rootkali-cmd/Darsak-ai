# CYBER-AGENT-4: Infrastructure Security Audit

**Audit Date:** 2026-06-23
**Scope:** Docker, Fly.io, CI/CD, Android apps, Cryptography, Database, Configuration
**Auditor:** CYBER-AGENT-4 (Infrastructure Security Specialist)

---

## Severity: HIGH

**Overall Risk Score: 7/10**

---

## Findings

### CRITICAL FINDINGS

---

### Finding: Secret Key Hardcoded as Default Value
- **Location:** `backend/src/core/config.py:45`
- **Issue:** `SECRET_KEY` has a default value of `"change-me-in-production-use-openssl-rand"`. While the `get_settings()` function raises a `ValueError` if this default is detected (line 71), the default itself is a known insecure string that could be accidentally used in misconfigured environments.
- **Risk:** If environment variables are not loaded (e.g., missing `.env` file in production, Docker misconfiguration), the application would either crash or use the hardcoded weak secret. Attackers could forge JWT tokens if they discover this default was used.
- **Fix:** Remove the default value entirely. Set `SECRET_KEY: str = ""` and rely solely on the validation check. Better yet, add a check in the Dockerfile or CI that fails if `SECRET_KEY` is not set.

---

### Finding: Access Token Expiry Set to 30 Days
- **Location:** `backend/src/core/config.py:47`
- **Issue:** `ACCESS_TOKEN_EXPIRE_MINUTES = 43200` (30 days). Refresh token expires in 365 days (line 48).
- **Risk:** Compromised tokens remain valid for an extremely long window. No token rotation mechanism is visible. Stolen tokens grant access for up to a year (refresh) or 30 days (access) without revocation.
- **Fix:** Reduce access token to 15-60 minutes. Implement refresh token rotation. Add a token revocation list or session-based invalidation.

---

### Finding: Hardcoded Instapay Username in Migrations
- **Location:** `backend/src/main.py:295`
- **Issue:** Line contains hardcoded PII: `username='ahmed-mahmoud-1@instapay'` in a SQL UPDATE statement that runs on every startup.
- **Risk:** This username is committed to source control. If this is a real payment account identifier, it constitutes a leak of financial PII. Additionally, this line overwrites the config on every server start, making it impossible to change without code modification.
- **Fix:** Move payment configuration to environment variables or a database-only admin configuration table. Remove hardcoded PII from source code.

---

### Finding: SERVICE_ROLE_KEY Used in Migration HTTP Calls
- **Location:** `backend/src/main.py:352-367`
- **Issue:** The `SUPABASE_SERVICE_ROLE_KEY` (the most privileged key in Supabase, bypasses RLS) is sent via plain HTTP headers in migration calls. The key is extracted from settings and passed directly.
- **Risk:** If request logging (e.g., Sentry, reverse proxy logs) captures headers, the service role key could be exposed. This key has full database access bypassing all Row Level Security policies.
- **Fix:** Use a dedicated migration tool with its own credentials. Rotate the service role key periodically. Ensure no middleware or proxy logs capture the Authorization header.

---

### HIGH FINDINGS

---

### Finding: No CI/CD Pipeline Exists
- **Location:** `.github/workflows/` (directory does not exist)
- **Issue:** There are zero GitHub Actions workflow files. No automated testing, linting, security scanning, or deployment gates exist.
- **Risk:** Code can be pushed directly to production without any security checks. No dependency vulnerability scanning (e.g., Dependabot, Snyk). No SAST/DAST. No container image scanning. No automated linting.
- **Fix:** Implement at minimum:
  - CI workflow with `ruff`/`mypy` for Python
  - `pip-audit` or `safety` for dependency scanning
  - GitHub container registry scanning
  - CD pipeline with deployment approval gates
  - Pre-commit hooks for secret detection

---

### Finding: Python Dependencies Use Unbounded Version Ranges
- **Location:** `backend/requirements.txt:1-27`
- **Issue:** All dependencies use `>=` with no upper bound (e.g., `fastapi>=0.110.0`, `cryptography>=44.0.0`). No lock file (`requirements.lock` or `poetry.lock`) exists.
- **Risk:** A malicious or compromised package update could be automatically pulled during build. Known CVEs in newer versions cannot be pinned. Reproducible builds are impossible.
- **Fix:** Generate a lock file with pinned exact versions. Use `pip-compile` or Poetry. Implement Dependabot with version update PRs. Run `pip-audit` in CI.

---

### Finding: Docker Runs as Root User
- **Location:** `backend/Dockerfile:1-28`
- **Issue:** No `USER` directive in the Dockerfile. The container runs as root by default.
- **Risk:** If an attacker escapes the application sandbox or finds a container escape vulnerability, they gain root access inside the container. This violates the principle of least privilege.
- **Fix:** Add a non-root user:
  ```dockerfile
  RUN useradd --create-home --shell /bin/bash appuser
  USER appuser
  ```
  Ensure the `/app` directory is owned by the non-root user.

---

### Finding: No .dockerignore File
- **Location:** `backend/` (no `.dockerignore` found)
- **Issue:** The `COPY . .` command on line 12 copies the entire `backend/` directory into the container, including `.env`, `__pycache__`, `*.pyc`, `.git/`, test files, and potentially secrets.
- **Risk:** Secrets in `.env` files could be baked into the Docker image layer. The image contains unnecessary attack surface (test code, dev dependencies, git history).
- **Fix:** Create `backend/.dockerignore`:
  ```
  .env
  .env.*
  __pycache__/
  *.pyc
  .git/
  .pytest_cache/
  tests/
  *.md
  ```

---

### Finding: Hardcoded Default Admin Email
- **Location:** `backend/src/core/config.py:62`
- **Issue:** `ADMIN_EMAIL: str = "ahmedtelly32@gmail.com"` is hardcoded as a default. This is a real email address committed to source control.
- **Risk:** Exposure of a real admin email in a public or semi-public repository enables social engineering, phishing, and targeted attacks against the platform administrator.
- **Fix:** Remove the default value. Use environment variables only. Rotate the admin account if this email has been exposed in a public repo.

---

### Finding: Teacher App Missing `isDebuggable = false`
- **Location:** `teacher_mobile_v2/android/app/build.gradle.kts:46-53`
- **Issue:** The `release` build type (line 49) does not set `isDebuggable = false`. The `debug` type also does not explicitly set it. Unlike the student app which explicitly sets `isDebuggable = false` in release (line 46).
- **Risk:** If the debug flag defaults to true, the release APK can be debugged with JDWP, allowing attackers to inspect memory, set breakpoints, and extract secrets at runtime.
- **Fix:** Add `isDebuggable = false` to the `release` buildType in `teacher_mobile_v2/android/app/build.gradle.kts`.

---

### Finding: Both Android Apps Missing `allowBackup = false`
- **Location:** `mobile-app/android/app/build.gradle.kts`, `teacher_mobile_v2/android/app/build.gradle.kts`
- **Issue:** Neither app sets `android:allowBackup="false"` in `defaultConfig`. The Flutter default is `true`.
- **Risk:** Users can use `adb backup` to extract the entire app's data, including SharedPreferences, SQLite databases, and cached credentials. An attacker with physical access can clone the app data.
- **Fix:** Add to `defaultConfig`:
  ```kotlin
  manifestPlaceholders["allowBackup"] = "false"
  ```
  Or in `AndroidManifest.xml`:
  ```xml
  android:allowBackup="false"
  android:fullBackupContent="false"
  ```

---

### MEDIUM FINDINGS

---

### Finding: Sentry Traces Sample Rate at 100%
- **Location:** `backend/src/main.py:12-17`
- **Issue:** `traces_sample_rate=1.0` means 100% of all transactions are sent to Sentry. This includes potentially sensitive request paths and response data.
- **Risk:** High bandwidth cost. Sensitive data (PII, tokens, student data) could be captured in traces and sent to Sentry. Increases attack surface if Sentry is compromised.
- **Fix:** Reduce to `0.1` (10%) or lower. Configure Sentry data scrubbing. Add `send_default_pii=False` and scrub sensitive headers.

---

### Finding: Health Check Endpoint Exposed Without Authentication
- **Location:** `backend/src/main.py:636-644`
- **Issue:** `/health` and `/health/deep` (lines 636, 647) are unauthenticated. The deep health check exposes database connectivity details and cache state.
- **Risk:** An attacker can probe infrastructure details (Supabase connectivity, Redis availability) without credentials. The deep health endpoint reveals internal architecture.
- **Fix:** Restrict `/health/deep` to internal networks or add basic auth. Keep `/health` lightweight for load balancers.

---

### Finding: JWT Uses HS256 (Symmetric) Algorithm
- **Location:** `backend/src/core/config.py:46`, `backend/src/core/security/auth.py:28`
- **Issue:** `ALGORITHM = "HS256"` uses HMAC-SHA256 with a shared secret for JWT signing. Both signing and verification use the same key.
- **Risk:** If the `SECRET_KEY` is compromised (via source code leak, env dump, etc.), an attacker can forge any JWT. Asymmetric algorithms (RS256) allow the signing key to be kept secret while verification uses a public key.
- **Fix:** Consider migrating to RS256 (RSA) or ES256 (ECDSA) for JWT signing. At minimum, ensure the secret key is at least 256 bits and stored securely.

---

### Finding: KDF Iterations Discrepancy Between Modules
- **Location:** `backend/src/core/security/crypto_utils.py:29` vs `backend/src/core/security/encryption.py:21`
- **Issue:** `crypto_utils.py` uses 600,000 PBKDF2 iterations, while `encryption.py` uses 100,000 iterations.
- **Risk:** The 100K iteration module provides weaker key derivation. OWASP recommends at least 600,000 iterations for PBKDF2-SHA256 as of 2023.
- **Fix:** Standardize to 600,000+ iterations in both files.

---

### Finding: HMAC Key Used as Fallback for AES Key Derivation
- **Location:** `backend/src/core/security/crypto_utils.py:13-31`
- **Issue:** When `AES_ENCRYPTION_KEY` is not set, the code derives the AES key from `HMAC_SECRET_KEY` using PBKDF2. However, it generates a new random salt each time `_get_aes_key()` is called (line 22: `salt = secrets.token_bytes(16)`), meaning the same HMAC key produces a different AES key every time.
- **Risk:** Encrypted data cannot be decrypted if the key is re-derived with a different salt. This would cause data loss. The function appears to be used for license keys (line 34), so the impact depends on whether encrypted payloads need to persist.
- **Fix:** Store the salt alongside encrypted data, or use a deterministic derivation (e.g., HKDF) when no explicit AES key is provided.

---

### Finding: Rate Limiter Fails Open When Redis is Down
- **Location:** `backend/src/infrastructure/rate_limiter.py:103`
- **Issue:** Line 103: `return True  # Fail open if Redis is down` — when Redis is unavailable, all requests are allowed.
- **Risk:** During Redis outages, the application becomes fully unprotected against brute force, DDoS, and credential stuffing attacks.
- **Fix:** Fall back to in-memory rate limiting (which already exists in the code) instead of failing open. The current `RateLimiter` class already handles this fallback, but the `RedisRateLimiter.is_allowed` method independently fails open.

---

### Finding: SQL Migrations Run on Every Startup
- **Location:** `backend/src/main.py:49-343`
- **Issue:** ~100 SQL statements execute via HTTP RPC on every server startup. This includes `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE ADD COLUMN IF NOT EXISTS` statements.
- **Risk:** If the Supabase RPC endpoint is slow or down, startup is delayed. The `exec_sql` RPC function must have elevated privileges, increasing attack surface. Race conditions could occur with multiple instances.
- **Fix:** Use a dedicated migration tool (Alembic, Supabase Migrations). Run migrations as a separate CI/CD step, not at application startup.

---

### LOW FINDINGS

---

### Finding: Debug Log Level in Production Dockerfile
- **Location:** `backend/Dockerfile:28`
- **Issue:** `"--log-level", "debug"` is hardcoded in the Gunicorn command.
- **Risk:** Verbose debug logging in production can expose sensitive request/response data, increase log storage costs, and degrade performance.
- **Fix:** Change to `"--log-level", "info"` or use an environment variable to control log level.

---

### Finding: Gunicorn Worker Count is 1
- **Location:** `backend/Dockerfile:21`
- **Issue:** `"--workers", "1"` limits the server to a single worker process.
- **Risk:** Under load, requests queue up. The `fly.toml` allows 25 concurrent connections but only 1 worker can process them. While this may be intentional for the 512MB VM, it limits throughput.
- **Fix:** Consider `"--workers", "2"` with `"--threads", "2"` for better concurrency within the 512MB memory limit.

---

### Finding: Keystore Password in Build Config
- **Location:** `mobile-app/android/app/build.gradle.kts:33-41`, `teacher_mobile_v2/android/app/build.gradle.kts:34-42`
- **Issue:** Both apps load signing credentials from `key.properties` file which contains passwords in plaintext.
- **Risk:** If `key.properties` is committed to source control (it's not in `.gitignore`), signing keys are exposed. The `.gitignore` files do not list `key.properties`.
- **Fix:** Add `key.properties` to `.gitignore` in both mobile app directories. Use environment variables or CI secret injection for signing in CI/CD.

---

### Finding: CORS Allows Credentials with Broad Origins
- **Location:** `backend/src/main.py:558-566`
- **Issue:** `allow_credentials=True` is set alongside multiple origins. The CORS configuration includes development origins (`localhost:3000`, `localhost:8000`) alongside production.
- **Risk:** If a developer accidentally adds a wildcard or broad origin, CSRF protection is weakened. Development origins should not be in production CORS.
- **Fix:** Separate CORS configs for development and production using environment variables. Remove localhost origins from the production CORS list.

---

### Finding: Vercel Config Missing Security Headers
- **Location:** `vercel.json`
- **Issue:** The Vercel deployment config has no security headers configured (no `X-Frame-Options`, `CSP`, `HSTS`, etc.).
- **Risk:** The web portal deployed via Vercel lacks basic browser security protections.
- **Fix:** Add security headers in `vercel.json`:
  ```json
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {"key": "X-Frame-Options", "value": "DENY"},
        {"key": "X-Content-Type-Options", "value": "nosniff"},
        {"key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains"}
      ]
    }
  ]
  ```

---

### Finding: Supabase Client Singleton Without Health Checks
- **Location:** `backend/src/core/security/supabase_repo.py:21-53`
- **Issue:** The Supabase client is created once and cached forever. No reconnection logic if the connection becomes stale.
- **Risk:** After network disruptions, the cached client may silently fail. The circuit breaker helps, but the client itself is never recreated.
- **Fix:** Add periodic health checks or TTL-based client recreation.

---

## Summary Table

| # | Finding | Severity | File | Risk Score |
|---|---------|----------|------|------------|
| 1 | Hardcoded SECRET_KEY default | CRITICAL | config.py:45 | 9/10 |
| 2 | 30-day access token expiry | CRITICAL | config.py:47 | 8/10 |
| 3 | Hardcoded Instapay PII | CRITICAL | main.py:295 | 8/10 |
| 4 | SERVICE_ROLE_KEY in HTTP headers | CRITICAL | main.py:352 | 8/10 |
| 5 | No CI/CD pipeline | HIGH | .github/ | 8/10 |
| 6 | Unbounded dependency versions | HIGH | requirements.txt | 7/10 |
| 7 | Docker runs as root | HIGH | Dockerfile | 7/10 |
| 8 | No .dockerignore | HIGH | backend/ | 6/10 |
| 9 | Hardcoded admin email | HIGH | config.py:62 | 6/10 |
| 10 | Teacher app missing isDebuggable=false | HIGH | build.gradle.kts | 7/10 |
| 11 | Missing allowBackup=false | HIGH | build.gradle.kts | 6/10 |
| 12 | Sentry 100% trace rate | MEDIUM | main.py:14 | 5/10 |
| 13 | Unauthenticated health endpoints | MEDIUM | main.py:636 | 4/10 |
| 14 | HS256 JWT algorithm | MEDIUM | config.py:46 | 5/10 |
| 15 | KDF iteration discrepancy | MEDIUM | crypto_utils.py / encryption.py | 5/10 |
| 16 | AES key derivation with random salt | MEDIUM | crypto_utils.py:22 | 5/10 |
| 17 | Rate limiter fails open | MEDIUM | rate_limiter.py:103 | 5/10 |
| 18 | SQL migrations on every startup | MEDIUM | main.py:49 | 4/10 |
| 19 | Debug log level in production | LOW | Dockerfile:28 | 3/10 |
| 20 | Single Gunicorn worker | LOW | Dockerfile:21 | 3/10 |
| 21 | Keystore not in .gitignore | LOW | build.gradle.kts | 4/10 |
| 22 | CORS with dev origins | LOW | main.py:558 | 3/10 |
| 23 | Vercel missing security headers | LOW | vercel.json | 3/10 |
| 24 | Supabase singleton no health check | LOW | supabase_repo.py:21 | 3/10 |

---

## Recommendations Priority

1. **Immediate (P0):** Remove hardcoded secrets, add `.dockerignore`, add `USER` to Dockerfile
2. **This Week (P1):** Implement CI/CD with security gates, pin dependency versions, add `allowBackup=false`
3. **This Month (P2):** Reduce token expiry, implement token rotation, standardize KDF iterations, add security headers to Vercel
4. **Next Sprint (P3):** Migrate to RS256 JWT, add Sentry data scrubbing, implement proper migration tooling

---

*Report generated by CYBER-AGENT-4 — Infrastructure Security Specialist*
