# Fix-06: Rate Limiting & CSRF Protection

> **Agent:** FIX-AGENT-6
> **Date:** 2026-06-23
> **Priority:** P1
> **Status:** COMPLETE

---

## Summary

Added distributed-safe rate limiting using Redis (Upstash), admin login lockout, CSRF origin validation, and migrated all in-memory rate limiters to Redis.

---

## Fix 1: Global Rate Limiter — Tiered Limits + Redis Init

### Problem
The `RateLimiter` was initialized without a Redis URL (`RateLimiter()`), so it always fell back to in-memory even when Upstash was configured. The middleware used a combined IP+auth-header key which diluted per-IP tracking.

### What Changed

**`backend/src/infrastructure/rate_limiter.py`** — Added `set_redis_url()` method, `increment()`, `ban_check()`, `set_ban()` helpers:

```python
# BEFORE
class RateLimiter:
    def __init__(self, redis_url=None, window=60):
        if redis_url and REDIS_AVAILABLE:
            self._redis_limiter = RedisRateLimiter(redis_url, window=window)
    # No set_redis_url, no increment/ban_check/set_ban

# AFTER
class RateLimiter:
    def __init__(self, redis_url=None, window=60):
        self._window = window
        if redis_url and REDIS_AVAILABLE:
            self._redis_limiter = RedisRateLimiter(redis_url, window=window)

    def set_redis_url(self, redis_url: str):
        if REDIS_AVAILABLE and redis_url:
            self._redis_limiter = RedisRateLimiter(redis_url, window=self._window)

    async def increment(self, key, window=60) -> int: ...
    async def ban_check(self, ban_key, ban_duration) -> int: ...
    async def set_ban(self, ban_key, ban_duration): ...
```

**`backend/src/main.py`** — Fixed init + tiered limits:

```python
# BEFORE
rate_limiter = RateLimiter()  # No Redis URL

# AFTER (in _init_services)
if settings.REDIS_URL:
    rate_limiter.set_redis_url(settings.REDIS_URL)
await rate_limiter.connect()
```

```python
# BEFORE (middleware)
max_requests = 120
if path in ("/api/auth/login", ...):
    max_requests = 10

# AFTER (middleware)
if path in ("/api/auth/login", "/api/auth/register", "/api/students/login", "/api/admin/login"):
    max_requests = 10  # Auth endpoints: 10/min
elif method in ("POST", "PUT", "PATCH", "DELETE"):
    max_requests = 30  # Write operations: 30/min
else:
    max_requests = 120  # Read operations: 120/min
```

Also added `X-RateLimit-Limit` response header and fixed IP extraction to use `X-Forwarded-For`.

---

## Fix 2: Admin Login Rate Limiting

### Problem
Admin login (`/api/admin/login`) had zero rate limiting. Brute-force attacks possible.

### What Changed

**`backend/src/api/admin.py`** — Added 5-attempt lockout with 5-minute ban:

```python
# BEFORE
@router.post("/login")
async def admin_login(request: Request):
    body = await request.json()
    if email != settings.ADMIN_EMAIL or password != settings.ADMIN_PASSWORD:
        raise HTTPException(401, "Invalid credentials")

# AFTER
ADMIN_LOGIN_MAX_ATTEMPTS = 5
ADMIN_LOGIN_BAN_SECONDS = 300  # 5 minutes

@router.post("/login")
async def admin_login(request: Request):
    client_ip = _get_client_ip(request)

    # Check distributed ban via Redis
    remaining_ban = await rate_limiter.ban_check(f"admin_login:{client_ip}", ADMIN_LOGIN_BAN_SECONDS)
    if remaining_ban > 0:
        raise HTTPException(429, f"تم حظر هذا العنوان مؤقتاً... {remaining_ban} ثانية.")

    if email != settings.ADMIN_EMAIL or password != settings.ADMIN_PASSWORD:
        count = await rate_limiter.increment(f"admin_login_fail:{client_ip}", ADMIN_LOGIN_WINDOW_SECONDS)
        if count >= ADMIN_LOGIN_MAX_ATTEMPTS:
            await rate_limiter.set_ban(f"admin_login:{client_ip}", ADMIN_LOGIN_BAN_SECONDS)
        raise HTTPException(401, "Invalid credentials")
```

Key design:
- **5 failed attempts** per minute per IP → **5-minute lockout**
- Tracked in Redis sorted sets (distributed-safe across Fly.io workers)
- Ban key auto-expires after lockout duration

---

## Fix 3: CSRF Origin Validation Middleware

### Problem
No CSRF protection. Cookie-based auth sessions (browser) could be exploited by cross-origin state-changing requests.

### What Changed

**`backend/src/main.py`** — New `csrf_middleware`:

```python
@app.middleware("http")
async def csrf_middleware(request: Request, call_next):
    # Skip safe methods
    if request.method in ("GET", "HEAD", "OPTIONS"):
        return await call_next(request)

    # Skip if Bearer token present (mobile/API clients)
    if request.headers.get("authorization", "").startswith("Bearer "):
        return await call_next(request)

    # Skip if no auth cookies present
    if "access_token" not in request.cookies:
        return await call_next(request)

    # Cookie-based session on state-changing request → validate Origin/Referer
    origin = request.headers.get("origin", "")
    referer = request.headers.get("referer", "")
    source_url = origin or referer

    if source_url:
        parsed = urlparse(source_url)
        source_origin = f"{parsed.scheme}://{parsed.netloc}"
        if source_origin not in allowed_origins:
            return JSONResponse(status_code=403, content={"detail": "CSRF validation failed"})

    return await call_next(request)
```

Key design:
- **Mobile apps** using `Authorization: Bearer <token>` → **exempt** (no cookies involved)
- **Browser sessions** using cookies → **Origin/Referer validated** against CORS allow list
- GET/HEAD/OPTIONS → always pass through
- No cookie present → pass through (non-browser client)

---

## Fix 4: Migrate Student Login Rate Limiter to Redis

### Problem
`students.py` used `_student_login_attempts: dict` (process-local). On Fly.io with multiple workers, rate limits were ineffective — each worker had its own dict.

### What Changed

**`backend/src/api/students.py`** — Replaced in-memory dict with Redis:

```python
# BEFORE
_student_login_attempts: dict[str, dict] = {}

def _check_rate_limit(code: str) -> None:
    state = _get_login_state(code)
    state["attempts"] = [t for t in state["attempts"] if now - t < LOGIN_WINDOW_SECONDS]
    if len(state["attempts"]) >= LOGIN_ATTEMPTS_PER_WINDOW:
        # Escalating bans stored in memory

# AFTER
from src.infrastructure.rate_limiter import rate_limiter

async def _check_rate_limit(code: str) -> None:
    ban_remaining = await rate_limiter.ban_check(f"student_ban:{code}", LOGIN_BAN_DURATIONS[-1])
    if ban_remaining > 0:
        raise HTTPException(429, f"تم حظر حسابك مؤقتاً... {ban_remaining} ثانية.")

    count = await rate_limiter.increment(f"student_login:{code}", LOGIN_WINDOW_SECONDS)
    if count >= LOGIN_ATTEMPTS_PER_WINDOW:
        ban_level = await rate_limiter.increment(f"student_ban_level:{code}", 600)
        ban_index = min(ban_level - 1, len(LOGIN_BAN_DURATIONS) - 1)
        ban_duration = LOGIN_BAN_DURATIONS[ban_index]
        await rate_limiter.set_ban(f"student_ban:{code}", ban_duration)
        raise HTTPException(429, f"تم حظر حسابك مؤقتاً... {ban_duration // 60} دقائق.")
```

Also migrated `auth.py` brute-force protection the same way:

```python
# BEFORE
_failed_attempts: dict[str, list[float]] = {}
_bruteforce_lock = asyncio.Lock()

async def _check_bruteforce(email: str) -> bool:
    async with _bruteforce_lock:
        attempts = _failed_attempts.get(email, [])

# AFTER
async def _check_bruteforce(email: str) -> bool:
    ban_remaining = await rate_limiter.ban_check(f"auth_lockout:{email}", LOCKOUT_DURATION_SECONDS)
    return ban_remaining > 0

async def _record_failed_attempt(email: str) -> None:
    count = await rate_limiter.increment(f"auth_fail:{email}", LOCKOUT_WINDOW_SECONDS)
    if count >= MAX_FAILED_ATTEMPTS:
        await rate_limiter.set_ban(f"auth_lockout:{email}", LOCKOUT_DURATION_SECONDS)
```

---

## Files Modified

| File | Changes |
|------|---------|
| `backend/src/infrastructure/rate_limiter.py` | Added `set_redis_url()`, `increment()`, `ban_check()`, `set_ban()` |
| `backend/src/main.py` | Fixed Redis init, tiered rate limits, CSRF middleware |
| `backend/src/api/admin.py` | Added admin login rate limiting (5 attempts → 5min ban) |
| `backend/src/api/auth.py` | Migrated brute-force protection to Redis |
| `backend/src/api/students.py` | Migrated student login rate limiter to Redis, made functions async |

---

## Rate Limit Summary

| Endpoint | Limit | Window | Lockout |
|----------|-------|--------|---------|
| Auth login/register/student login | 10 req/min per IP | 60s | — |
| Admin login | 5 failures per IP | 60s | 5 min ban |
| Student login (per code) | 4 failures per code | 60s | 5 min, then 10 min |
| Teacher auth (brute-force) | 5 failures per email | 15 min | 15 min ban |
| Write operations (POST/PUT/DELETE) | 30 req/min per IP | 60s | — |
| Read operations (GET) | 120 req/min per IP | 60s | — |
| General API | 120 req/min per IP | 60s | — |

---

## CSRF Protection Summary

| Request Type | Protection |
|--------------|------------|
| Mobile apps (Bearer token header) | Exempt — no CSRF check |
| Browser with cookies on GET/HEAD/OPTIONS | Exempt — safe methods |
| Browser with cookies on POST/PUT/DELETE | Origin/Referer validated against CORS allow list |
| Direct API calls without cookies | Exempt — no session to protect |
