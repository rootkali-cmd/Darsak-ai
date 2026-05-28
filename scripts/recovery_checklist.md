# DarsakAI Disaster Recovery & Production Validation Checklist

## 1. Backup Verification

### Daily Checks
- [ ] Run `python backend/scripts/backup_manager.py verify latest`
- [ ] Verify backup manifest exists and is readable
- [ ] Check backup size is within expected range (>100MB for full, >10MB for pg-only)
- [ ] Verify PostgreSQL dump contains all tables
- [ ] Verify at least one successful backup in the last 24 hours

### Weekly Checks
- [ ] Perform restore dry-run: `python backend/scripts/restore.py restore <backup_id> --dry-run`
- [ ] Validate target schema: `python backend/scripts/restore.py validate-schema`
- [ ] Simulate corruption detection: `python backend/scripts/restore.py simulate-corruption <backup_id>`
- [ ] Verify corruption is detected by: `python backend/scripts/restore.py verify <backup_id>`
- [ ] Check retention policy compliance: `python backend/scripts/backup_manager.py cleanup --dry-run`

### Monthly Checks
- [ ] Full restore to test environment
- [ ] Verify restored data count matches production
- [ ] Test login with restored credentials
- [ ] Verify sync operations work with restored DB
- [ ] Measure and document restore time (target: < 30 min for full restore)

---

## 2. Load Test Execution

### Prerequisites
- [ ] k6 installed: `which k6`
- [ ] Target API is accessible
- [ ] Test credentials exist in database
- [ ] Sufficient test data loaded (>100 students, >10 groups per teacher)

### Test Scenarios

#### 2a. General Load Test
```bash
# Light load (smoke test)
k6 run --vus 10 --duration 1m scripts/load_test.js

# Medium load
k6 run --vus 100 --duration 5m scripts/load_test.js

# Heavy load
k6 run --vus 1000 --duration 10m scripts/load_test.js

# Maximum load
k6 run --vus 5000 --duration 5m scripts/load_test.js

# Extreme load (if infra can handle)
k6 run --vus 10000 --duration 3m scripts/load_test.js
```

#### 2b. Sync Storm Test
```bash
# Simulate offline accumulation + reconnect
k6 run --vus 200 --duration 10m scripts/sync_storm_test.js

# Simulate mass reconnection event
k6 run --vus 500 --duration 5m scripts/sync_storm_test.js
```

### Thresholds
- [ ] Failure rate < 5% for all endpoints
- [ ] p95 latency < 3s for read endpoints
- [ ] p95 latency < 5s for write/sync endpoints
- [ ] No 429 (rate limit) errors on authenticated endpoints
- [ ] No 500 errors during steady state
- [ ] Sync operations complete within 30s at 200 concurrent users

---

## 3. Memory Leak Detection (Flutter Desktop)

### Quick Check (5 min)
- [ ] Launch desktop app
- [ ] Navigate between all screens (Home, Students, Grades, Attendance, Invoices, Settings)
- [ ] Trigger sync cycle
- [ ] Check RAM usage before/after (target: < 50MB increase)

### Medium Check (1 hour)
- [ ] Run app with 500+ students in local DB
- [ ] Navigate continuously (5s per screen)
- [ ] Trigger sync every 3 minutes
- [ ] Monitor RAM: should stabilize ±20MB
- [ ] Check for unclosed streams/sockets

### Extended Check (8+ hours)
- [ ] Leave app running with auto-sync enabled
- [ ] Simulate connectivity changes every 5 minutes
- [ ] Load large invoices list (100+ items)
- [ ] Generate and print QR codes
- [ ] Verify RAM stabilizes (no linear growth)
- [ ] Check Hive box sizes are stable
- [ ] Verify no timer/stream accumulation

### Known Risk Areas
- [ ] `StreamSubscription` in `SyncService._connectivitySubscription`
- [ ] `Timer.periodic` in `SyncService._syncTimer`
- [ ] `Provider` listeners in dashboard widgets
- [ ] `Image.memory` caches in student avatars
- [ ] Hive box watchers in data providers

---

## 4. Production Validation Test Cases

### 4.1 Authentication & Authorization
- [ ] Login with valid credentials → 200 + token
- [ ] Login with wrong password → 401
- [ ] Login with deactivated account → 403
- [ ] Access protected route without token → 401
- [ ] Access admin route as teacher → 403
- [ ] Access teacher route as student → 403
- [ ] Token refresh with valid token → 200 + new token
- [ ] Token refresh with expired token → 401
- [ ] Reuse old refresh token → 401 (rotation check)
- [ ] HttpOnly cookie present in login response

### 4.2 Sync Operations
- [ ] Push encrypted payload → 201 with queue_id
- [ ] Pull pending items → returns items with expected fields
- [ ] Ack processed items → items marked synced
- [ ] Ack non-existent items → graceful handling (no error)
- [ ] Push with duplicate operation_id → idempotent
- [ ] Pull with since parameter → returns only newer items
- [ ] Pull with limit=0 → empty result
- [ ] Sync with corrupted ciphertext → graceful error
- [ ] Concurrent push from same teacher → no data loss
- [ ] Dead-letter recovery → corrupted items isolated

### 4.3 Data Integrity
- [ ] Create student → stored with unique code
- [ ] Create student with duplicate code → 409 or 400
- [ ] Create grade with score > max_score → constraint violation
- [ ] Create invoice with negative amount → constraint violation
- [ ] Delete student → cascade deletes attendance/grades
- [ ] Orphan record check: run `integrity_reporter.py`
- [ ] Audit log created for all mutating operations

### 4.4 Rate Limiting
- [ ] Rapid login attempts (10+ in 60s) → 429
- [ ] Normal API usage → no rate limiting
- [ ] Rate limit resets after window expires

### 4.5 Security Headers
- [ ] HSTS header present: `max-age=31536000; includeSubDomains`
- [ ] X-Content-Type-Options: `nosniff`
- [ ] X-Frame-Options: `DENY`
- [ ] Content-Security-Policy: present and valid
- [ ] Referrer-Policy: present
- [ ] Permissions-Policy: present

### 4.6 Offline Recovery
- [ ] Kill network while syncing → graceful failure message
- [ ] Restore network → auto-reconnect within max 120s
- [ ] Offline changes → queued in sync_queue
- [ ] Reconnect → queued items pushed to server
- [ ] Server rejects item → moved to dead_letter
- [ ] Dead letter → recoverable via `recoverDeadLetters()`
- [ ] Multiple offline periods → no data loss

### 4.7 Subscription & AI Limits
- [ ] Trial teacher → limited AI requests (check counting)
- [ ] Expired trial → AI requests blocked
- [ ] Paid subscription → full access
- [ ] AI request count increments correctly
- [ ] AI request count resets monthly

---

## 5. Deployment Readiness

### Environment Configuration
- [ ] All secrets in environment variables, NOT in code
- [ ] `.env.vercel` is in `.gitignore` (token leak fixed)
- [ ] `SECRET_KEY` is 64+ char hex string
- [ ] `SUPABASE_JWT_SECRET` matches Supabase dashboard
- [ ] `CORS_ORIGINS` restricted to known domains
- [ ] `LOG_LEVEL` = `INFO` in production (not `DEBUG`)
- [ ] `SENTRY_DSN` set for error monitoring
- [ ] `traces_sample_rate` = 0.1 for production (not 1.0)

### CI/CD Pipeline
- [ ] CI passes all checks (lint, test, build)
- [ ] npm audit passes (no critical vulnerabilities)
- [ ] pip-audit passes (no critical vulnerabilities)
- [ ] truffleHog scan passes (no leaked secrets)
- [ ] Flutter analyze passes (no errors)
- [ ] Web build succeeds (no TypeScript errors)
- [ ] All 33+ backend tests pass

### Monitoring
- [ ] Sentry DSN configured for backend
- [ ] Sentry DSN configured for web portal
- [ ] Backend health check endpoint responds 200
- [ ] Audit logging enabled and operational
- [ ] Error alerting configured (email, Slack, Telegram)
- [ ] Rate limit monitoring in place

### Rollback
- [ ] Last known good backup identified
- [ ] Rollback procedure documented
- [ ] Restore to previous version < 30 minutes
- [ ] Database rollback tested in staging
- [ ] Frontend rollback via Vercel dashboard (instant)
- [ ] Desktop app rollback via AppVeyor artifacts

---

## 6. Launch Checklist

### Pre-Launch (24 hours before)
- [ ] Run full backup: `python backend/scripts/backup_manager.py create --type full`
- [ ] Verify backup integrity: `python backend/scripts/backup_manager.py verify <backup_id>`
- [ ] Run integrity reporter: `python backend/scripts/integrity_reporter.py`
- [ ] Run k6 smoke test: `k6 run --vus 10 --duration 1m scripts/load_test.js`
- [ ] Check Sentry for recent errors
- [ ] Verify all environment variables are correct
- [ ] Verify security headers with curl
- [ ] Final code review of all changes

### Launch Day
- [ ] Push latest code to main branch
- [ ] Verify Vercel deployment succeeds
- [ ] Verify Fly.io deployment succeeds
- [ ] Run health checks on all services
- [ ] Smoke test login flow
- [ ] Smoke test sync flow
- [ ] Monitor Sentry for first-hour errors
- [ ] Monitor API latency (target: p95 < 2s)
- [ ] Monitor error rate (target: < 1%)

### Post-Launch (48 hours after)
- [ ] Review Sentry error report
- [ ] Review k6 load test results
- [ ] Verify backup was created post-launch
- [ ] Check database size growth
- [ ] Survey beta users for issues
- [ ] Document any production-only bugs found

---

## 7. Production Readiness Score Calculator

| Category | Max Score | Score | Notes |
|----------|-----------|-------|-------|
| Backup & Restore | 20 | | |
| Load Testing | 20 | | |
| Memory Stability | 15 | | |
| Auth Security | 15 | | |
| Data Integrity | 10 | | |
| Sync Durability | 10 | | |
| Monitoring | 5 | | |
| CI/CD | 5 | | |
| **Total** | **100** | | |

**Pass threshold:** 80/100
**Conditional pass:** 70/80 (with documented exceptions)
**Fail:** < 70 — Do NOT launch

---

## 8. Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Backend SRE | Ahmed | [contact] |
| Frontend Lead | [name] | [contact] |
| Database Admin | [name] | [contact] |
| Infrastructure | [name] | [contact] |

---

## 9. Known Production Risks (unresolved)

| Risk | Severity | Mitigation | Owner |
|------|----------|------------|-------|
| Sentry Flutter not installed | Medium | Manual monitoring for now | Ahmed |
| No Playwright E2E tests yet | Medium | Manual smoke tests before launch | Ahmed |
| k6 load tests not executed | Medium | Run before launch | Ahmed |
| Memory leak not profiled | Low | Desktop app limited session (~2hr) | Ahmed |
