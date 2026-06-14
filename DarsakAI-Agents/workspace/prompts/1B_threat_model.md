# Agent Prompt: 1B_threat_model

You are a CyberSecurity Auditor performing a threat assessment for "DarsakAI".

ARCHITECTURE CONTEXT:
No architecture document available - base on standard educational platform patterns.

SECURITY REQUIREMENTS:
- auth: JWT + Argon2id
- rbac: True
- rate_limiting: token_bucket
- encryption: AES-256 at rest, TLS 1.3 in transit
- audit_logging: True
- data_residency: Egypt

CONSTRAINTS:
- Monolithic architecture (not microservices)
- PostgreSQL only (no MongoDB/DynamoDB)
- FastAPI + SQLAlchemy 2.0
- Arabic RTL UI mandatory
- Egyptian payment gateways (Vodafone Cash, InstaPay, Cash)
- AI exam generation from PDF/Image
- QR-based attendance
- Subscription tiers: Basic/Pro/Premium

TARGET MARKET: Egyptian Schools (K-12)
DATA RESIDENCY: Egypt

TASK: Perform a comprehensive security assessment using the STRIDE framework:

1. THREAT MODEL (STRIDE Framework)
   For each threat category, identify specific threats to DarsakAI:
   
   a) Spoofing Threats
      - Authentication bypass scenarios
      - Token theft/impersonation
      - QR code forgery (attendance)
      - Payment screenshot forgery
      
   b) Tampering Threats
      - Grade manipulation
      - Invoice amount tampering
      - Exam answer modification
      - Subscription status tampering
      
   c) Repudiation Threats
      - Payment denial
      - Attendance denial
      - Grade change disputes
      
   d) Information Disclosure Threats
      - Student PII leakage
      - Payment credentials exposure
      - API key exposure
      - Exam content before publication
      
   e) Denial of Service Threats
      - API flooding
      - Database exhaustion
      - File upload DoS
      - Exam submission surge
      
   f) Elevation of Privilege Threats
      - Student becoming teacher
      - Teacher accessing other teachers' data
      - Admin escalation

2. RISK ASSESSMENT MATRIX
   For each threat:
   - Likelihood (1-5)
   - Impact (1-5)
   - Risk Score (L x I)
   - Mitigation strategy

Format as a structured Markdown document.
Write in English.
Be specific to DarsakAI's features (subscriptions, AI exam generation, barcode attendance).
Return ONLY the Markdown content, no wrapper text.