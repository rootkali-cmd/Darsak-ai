# CYBER-AGENT-5: Web Portal Security Audit

**Audit Date:** 2026-06-22
**Scope:** `web-portal/` — Next.js 14.2.3 application
**Severity:** HIGH
**Risk Score:** 7/10

---

## Summary

The DarsakAI web portal has a **solid security foundation** with good security headers, no XSS via `dangerouslySetInnerHTML`, and proper input validation via Zod. However, the authentication architecture has critical weaknesses — tokens stored in `localStorage` and client-side cookies without `HttpOnly` make the application vulnerable to token theft via XSS. The absence of server-side middleware means route protection is entirely client-side.

---

## Findings

### Finding 1: Tokens Stored in localStorage (XSS-Accessible)

- **Location:** `src/lib/auth.ts:13-21`
- **Issue:** Both `access_token` and `refresh_token` are stored in `localStorage`. Any XSS vulnerability in the application or its dependencies (e.g., compromised npm package) can exfiltrate these tokens via `localStorage.getItem('access_token')`.
- **Risk:** **CRITICAL** — Full account takeover. An attacker with XSS can steal the JWT and impersonate any teacher.
- **Fix:** Store tokens exclusively in `HttpOnly`, `Secure`, `SameSite=Strict` cookies set by the **server** (via API response headers). Remove all `localStorage` token access from the client.

### Finding 2: Cookies Set via `document.cookie` (Not HttpOnly)

- **Location:** `src/lib/auth.ts:1-5`
- **Issue:** The `setCookie()` helper uses `document.cookie` to set `access_token` and `refresh_token` cookies. Cookies set this way **cannot** have the `HttpOnly` flag, meaning JavaScript (and thus XSS payloads) can read them.
- **Risk:** **HIGH** — Tokens are accessible to any client-side script, defeating the purpose of using cookies over localStorage.
- **Fix:** Set cookies server-side in the login API response using `Set-Cookie` headers with `HttpOnly; Secure; SameSite=Strict`. The frontend should not set auth cookies directly.

### Finding 3: No Server-Side Middleware for Route Protection

- **Location:** (no `middleware.ts` exists)
- **Issue:** The entire dashboard (`/dashboard/*`) is protected only by the client-side `ProtectedRoute` component, which checks `localStorage` for a token. Without server-side middleware, the full page HTML/JS is served to unauthenticated users before React hydrates and redirects. An attacker can view the page source, bundled JS, and any data fetched before auth check completes.
- **Risk:** **MEDIUM** — Information leakage of page structure and client-side logic. Also creates a race condition window where unauthenticated users can briefly access the dashboard.
- **Fix:** Add a `middleware.ts` at the web-portal root that validates the JWT token (from cookie or header) before serving protected routes. Next.js middleware runs server-side before the page is rendered.

### Finding 4: CSP Allows `unsafe-inline` for Scripts

- **Location:** `next.config.js:19`
- **Issue:** The Content Security Policy includes `script-src 'self' 'unsafe-inline'`. The `unsafe-inline` directive allows execution of inline `<script>` tags, which significantly weakens XSS protection.
- **Risk:** **MEDIUM** — If any injection vector exists (e.g., through a compromised dependency or a reflected input), inline script execution is permitted by CSP.
- **Fix:** Remove `unsafe-inline` from `script-src`. For Next.js, use nonce-based CSP or hash-based CSP. Next.js supports `next/script` with nonces. For styles, `unsafe-inline` is acceptable for Tailwind but should eventually move to nonces.

### Finding 5: No CSRF Protection

- **Location:** All API calls in `src/lib/api.ts`
- **Issue:** The application uses Bearer token authentication (which provides some CSRF resistance), but there is no explicit CSRF token mechanism. The `withCredentials: true` setting on Axios means cookies are sent with requests. If an attacker can trick a user into making a cross-origin request, cookies (including auth cookies) would be sent.
- **Risk:** **MEDIUM** — Combined with the non-HttpOnly cookies, CSRF attacks could allow an attacker to perform actions on behalf of authenticated users.
- **Fix:** Implement CSRF tokens for state-changing requests, or ensure `SameSite=Strict` on all auth cookies and remove `withCredentials: true` if relying solely on Bearer tokens.

### Finding 6: Download API Route — No Authentication

- **Location:** `src/app/api/download/[file]/route.ts:47-62`
- **Issue:** The `/api/download/[file]` endpoint is publicly accessible without any authentication check. Anyone can request any file in the `FILE_RELEASE_MAP` or fall back to `DEFAULT_TAG`. While the route only redirects to GitHub releases (not serving files directly), it reveals the release structure.
- **Risk:** **LOW** — Information disclosure of release tags. No direct file serving risk due to 302 redirect.
- **Fix:** Add authentication middleware to the download route, or accept this as intentional (public downloads).

### Finding 7: Hardcoded Plan IDs and Support Phone in Client Bundle

- **Location:** `src/app/dashboard/subscription/page.tsx:31-69`
- **Issue:** Subscription plan UUIDs (`3628fdf5-3a79-43c3-8c04-211f31704e07`, etc.), support phone number (`01031524947`), and the API base URL are hardcoded in the client bundle. This data is visible in the JavaScript source.
- **Risk:** **LOW** — Information leakage. Plan IDs could be used to tamper with subscription requests if backend validation is weak.
- **Fix:** Fetch plan data from the API instead of hardcoding. Phone numbers should come from environment variables or API responses.

### Finding 8: No Rate Limiting on Login/Register Forms

- **Location:** `src/app/login/page.tsx`, `src/app/register/page.tsx`
- **Issue:** The login and registration forms have no client-side rate limiting or account lockout mechanisms. While the backend may have rate limiting, the frontend allows unlimited submission attempts.
- **Risk:** **MEDIUM** — Brute force attacks on login credentials. Credential stuffing attacks.
- **Fix:** Add client-side rate limiting (e.g., disable button for N seconds after failed attempt). Ensure backend has proper rate limiting and account lockout.

### Finding 9: Error Messages May Leak Backend Details

- **Location:** `src/app/login/page.tsx:43`, `src/app/register/page.tsx:53`
- **Issue:** Error messages from the backend (`error.response?.data?.detail`) are displayed directly to users via `toast.error()`. Backend error details (stack traces, database errors) could be exposed.
- **Risk:** **LOW** — Information disclosure that could aid attackers in understanding the backend architecture.
- **Fix:** Map backend errors to generic user-friendly messages. Never display raw backend error details.

### Finding 10: Sentry Error Reporting Without Source Map Protection

- **Location:** `src/components/ui/ErrorBoundary.tsx:27`, `@sentry/nextjs` dependency
- **Issue:** Sentry is configured to capture exceptions with component stacks. If source maps are uploaded to Sentry and not properly access-controlled, they could reveal the full application source code.
- **Risk:** **LOW** — Source code disclosure if Sentry project is not properly secured.
- **Fix:** Ensure Sentry projects have proper access controls. Restrict source map uploads to CI/CD. Use `sentry.properties` to control access.

### Finding 11: Subscription Guard Bypassed for Specific Path

- **Location:** `src/app/dashboard/layout.tsx:13`
- **Issue:** The `SubscriptionGuard` is bypassed when `pathname === '/dashboard/subscription'`. While this is intentional (to allow users to view/activate subscriptions), it means unauthenticated users with a valid token could access subscription data without an active subscription.
- **Risk:** **LOW** — Intentional design, but worth noting that subscription page is accessible without active subscription.
- **Fix:** Acceptable as-is. The subscription page needs to be accessible for users to activate.

---

## Positive Findings (Good Security Practices)

| Practice | Location |
|----------|----------|
| No `dangerouslySetInnerHTML` usage | Entire codebase |
| Zod schema validation on forms | `login/page.tsx`, `register/page.tsx` |
| Security headers configured | `next.config.js:11-20` |
| `X-Frame-Options: DENY` | `next.config.js:12` |
| `Strict-Transport-Security` with preload | `next.config.js:15` |
| `frame-ancestors 'none'` in CSP | `next.config.js:19` |
| Download route has filename validation | `api/download/[file]/route.ts:53` |
| React auto-escapes all JSX output | All components |
| No `.env` files committed | Repository root |
| Proper `SameSite=Lax` on cookies | `auth.ts:4` |
| Token refresh with automatic redirect | `api.ts:31-66` |
| ErrorBoundary catches runtime errors | `ErrorBoundary.tsx` |

---

## Recommendations (Priority Order)

1. **[CRITICAL]** Move token storage to `HttpOnly` cookies set by the server. Remove `localStorage` token access entirely.
2. **[HIGH]** Add `middleware.ts` for server-side route protection on `/dashboard/*`.
3. **[HIGH]** Remove `unsafe-inline` from CSP `script-src`. Use nonces or hashes.
4. **[MEDIUM]** Implement CSRF token protection for state-changing API requests.
5. **[MEDIUM]** Add client-side rate limiting on login/register forms.
6. **[LOW]** Sanitize backend error messages before displaying to users.
7. **[LOW]** Move hardcoded plan IDs and phone numbers to API-driven data.

---

## Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `src/lib/auth.ts` | 39 | Token management |
| `src/lib/api.ts` | 174 | Axios API client + interceptors |
| `src/lib/utils.ts` | 44 | Utility functions |
| `src/app/layout.tsx` | 36 | Root layout |
| `src/app/providers.tsx` | 49 | React Query + auth sync |
| `src/app/login/page.tsx` | 201 | Login form |
| `src/app/register/page.tsx` | 230 | Registration form |
| `src/app/dashboard/layout.tsx` | 47 | Dashboard layout + guards |
| `src/app/dashboard/page.tsx` | 278 | Dashboard home |
| `src/app/dashboard/settings/page.tsx` | 263 | Settings (profile, password) |
| `src/app/dashboard/students/page.tsx` | 287 | Student management |
| `src/app/dashboard/students/[id]/page.tsx` | 374 | Student report + AI analysis |
| `src/app/dashboard/grades/page.tsx` | 232 | Grade management |
| `src/app/dashboard/attendance/page.tsx` | 275 | Attendance + barcode scanner |
| `src/app/dashboard/invoices/page.tsx` | 364 | Invoice management |
| `src/app/dashboard/groups/page.tsx` | 191 | Group management |
| `src/app/dashboard/subscription/page.tsx` | 621 | Subscription + payment |
| `src/app/dashboard/qr/page.tsx` | 167 | QR code generation |
| `src/app/dashboard/downloads/page.tsx` | 92 | App downloads |
| `src/app/dashboard/assistants/page.tsx` | 96 | Assistant management |
| `src/app/api/download/[file]/route.ts` | 62 | Download redirect |
| `src/app/api/update/check/route.ts` | 11 | Version check |
| `src/components/layout/ProtectedRoute.tsx` | 31 | Client-side auth guard |
| `src/components/layout/SubscriptionGuard.tsx` | 61 | Subscription check |
| `src/components/layout/Sidebar.tsx` | 132 | Navigation sidebar |
| `src/components/layout/Header.tsx` | 123 | Header with notifications |
| `src/components/ui/ErrorBoundary.tsx` | 53 | Error boundary + Sentry |
| `src/components/QuizGenerator.tsx` | 98 | Quiz generator |
| `next.config.js` | 27 | Next.js config + security headers |
| `package.json` | 43 | Dependencies |

---

*Report generated by CYBER-AGENT-5 — DarsakAI Agent Swarm*
