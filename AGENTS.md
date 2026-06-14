# DarsakAI - Project Handoff Document

> **Last updated:** 2026-06-14
> **Purpose:** Complete context for continuing development on a new system.

---

## 1. Project Overview

DarsakAI is an educational platform for Egyptian schools with 5 components:

| Component | Path | Tech | Purpose |
|-----------|------|------|---------|
| Backend API | `backend/` | Python/FastAPI | REST API + Supabase + Redis |
| Student Mobile App | `mobile-app/` | Flutter/Dart | Student-facing Android app |
| Teacher Mobile App | `teacher_mobile_v2/` | Flutter/Dart | Teacher-facing Android app |
| Web Portal | `web-portal/` | Next.js | Admin/teacher web dashboard |
| AI Agents | `DarsakAI-Agents/` | Python | Multi-agent system |

---

## 2. Architecture

### Backend (`backend/`)
- **Entry point:** `src/main.py` — FastAPI app with auto-migrations on startup
- **API routes:** `src/api/` — exams.py, auth.py, students.py, grades.py, reports.py, student_me.py, dashboard.py, etc.
- **Schemas:** `src/schemas/` — Pydantic models for request/response
- **Services:** `src/services/supabase_services.py` — All DB operations via Supabase
- **Auth:** `src/utils/dependencies.py` — `get_current_student`, `get_current_teacher`
- **DB:** Supabase (PostgreSQL) — not local, cloud-hosted
- **Cache:** Redis (Upstash) — for rate limiting, pub/sub
- **Config:** `src/core/config.py` — env vars, API keys

### Deployment
- **Backend:** Deployed to **Fly.io** at `https://darsak-backend.fly.dev`
- **Deploy command:** `flyctl deploy --app darsak-backend` (from `backend/` dir)
- **Fly.io auth:** `ahmedtelly32@gmail.com` (flyctl is at `~/.fly/bin/flyctl`)

### Mobile Apps
- Both apps point to `https://darsak-backend.fly.dev/api` (in `mobile-app/lib/core/constants.dart` and `teacher_mobile_v2/lib/services/api_service.dart`)
- **Package names:** `com.darsak.ai` (student), `com.darsakai.darsak_teacher_v2` (teacher)

---

## 3. Database Tables (Key Ones)

| Table | Purpose |
|-------|---------|
| `users` | Teachers + admins |
| `students` | Students (columns: `id`, `full_name`, `code`, `teacher_id`, `pin_hash`) |
| `exams` | Exams (columns: `id`, `teacher_id`, `title`, `duration_minutes`, `status`, `deadline_at`, `show_results_at`) |
| `questions` | Exam questions (MC + essay) |
| `student_exams` | Student exam attempts (status: `in_progress` → `submitted` → `graded`) |
| `student_answers` | Individual answers per question |
| `exam_results` | AI analysis per student exam |
| `grades` | Manual teacher-entered grades (separate from exams) |
| `attendance` | Student attendance records |
| `invoices` | Payment tracking |

**IMPORTANT:** The `students` table uses `full_name` NOT `name`. This caused a bug that was fixed.

---

## 4. What Was Done (Session History)

### Features Completed ✅

1. **Route ordering fix** — `/available` and `/my-results` were caught by `GET /{exam_id}` (teacher route)
2. **Submit 500 error fix** — Missing `created_at` column in `student_answers` table
3. **Notifications FK constraint** — Removed foreign key constraint
4. **Exam screen UX** — Auto-advance on answer click (no double-click needed)
5. **5-minute grace period** — After exam deadline, student gets 5 more minutes + auto-submit
6. **Auto-submit on dispose** — Leaving exam screen auto-submits answers
7. **Exam results visibility (`show_results_at`)** — Teacher sets when correct answers become visible to students
8. **Student dashboard stats** — Home screen shows combined stats from grades + exams (average, best, worst, total)
9. **Recent grades** — Home screen shows last 2 results (merged from both grades table and exam results)
10. **Low grades count** — Counts low scores from both grades table AND exam results
11. **Teacher exam results screen** — New `exam_results_screen.dart` shows per-exam student results with names
12. **Exams list "النتائج" button** — Published exams show a results button in teacher's exam list
13. **AI Reports fix** — `ReportsApiService` now uses shared `ApiService().dio` for proper token refresh
14. **`full_name` bug fix** — Fixed `name` → `full_name` in exam results queries (2 places)
15. **Student stats endpoint** — `GET /students/me/stats` returns exam stats (counts both `graded` and `submitted` with scores)

### Deployments Made 🚀
- Backend deployed to Fly.io 3 times during this session
- Both mobile apps built (release) and installed on device (CPH2059)
- All code pushed to GitHub: `https://github.com/rootkali-cmd/Darsak-ai.git`

---

## 5. Current State — What Works / What Doesn't

### Working ✅
- Student login + exam taking + submission + auto-grading (MC)
- Student results page (score %, correct/wrong % — hidden until `show_results_at`)
- Student home screen: attendance rate, average grade (merged), low grades count (merged), payment status, exam stats cards, last 2 grades
- Teacher: create/publish exams, view per-exam student results
- Teacher: AI reports (student performance analytics)
- Teacher: grades, attendance, invoices CRUD
- Backend: all migrations run on startup, health checks pass

### Not Yet Done / Potential Improvements 🔧
- `show_results_at` — Teacher needs UI to set this field when creating/editing exams (backend works, but `AddEditExamScreen` doesn't have the date picker yet)
- Desktop app — exists at `desktop_app/` but not actively maintained in these sessions
- Web portal — exists at `web-portal/` but minimal changes
- Essay question grading — still manual (auto-grading is MC only)
- Push notifications — not implemented (only local notification badge from API)
- The `grades` table and `student_exams` table are separate data sources — merged on frontend but could be unified in backend

---

## 6. Key Files to Know

### Backend
| File | What it does |
|------|-------------|
| `src/main.py` | App startup, CORS, route registration, ALL migrations |
| `src/api/exams.py` | All exam endpoints (start, submit, results, available, my-results) |
| `src/api/student_me.py` | Student self-service (profile, grades, attendance, invoices, stats, AI chat) |
| `src/api/auth.py` | Login, register, refresh token, /me |
| `src/api/reports.py` | Teacher AI reports (per-student analytics) |
| `src/services/supabase_services.py` | ALL database operations (ExamService, StudentExamService, etc.) |
| `src/schemas/exam.py` | Pydantic models for exams |
| `src/utils/dependencies.py` | Auth dependencies (get_current_student, get_current_teacher) |

### Student Mobile App
| File | What it does |
|------|-------------|
| `lib/core/constants.dart` | API base URL, app version |
| `lib/core/api_service.dart` | All API calls |
| `lib/providers/data_provider.dart` | Centralized data (grades, attendance, exams, invoices) |
| `lib/screens/home_screen.dart` | Main dashboard with stats |
| `lib/screens/exam_take_screen.dart` | Exam taking UI |
| `lib/screens/exam_result_screen.dart` | Exam result display |

### Teacher Mobile App
| File | What it does |
|------|-------------|
| `lib/services/api_service.dart` | API base URL + all API calls |
| `lib/services/reports_api_service.dart` | AI reports API (uses shared Dio) |
| `lib/screens/exams/exams_screen.dart` | Exam list with results button |
| `lib/screens/exams/exam_results_screen.dart` | Per-exam student results |
| `lib/screens/reports/ai_reports_screen.dart` | AI analytics dashboard |

---

## 7. Development Workflow

### To work locally:
```bash
cd backend
pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8000
```

### To deploy backend:
```bash
export PATH="$HOME/.fly/bin:$PATH"
cd backend
flyctl deploy --app darsak-backend
```

### To build + install mobile apps:
```bash
cd mobile-app && flutter build apk --release --target-platform android-arm64 && flutter install --release
cd teacher_mobile_v2 && flutter build apk --release --target-platform android-arm64 && flutter install --release
```

### Device connected via USB:
```
CPH2059 (mobile) • 6251d0be • android-arm64 • Android 11 (API 30)
```

---

## 8. Important Notes / Gotchas

1. **`students.full_name` NOT `students.name`** — This caused a 500 error. Always use `full_name`.
2. **Supabase is cloud** — No local DB. All queries go to Supabase hosted PostgreSQL.
3. **Migrations run on startup** — All in `src/main.py`, using `IF NOT EXISTS`. Safe to run repeatedly.
4. **`get_student_exams` returns all statuses** — The stats endpoint now counts both `graded` and `submitted` with scores.
5. **Fly.io deploys are quick** — Usually ~30 seconds. Health check at `https://darsak-backend.fly.dev/health`.
6. **Both apps use release builds** — Debug builds were used during development, release for final installs.
7. **The `show_results_at` field** is on the `exams` table but has no teacher UI yet — needs a DateTimePicker in `AddEditExamScreen`.
