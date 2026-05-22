# DarsakAI Backend

## 🚀 Quick Start

### 1. Prerequisites
- Python 3.10+
- Supabase Project (configured in `.env`)
- Redis (optional, for sync buffer)
- Ollama (optional, for AI analysis)

### 2. Setup

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Supabase credentials
```

### 3. Database Setup

Run the SQL migration in Supabase Dashboard → SQL Editor:
```bash
# Copy contents of scripts/migration.sql
# Paste in Supabase SQL Editor and run
```

### 4. Seed Data (Optional)

```bash
python scripts/seed_data.py
```

### 5. Run the API

```bash
uvicorn src.main:app --reload --port 8000
```

### 6. Access

- API: http://localhost:8000
- Swagger Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### 7. Run Tests

```bash
# Unit tests
pytest tests/test_encryption.py tests/test_ai_analyzer.py -v

# Integration tests
python scripts/test_api.py
```

## 📋 API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Register new teacher/admin |
| POST | `/api/auth/login` | Login and get JWT tokens |
| POST | `/api/auth/refresh` | Refresh access token |
| GET | `/api/auth/me` | Get current user |
| PATCH | `/api/auth/me` | Update current user |
| POST | `/api/students/` | Create student |
| GET | `/api/students/` | List students |
| GET | `/api/students/{id}` | Get student details |
| PATCH | `/api/students/{id}` | Update student |
| DELETE | `/api/students/{id}` | Delete student |
| POST | `/api/students/login` | Student login (code + PIN) |
| POST | `/api/students/analyze` | AI analysis of student grades |
| GET | `/api/students/{id}/report/pdf` | Export student report as PDF |
| POST | `/api/groups/` | Create group |
| GET | `/api/groups/` | List groups |
| PATCH | `/api/groups/{id}` | Update group |
| DELETE | `/api/groups/{id}` | Delete group |
| POST | `/api/attendance/` | Mark attendance |
| POST | `/api/attendance/bulk` | Bulk mark attendance |
| GET | `/api/attendance/` | Get attendance records |
| GET | `/api/attendance/stats` | Attendance statistics |
| POST | `/api/grades/` | Add grade |
| POST | `/api/grades/bulk` | Bulk upload grades |
| GET | `/api/grades/` | List grades |
| GET | `/api/grades/stats` | Grade statistics |
| POST | `/api/invoices/` | Create invoice |
| GET | `/api/invoices/` | List invoices |
| PATCH | `/api/invoices/{id}` | Update invoice |
| DELETE | `/api/invoices/{id}` | Delete invoice |
| GET | `/api/invoices/stats` | Invoice statistics |
| GET | `/api/qr/generate/{teacher_id}` | Generate teacher QR code |
| POST | `/api/qr/verify` | Verify QR code |
| POST | `/api/sync/push` | Push encrypted sync payload |
| GET | `/api/sync/pull` | Pull pending sync payloads |
| POST | `/api/sync/ack` | Acknowledge synced payloads |

## 🔐 Security

- JWT-based authentication with access + refresh tokens
- Password hashing with bcrypt
- End-to-end encryption (AES-256-GCM) for sync payloads
- Rate limiting (120 req/min per IP)
- Sensitive data filtering in logs
- Audit logging for all critical operations
- Supabase Row Level Security (RLS) enabled

## 🔄 Architecture

```
┌─────────────┐     HTTPS     ┌──────────────────┐     REST API     ┌─────────────┐
│   Client    │ ────────────> │   FastAPI Backend │ ─────────────> │   Supabase   │
│ (Web/Mobile)│ <──────────── │   (Python 3.12)   │ <────────────── │ (PostgreSQL) │
└─────────────┘     JSON      └──────────────────┘     JSON         └─────────────┘
                                      │
                                      ├────> Redis (sync buffer)
                                      ├────> Ollama (AI analysis)
                                      └────> Local file system (PDF/QR)
```

## 📁 Project Structure

```
backend/
── src/
│   ├── main.py                 # FastAPI app + middleware
│   ├── api/                    # API routes (8 modules)
│   ├── core/                   # Config, security, logging
│   ├── models/                 # SQLAlchemy models (schema reference)
│   ├── schemas/                # Pydantic request/response models
│   ├── services/               # Business logic + Supabase services
│   └── utils/                  # Dependencies, helpers
├── scripts/
│   ├── migration.sql           # Database schema
│   ├── seed_data.py            # Initial data seeding
│   ├── test_supabase.py        # Supabase integration tests
│   └── test_api.py             # Full API integration tests
├── tests/                      # Unit tests
├── requirements.txt
├── .env                        # Environment variables
└── README.md
```

## 🔑 Default Credentials (Development)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@darsak.ai | Admin@123456 |
| Teacher | teacher@darsak.ai | Teacher@123456 |
| Student PIN | (any student) | 1234 |

⚠️ **Change these in production!**
