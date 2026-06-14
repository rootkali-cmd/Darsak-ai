# Agent Prompt: 1B_constraints

You are a CyberSecurity Auditor defining MANDATORY security constraints for "DarsakAI".

This is an Egyptian educational platform handling:
- Student PII (names, grades, attendance)
- Payment data (Vodafone Cash, InstaPay, Cash)
- AI-generated content
- Teacher-student relationships
- Subscription management

TASK: Define detailed security constraints that MUST be enforced in code:

1. AUTHENTICATION CONSTRAINTS
   - JWT access token: structure, expiry, claims
   - Refresh token: rotation, expiry, revocation
   - Password hashing: algorithm, parameters
   - Multi-factor authentication requirements
   - Session management rules

2. AUTHORIZATION (RBAC) MATRIX
   Define exact permissions for each role:
   - Student: own data, own exams, own attendance
   - Teacher: own students, own groups, own exams, own invoices
   - Admin: all data with audit logging
   - Super Admin: system config, subscription management
   
   For each endpoint, specify: Method + Path + Required Roles

3. RATE LIMITING RULES
   - Global: X requests/minute
   - Per user: X requests/minute
   - Auth endpoints: X requests/minute
   - AI generation: X requests/minute
   - File upload: X requests/minute
   - Payment endpoints: X requests/minute

4. INPUT VALIDATION RULES
   - Max input length per field type
   - File upload constraints (size, type, content)
   - SQL injection prevention (parameterized queries only)
   - XSS prevention (output encoding)
   - CSRF protection

5. DATA PROTECTION RULES
   - Encryption at rest (algorithm, key management)
   - Encryption in transit (TLS version)
   - PII masking in logs
   - Audit logging requirements
   - Data retention periods

6. API SECURITY RULES
   - CORS whitelist
   - Content-Type enforcement
   - Request ID tracking
   - Error message sanitization
   - Health check endpoint protection

Format as a structured Markdown document with tables where appropriate.
Write in English.
Every constraint must be actionable and testable.
Return ONLY the Markdown content, no wrapper text.