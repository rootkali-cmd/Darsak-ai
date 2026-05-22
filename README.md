# DarsakAI - نظام إدارة التعليم الذكي

## 📖 نظرة عامة

DarsakAI هو نظام تعليمي متكامل يعتمد على الذكاء الاصطناعي لإدارة الفصول، تحليل أداء الطلاب، وتقديم تقارير ذكية للمدرسين.

## ️ البنية

```
darsak-ai/
├── backend/          # FastAPI + Supabase + AI (Ollama)
├── web-portal/       # Next.js 14 Teacher Dashboard
├── desktop-app/      # Flutter Windows (Teacher/Assistant)
├── mobile-app/       # Flutter Android/iOS (Students)
├── docs/             # API specs, DB schema, deployment guides
└── docker-compose.yml # Local dev services
```

## 🔄 المراحل

| المرحلة | الوصف | الحالة |
|---------|-------|--------|
| 1 | Backend + AI Core + Supabase | ✅ مكتملة |
| 2 | Web Portal (Teacher Dashboard) | ✅ مكتملة |
| 3 | Desktop App (Windows) | ⬜ لم تبدأ |
| 4 | Mobile App (Students) |  لم تبدأ |

## 🚀 تشغيل سريع

### Backend

```bash
cd backend
pip install -r requirements.txt

# 1. Run SQL migration in Supabase Dashboard
# 2. Seed data
python scripts/seed_data.py

# 3. Start API
uvicorn src.main:app --reload --port 8000

# 4. Open docs
# http://localhost:8000/docs
```

### Test

```bash
# Unit tests
pytest tests/ -v

# Integration tests
python scripts/test_api.py
```

## 🔐 الأمان

- تشفير من طرف لطرف (AES-256-GCM)
- JWT Authentication
- Audit Logging شامل
- Rate Limiting
- Supabase Row Level Security
- لا يتم تخزين أي بيانات حساسة في الكود

## 📊 قاعدة البيانات

- **Provider**: Supabase PostgreSQL
- **Tables**: 8 (users, students, groups, attendances, grades, invoices, encrypted_payloads, audit_logs)
- **RLS**: Enabled on all tables
- **Indexes**: 17 optimized indexes

##  بيانات الدخول التجريبية

| الدور | البريد | كلمة المرور |
|-------|--------|-------------|
| Admin | admin@darsak.ai | Admin@123456 |
| Teacher | teacher@darsak.ai | Teacher@123456 |
| Student PIN | (أي طالب) | 1234 |

## 📝 الترخيص

جميع الحقوق محفوظة © 2026 DarsakAI
# Darsak-ai
