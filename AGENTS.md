# DarsakAI - Project Handoff Document

> **Last updated:** 2026-07-04
> **Session:** Phase 18 — AI Classroom Integration
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
| OpenMAIC | `openmaic/` | Next.js/TypeScript | AI classroom (multi-agent) |
| Desktop App | `desktop_app/` | Flutter/Dart | Windows teacher desktop |

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

### Desktop App
- Windows desktop (Flutter), builds to `desktop_app/build/windows/x64/Release/darsak_desktop.exe`
- Uses local SQLite (via `sqflite_common_ffi`) as cache + API calls for live data
- Inno Setup installer: `C:\Users\Ahmed\AppData\Local\Programs\Inno Setup 6\ISCC.exe`

---

## 3. Database Tables (Key Ones)

| Table | Purpose |
|-------|---------|
| `users` | Teachers + admins |
| `students` | Students (columns: `id`, `full_name`, `code`, `teacher_id`, `pin_hash`, `is_active`) |
| `exams` | Exams (columns: `id`, `teacher_id`, `title`, `duration_minutes`, `status`, `deadline_at`, `show_results_at`) |
| `questions` | Exam questions (MC + essay) |
| `student_exams` | Student exam attempts (status: `in_progress` → `submitted` → `graded`) |
| `student_answers` | Individual answers per question |
| `exam_results` | AI analysis per student exam |
| `grades` | Manual teacher-entered grades (separate from exams) |
| `attendance` | Student attendance records |
| `invoices` | Payment tracking |
| `subscription_plans` | Plan definitions (Basic/Pro/Premium) |
| `teacher_subscriptions` | Active teacher subscriptions |

**IMPORTANT:** The `students` table uses `full_name` NOT `name`. This caused a bug that was fixed.

---

## 4. What Was Done (Session History)

### Session 2026-06-24 ✅

**Backend Fixes (deployed v194):**
- `_to_exam_response` in `exams.py:30`: Added `"published": exam.get("status") == "published"` — frontend gets `published` bool derived from `status` field
- `_to_student_exam_response` in `exams.py:60-61`: Added `student_name` + `student_code` fields from the student_exam row
- Reports endpoint `reports.py:48`: Changed `.eq("status", "graded")` → `.in_("status", ["graded", "submitted"])` — includes submitted-but-not-graded exams in reports
- `supabase_services.py:489`: `get_by_teacher` limit 100→200 + `created_at desc` ordering — prevents missing exams in teacher exam list
- Submit endpoint `exams.py:299`: Added guard `if se.get("status") in ("graded", "submitted"):` — prevents re-submission of already-submitted exams
- Dashboard endpoint `dashboard.py:28,35`: Fixed `today_count`→`present` and `total_paid`→`paid_amount` to match Supabase column names
- `StudentResponse` schema `student.py:42`: Added `is_paid: bool = False`
- `students.py`: Created `_enrich_student()` async helper that checks invoices for `is_paid` status — used in `list_students`, `get_student`, and `update_student` endpoints
- `student_me.py:54`: Student profile endpoint now uses `_enrich_student` to return `is_paid`

**Teacher Mobile Fixes:**
- `subscription_guard.dart`: Added static `_isRedirecting` guard to prevent infinite redirect loop in `SubscriptionRequiredWidget`
- `auth_provider.dart`: `_init()` validates subscription before first `notifyListeners()`
- `api_service.dart`: Dio interceptor now has max retry count (2) to prevent infinite loop on 401
- `splash_screen.dart`: Replaced busy `while` loop with `addPostFrameCallback` + listener pattern + 5s safety timeout
- Removed `OnlineRequestsScreen` (import + button + file)

**Student Mobile Fixes:**
- `auth_provider.dart`: `tryAutoLogin()` now `await refreshSubscription()` before setting `AuthStatus.authenticated` — prevents subscription dialog race condition
- `auth_provider.dart`: Added `subscriptionLoaded` flag to guard `_checkSubscription()` — only shows dialog when data definitely arrived
- `auth_provider.dart`: Added `isOnline` getter back after connectivity refactor
- `error_state.dart`: Fixed `AppTheme.danger` reference
- `app_colors.dart`: Fixed `textMuted` method signature

**Desktop App:**
- Deleted 6 deprecated files: `qr_screen.dart`, `qr_camera_screen.dart`, `teacher_code_screen.dart`, `online_requests_screen.dart`, `sync_status_indicator.dart`, `qr_code_widget.dart` (kept)
- Sidebar: Removed QR + subscription items (12 items now)
- Attendance: Removed QR scan button + import
- Settings: Removed "كود المدرس" field
- Dashboard: Real API stats from `/dashboard/stats`, subscription plan badge (colored), 6 quick actions, loading/error/refresh states
- `exam.dart:34`: `published` now derived from `status` field (backwards-compatible)
- `database_service.dart`: Same `published` derivation in SQLite cache
- `api_service.dart`: Added `limit: 500` to `getStudents()` and `getGrades()`, `limit: 200` to `getExams()` — prevents truncated lists
- `ai_reports_screen.dart`: Fixed `getMe()` fallback (tries `api.getMe()` then raw `client.get('/auth/me')`)

**Light Mode Fix:**
- `app_theme.dart`: `lightBorder` changed from `#E2E5EA`→`#D1D5DB` (higher contrast)

**Auto-Capitalize:**
- 66 `TextCapitalization.characters` added across 25 files in all 3 apps (skipped password/email/phone/number fields)

**Agent System:**
- `agent-system/db-schema.json`: Exported — 27 tables, full schema + relationships
- `agent-system/db-sample.json`: Exported — sample rows per table
- `agent-system/AGENT-CHIEF.md`: Protocol for agent orchestration
- `agent-system/reports/`: 12 reports (5 cyber, 6 fix, 1 chief decision)

**Artifacts Built:**
- Desktop app: `darsak_desktop.exe` ✅
- Teacher APK (37.8MB) ✅
- Student APK (35.3MB) ✅
- Git pushed: commits `67f1b0d`, `56c3016`, `ca06c10`
- Backend deployed: Fly.io v194

---

## 5. Current State — What Works / What Doesn't

### Working ✅
- **Student:** Login, exam taking, submission, auto-grading (MC), results page (with `show_results_at` timing), home screen stats (attendance, grades merged, low grades, payment, exam stats), last 2 grades
- **Teacher:** Create/publish exams, per-exam student results, AI reports (performance analytics), grades/attendance/invoices CRUD, subscription management
- **Desktop:** Dashboard (real stats, plan badge, 6 quick actions), exams list (results button), student management, grades, attendance, settings, AI reports
- **Backend:** All migrations run on startup, health checks pass, re-submission blocked, dashboard stats fixed, `published` field derived from `status`, `is_paid` enrichment on all student endpoints
- **Security:** Rate limiting (Redis), auth via JWT, subscription guards on all apps, exception sanitization (no PII/stack leaks)

### Not Yet Done / Potential Improvements 🔧
- `show_results_at` — Teacher needs UI to set this field when creating/editing exams (backend works, but no date picker UI yet)
- Essay question grading — still manual (auto-grading is MC only)
- Push notifications — not implemented (only local notification badge from API)
- Grades + student_exams tables are separate — merged on frontend but could be unified in backend
- Subscription pricing slider — Teacher mobile + Desktop need flexible pricing slider for Premium plan (700–5000 students), monthly/yearly toggle
- Agent swarm security analysis — DB schema exported, agents ready to run with full schema access
- Phone not connected — ADB shows "no devices/emulators found" — can't install/test APKs on device `6251d0be`
- Web portal — exists at `web-portal/` but minimal changes

### Session 2026-06-28 ✅

**Backend Fixes (deployed v195):**
- `storage/routes.py:236`: Fixed server error when creating courses — `teacher_id` moved before `_check_storage_quota` (was checking quota before teacher was known)
- `storage/routes.py:_check_storage_quota`: Added `try/except` + `course_files` table count — fixes "فشل إنشاء الدرس" on video/file upload
- `main.py`: Added Phase 10 migrations for course-related columns (`cover_image_r2_key`, `video_url`, `r2_video_key`, etc.)

**Security Fixes (P0 from Agent Chief):**
- `admin.py:85`: Admin login now uses bcrypt `verify_password()` against stored hash in `admin_config` table (was plaintext `==`)
- `main.py:370-380`: Removed hardcoded Instapay username from migration — username column now nullable, set via Telegram bot only
- `students.py`: Removed `pin_hash` from all serialization outputs (`_serialize_student`, `_enrich_student`, `_batch_enrich_students`) — `has_pin` derived field kept
- `versions.py:417-423`: Removed hardcoded Instapay fallback — returns empty string when DB has no config
- `student_me.py:597-611`: Removed hardcoded Instapay/QR fallbacks — reads from DB only
- `payments.py:186-198`: Removed hardcoded Instapay fallback — reads from DB only
- `config.py:83`: Removed hardcoded `ADMIN_EMAIL` default — set to `""`, env-only
- `main.py:789`: Added Phase 11 migration — `admin_config` table for bcrypt admin password hash

**Teacher Mobile Fixes:**
- `course_detail_screen.dart`: All 12 SnackBar error handlers now show actual error messages instead of generic "فشل" — uses `_errorMsg()` helper with proper Dart syntax (fixes #51 analyzer warnings to 0)
- `course_detail_screen.dart`: Empty catch block for published toggle now shows error feedback
- `course_detail_screen.dart`: Added `import 'package:dio/dio.dart'` for error type checking

**Artifacts Built:**
- Teacher APK (38.2MB) ✅
- Student APK (35.6MB) ✅
- Backend deployed: Fly.io v195 ✅

### Session 2026-07-04 ✅

**AI Classroom Integration (Phase 18):**
- `openmaic/` — Added full OpenMAIC source (THU-MAIC/OpenMAIC v0.2.2) as part of repo
- OpenMAIC Dockerfile fixed: added `scripts/` copy, removed `public/vendor` (generated at build)
- OpenMAIC deployed to Fly.io as `darsak-ai-classroom.fly.dev`: Next.js multi-agent classroom platform
- Fly secrets set: `OPENROUTER_API_KEY`, `DEFAULT_MODEL=deepseek/deepseek-v4-flash`, `OPENROUTER_MODELS`
- OpenMAIC LLM integration has a bug: `@ai-sdk/openai` fetch wrapper crashes with OpenRouter (JSON parse error) — bypassed with backend proxy

**Backend AI Chat Proxy:**
- New file `src/api/ai_classroom.py`:
  - `POST /chat/{token}/message` — calls OpenRouter directly via httpx (bypasses broken SDK)
  - `GET /chat/{token}` — returns full Arabic HTML WebView page for chat UI
  - Per-minute billing: 0.42 EGP/min, min wallet 10 EGP
  - Auto-end lesson when balance < 10 EGP for >1 minute
- `main.py` — Phase 18 migration added: `ALTER TABLE ai_lesson_sessions ADD COLUMN chat_token VARCHAR(64)` + index
- Fixed migration indentation bug (EXTRA_SQL was outside try block) → now executes on startup
- Backend deployed: Fly.io v204 ✅

**Student App v1.8.0:**
- Version bumped from `1.7.4+16` → `1.8.0+1`
- `startAiLesson()` accepts nullable `classroomUrl`
- `AiLessonPlayerScreen` uses `classroom_url` from start endpoint
- `_checkBalance()` added to lesson list screen
- New files: `lib/screens/ai_classroom/` (lesson list, player, summary)

**APKs Built & Uploaded:**
- Student APK v1.8.0 (36.6MB) — downloaded from `api/downloads/student-v1.8.0.apk`
- Teacher APK v2.5.3 (38.2MB) — downloaded from `api/downloads/teacher-v2.5.3.apk`
- Old student v1.7.4 APK kept for backward compatibility

**Git:**
- Commit `59ceee7` — `v1.8.0: AI Classroom integration`
- OpenMAIC source added as regular directory (not submodule) — `.git/` removed
- Pushed to `origin/main`

---

## 6. Key Files to Know

### Backend
| File | What it does |
|------|-------------|
| `src/main.py` | App startup, CORS, route registration, ALL migrations |
| `src/api/exams.py` | All exam endpoints (CRUD, start, submit, results, my-results) |
| `src/api/student_me.py` | Student self-service (profile, grades, attendance, invoices, stats, AI chat) |
| `src/api/auth.py` | Login, register, refresh token, /me |
| `src/api/reports.py` | Teacher AI reports (per-student analytics) |
| `src/api/students.py` | Student CRUD, `_enrich_student` helper with `is_paid` |
| `src/api/dashboard.py` | Teacher dashboard stats |
| `src/services/supabase_services.py` | ALL database operations (ExamService, StudentExamService, etc.) |
| `src/schemas/student.py` | `StudentResponse` with `is_paid` field |
| `src/schemas/exam.py` | Pydantic models for exams |
| `src/utils/dependencies.py` | Auth dependencies (`get_current_student`, `get_current_teacher`) |

### Desktop App
| File | What it does |
|------|-------------|
| `lib/core/constants.dart` | API base URL, DB table names |
| `lib/core/api/api_service.dart` | All API calls |
| `lib/core/api/api_client.dart` | Dio wrapper with auth interceptor |
| `lib/core/api/subscription_guard.dart` | Subscription check (async with cache) |
| `lib/core/database/database_service.dart` | SQLite local cache |
| `lib/core/services/reports_api_service.dart` | AI reports API |
| `lib/core/models/exam.dart` | `ExamModel`, `ExamResultModel` |
| `lib/core/models/student.dart` | `StudentModel` with `isPaid` |
| `lib/core/theme/app_theme.dart` | Colors, theme (light/dark) |
| `lib/providers/data_provider.dart` | Centralized data (grades, attendance, exams) |
| `lib/providers/auth_provider.dart` | Auth state management |
| `lib/ui/widgets/sidebar.dart` | Navigation sidebar (12 items) |
| `lib/ui/screens/dashboard/dashboard_screen.dart` | Main dashboard with stats + quick actions |

### Teacher Mobile App
| File | What it does |
|------|-------------|
| `lib/services/api_service.dart` | API base URL + all API calls |
| `lib/services/reports_api_service.dart` | AI reports API (uses shared Dio) |
| `lib/core/subscription_guard.dart` | Subscription check with static redirect guard |
| `lib/providers/auth_provider.dart` | Auth state (validates sub before notify) |
| `lib/screens/splash_screen.dart` | Splash with listener (no busy loop) |
| `lib/screens/exams/exams_screen.dart` | Exam list with results button |
| `lib/screens/exams/exam_results_screen.dart` | Per-exam student results |
| `lib/screens/reports/ai_reports_screen.dart` | AI analytics dashboard |

### Student Mobile App
| File | What it does |
|------|-------------|
| `lib/core/api_service.dart` | All API calls |
| `lib/providers/auth_provider.dart` | Auth with subscription race fix |
| `lib/screens/home_screen.dart` | Dashboard with merged stats |
| `lib/screens/exam_take_screen.dart` | Exam taking UI |
| `lib/screens/ai_classroom/` | AI Classroom screens (lesson list, player, summary) |

### OpenMAIC (AI Classroom)
| File | What it does |
|------|-------------|
| `app/api/chat/route.ts` | Chat endpoint (broken — `@ai-sdk/openai` JSON parse error) |
| `app/api/generate-classroom/route.ts` | Multi-agent classroom generation |
| `app/layout.tsx` | Root layout |
| `app/page.tsx` | Landing page |
| `Dockerfile` | Fly.io container build |

---

## 7. Development Workflow

### To work locally:
```bash
cd backend
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

### To deploy backend:
```bash
cd backend
flyctl deploy --app darsak-backend
```

### To build desktop:
```bash
cd desktop_app
flutter build windows --release
```

### To build + install mobile apps:
```bash
cd mobile-app && flutter build apk --release --target-platform android-arm64 && flutter install --release
cd teacher_mobile_v2 && flutter build apk --release --target-platform android-arm64 && flutter install --release
```

### To build installer:
```bash
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\Users\Ahmed\Desktop\darsak AI\desktop_app\installer.iss"
```

### To verify backend syntax:
```bash
python -c "import ast; ast.parse(open('src/api/students.py', encoding='utf-8').read())"
```

---

## 8. Important Notes / Gotchas

1. **`students.full_name` NOT `students.name`** — Always use `full_name`.
2. **Supabase is cloud** — No local DB. All queries go to Supabase hosted PostgreSQL.
3. **Migrations run on startup** — All in `src/main.py`, using `IF NOT EXISTS`. Safe to run repeatedly.
4. **`is_paid` enrichment** — `_enrich_student()` queries `invoices` table per student. For large class sizes (>100), consider batching.
5. **`published` is derived** — Not a DB column on `exams`. Derived from `status == "published"` in `_to_exam_response()`.
6. **Fly.io deploys are quick** — Usually ~30 seconds. Health check at `https://darsak-backend.fly.dev/health`.
7. **Both apps use release builds** — Debug builds were used during development, release for final installs.
8. **Phone device ID**: `6251d0be` (CPH2059) — currently not connected via ADB.
9. **Desktop cache** — SQLite at `%APPDATA%/darsak_desktop/darsak.db`. Cache-first with background API refresh.
10. **Agent system** — `agent-system/` with 12 reports, Chief decision, DB schema files, protocol files.
11. **Auto-capitalize**: 66 fields updated; 51 skipped (password/email/number/already had capital).
12. **Backend exception sanitization** — All internal error details replaced with generic "internal error" — no PII or stack traces leaked.
