# WEBSITE-AGENT-5: Frontend Code Security Audit

**Audit Date:** 2026-06-23
**Target:** darsakai.com (landing/marketing website)
**Pages Audited:** Main page, Downloads page, Privacy, Terms, FAQ, Refund Policy
**Login Page:** Not found at `/login` or `/pages/login` (returns 404) — login is mobile-app-only

---

## Page: https://darsakai.com/ (Main Landing Page)

### Finding: Contact Form Missing CSRF Token
- **Location:** `<form class="contact-form" action="#" method="POST">` in main page HTML
- **Issue:** The contact form uses POST method but contains no CSRF token (`<input type="hidden" name="_csrf" ...>`) or any anti-CSRF mechanism (no token in headers, no same-site cookie reliance visible).
- **Risk:** **Medium** — An attacker can craft a malicious page that auto-submits this form on behalf of a victim. Since the form action is `#` (dead/non-functional), this is currently a low-impact UX bug. However, if the form is later wired to a real backend endpoint, it becomes an active CSRF vulnerability.
- **Fix:** Add a CSRF token to the form (hidden field) and validate it server-side. Ensure `SameSite=Strict` or `Lax` cookies are set. Alternatively, implement a honeypot or reCAPTCHA for spam protection.

### Finding: Form Action is Non-Functional (#)
- **Location:** `<form class="contact-form" action="#" method="POST">`
- **Issue:** The form action is `#` which means it submits to the current page with no backend processing. This is a dead form.
- **Risk:** **Low** — Indicates incomplete feature. Users may attempt to submit expecting a response. Could be used as a phishing vector if an attacker replaces the action with a malicious URL via DOM manipulation.
- **Fix:** Implement proper form handling or remove the form entirely until ready.

### Finding: No Content Security Policy (CSP) Meta Tag
- **Location:** `<head>` section of all pages
- **Issue:** No `<meta http-equiv="Content-Security-Policy">` tag present. No evidence of CSP HTTP headers being set (would need server-side verification).
- **Risk:** **Medium** — Without CSP, the site is more vulnerable to XSS attacks. Inline scripts, external script injection, and data exfiltration are all possible if any XSS vector is found.
- **Fix:** Implement a strict CSP policy: `default-src 'self'; script-src 'self'; style-src 'self' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:;`

### Finding: External Resource Loaded Without Subresource Integrity (SRI)
- **Location:** CSS `@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800&display=swap')`
- **Issue:** Google Fonts CSS is imported without an integrity attribute. While SRI cannot be applied to `@import` directives in CSS, this represents a supply-chain risk — a compromised Google Fonts CDN could serve malicious CSS.
- **Risk:** **Low** — Google Fonts is a trusted CDN, but supply-chain attacks are a real threat. CSS injection can lead to data exfiltration via `background-image` URLs.
- **Fix:** Consider self-hosting the Cairo font. If using CDN, monitor for anomalies. Note: SRI is not supported for CSS `@import`.

### Finding: No External Tracking Scripts Detected (Positive)
- **Location:** All pages
- **Issue:** No Google Analytics, Facebook Pixel, or other third-party tracking scripts detected.
- **Risk:** **N/A** — This is a positive finding. No user tracking means no third-party data leakage.
- **Fix:** None needed. If analytics are added in the future, ensure consent mechanisms are in place (GDPR/ePrivacy compliance).

### Finding: No Inline Scripts (Positive)
- **Location:** All pages
- **Issue:** No `<script>` tags with inline code detected. All JavaScript is in external `js/main.js` file.
- **Risk:** **N/A** — Positive finding. Reduces XSS attack surface.
- **Fix:** None needed. Maintain this pattern.

### Finding: Inline Styles on Elements
- **Location:** Multiple elements (e.g., `style="height:40px;width:40px;border-radius:8px;object-fit:cover"`, `style="color:var(--primary)"`, etc.)
- **Issue:** Inline `style` attributes used throughout. While not directly a security issue, a strict CSP with `style-src 'self'` would block these.
- **Risk:** **Low** — Inline styles reduce CSP effectiveness. An attacker who finds an XSS vector could manipulate inline styles to deface the page or create overlay phishing UIs.
- **Fix:** Move inline styles to CSS classes. Use a CSS utility framework or BEM naming convention.

### Finding: No `autocomplete` Attributes on Form Fields
- **Location:** Contact form inputs (`name`, `email`, `subject`, `message`)
- **Issue:** No `autocomplete="off"` on form fields. While this form doesn't handle sensitive data (passwords), missing autocomplete attributes on the email field could allow browser autofill to populate data unexpectedly.
- **Risk:** **Informational** — Low risk since this is a public contact form. However, best practice is to use `autocomplete="email"` for email fields and `autocomplete="name"` for name fields for better UX and security.
- **Fix:** Add appropriate `autocomplete` attributes: `autocomplete="name"` for name, `autocomplete="email"` for email.

---

## Page: https://darsakai.com/pages/downloads (Downloads Page)

### Finding: GitHub Repository Structure Exposed
- **Location:** Download links: `https://github.com/rootkali-cmd/Darsak-ai/releases/download/v2.5.0/darsak-student-v1.6.0.apk`
- **Issue:** The full GitHub repository path (`rootkali-cmd/Darsak-ai`) and release structure are exposed. This reveals the GitHub username and repository naming convention.
- **Risk:** **Low** — Exposes internal project structure. An attacker could use this to: (1) monitor releases for vulnerabilities, (2) enumerate branch names, (3) identify contributor activity patterns, (4) craft targeted phishing APKs with similar naming.
- **Fix:** Consider hosting downloads on your own domain or a dedicated download CDN. If using GitHub Releases is necessary, the exposure is acceptable but monitor the repo for forks/clones that could distribute malware.

### Finding: Download Links Not Using HTTPS-Verified CDN
- **Location:** GitHub release download links (`https://github.com/...`)
- **Issue:** While GitHub uses HTTPS, there is no SRI integrity hash on the download links. Users cannot verify the file hasn't been tampered with between hosting and download.
- **Risk:** **Medium** — If a MITM attack occurs (e.g., compromised DNS, corporate proxy), the downloaded APK/EXE could be modified to contain malware. For APK files especially, this is critical as they install directly on devices.
- **Fix:** Publish SHA-256 checksums alongside each download. Add integrity verification instructions or implement code signing for APKs/EXEs. Ideally, use Google Play Store for Android apps and Microsoft Store for Windows apps.

### Finding: APK Downloads from Outside Official Store
- **Location:** `darsak-student-v1.6.0.apk`, `darsak-teacher-v2.3.0.apk`
- **Issue:** Android APK files are distributed directly from GitHub rather than Google Play Store. This bypasses Google's Play Protect scanning and requires users to enable "Install from unknown sources."
- **Risk:** **Medium** — Users may be exposed to sideloaded malware if download links are compromised. Also, Android will warn users about unknown sources, reducing trust.
- **Fix:** Publish apps on Google Play Store. If direct APK distribution is necessary, use APK signing and provide verification instructions.

### Finding: No Download Integrity Verification
- **Location:** All download links
- **Issue:** No SHA-256 checksums or digital signatures provided for downloaded files.
- **Risk:** **Medium** — Users cannot verify the authenticity/integrity of downloaded files.
- **Fix:** Add checksums (e.g., "SHA-256: abc123...") next to each download link and implement file signing.

---

## Page: https://darsakai.com/pages/privacy (Privacy Policy)

### Finding: No Security Issues Found (Positive)
- **Location:** Full page content
- **Issue:** Static HTML content with no forms, scripts, or interactive elements.
- **Risk:** **N/A** — Clean static page.
- **Fix:** None needed.

---

## Page: https://darsakai.com/pages/terms (Terms of Service)

### Finding: No Security Issues Found (Positive)
- **Location:** Full page content
- **Issue:** Static HTML content with no forms, scripts, or interactive elements.
- **Risk:** **N/A** — Clean static page.
- **Fix:** None needed.

---

## Page: https://darsakai.com/pages/faq (FAQ Page)

### Finding: No Security Issues Found (Positive)
- **Location:** Full page content
- **Issue:** Static HTML with `<details>` elements for FAQ accordion. No forms or dynamic content.
- **Risk:** **N/A** — Clean static page.
- **Fix:** None needed.

---

## Page: https://darsakai.com/pages/refund-policy (Refund Policy)

### Finding: No Security Issues Found (Positive)
- **Location:** Full page content
- **Issue:** Static HTML content with no forms, scripts, or interactive elements.
- **Risk:** **N/A** — Clean static page.
- **Fix:** None needed.

---

## External JavaScript Analysis: js/main.js

### Finding: No eval(), Function(), or Dynamic Code Execution (Positive)
- **Location:** `js/main.js` (38 lines total)
- **Issue:** The JavaScript file contains only two functions: `initReveal()` (IntersectionObserver animation) and `initFaq()` (click handler for FAQ toggles). No `eval()`, `Function()`, `setTimeout(string)`, or `setInterval(string)` calls.
- **Risk:** **N/A** — Excellent. Minimal attack surface.
- **Fix:** None needed. Maintain this clean pattern.

### Finding: No DOM Manipulation with User Input (Positive)
- **Location:** `js/main.js`
- **Issue:** No user input is read from URL parameters, forms, or localStorage and injected into the DOM. The script only reads existing DOM elements and adds classes/attributes.
- **Risk:** **N/A** — No DOM-based XSS vectors detected.
- **Fix:** None needed.

### Finding: No External Script Loads (Positive)
- **Location:** `js/main.js`
- **Issue:** No dynamic script loading (`createElement('script')`, `import()`, `fetch()` for scripts).
- **Risk:** **N/A** — No script injection vectors.
- **Fix:** None needed.

---

## External CSS Analysis: css/style.css

### Finding: Google Fonts Loaded Over HTTPS
- **Location:** `@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800&display=swap')`
- **Issue:** External font loaded from Google Fonts CDN. The URL uses HTTPS.
- **Risk:** **Low** — Trusted CDN, but represents a supply-chain dependency. No SRI possible for CSS @import.
- **Fix:** Consider self-hosting the font for maximum control. At minimum, monitor Google Fonts for integrity issues.

### Finding: No `url()` References to External Domains (Positive)
- **Location:** `css/style.css`
- **Issue:** No `background-image: url(...)` or other CSS property references external URLs. All visual elements use CSS gradients and solid colors.
- **Risk:** **N/A** — No CSS-based data exfiltration possible via external URL loading.
- **Fix:** None needed.

---

## Pages Not Found

### Finding: Login Page Returns 404
- **Location:** `https://darsakai.com/login` and `https://darsakai.com/pages/login`
- **Issue:** No login page exists on the marketing website. Authentication is handled exclusively through the mobile apps.
- **Risk:** **Informational** — This is actually a positive security pattern. Keeping authentication within native apps provides better security (certificate pinning, secure storage, etc.) compared to web-based login.
- **Fix:** None needed. Maintain app-only authentication.

---

## Summary of All Findings

| # | Finding | Page | Risk Level | Status |
|---|---------|------|------------|--------|
| 1 | Contact form missing CSRF token | Main | Medium | Open |
| 2 | Form action is non-functional (#) | Main | Low | Open |
| 3 | No Content Security Policy | All pages | Medium | Open |
| 4 | External resource without SRI | Main (CSS) | Low | Open |
| 5 | No tracking scripts | All pages | N/A | Positive |
| 6 | No inline scripts | All pages | N/A | Positive |
| 7 | Inline styles on elements | Main | Low | Open |
| 8 | No autocomplete attributes on forms | Main | Info | Open |
| 9 | GitHub repo structure exposed | Downloads | Low | Open |
| 10 | Downloads without integrity verification | Downloads | Medium | Open |
| 11 | APK downloads outside official store | Downloads | Medium | Open |
| 12 | No download checksums/signatures | Downloads | Medium | Open |
| 13 | No eval() or dynamic code execution | JS | N/A | Positive |
| 14 | No DOM-based XSS vectors | JS | N/A | Positive |
| 15 | Google Fonts via HTTPS | CSS | Low | Accepted |

---

## Risk Distribution

- **Medium Risk:** 4 findings (CSRF token missing, CSP absent, APK distribution, download integrity)
- **Low Risk:** 5 findings (dead form, no SRI, inline styles, GitHub exposure, Google Fonts)
- **Informational:** 1 finding (autocomplete)
- **Positive (No Issue):** 5 findings (no tracking, no inline scripts, clean JS, no eval, no external DOM)

---

## Overall Frontend Security Score: B+

### Justification:

**Strengths (why not lower):**
- Extremely minimal JavaScript (38 lines) — minimal attack surface
- Zero eval(), dynamic code execution, or DOM manipulation with user input
- No third-party tracking scripts (privacy-respecting)
- No inline scripts anywhere — all JS is external
- HTTPS enforced for all resources
- Static site architecture reduces server-side attack vectors
- No login page on web (reduces credential exposure surface)
- Clean HTML with no sensitive data in comments or hidden fields

**Weaknesses (why not A):**
- No Content Security Policy (CSP) implemented — this is the single biggest gap
- Contact form lacks CSRF protection
- APK downloads from GitHub without integrity verification or checksums
- No Subresource Integrity on external CSS/Fonts
- Inline styles reduce CSP effectiveness if implemented later
- GitHub repository structure/username exposed in download URLs

### Priority Remediation:

1. **HIGH:** Implement Content Security Policy (CSP) headers and meta tags
2. **HIGH:** Add SHA-256 checksums for all downloadable files (APKs, EXEs)
3. **MEDIUM:** Add CSRF token to contact form (or remove form until backend is ready)
4. **MEDIUM:** Consider self-hosting Google Fonts for supply-chain control
5. **LOW:** Move inline styles to CSS classes
6. **LOW:** Add `autocomplete` attributes to form fields
7. **LOW:** Consider hosting downloads on own domain instead of GitHub Releases

### Overall Assessment:

The darsakai.com frontend is **well-built from a security perspective** for a marketing/landing page. The codebase is minimal, clean, and avoids common frontend vulnerabilities. The primary gaps are in security headers (CSP) and download integrity verification — both are industry best practices that should be implemented before the platform scales. The absence of a web-based login portal significantly reduces the attack surface.
