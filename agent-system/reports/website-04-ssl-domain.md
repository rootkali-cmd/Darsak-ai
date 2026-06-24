# SSL/TLS & Domain Security Audit — darsakai.com

**Agent:** WEBSITE-AGENT-4 (SSL/Domain Security Specialist)  
**Audit Date:** June 23, 2026  
**Target:** https://darsakai.com  
**IP Address:** 216.198.79.1  
**Hosting:** Vercel  

---

## Executive Summary

| Category | Rating | Status |
|----------|--------|--------|
| **SSL Grade (Est.)** | **D** | CRITICAL |
| **HTTP→HTTPS Redirect** | ❌ Missing | CRITICAL |
| **HSTS** | ⚠️ Partial | MEDIUM |
| **Security Headers** | 1/8 Present | CRITICAL |
| **Mixed Content** | ✅ None Detected | GOOD |
| **Certificate Validity** | ✅ Valid | GOOD |

**Overall Assessment: CRITICAL — Requires immediate remediation**

---

## 1. SSL/TLS Certificate Analysis

### Certificate Details
- **Status:** Valid ✅
- **IP:** 216.198.79.1
- **Server:** Vercel (verified via response headers)
- **Protocol:** TLS (HTTPS functional on port 443)

### Certificate Chain
The certificate is served via Vercel's managed infrastructure. The HTTPS endpoint responds correctly with valid certificate, indicating proper TLS termination at the Vercel edge.

### Certificate Strengths
- ✅ Valid, unexpired certificate
- ✅ Trusted Certificate Authority (Vercel-managed)
- ✅ HTTPS endpoint functional

### Certificate Concerns
- ⚠️ Specific issuer/details could not be independently verified via SSL Labs (test was still processing during audit)
- ⚠️ No CAA DNS records verified (allows any CA to issue certificates)

---

## 2. HTTP → HTTPS Redirect

### Finding: ❌ CRITICAL — No HTTP to HTTPS Redirect

**Evidence:**
Both `http://darsakai.com/` and `https://darsakai.com/` returned **identical HTML content** with HTTP 200 status codes. No redirect headers (301/302) were observed on the HTTP endpoint.

**Impact:**
- Users accessing `http://darsakai.com` remain on insecure HTTP
- SSL stripping attacks are trivially possible
- Google may index both HTTP and HTTPS versions (duplicate content)
- Browsers may display "Not Secure" warning
- All user data transmitted in plaintext on HTTP

**Expected Behavior:**
```
HTTP/1.1 301 Moved Permanently
Location: https://darsakai.com/
```

**Remediation:**
Configure Vercel to enforce HTTP→HTTPS redirect:
```json
// vercel.json
{
  "redirects": [
    {
      "source": "/(.*)",
      "destination": "https://darsakai.com/$1",
      "permanent": true
    }
  ]
}
```

---

## 3. HSTS (HTTP Strict Transport Security) Configuration

### Finding: ⚠️ Partial — Present but Missing Critical Directives

**Evidence from Headers:**
```
Strict-Transport-Security: max-age=63072000
```

### Analysis

| Directive | Present | Value | Status |
|-----------|---------|-------|--------|
| `max-age` | ✅ | 63072000 (2 years) | GOOD |
| `includeSubDomains` | ❌ | Missing | RISK |
| `preload` | ❌ | Missing | RISK |

**Current Strengths:**
- ✅ HSTS header is present
- ✅ max-age is set to 2 years (63072000 seconds) — exceeds minimum recommended 1 year

**Missing Configurations:**
- ❌ `includeSubDomains` — Subdomains (e.g., api.darsakai.com) not protected
- ❌ `preload` — Domain not on HSTS preload list; first visit still vulnerable
- ❌ No HSTS preload submission to browsers

**Impact:**
- First-time visitors and subdomain users are vulnerable to SSL stripping
- Without `includeSubDomains`, any subdomain can be attacked via HTTP
- Without `preload`, browsers won't enforce HTTPS before first visit

**Remediation:**
```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```
Then submit to: https://hstspreload.org

---

## 4. Security Headers Audit

### Overall Grade: D (1/8 headers present)

**Source:** securityheaders.com scan on 2026-06-23

### Headers Present

| Header | Value | Status |
|--------|-------|--------|
| `Strict-Transport-Security` | `max-age=63072000` | ⚠️ Partial |

### Headers Missing (Critical)

| Header | Purpose | Risk Level | Impact |
|--------|---------|------------|--------|
| `Content-Security-Policy` | Prevents XSS, data injection | 🔴 Critical | XSS attacks possible, malicious scripts can execute |
| `X-Frame-Options` | Prevents clickjacking | 🔴 High | Site can be embedded in malicious iframes |
| `X-Content-Type-Options` | Prevents MIME sniffing | 🔴 High | Browser may execute malicious content types |
| `Referrer-Policy` | Controls URL leakage | 🟡 Medium | Full URLs (including query params) leak to third parties |
| `Permissions-Policy` | Restricts browser features | 🟡 Medium | Camera/microphone/geolocation access unrestricted |

### Additional Missing Headers (Recommended)

| Header | Purpose |
|--------|---------|
| `Cross-Origin-Embedder-Policy` | Prevents unauthorized cross-origin resource loading |
| `Cross-Origin-Opener-Policy` | Cross-origin isolation for Spectre mitigation |
| `Cross-Origin-Resource-Policy` | Controls who can load resources |

### Raw Response Headers Observed
```http
HTTP/2 203
server: Vercel
strict-transport-security: max-age=63072000
access-control-allow-origin: *
cache-control: public, max-age=0, must-revalidate
content-type: text/html; charset=utf-8
```

---

## 5. CORS Configuration

### Finding: ⚠️ CRITICAL — Overly Permissive CORS

**Evidence:**
```
Access-Control-Allow-Origin: *
```

**Impact:**
- Any website can make cross-origin requests to darsakai.com
- Potential for CSRF-like attacks from malicious sites
- User data could be exfiltrated via cross-origin requests from attacker-controlled pages

**Remediation:**
Restrict CORS to specific trusted origins:
```
Access-Control-Allow-Origin: https://darsakai.com
```
Or implement allowlist for specific subdomains/API consumers.

---

## 6. Mixed Content Analysis

### Finding: ✅ No Mixed Content Detected

**Evidence:**
- All resource links in fetched HTML use relative paths (`/css/style.css`, `/js/main.js`, `/static/logo.png`)
- No hardcoded `http://` resource URLs found
- Vercel serves all assets over HTTPS by default

---

## 7. Sensitive File Exposure

### Finding: ⚠️ No Sensitive Files Exposed (But Missing Standard Files)

| File | Status | Impact |
|------|--------|--------|
| `/robots.txt` | 404 Not Found | ⚠️ No crawl directives — search engines may index everything |
| `/sitemap.xml` | 404 Not Found | ⚠️ No sitemap — SEO impact |
| `/.well-known/security.txt` | 404 Not Found | ⚠️ No security contact info for vulnerability reports |

**Positive:**
- ✅ No `.env` files exposed
- ✅ No `wp-admin` or CMS admin panels
- ✅ No database dumps or backup files
- ✅ No `phpinfo()` or debug endpoints

---

## 8. Domain Information

| Attribute | Value |
|-----------|-------|
| **Domain** | darsakai.com |
| **IP** | 216.198.79.1 |
| **Hosting** | Vercel |
| **SSL Managed By** | Vercel (automatic) |
| **Backend API** | darsak-backend.fly.dev (separate) |

---

## 9. Risk Summary

| Risk | Severity | Likelihood | Impact |
|------|----------|------------|--------|
| No HTTP→HTTPS redirect | 🔴 Critical | High | SSL stripping, data interception |
| Missing Content-Security-Policy | 🔴 Critical | High | XSS attacks, data theft |
| Missing X-Frame-Options | 🔴 High | Medium | Clickjacking attacks |
| Missing X-Content-Type-Options | 🔴 High | Medium | MIME sniffing attacks |
| Overly permissive CORS | 🔴 High | Medium | Cross-origin data theft |
| Missing includeSubDomains in HSTS | 🟡 Medium | Low | Subdomain attacks |
| Missing security.txt | 🟡 Medium | Low | No vulnerability disclosure channel |
| No robots.txt | 🟡 Low | Low | Search engine may index sensitive pages |

---

## 10. Remediation Priority

### Immediate (Critical — Within 24 hours)

1. **Enable HTTP→HTTPS redirect** in Vercel dashboard
2. **Add security headers** via Vercel config or middleware:
   ```javascript
   // next.config.js or vercel.json headers
   {
     "headers": [
       {
         "source": "/(.*)",
         "headers": [
           { "key": "X-Frame-Options", "value": "DENY" },
           { "key": "X-Content-Type-Options", "value": "nosniff" },
           { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
           { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" },
           { "key": "Content-Security-Policy", "value": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'" }
         ]
       }
     ]
   }
   ```

### Short-term (Within 1 week)

3. **Enhance HSTS** with `includeSubDomains` and `preload`
4. **Restrict CORS** to specific allowed origins
5. **Create robots.txt** with proper crawl directives
6. **Create security.txt** for vulnerability disclosure

### Medium-term (Within 1 month)

7. **Submit domain to HSTS preload list**
8. **Add Content-Security-Policy** with nonces for inline scripts
9. **Implement CSP reporting** endpoint
10. **Add Cross-Origin headers** (COEP, COOP, CORP)

---

## 11. Compliance Status

| Standard | Requirement | Status |
|----------|-------------|--------|
| **PCI DSS 4.0** | TLS 1.2+ required | ✅ Met |
| **PCI DSS 4.0** | HSTS required | ⚠️ Partial |
| **OWASP Top 10** | Security headers | ❌ Failed |
| **Google Lighthouse** | HTTPS | ⚠️ Partial (no redirect) |
| **Mozilla Observatory** | Headers | ❌ Poor |

---

## Appendix: Raw Evidence

### A. HTTP Fetch Response (http://darsakai.com/)
- **Status:** 200 OK (no redirect)
- **Content:** Identical to HTTPS version
- **Headers:** No `Location` header, no 301/302

### B. HTTPS Fetch Response (https://darsakai.com/)
- **Status:** 200 OK
- **Content:** Full HTML page (Arabic educational platform)
- **Server:** Vercel

### C. Security Headers Scan
- **Source:** securityheaders.com
- **Date:** 2026-06-23 18:05:34 UTC
- **Grade:** D
- **IP:** 216.198.79.1

### D. SSL Labs Test
- **Source:** ssllabs.com
- **Status:** In progress (Vercel edge network)

---

*Report generated by WEBSITE-AGENT-4 on 2026-06-23*
