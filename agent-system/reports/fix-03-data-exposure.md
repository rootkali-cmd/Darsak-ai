# Fix-03: Data Exposure & PII Leakage Vulnerabilities

**Agent:** FIX-AGENT-3 (Data Exposure Fixer)
**Date:** 2026-06-23
**Status:** All fixes applied

---

## Fix 1: Remove `pin_hash` from API Responses (CRITICAL)

**File:** `backend/src/api/students.py:84-97`
**Severity:** CRITICAL (P0) — Exposes password-equivalent hash in API responses

### Before

```python
def _serialize_student(s: dict) -> dict:
    return {
        "id": str(s.get("id", "")),
        "teacher_id": str(s.get("teacher_id", "")),
        "full_name": s.get("full_name", ""),
        "code": s.get("code", ""),
        "parent_phone": s.get("parent_phone"),
        "group_id": str(s.get("group_id")) if s.get("group_id") else None,
        "pin_hash": s.get("pin_hash"),            # <-- EXPOSED HASH
        "has_pin": s.get("pin_hash") is not None,
        "is_active": s.get("is_active", True),
        "created_at": str(s.get("created_at", "")),
        "updated_at": str(s.get("updated_at", "")),
    }
```

### After

```python
def _serialize_student(s: dict) -> dict:
    return {
        "id": str(s.get("id", "")),
        "teacher_id": str(s.get("teacher_id", "")),
        "full_name": s.get("full_name", ""),
        "code": s.get("code", ""),
        "parent_phone": s.get("parent_phone"),
        "group_id": str(s.get("group_id")) if s.get("group_id") else None,
        "has_pin": s.get("pin_hash") is not None,
        "is_active": s.get("is_active", True),
        "created_at": str(s.get("created_at", "")),
        "updated_at": str(s.get("updated_at", "")),
    }
```

**Impact:** `_serialize_student()` is used in `PUT /{student_id}` response. The `pin_hash` was returned in the API response body, allowing any authenticated teacher to extract the bcrypt hash of their students' PINs. The `StudentResponse` schema in `src/schemas/student.py` correctly does NOT include `pin_hash`, but this serialization helper bypassed it.

---

## Fix 2: Sentry Traces Rate + PII Scrubbing

**File:** `backend/src/main.py:10-37`
**Severity:** HIGH (P1) — 100% trace sampling floods Sentry; no PII scrubbing

### Before

```python
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN", ""),
    traces_sample_rate=1.0,
    environment=os.environ.get("ENVIRONMENT", "development"),
    release=f"darsakai-backend@{os.environ.get('VERSION', '1.0.0')}",
)
```

### After

```python
import sentry_sdk
import re


def _sentry_scrub_pii(event, hint):
    """Scrub PII (email, name, phone, tokens) from Sentry events before sending."""
    import json

    def _scrub_value(val):
        if not isinstance(val, str):
            return val
        # Mask email addresses
        val = re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]', val)
        # Mask phone numbers (Egyptian: +20/0 followed by 10-11 digits)
        val = re.sub(r'(?:\+20|0)?1[0125]\d{8}', '[PHONE]', val)
        # Mask JWT tokens
        val = re.sub(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+', '[TOKEN]', val)
        # Mask Bearer tokens
        val = re.sub(r'Bearer\s+[a-zA-Z0-9._-]+', 'Bearer [TOKEN]', val)
        return val

    def _scrub_dict(d):
        for key in list(d.keys()):
            if key.lower() in ('email', 'phone', 'password', 'pin', 'pin_hash',
                               'access_token', 'refresh_token', 'secret_key',
                               'supabase_service_role_key', 'authorization'):
                d[key] = '[SCRUBBED]'
            elif isinstance(d[key], str):
                d[key] = _scrub_value(d[key])
            elif isinstance(d[key], dict):
                _scrub_dict(d[key])
            elif isinstance(d[key], list):
                for item in d[key]:
                    if isinstance(item, dict):
                        _scrub_dict(item)

    try:
        # Scrub request data
        if 'request' in event:
            if 'headers' in event['request']:
                _scrub_dict(event['request']['headers'])
            if 'data' in event['request']:
                if isinstance(event['request']['data'], dict):
                    _scrub_dict(event['request']['data'])
        # Scrub extra data
        if 'extra' in event:
            _scrub_dict(event['extra'])
        # Scrub breadcrumbs
        if 'breadcrumbs' in event and 'values' in event['breadcrumbs']:
            for bc in event['breadcrumbs']['values']:
                if 'data' in bc and isinstance(bc['data'], dict):
                    _scrub_dict(bc['data'])
    except Exception:
        pass

    return event


sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN", ""),
    traces_sample_rate=0.1,
    environment=os.environ.get("ENVIRONMENT", "development"),
    release=f"darsakai-backend@{os.environ.get('VERSION', '1.0.0')}",
    before_send=_sentry_scrub_pii,
)
```

**Impact:** `traces_sample_rate` reduced from 1.0 (100%) to 0.1 (10%) — Sentry cost/performance impact reduced 10x. Added `before_send` hook that scrubs emails, phone numbers, JWT tokens, Bearer tokens, and sensitive field keys (password, pin, access_token, etc.) before any data is sent to Sentry.

---

## Fix 3: Add Content-Security-Policy Header

**File:** `backend/src/main.py:588-600`
**Severity:** MEDIUM (P1) — Missing CSP allows XSS injection vectors

### Before

```python
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return response
```

### After

```python
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    )
    return response
```

**Impact:** Adds a strict CSP policy:
- `default-src 'self'` — blocks all external resource loading by default
- `script-src 'self'` — no inline scripts, no external CDN scripts
- `style-src 'self' 'unsafe-inline'` — allows Tailwind/utility CSS (needed for Flutter web + inline styles)
- `img-src 'self' data: https:` — allows images from self, data URIs, and HTTPS sources
- `frame-ancestors 'none'` — prevents clickjacking (reinforces X-Frame-Options)
- `base-uri 'self'` + `form-action 'self'` — prevents base tag injection and form hijacking

---

## Fix 4: Fix CORS Configuration

**File:** `backend/src/core/config.py:50-53`
**Severity:** MEDIUM (P1) — HTTP origins allow MITM credential theft

### Before

```python
CORS_ORIGINS: list[str] = [
    "http://localhost:3000",
    "http://localhost:8000",
]
```

### After

```python
CORS_ORIGINS: list[str] = [
    "https://localhost:3000",
    "https://localhost:8000",
]
```

**Impact:** HTTP localhost origins removed. HTTP origins are vulnerable to MITM attacks where an attacker on the same network can intercept cookies/credentials sent with `allow_credentials=True`. HTTPS is required for secure credential transmission. Production domains (darsakai.com, vercel.app) are already HTTPS in `main.py`.

---

## Summary

| Fix | Severity | File | Issue |
|-----|----------|------|-------|
| 1. Remove `pin_hash` | CRITICAL | `students.py:84` | PIN hash exposed in API responses |
| 2. Sentry PII scrub | HIGH | `main.py:10` | 100% trace rate + no PII scrubbing |
| 3. Content-Security-Policy | MEDIUM | `main.py:588` | Missing CSP header |
| 4. CORS HTTP origins | MEDIUM | `config.py:50` | HTTP origins with credentials |

**Files modified:**
- `backend/src/api/students.py` — removed `pin_hash` from `_serialize_student()`
- `backend/src/main.py` — Sentry config with PII scrubbing + CSP header
- `backend/src/core/config.py` — HTTP → HTTPS for localhost CORS origins
