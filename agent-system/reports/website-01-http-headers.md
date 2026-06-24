# WEBSITE-AGENT-1: HTTP Security Headers Audit

**Target:** https://darsakai.com  
**Date:** 2026-06-23  
**Auditor:** WEBSITE-AGENT-1 (HTTP Security Headers Specialist)  
**Platform:** Vercel (Frankfurt, fra1)

---

## URL: https://darsakai.com/ (Main Page)

**Status:** 200 OK | **Response Time:** ~21s cache age

### Headers Returned

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=63072000` |
| `Access-Control-Allow-Origin` | `*` |
| `Cache-Control` | `public, max-age=0, must-revalidate` |
| `Content-Type` | `text/html; charset=utf-8` |
| `Server` | `Vercel` |
| `ETag` | `"2296edaa45e50402bba504410dc2ab55"` |
| `Content-Length` | `20101` |
| `Accept-Ranges` | `bytes` |
| `X-Vercel-Cache` | `HIT` |
| `X-Vercel-Id` | `fra1::td4k7-...` |

### Findings

#### Strict-Transport-Security (HSTS)
- **Status:** Present (Partial)
- **Value:** `max-age=63072000` (~2 years)
- **Risk:** Without `includeSubDomains`, subdomains could be downgraded to HTTP. Without `preload`, browser won't enforce HSTS before first visit.
- **Fix:** Set `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`

#### Content-Security-Policy (CSP)
- **Status:** MISSING
- **Value:** Not set
- **Risk:** No protection against XSS, data injection, or clickjacking. Malicious scripts can be injected freely. Third-party scripts have unrestricted access.
- **Fix:** Implement a strict CSP, e.g.:
  ```
  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' https://darsak-backend.fly.dev; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
  ```

#### X-Content-Type-Options
- **Status:** MISSING
- **Value:** Not set
- **Risk:** Browsers may MIME-sniff responses, potentially executing content as a different type (e.g., treating a JSON response as HTML).
- **Fix:** Set `X-Content-Type-Options: nosniff`

#### X-Frame-Options
- **Status:** MISSING
- **Value:** Not set
- **Risk:** Site can be embedded in iframes on other domains, enabling clickjacking attacks.
- **Fix:** Set `X-Frame-Options: DENY` (or `SAMEORIGIN` if embedding is needed)

#### X-XSS-Protection
- **Status:** MISSING
- **Value:** Not set
- **Risk:** Legacy browsers may not activate XSS filters. While modern browsers have deprecated this header, it still provides defense-in-depth for older clients.
- **Fix:** Set `X-XSS-Protection: 1; mode=block`

#### Referrer-Policy
- **Status:** MISSING
- **Value:** Not set
- **Risk:** Full referrer URLs (including query parameters and path) are leaked to third-party sites, potentially exposing sensitive information.
- **Fix:** Set `Referrer-Policy: strict-origin-when-cross-origin` or `no-referrer`

#### Permissions-Policy
- **Status:** MISSING
- **Value:** Not set
- **Risk:** Browser features (camera, microphone, geolocation, etc.) are not restricted. Malicious scripts could attempt to access these APIs.
- **Fix:** Set `Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()`

#### Cache-Control
- **Status:** Present
- **Value:** `public, max-age=0, must-revalidate`
- **Risk:** Low. The page revalidates on every request, which is acceptable for a landing page. However, sensitive pages (if any) should use `no-store`.
- **Fix:** Fine for public landing page. Ensure login/dashboard pages use `no-store, no-cache`.

#### Set-Cookie
- **Status:** No cookies set
- **Value:** N/A
- **Risk:** None (no session cookies on public page).
- **Fix:** When cookies are used, ensure: `HttpOnly; Secure; SameSite=Lax; Path=/`

#### Server
- **Status:** Present (Information Leak)
- **Value:** `Vercel`
- **Risk:** Reveals hosting platform. Attackers can target Vercel-specific vulnerabilities.
- **Fix:** Set `Server:` header to empty or remove entirely (Vercel may not allow this — mitigated by Vercel's security posture).

#### X-Powered-By
- **Status:** Not present (GOOD)
- **Value:** N/A
- **Risk:** None. Framework info is not leaked.
- **Fix:** Keep as-is. Ensure no backend framework leaks this.

#### CORS Headers
- **Status:** Present (OVERLY PERMISSIVE)
- **Value:** `Access-Control-Allow-Origin: *`
- **Risk:** Any website can make cross-origin requests to darsakai.com. If the site serves authenticated content or APIs, this allows CSRF-style data exfiltration from any domain.
- **Fix:** Restrict to specific trusted origins:
  ```
  Access-Control-Allow-Origin: https://darsakai.com
  ```
  Or use a whitelist for known frontend domains.

---

## URL: https://darsakai.com/login (404 - Page Not Found)

**Status:** 404 Not Found | **Platform:** Vercel

### Headers Returned

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=63072000` |
| `Cache-Control` | `public, max-age=0, must-revalidate` |
| `Content-Type` | `text/plain; charset=utf-8` |
| `Server` | `Vercel` |
| `X-Vercel-Error` | `NOT_FOUND` |
| `X-Vercel-Id` | `fra1::vhwbs-...` |

### Findings

#### Information Disclosure via Vercel Headers
- **Status:** Present
- **Value:** `X-Vercel-Error: NOT_FOUND`, `X-Vercel-Id: fra1::...`
- **Risk:** Reveals internal infrastructure details (edge region, request ID format). `X-Vercel-Id` contains a traceable request hash.
- **Fix:** Remove these headers in `vercel.json`:
  ```json
  {
    "headers": [
      {
        "source": "/(.*)",
        "headers": [
          { "key": "X-Vercel-Error", "value": "" },
          { "key": "X-Vercel-Id", "value": "" }
        ]
      }
    ]
  }
  ```

#### Missing Security Headers
- **Status:** All security headers MISSING (same as main page)
- **Risk:** 404 pages are also vulnerable to the same attacks as the main page.
- **Fix:** Apply security headers globally via `vercel.json` (see recommendations).

---

## URL: https://darsakai.com/dashboard (404 - Page Not Found)

**Status:** 404 Not Found | **Platform:** Vercel

### Findings
Identical to `/login` 404 page. Same header profile:
- HSTS: present (partial)
- All security headers: MISSING
- Vercel info leak headers: present
- No cookies set

---

## URL: https://darsakai.com/api (404 - Page Not Found)

**Status:** 404 Not Found | **Platform:** Vercel

### Findings
Identical to `/login` and `/dashboard` 404 pages. Same header profile:
- HSTS: present (partial)
- All security headers: MISSING
- Vercel info leak headers: present
- No cookies set

**Note:** The actual API backend is at `https://darsak-backend.fly.dev`. This `/api` path on darsakai.com returns a Vercel 404, confirming the frontend and backend are on separate domains. CORS policy on the Vercel frontend is relevant here — any origin can read responses from this domain.

---

## Summary Table

| Header | Main (/) | /login | /dashboard | /api |
|--------|----------|--------|------------|------|
| `Strict-Transport-Security` | PARTIAL (no includeSubDomains) | PARTIAL | PARTIAL | PARTIAL |
| `Content-Security-Policy` | MISSING | MISSING | MISSING | MISSING |
| `X-Content-Type-Options` | MISSING | MISSING | MISSING | MISSING |
| `X-Frame-Options` | MISSING | MISSING | MISSING | MISSING |
| `X-XSS-Protection` | MISSING | MISSING | MISSING | MISSING |
| `Referrer-Policy` | MISSING | MISSING | MISSING | MISSING |
| `Permissions-Policy` | MISSING | MISSING | MISSING | MISSING |
| `Cache-Control` | OK | OK | OK | OK |
| `Set-Cookie` | None | None | None | None |
| `Server` | Vercel (LEAK) | Vercel (LEAK) | Vercel (LEAK) | Vercel (LEAK) |
| `X-Powered-By` | Not present | Not present | Not present | Not present |
| `Access-Control-Allow-Origin` | `*` (OVERLY OPEN) | N/A | N/A | N/A |
| `X-Vercel-Error` | Not present | LEAK | LEAK | LEAK |
| `X-Vercel-Id` | LEAK | LEAK | LEAK | LEAK |

---

## Risk Summary

| Category | Risk Level | Details |
|----------|-----------|---------|
| XSS Protection | HIGH | No CSP, no X-XSS-Protection, no X-Content-Type-Options |
| Clickjacking | HIGH | No X-Frame-Options, no CSP frame-ancestors |
| MITM / Downgrade | MEDIUM | HSTS present but missing includeSubDomains and preload |
| Information Disclosure | MEDIUM | Server header reveals Vercel; X-Vercel-Id leaks trace IDs |
| CORS | HIGH | `Access-Control-Allow-Origin: *` allows any origin |
| Data Leakage | MEDIUM | No Referrer-Policy, no Permissions-Policy |

---

## Overall Score: F

**Justification:**
- 0 of 6 critical security headers are implemented (CSP, X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy)
- CORS is fully open (`*`) with no restrictions
- HSTS is incomplete (missing `includeSubDomains` and `preload`)
- Multiple information disclosure headers are present
- No cookies to evaluate (site appears to be a static landing page)

---

## Recommended Fixes

### 1. Add `vercel.json` (or update existing) with global security headers:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://darsak-backend.fly.dev; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
        },
        {
          "key": "Strict-Transport-Security",
          "value": "max-age=63072000; includeSubDomains; preload"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        },
        {
          "key": "Permissions-Policy",
          "value": "camera=(), microphone=(), geolocation=(), interest-cohort=()"
        },
        {
          "key": "X-Vercel-Error",
          "value": ""
        },
        {
          "key": "X-Vercel-Id",
          "value": ""
        }
      ]
    },
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Access-Control-Allow-Origin",
          "value": "https://darsakai.com"
        },
        {
          "key": "Cache-Control",
          "value": "no-store, no-cache, must-revalidate"
        }
      ]
    },
    {
      "source": "/(login|dashboard|admin)(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-store, no-cache, must-revalidate, private"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        }
      ]
    }
  ]
}
```

### 2. Fix CORS to be origin-specific:
Instead of `Access-Control-Allow-Origin: *`, only allow `https://darsakai.com` and the teacher domain.

### 3. Remove Vercel information leak headers:
Use the `vercel.json` headers config to suppress `X-Vercel-Error` and `X-Vercel-Id`.

### 4. For the backend API (Fly.io):
The backend at `darsak-backend.fly.dev` should also have these headers applied in `src/main.py` via FastAPI middleware:
```python
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains; preload"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Access-Control-Allow-Origin"] = "https://darsakai.com"
    return response
```

---

*Report generated by WEBSITE-AGENT-1 on 2026-06-23*
