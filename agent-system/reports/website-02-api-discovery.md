# API Discovery Report — darsakai.com

| Field | Value |
|-------|-------|
| **Agent** | WEBSITE-AGENT-2 (API Discovery Specialist) |
| **Target** | `https://darsakai.com` |
| **Scan Date** | 2026-06-23 |
| **Scan Type** | Exposed Endpoint / Sensitive File Discovery |
| **Total URLs Tested** | 17 |

---

## Executive Summary

The domain `darsakai.com` is a **static marketing/landing page** hosted as plain HTML/CSS/JS. It is **not** the backend application server — the actual backend API runs on Fly.io at `https://darsak-backend.fly.dev`. No sensitive files, credentials, source code, or API endpoints were found exposed on `darsakai.com`. One notable finding is a `403 Forbidden` on `/wp-admin`, suggesting a WordPress-like request filter is in place despite the site being static HTML.

**Overall Risk: LOW** — The marketing site is clean, but the missing `robots.txt` and `sitemap.xml` are SEO concerns, and the 403 on `/wp-admin` warrants investigation into the hosting stack.

---

## Detailed URL Scan Results

| # | URL | HTTP Status | First ~200 Chars of Response Body | Security Risk? | Severity |
|---|-----|-------------|-----------------------------------|----------------|----------|
| 1 | `/robots.txt` | **404** | *(empty — Not Found)* | No | SAFE |
| 2 | `/sitemap.xml` | **404** | *(empty — Not Found)* | No | SAFE |
| 3 | `/api` | **404** | *(empty — Not Found)* | No | SAFE |
| 4 | `/api/health` | **404** | *(empty — Not Found)* | No | SAFE |
| 5 | `/api/v1` | **404** | *(empty — Not Found)* | No | SAFE |
| 6 | `/.env` | **404** | *(empty — Not Found)* | No | SAFE |
| 7 | `/.git/HEAD` | **404** | *(empty — Not Found)* | No | SAFE |
| 8 | `/.git/config` | **404** | *(empty — Not Found)* | No | SAFE |
| 9 | `/package.json` | **404** | *(empty — Not Found)* | No | SAFE |
| 10 | `/debug` | **404** | *(empty — Not Found)* | No | SAFE |
| 11 | `/trace` | **404** | *(empty — Not Found)* | No | SAFE |
| 12 | `/admin` | **404** | *(empty — Not Found)* | No | SAFE |
| 13 | `/wp-admin` | **403** | *(Forbidden — server returned a 403 response)* | Low | LOW |
| 14 | `/phpmyadmin` | **404** | *(empty — Not Found)* | No | SAFE |
| 15 | `/server-info` | **404** | *(empty — Not Found)* | No | SAFE |
| 16 | `/config.json` | **404** | *(empty — Not Found)* | No | SAFE |
| 17 | `/credentials` | **404** | *(empty — Not Found)* | No | SAFE |

---

## Analysis by Category

### 1. Sensitive Files (CRITICAL checks)
| File | Status | Notes |
|------|--------|-------|
| `.env` | 404 | Not exposed — good |
| `.git/HEAD` | 404 | Not exposed — good |
| `.git/config` | 404 | Not exposed — good |
| `package.json` | 404 | Not exposed — good |
| `config.json` | 404 | Not exposed — good |
| `credentials` | 404 | Not exposed — good |

**Verdict:** No sensitive configuration files or source code exposed.

### 2. API Endpoints
| Endpoint | Status | Notes |
|----------|--------|-------|
| `/api` | 404 | No API on marketing site |
| `/api/health` | 404 | No health endpoint |
| `/api/v1` | 404 | No versioned API |

**Verdict:** The marketing domain does not serve any API. The backend API lives at `https://darsak-backend.fly.dev` (Fly.io), not on `darsakai.com`.

### 3. Admin / Debug Panels
| Path | Status | Notes |
|------|--------|-------|
| `/admin` | 404 | No admin panel |
| `/wp-admin` | 403 | Server returns 403 — likely a hosting/WAF rule blocking WordPress-style paths |
| `/debug` | 404 | Not exposed |
| `/trace` | 404 | Not exposed |
| `/server-info` | 404 | Not exposed |
| `/phpmyadmin` | 404 | Not exposed |

**Verdict:** No admin panels or debug interfaces exposed. The 403 on `/wp-admin` suggests the hosting provider (or a reverse proxy) actively blocks common WordPress attack paths — this is **defensive behavior**, not a vulnerability.

### 4. SEO / Crawling Files
| File | Status | Notes |
|------|--------|-------|
| `/robots.txt` | 404 | Missing — SEO concern |
| `/sitemap.xml` | 404 | Missing — SEO concern |

**Verdict:** Neither `robots.txt` nor `sitemap.xml` exist. While not a security issue, this is an SEO best-practice gap.

---

## Site Architecture Findings

### What darsakai.com IS
- A **static HTML marketing/landing page** (Arabic RTL, education platform)
- Uses plain CSS (`css/style.css`) and JS (`js/main.js`)
- Contains: Hero section, Features, App downloads, Pricing, Contact form, Footer
- Pages found: `/pages/downloads`, `/pages/privacy`, `/pages/terms`, `/pages/refund-policy`, `/pages/faq`
- Static assets: `/static/favicon.png`, `/static/logo.png`

### What darsakai.com IS NOT
- NOT the backend API server
- NOT a WordPress site (despite `/wp-admin` returning 403)
- NOT hosting any dynamic application logic

### Backend Location
The actual API backend is deployed at:
```
https://darsak-backend.fly.dev
```
(This is the Fly.io deployment, separate from the marketing domain.)

---

## Findings & Recommendations

### No Critical or High Issues Found

| Priority | Finding | Recommendation |
|----------|---------|----------------|
| LOW | `/wp-admin` returns 403 instead of 404 | Investigate hosting stack — the 403 suggests a rule/waf blocking this path. Consider if the hosting provider is WordPress-oriented (unnecessary for a static site). |
| INFO | No `robots.txt` | Add a `robots.txt` to control crawler behavior and protect any non-public paths |
| INFO | No `sitemap.xml` | Add a `sitemap.xml` for SEO purposes |
| INFO | Contact form has no visible CAPTCHA | The contact form on the homepage (`/#contact`) appears to submit to `#` (no action) — verify it's not processing without spam protection |

---

## Summary Table — Risk Distribution

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 0 |
| LOW | 1 (`/wp-admin` 403) |
| SAFE | 16 |
| **Total** | **17** |

---

## Next Steps

1. **Backend API Scan** — The real attack surface is `https://darsak-backend.fly.dev/api/*`. This should be scanned separately for auth bypass, data leakage, injection, etc.
2. **Mobile APK Analysis** — Download and decompile the APK files hosted on GitHub to check for hardcoded secrets, API keys, or insecure configurations.
3. **SSL/TLS Audit** — Verify the TLS configuration on both `darsakai.com` and `darsak-backend.fly.dev`.

---

*Report generated by WEBSITE-AGENT-2 (API Discovery Specialist)*
*Scan completed: 2026-06-23*
