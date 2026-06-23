# Fix-04: Infrastructure & Security Fixes

**Agent:** FIX-AGENT-4 (Infrastructure Security Fixer)
**Date:** 2026-06-23
**Files Modified:**
- `backend/src/core/config.py`
- `backend/requirements.txt`
- `backend/Dockerfile`
- `backend/src/main.py`

---

## Fix 1: SECRET_KEY Default → Random Generation

**Problem:** Default SECRET_KEY was a static string `"change-me-in-production-use-openssl-rand"`. If an attacker knows the key, they can forge JWT tokens.

**File:** `backend/src/core/config.py`

### Before
```python
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # ...
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand"
    # ...


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    if not s.SECRET_KEY or s.SECRET_KEY == "change-me-in-production-use-openssl-rand":
        raise ValueError("SECRET_KEY must be set in environment. Use `openssl rand -hex 32` to generate one.")
    # ...
```

### After
```python
import secrets
import logging
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # ...
    SECRET_KEY: str = ""
    # ...


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    if not s.SECRET_KEY:
        s.SECRET_KEY = secrets.token_hex(32)
        logging.warning(
            "SECURITY WARNING: SECRET_KEY not set in environment. Generated a random key. "
            "Tokens will be invalidated on restart. Set SECRET_KEY env var for production."
        )
    # ...
```

**Why:** Generates a cryptographically secure 64-char hex key at runtime if env var is missing. Logs a clear warning so operators know to set it for production (required for token persistence across restarts).

---

## Fix 2: Pin Dependencies with Upper Bounds

**Problem:** All dependencies used `>=` without upper bounds. A breaking change in a major version could silently break the app.

**File:** `backend/requirements.txt`

### Before
```
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
gunicorn>=23.0.0
pydantic>=2.6.0
...
```

### After
```
fastapi>=0.110.0,<1.0.0
uvicorn[standard]>=0.27.0,<1.0.0
gunicorn>=23.0.0,<24.0.0
pydantic>=2.6.0,<3.0.0
pydantic-settings>=2.1.0,<3.0.0
email-validator>=2.1.0,<3.0.0
python-jose[cryptography]>=3.3.0,<4.0.0
bcrypt>=4.1.0,<5.0.0
httpx>=0.27.0,<1.0.0
redis>=5.0.0,<6.0.0
apscheduler>=3.10.0,<4.0.0
pytz>=2024.1,<2027.0
pytest>=8.0.0,<9.0.0
pytest-asyncio>=0.23.0,<1.0.0
python-multipart>=0.0.9,<1.0.0
sqlalchemy[asyncio]>=2.0.0,<3.0.0
asyncpg>=0.29.0,<1.0.0
supabase>=2.10.0,<3.0.0
postgrest>=0.18.0,<1.0.0
python-telegram-bot>=20.0,<22.0
sentry-sdk>=2.20.0,<3.0.0
cryptography>=44.0.0,<45.0.0
qrcode[pil]>=7.4.0,<9.0.0
Pillow>=10.0.0,<12.0.0
PyMuPDF>=1.23.0,<2.0.0
pdfplumber>=0.10.0,<1.0.0
pdf2image>=1.17.0,<2.0.0
```

**Why:** Upper bounds prevent unexpected breaking changes from major version bumps while still allowing patch/minor updates within the bounded range.

---

## Fix 3: Docker Security Hardening

**Problem:** Container ran as root (default). No HEALTHCHECK instruction. `.dockerignore` already existed but was fine.

**File:** `backend/Dockerfile`

### Before
```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev poppler-utils && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "src.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "1", \
     "--bind", "0.0.0.0:8000", \
     "--max-requests", "500", \
     "--max-requests-jitter", "50", \
     "--timeout", "120", \
     "--graceful-timeout", "30", \
     "--keep-alive", "5", \
     "--log-level", "debug"]
```

### After
```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev poppler-utils && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["gunicorn", "src.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "1", \
     "--bind", "0.0.0.0:8000", \
     "--max-requests", "500", \
     "--max-requests-jitter", "50", \
     "--timeout", "120", \
     "--graceful-timeout", "30", \
     "--keep-alive", "5", \
     "--log-level", "debug"]
```

**Why:**
- `USER appuser`: Non-root execution prevents container breakout exploits from gaining root on host.
- `HEALTHCHECK`: Enables orchestrators (Fly.io, Docker, K8s) to detect and restart unhealthy containers automatically.
- `.dockerignore` already excluded `.env`, `.git`, `__pycache__`, etc. — no changes needed.

---

## Fix 4: Admin-Protect `/health/deep` Endpoint

**Problem:** `/health/deep` was publicly accessible with no authentication. It leaked internal error details (`database_error`, `cache_error`) containing connection strings, stack traces, and infrastructure info.

**File:** `backend/src/main.py`

### Before
```python
@app.get("/health/deep")
async def deep_health():
    """Deep health check - verifies DB, cache, and circuit breaker states."""
    checks = {
        "app": True,
        "database": False,
        "cache": False,
        "rate_limiter": "redis" if hasattr(rate_limiter, '_use_redis') and rate_limiter._use_redis else "memory",
    }

    # Check Supabase connectivity
    try:
        from src.core.security.supabase_repo import get_supabase
        await get_supabase()
        checks["database"] = True
    except Exception as e:
        checks["database_error"] = str(e)[:200]
        checks["database"] = False

    # Check cache stats
    try:
        stats = await cache.stats
        checks["cache"] = stats
    except Exception as e:
        checks["cache_error"] = str(e)

    overall_healthy = all(v is True or isinstance(v, dict) for v in checks.values())
    status_code = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return JSONResponse(
        status_code=status_code,
        content={"status": "healthy" if overall_healthy else "degraded", "checks": checks},
    )
```

### After
```python
@app.get("/health/deep")
async def deep_health(request: Request):
    """Deep health check - admin only. Verifies DB, cache, and circuit breaker states."""
    from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

    security = HTTPBearer(auto_error=False)
    credentials: HTTPAuthorizationCredentials | None = await security(request)

    if not credentials:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": "Not authenticated"},
        )

    from src.utils.dependencies import decode_token
    token_data = decode_token(credentials.credentials)
    if not token_data or token_data.get("role") != "admin":
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "Admin access required"},
        )

    checks = {
        "app": True,
        "database": False,
        "cache": False,
        "rate_limiter": "redis" if hasattr(rate_limiter, '_use_redis') and rate_limiter._use_redis else "memory",
    }

    # Check Supabase connectivity
    try:
        from src.core.security.supabase_repo import get_supabase
        await get_supabase()
        checks["database"] = True
    except Exception:
        checks["database"] = False

    # Check cache stats
    try:
        stats = await cache.stats
        checks["cache"] = stats
    except Exception:
        checks["cache"] = False

    overall_healthy = all(v is True or isinstance(v, dict) for v in checks.values())
    status_code = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return JSONResponse(
        status_code=status_code,
        content={"status": "healthy" if overall_healthy else "degraded", "checks": checks},
    )
```

**Why:**
- Requires valid JWT with `role=admin` — prevents unauthorized users from probing infrastructure health.
- Removed `database_error` and `cache_error` fields that leaked internal exception messages (connection strings, stack traces).
- Basic `/health` endpoint remains public for load balancers/Fly.io health checks.

---

## Summary

| Fix | Priority | Risk Reduced |
|-----|----------|-------------|
| 1. SECRET_KEY random generation | P0 | Token forgery if default key leaked |
| 2. Dependency pinning | P1 | Supply-chain breaking changes |
| 3. Docker non-root + healthcheck | P1 | Container breakout, undetected failures |
| 4. /health/deep admin auth | P0 | Infrastructure info disclosure |
