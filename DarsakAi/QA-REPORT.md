# DarsakAI — تقرير ضمان الجودة الشامل (QA Audit Report)

**التاريخ:** 2026-05-28  
**النسخة:** 1.3.0  
**المراجع:** Ahmed (Hostile QA Engineer)  
**المنصة:** Web Portal (Next.js) + Desktop App (Flutter) + Backend (FastAPI)  

---

## جدول المحتويات
1. [ملخص تنفيذي](#1-ملخص-تنفيذي)
2. [ثغرات أمنية — حرجة (CRITICAL)](#2-ثغرات-أمنية--حرجة-critical)
3. [ثغرات أمنية — عالية (HIGH)](#3-ثغرات-أمنية--عالية-high)
4. [ثغرات أمنية — متوسطة (MEDIUM)](#4-ثغرات-أمنية--متوسطة-medium)
5. [مشاكل متزامنة وأداء](#5-مشاكل-متزامنة-وأداء)
6. [مشاكل واجهة المستخدم (UX)](#6-مشاكل-واجهة-المستخدم-ux)
7. [مشاكل المزامنة (Sync)](#7-مشاكل-المزامنة-sync)
8. [تغطية الاختبارات](#8-تغطية-الاختبارات)
9. [التوصيات](#9-التوصيات)

---

## 1. ملخص تنفيذي

### إجمالي المشاكل المكتشفة: **87**
| المستوى | العدد |
|---------|-------|
| CRITICAL | 12 |
| HIGH | 16 |
| MEDIUM | 29 |
| LOW | 22 |
| INFO | 8 |

### أكثر المناطق خطورة:
1. **المصادقة (Authentication)** — JWT بدون audience/issuer validation، refresh tokens لا تبطل القديم، localStorage للتخزين
2. **التحكم بالصلاحيات (Authorization)** — 8 endpoints تعاني IDOR (معلم يصل لبيانات معلم آخر)
3. **الحدود (Rate Limiting)** — in-memory only، لا يعمل في multi-instance
4. **المزامنة (Sync)** — AI request limit counting معطل بالكامل، trial expiry لا يُفحص
5. **التغطية (Testing)** — 0 tests للـ web portal، 1 broken test للـ Flutter

---

## 2. ثغرات أمنية — CRITICAL

### C-01: Vercel OIDC Token مكشوف في الـ Repository
- **الملف:** `web-portal/.env.vercel`
- **الوصف:** توكن OIDC صالح في ملف مرفوع للـ repo
- **الخطورة: يمكن لأي شخص لديه حق الوصول للـ repo أن ينشر كود خبيث على Vercel**
- **الإصلاح:** Revoke فوراً + إضافة `.env.vercel` إلى `.gitignore` + تدوير كل الأسرار

### C-02: AI Request Limit معطل بالكامل
- **الملف:** `backend/src/core/subscription_guard.py:63-69`
- **الوصف:** `current = 0` Hardcoded — لا يوجد عدّ لاستخدام AI
- **التأثير:** أي مستخدم (حتى مجاني) يمكنه استعمال AI بلا حدود
- **الإصلاح:** تنفيذ عدّ حقيقي في Redis/Database

### C-03: Trial Expiry لا يُفحص
- **الملف:** `backend/src/core/subscription_guard.py:17-26, 93-110`
- **الوصف:** دوال التحقق من الاشتراك لا تفحص `trial_end_date`
- **التأثير:** مستخدمون منتهية صلاحية نسختهم التجريبية لا يزالون يحصلون على كل المميزات

### C-04: TOCTOU Race Condition في إنشاء الطلاب
- **الملف:** `backend/src/api/students.py:28` + `subscription_guard.py:93-100`
- **الوصف:** بين التحقق من حد الطلاب والإنشاء الفعلي، يمكن طلب متزامن أن يتجاوز الحد
- **الإصلاح:** استخدام PostgreSQL advisory lock أو transaction Serializable

### C-05: Client-Side Only Authentication
- **الملف:** `web-portal/src/components/layout/ProtectedRoute.tsx`
- **الوصف:** التحقق من المصادقة يتم بالكامل في المتصفح عبر `localStorage.getItem()`
- **التأثير:** أي شخص يفتح DevTools ويضيف `access_token` إلى localStorage يحصل على وصول كامل
- **الإصلاح:** إضافة `middleware.ts` مع تحقق من صحة التوكن على السيرفر

### C-06: Admin Route بدون تحقق صلاحية
- **الملف:** `web-portal/src/app/admin/analytics/page.tsx`
- **الوصف:** صفحة `/admin/analytics` تظهر لأي مستخدم Authenticated
- **التأثير:** أي معلم أو طالب يمكنه رؤية تحليلات النظام الحساسة (عدد المستخدمين، معدلات الأعطال)

### C-07: Attendance Bulk بدون Validation
- **الملف:** `backend/src/api/attendance.py:57-99`
- **الوصف:** `records: list[dict]` بدون schema — بيانات خام تمر إلى قاعدة البيانات بدون تحقق من ملكية student_id
- **الإصلاح:** استخدام Pydantic model للتحقق من كل record + التحقق من student ownership

### C-08: JWT Algorithm Confusion
- **الملف:** `backend/src/core/security/auth.py:26,32,37`
- **الوصف:** ALGORITHM يُقرأ من الإعدادات بدون allowlist
- **الإصلاح:** Hardcode allowed algorithms (HS256 only)

### C-09: In-Memory Rate Limiter
- **الملف:** `backend/src/main.py:33, 221-247`
- **الوصف:** defaultdict في الذاكرة — لا يصمد مع إعادة التشغيل أو multiple instances
- **الإصلاح:** استخدام Redis

### C-10: JWT Tokens in localStorage
- **الملف:** `web-portal/src/lib/auth.ts`
- **الوصف:** localStorage يسمح لأي JavaScript في نفس origin بقراءة التوكنات
- **الإصلاح:** استخدام HttpOnly Cookies

### C-11: التحقق من الصلاحية في `POST /attendance/bulk` و `POST /exams/result/{id}`
- **الملف:** `backend/src/api/attendance.py`, `exams.py`
- **الوصف:** لا تحقق من ملكية student_id في attendance، ولا تحقق من ملكية teacher للنتائج
- **التأثير:** معلم يمكنه التلاعب بحضور أي طالب في النظام، أو عرض نتائج أي طالب

### C-12: Unauthenticated File Writes
- **الملف:** `backend/src/api/analytics.py:14-37`, `versions.py:337-352`
- **الوصف:** `POST /analytics/event` و `POST /telemetry/event` بدون auth — أي شخص يكتب ملفات JSONL
- **الإصلاح:** إضافة auth أو rate limiting حاد

---

## 3. ثغرات أمنية — HIGH

### H-01: لا يوجد Account Lockout
- **الملف:** `backend/src/api/auth.py:87-105`
- **الوصف:** `/login` بدون حماية brute-force
- **الإصلاح:** تنفيذ lockout بعد N محاولة فاشلة باستخدام Redis

### H-02: لا يوجد Password Complexity
- **الملف:** `backend/src/api/auth.py:18-28`
- **الوصف:** `min_length=6` فقط، كلمات مرور مثل `123456` مسموحة
- **الإصلاح:** فرض minimum 8 characters + uppercase + digit + special

### H-03: Refresh Token Rotation غير مفعل
- **الملف:** `backend/src/api/auth.py:108-122`
- **الوصف:** الـ refresh token القديم يظل صالحاً بعد التحديث
- **الإصلاح:** إبطال الـ refresh token القديم عند كل refresh

### H-04: Duplicate Route في students.py
- **الملف:** `backend/src/api/students.py:88-103, 132-148`
- **الوصف:** `GET /{student_id}/pin` معرف مرتين — الثانية تلغي الأولى
- **الإصلاح:** دمج endpoint واحد

### H-05: Teacher Code Enumeration
- **الملف:** `backend/src/api/students.py:173-183`
- **الوصف:** `POST /students/verify-teacher` بدون auth، يعيد `teacher_id` + `teacher_code` + `teacher_name`
- **الإصلاح:** إضافة auth + تقليل البيانات المرتجعة

### H-06: `get_current_student` بدون `is_active` check
- **الملف:** `backend/src/utils/dependencies.py:60-80`
- **الوصف:** الطلاب المعطلون يمكنهم استخدام التوكنات
- **الإصلاح:** إضافة `is_active` check

### H-07: Cookie بدون HttpOnly
- **الملف:** `web-portal/src/lib/auth.ts:4,9`
- **الوصف:** `Secure; SameSite=Lax` بدون `HttpOnly`
- **الإصلاح:** تعيين الـ cookies من السيرفر مع `HttpOnly`

### H-08: لا يوجد Server-Side Middleware
- **الملف:** مفقود بالكامل
- **الوصف:** لا يوجد `middleware.ts` في Next.js
- **الإصلاح:** إنشاء middleware.ts للتحقق من التوكن على السيرفر

### H-09: IDOR في Notification Read
- **الملف:** `backend/src/api/subscriptions.py:233-239`
- **الوصف:** أي معلم يمكنه وضع علامة "مقروءة" على أي إشعار
- **الإصلاح:** التحقق من ownership قبل التحديث

### H-10: IDOR في Exam Questions
- **الملف:** `backend/src/api/exams.py:178-201`
- **الوصف:** PUT/DELETE لأسئلة الامتحان لا يتحقق من ملكية السؤال للامتحان
- **الإصلاح:** التحقق من `question["exam_id"] == exam_id`

### H-11: IDOR في Exam Submission
- **الملف:** `backend/src/api/exams.py:243-256`
- **الوصف:** أي طالب يقدم أي امتحان منشور بغض النظر عن المعلم
- **الإصلاح:** التحقق من `exam["teacher_id"] == student["teacher_id"]`

### H-12: IDOR في QR Student Check-in
- **الملف:** `backend/src/api/qr.py:68-124`
- **الوصف:** لا تحقق من أن `teacher_id` يطابق group's teacher
- **الإصلاح:** التحقق من `group["teacher_id"] == teacher_id`

### H-13: Unbounded Queries في Subscription Guard
- **الملف:** `backend/src/core/subscription_guard.py:75,84`
- **الوصف:** جلب 10,000 سجل للذاكرة لمجرد العد
- **الإصلاح:** استخدام `SELECT COUNT(*)` بدلاً من جلب الكل

### H-14: Telegram Webhook NameError
- **الملف:** `backend/src/api/auth.py:57`
- **الوصف:** `subscription_plan_service` ليس مستورداً — NameError في runtime
- **الإصلاح:** إضافة الاستيراد المفقود

### H-15: Sync Push يستخدم `get_current_user`
- **الملف:** `backend/src/api/sync.py:19`
- **الوصف:** يقبل توكنات الطلاب أيضاً وليس فقط المعلمين
- **الإصلاح:** استخدام `get_current_teacher`

### H-16: Error Details Exposed
- **الملف:** `backend/src/api/versions.py:352`
- **الوصف:** `POST /telemetry/event` يعيد `str(e)` — تسريب تفاصيل الأخطاء
- **الإصلاح:** رسالة خطأ عامة

---

## 4. ثغرات أمنية — MEDIUM

| # | الوصف | الملف |
|---|-------|-------|
| M-01 | JWT بدون audience/issuer | `auth.py:25,31,37` |
| M-02 | Token type غير مُفحص | `auth.py:35-39` |
| M-03 | Database password افتراضي في الكود | `config.py:10-11` |
| M-04 | Weak rate limit key (IP + 20 chars من auth header) | `main.py:226-228` |
| M-05 | Sentry traces_sample_rate=1.0 (تسريب PII) | `main.py:15` |
| M-06 | `sanitize_text` مجرد `.strip()` — لا sanitization حقيقي | `sanitizer.py:4-7` |
| M-07 | PIN sanitization يقلل entropy (uppercase + إزالة الرموز) | `sanitizer.py:14-15` |
| M-08 | Audit log failures مكتومة | `auth.py:43-51` |
| M-09 | Student login teacher_code اختياري — لا binding للمعلم | `students.py:196-207` |
| M-10 | PDF injection عبر unsanitized names | `students.py:246-274` |
| M-11 | Trial status عبر string prefix ("trial-") قابل للتزوير | `subscription_guard.py:25` |
| M-12 | `POST /analytics/event` بدون حجم أقصى | `analytics.py:14-37` |
| M-13 | `POST /telemetry/event` بدون حجم أقصى | `versions.py:337-352` |
| M-14 | Sync pull limit بدون upper bound | `sync.py:61-99` |
| M-15 | لا CSRF protection | `src/lib/api.ts` |
| M-16 | Registration auto-login بدون email verification | `register/page.tsx` |
| M-17 | لا Security Headers في next.config.js | `next.config.js` |
| M-18 | SubscriptionGuard client-side bypass | `SubscriptionGuard.tsx` |
| M-19 | Missing file validation على payment upload | `subscription/page.tsx` |
| M-20 | Timing side-channel في student login (enumeration) | `students.py:186-207` |
| M-21 | Attendance group_id بدون ownership check | `attendance.py:36-43` |

---

## 5. مشاكل متزامنة وأداء

| # | المشكلة | التأثير | الملف |
|---|---------|---------|-------|
| P-01 | كل 3 دقائق fetch لجميع البيانات — لا incremental sync | بطء مع increase البيانات | `sync_service.dart` |
| P-02 | Unbounded queries تجلب 10K سجل للذاكرة | OOM مع البيانات الكبيرة | `subscription_guard.py` |
| P-03 | Rate limiter in-memory dictionary بدون eviction | Memory leak | `main.py` |
| P-04 | AI analyze يقارن subject بدون normalize — "Math" != "math" | فشل مطابقة | `students_screen.dart` |
| P-05 | Select بدون pagination limit في attendance list | بطء | `attendance.py` |
| P-06 | SQLAlchemy models تُستخدم كـ schema reference فقط — لا ORM حقيقي | تكرار الكود | `models/*.py` |
| P-07 | NetworkDiscovery stubbed — دائماً 127.0.0.1 | LAN P2P لا يعمل | `desktop_app` |
| P-08 | SubscriptionService لديه Dio interceptor مكرر | صيانة صعبة | `subscription_service.dart` |

---

## 6. مشاكل واجهة المستخدم (UX)

| # | المشكلة | الملف | الخطورة |
|---|---------|-------|---------|
| UX-01 | لا Error Boundaries — أي خطأ unhandled يوقف الصفحة | `web-portal` (عام) | HIGH |
| UX-02 | لا Skeleton loading في صفحات كثيرة | معظم الصفحات | MEDIUM |
| UX-03 | `auth.isAuthenticated()` يتحقق من وجود token فقط — لا يتحقق من صلاحيته | `auth.ts` | MEDIUM |
| UX-04 | Error messages تُظهر back-end details للمستخدم | `login/page.tsx`, `register/page.tsx` | LOW |
| UX-05 | لا Empty state مخصصة — معظمها "لا توجد بيانات" | صفحات متعددة | LOW |
| UX-06 | `confirm()` في delete — بدلاً من modal مخصص | `students/page.tsx` | LOW |
| UX-07 | Student search في grades_page يأخذ من flight — كل التصفية Client-side | `grades/page.tsx` | MEDIUM |

---

## 7. مشاكل المزامنة (Sync)

| # | المشكلة | التأثير | الملف |
|---|---------|---------|-------|
| S-01 | `syncFromServer()` بدون incremental — كل مرة fetch ALL | بطء شديد + data usage عالي | `sync_service.dart` |
| S-02 | `sync_queue` يطابق items بالـ `id` أو `code` — إذا تغير المفتاح تضيع المزامنة | فقدان بيانات | `local_db.dart` |
| S-03 | `ConflictResolver` فقط last-writer-wins — لا merge على مستوى الحقول | فقدان تغييرات | `conflict_resolver.dart` |
| S-04 | No idempotency keys في sync queue — duplicate items ممكنة | تكرار بيانات | `local_db.dart` |
| S-05 | Backup قبل كل `syncFromServer()` — مع البيانات الكبيرة يستنزف المساحة | Disk full | `sync_service.dart` |
| S-06 | `clearSyncedItems()` يحذف كل `synced == true` — بدون تحقق من server ack | فقدان بيانات غير مؤكدة | `local_db.dart` |
| S-07 | `_onSyncChange` يستمع لتغيرات الاتصال لكنه لا يتعامل مع partial connectivity | تزامن غير كامل | `data_provider.dart` |
| S-08 | لا يوجد dedup للـ sync queue items — نفس العملية قد تضاف مراراً | تكرار | `local_db.dart` |

---

## 8. تغطية الاختبارات

### 8.1 Backend (Python)
| المنطقة | الاختبارات الحالية | المطلوبة | التغطية |
|---------|-------------------|---------|---------|
| Auth | 5 tests (3 تعمل) | 15+ | 10% |
| AI Analyzer | 5 tests (3 تعمل) | 10+ | 20% |
| Encryption | 5 tests (كلها تعمل) | 10+ | 30% |
| Students | 0 | 20+ | 0% |
| Groups | 0 | 10+ | 0% |
| Attendance | 0 | 15+ | 0% |
| Grades | 0 | 10+ | 0% |
| Invoices | 0 | 10+ | 0% |
| Sync | 0 | 20+ | 0% |
| QR | 0 | 10+ | 0% |
| Subscriptions | 0 | 15+ | 0% |
| Exams | 0 | 25+ | 0% |
| **المجموع** | **15 (11 تعمل)** | **170+** | **6%** |

### 8.2 Web Portal (Next.js/TypeScript)
| المنطقة | الاختبارات الحالية | المطلوبة | التغطية |
|---------|-------------------|---------|---------|
| **الكل** | **0** | **100+** | **0%** |

### 8.3 Desktop App (Flutter)
| المنطقة | الاختبارات الحالية | المطلوبة | التغطية |
|---------|-------------------|---------|---------|
| Widget | 1 (لا يعمل - broken import) | 50+ | 0% |
| Unit | 0 | 80+ | 0% |
| Integration | 0 | 30+ | 0% |
| **المجموع** | **1 (broken)** | **160+** | **0%** |

---

## 9. التوصيات

### أولوية فورية (قبل الإطلاق):
1. إزالة `.env.vercel` من الـ repo + Revoke Vercel OIDC token
2. إصلاح AI request limit counting (حالياً `current = 0` hardcoded)
3. إضافة `middleware.ts` للتحقق من التوكن على السيرفر
4. إصلاح IDOR في `POST /attendance/bulk` و `GET /exams/result/{id}`
5. إبطال `traces_sample_rate=1.0` في Sentry production

### أولوية عالية (الأسبوع الأول):
6. تنفيذ refresh token rotation
7. إضافة HttpOnly cookies بدلاً من localStorage للتوكنات
8. إضافة rate limiting حقيقي (Redis)
9. إصلاح Trial expiry check
10. تغطية الاختبارات: كتابة 50+ API test

### أولوية متوسطة (الشهر الأول):
11. تنفيذ incremental/delta sync
12. إضافة Error Boundaries للـ web portal
13. إضافة Content-Security-Policy
14. تثبيت Sentry في Flutter و Web portal
15. تنفيذ Idempotency keys في sync queue

---

## 10. الإصلاحات المطبّعة (Production Hardening — 2026-05-28)

### 10.1 Database Integrity
- 8 new migration files (006–013) added:
  - `006_unique_constraints.sql` — unique student code per teacher, attendance per student/day, grade per student/exam
  - `007_check_constraints.sql` — score ≤ max_score, positive amounts, valid status enums, email format
  - `008_additional_indexes.sql` — updated_at indexes, combined teacher_id queries, Arabic full-text search
  - `009_sync_cursors.sql` — per-table cursor tracking for incremental sync
  - `010_dead_letter_queue.sql` — isolated queue for corrupted/unprocessable items
  - `011_audit_enhancements.sql` — device_id, session_id, before/after state, duration_ms
  - `012_subscription_constraints.sql` — price/student limits positive, end_date > start_date
  - `013_operation_id_tracking.sql` — idempotency via processed_operations table with 7-day cleanup
- `scripts/integrity_reporter.py` — CLI scanner: 13 integrity checks (orphan records, null violations, negative scores, duplicate codes, duplicate attendance)

### 10.2 Incremental Sync
- **Backend** (`backend/src/services/sync_buffer.py`):
  - `operation_id` (UUID v4) on every queue item for idempotency
  - `is_operation_processed()` / `mark_operation_processed()` — dedup via Redis set with 7-day TTL
  - Dead-letter queue with retry tracking (max 3 retries, auto-isolate)
  - `recover_dead_letters()` — replay dead items back into live queue
  - `cleanup_old_items()` — TTL-based purging of stale queue items
- **Flutter** (`desktop_app/lib/core/sync_service.dart`):
  - Cursor-based incremental sync: `_cursorMap` persisted in Hive `sync_cursors` box
  - `_processBatch()` — per-table batch processing with cursor save
  - `_recoverDeadLetters()` — automatic dead-letter replay on each `fullSync()`
  - `AckResponse` cycle: pushes `acked_ids` to `/sync/ack` after successful upload
- **Flutter** (`desktop_app/lib/core/local_db.dart`):
  - `deadLetterBox` Hive box — corrupted items isolated from live queue
  - `operation_id` (UUID v4) on every sync queue item
  - Transaction checkpoints: `box.flush()` after every batch write
  - `recoverDeadLetters()` — batch replay of dead letters into sync queue
  - Cursor tracking: `syncCursorsBox` for per-table timestamps

### 10.3 Queue Crash Recovery
- Dead-letter queue isolates corrupted items instead of blocking entire sync
- `recoverDeadLetters()` runs at start of every `fullSync()`
- Operation IDs prevent duplicate processing even if client retries
- Max 3 retries before automatic dead-letter isolation
- `sync_buffer.push_to_dead_letter()` for backend-side isolation
- `dead_letter_queue` DB table with `retry_count`, `error_message`, `status` tracking

### 10.4 Conflict Resolution (Field-Level Merge)
- **Backend** (`conflict_resolver.py`):
  - `SERVER_AUTHORITATIVE_TABLES` — invoices/attendance always use server version
  - `FIELD_BASED_MERGE_TABLES` — students/groups merge at field level, not record level
  - Immutable fields (`id`, `code`, `created_at`, `teacher_id`) always use server value
  - Per-field conflict logging with resolution strategy
  - `resolve_batch()` for multi-record conflict resolution
- **Flutter** (`conflict_resolver.dart`):
  - Matched backend strategy: server-authoritative for invoices/payments
  - Field-merge for students/groups with immutables preserved
  - Device priority for payments (accounts device preferred)
  - Conflict logs stored in Hive `conflict_logs` box with resolver metadata

### 10.5 Audit Logging
- **Backend** (`backend/src/api/audit.py`):
  - `POST /audit/log` — tamper-resistant append-only logging
  - `GET /audit/logs` — searchable with filters (actor_id, resource_type, action, date range)
  - `GET /audit/export` — JSONL export for admin audit trail
  - Enhanced fields: `before_state`, `after_state`, `device_id`, `session_id`, `duration_ms`
  - `AuditService.search()` in Supabase — supports filtered paginated queries
- **Migrations**: `011_audit_enhancements.sql` adds new columns with indexes

### 10.6 CI/CD Security Gates
- `.github/workflows/ci.yml`:
  - Python lint (flake8) + type check (mypy)
  - Backend tests (pytest, 15+ coverage)
  - Flutter analyze (no fatal-infos)
  - Web lint (ESLint, max 50 warnings) + type check (tsc)
  - Web build verification (npm run build)
  - npm audit (fail on critical severity)
  - Python dependency audit (pip-audit)
  - Secrets scan (truffleHog across diff)
  - Database integrity reporter run

### 10.7 ما زال معلقاً
- [ ] High concurrency load testing (k6) — 100/1000/5000/10000 concurrent
- [ ] Memory leak detection in Flutter (long-running session, navigation cyclying)
- [ ] Sentry Flutter re-installation (blocked by libcurl-dev/libsecret-1-dev on build machine)
- [ ] Web portal E2E tests (Playwright installed, tests pending)
- [ ] API contract tests (Newman installed, Postman collections pending)
- [ ] Backup & restore system (encrypted scheduled snapshots)
- [ ] Push all changes to GitHub (waiting for hardening mission completion)---
