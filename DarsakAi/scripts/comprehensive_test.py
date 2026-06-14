#!/usr/bin/env python3
"""
DarsakAI Comprehensive Test Tool - Open Source
Tests all features and generates detailed HTML reports.

Usage:
    python scripts/comprehensive_test.py [--url <base_url>] [--report <path>]

Dependencies:
    pip install httpx
"""

import argparse
import datetime
import json
import os
import random
import string
import sys
import time
import traceback
import uuid
from dataclasses import dataclass, field

try:
    import httpx
except ImportError:
    print("Missing dependency: httpx")
    print("Install with: pip install httpx")
    sys.exit(1)


@dataclass
class TestResult:
    name: str
    category: str
    passed: bool
    detail: str = ""
    duration_ms: float = 0.0
    request: str = ""
    response: str = ""


@dataclass
class TestSuite:
    base_url: str
    results: list[TestResult] = field(default_factory=list)
    _token: str | None = None
    _refresh_token: str | None = None
    _student_token: str | None = None
    _teacher_id: str | None = None
    _teacher_code: str | None = None
    _student_id: str | None = None
    _student_code: str | None = None
    _group_id: str | None = None
    _grade_id: str | None = None
    _invoice_id: str | None = None
    _attendance_date: str | None = None
    _exam_id: str | None = None
    _start_time: float = 0.0

    def _api_url(self, path: str) -> str:
        return f"{self.base_url}/api{path}"

    def _headers(self) -> dict:
        h = {"Content-Type": "application/json"}
        if self._token:
            h["Authorization"] = f"Bearer {self._token}"
        return h

    def _log(self, name: str, category: str, passed: bool, detail: str = "",
             duration_ms: float = 0.0, req: str = "", resp: str = ""):
        self.results.append(TestResult(
            name=name, category=category, passed=passed,
            detail=detail, duration_ms=duration_ms,
            request=req[:500], response=resp[:500],
        ))

    def _test(self, name: str, category: str, fn, *args, **kwargs):
        start = time.time()
        try:
            fn(*args, **kwargs)
            self._log(name, category, True, duration_ms=(time.time() - start) * 1000)
        except AssertionError as e:
            self._log(name, category, False, detail=str(e),
                      duration_ms=(time.time() - start) * 1000)
        except Exception as e:
            tb = traceback.format_exc()
            self._log(name, category, False, detail=f"{type(e).__name__}: {e}",
                      duration_ms=(time.time() - start) * 1000, resp=tb)

    def _rand_str(self, n=8) -> str:
        return ''.join(random.choices(string.ascii_lowercase, k=n))

    def run_all(self):
        self._start_time = time.time()
        print(f"\n{'='*60}")
        print(f"  DarsakAI Comprehensive Test Tool")
        print(f"  Target: {self.base_url}")
        print(f"  Started: {datetime.datetime.now().isoformat()}")
        print(f"{'='*60}\n")

        self._test_health()
        self._test_auth()
        self._test_students()
        self._test_groups()
        self._test_attendance()
        self._test_grades()
        self._test_invoices()
        self._test_sync()
        self._test_exams()
        self._test_versions()
        self._test_analytics()
        self._test_audit()
        self._test_subscriptions()
        self._test_student_me()
        self._test_error_handling()

        self._print_summary()

    # ─── Health ────────────────────────────────────────────────
    def _test_health(self):
        def _check():
            r = httpx.get(f"{self.base_url}/health", timeout=10)
            assert r.status_code == 200, f"Expected 200, got {r.status_code}"
            data = r.json()
            assert "status" in data, f"No status in: {data}"
        self._test("GET /health", "Health", _check)

    # ─── Auth ──────────────────────────────────────────────────
    def _test_auth(self):
        email = f"test_{self._rand_str()}@example.com"
        password = "TestPass123!"
        full_name = f"Test User {self._rand_str(4)}"

        def _register():
            r = httpx.post(self._api_url("/auth/register"), json={
                "email": email, "password": password,
                "full_name": full_name, "role": "teacher",
            }, timeout=15)
            assert r.status_code == 201, f"Register failed: {r.status_code} {r.text}"
            data = r.json()
            assert "id" in data, f"No id in: {data}"
            assert "teacher_code" in data, f"No teacher_code in: {data}"
            self._teacher_id = data["id"]
            self._teacher_code = data.get("teacher_code", "")
        self._test("POST /auth/register", "Auth", _register)

        def _login():
            r = httpx.post(self._api_url("/auth/login"), json={
                "email": email, "password": password,
            }, timeout=15)
            assert r.status_code == 200, f"Login failed: {r.status_code} {r.text}"
            data = r.json()
            assert "access_token" in data, f"No access_token in: {data}"
            assert "refresh_token" in data, f"No refresh_token in: {data}"
            self._token = data["access_token"]
            self._refresh_token = data["refresh_token"]
        self._test("POST /auth/login", "Auth", _login)

        def _me():
            r = httpx.get(self._api_url("/auth/me"), headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"GET /auth/me failed: {r.status_code} {r.text}"
            data = r.json()
            assert data.get("email") == email, f"Email mismatch: {data.get('email')} != {email}"
        self._test("GET /auth/me", "Auth", _me)

        def _refresh():
            r = httpx.post(self._api_url("/auth/refresh"), json={
                "refresh_token": self._refresh_token,
            }, headers={"Content-Type": "application/json"}, timeout=10)
            assert r.status_code == 200, f"Refresh failed: {r.status_code} {r.text}"
            data = r.json()
            assert "access_token" in data, f"No access_token after refresh: {data}"
            self._token = data["access_token"]
        self._test("POST /auth/refresh", "Auth", _refresh)

        def _bad_login():
            r = httpx.post(self._api_url("/auth/login"), json={
                "email": email, "password": "wrongpassword",
            }, timeout=10)
            assert r.status_code == 401, f"Expected 401, got {r.status_code}"
        self._test("POST /auth/login (wrong password)", "Auth - Error", _bad_login)

        def _unauthorized():
            r = httpx.get(self._api_url("/students/"), timeout=10)
            assert r.status_code == 403, f"Expected 403, got {r.status_code}"
        self._test("GET /students/ (no auth)", "Auth - Error", _unauthorized)

    # ─── Students ──────────────────────────────────────────────
    def _test_students(self):
        name = f"Student {self._rand_str(6)}"

        def _create():
            r = httpx.post(self._api_url("/students/"), json={
                "full_name": name, "pin": "ABC123",
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 201, f"Create student failed: {r.status_code} {r.text}"
            data = r.json()
            assert "id" in data, f"No id in: {data}"
            assert "code" in data, f"No code in: {data}"
            self._student_id = data["id"]
            self._student_code = data["code"]
        self._test("POST /students/", "Students", _create)

        def _list():
            r = httpx.get(self._api_url("/students/"), headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List students failed: {r.status_code}"
            data = r.json()
            assert isinstance(data, list), f"Expected list, got {type(data)}"
        self._test("GET /students/", "Students", _list)

        def _get_by_id():
            r = httpx.get(self._api_url(f"/students/{self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Get student failed: {r.status_code} {r.text}"
            data = r.json()
            assert data.get("id") == self._student_id, f"ID mismatch"
        self._test("GET /students/{id}", "Students", _get_by_id)

        def _check_pin():
            r = httpx.get(self._api_url(f"/students/{self._student_id}/pin"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Check pin failed: {r.status_code} {r.text}"
            data = r.json()
            assert "has_pin" in data, f"No has_pin in: {data}"
        self._test("GET /students/{id}/pin", "Students", _check_pin)

        def _reset_pin():
            r = httpx.patch(self._api_url(f"/students/{self._student_id}/pin"),
                           json={"pin": "XYZ789"}, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Reset pin failed: {r.status_code} {r.text}"
            data = r.json()
            assert data.get("has_pin") is True, f"has_pin not True: {data}"
        self._test("PATCH /students/{id}/pin", "Students", _reset_pin)

        def _count():
            r = httpx.get(self._api_url("/students/count"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Count failed: {r.status_code}"
            data = r.json()
            assert "count" in data, f"No count in: {data}"
        self._test("GET /students/count", "Students", _count)

        def _update():
            new_name = f"Updated {name}"
            r = httpx.patch(self._api_url(f"/students/{self._student_id}"),
                           json={"full_name": new_name},
                           headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Update failed: {r.status_code} {r.text}"
            data = r.json()
            assert data.get("full_name") == new_name, f"Name not updated"
        self._test("PATCH /students/{id}", "Students", _update)

    # ─── Groups ────────────────────────────────────────────────
    def _test_groups(self):
        group_name = f"Group {self._rand_str(5)}"

        def _create():
            r = httpx.post(self._api_url("/groups/"), json={
                "name": group_name, "subject": "math",
                "level": "1st_prep", "day_of_week": "sunday",
                "time_slot": "10:00-11:30",
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 201, f"Create group failed: {r.status_code} {r.text}"
            data = r.json()
            assert "id" in data, f"No id in: {data}"
            self._group_id = data["id"]
        self._test("POST /groups/", "Groups", _create)

        def _list():
            r = httpx.get(self._api_url("/groups/"), headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List failed: {r.status_code}"
            data = r.json()
            assert isinstance(data, list), f"Expected list"
        self._test("GET /groups/", "Groups", _list)

        def _get():
            r = httpx.get(self._api_url(f"/groups/{self._group_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Get failed: {r.status_code} {r.text}"
            data = r.json()
            assert data.get("id") == self._group_id
        self._test("GET /groups/{id}", "Groups", _get)

        def _update():
            r = httpx.patch(self._api_url(f"/groups/{self._group_id}"),
                           json={"name": f"Updated {group_name}"},
                           headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Update failed: {r.status_code} {r.text}"
        self._test("PATCH /groups/{id}", "Groups", _update)

        def _delete():
            r = httpx.delete(self._api_url(f"/groups/{self._group_id}"),
                            headers=self._headers(), timeout=10)
            assert r.status_code == 204, f"Delete failed: {r.status_code}"
        self._test("DELETE /groups/{id}", "Groups", _delete)

    # ─── Attendance ────────────────────────────────────────────
    def _test_attendance(self):
        self._attendance_date = datetime.date.today().isoformat()

        def _mark():
            r = httpx.post(self._api_url("/attendance/"), json={
                "student_id": self._student_id,
                "group_id": self._group_id or "",
                "date": self._attendance_date,
                "status": "present",
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Mark attendance failed: {r.status_code} {r.text}"
        self._test("POST /attendance/", "Attendance", _mark)

        def _bulk():
            r = httpx.post(self._api_url("/attendance/bulk"), json={
                "records": [{
                    "student_id": self._student_id,
                    "date": self._attendance_date,
                    "status": "present",
                }],
            }, headers=self._headers(), timeout=15)
            assert r.status_code in (200, 201), f"Bulk failed: {r.status_code} {r.text}"
        self._test("POST /attendance/bulk", "Attendance", _bulk)

        def _list():
            r = httpx.get(self._api_url(f"/attendance/?student_id={self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List failed: {r.status_code}"
        self._test("GET /attendance/", "Attendance", _list)

        def _stats():
            r = httpx.get(self._api_url(f"/attendance/stats?student_id={self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Stats failed: {r.status_code}"
        self._test("GET /attendance/stats", "Attendance", _stats)

    # ─── Grades ────────────────────────────────────────────────
    def _test_grades(self):
        def _create():
            r = httpx.post(self._api_url("/grades/"), json={
                "student_id": self._student_id,
                "exam_name": "Quiz 1",
                "subject": "math",
                "score": 85, "max_score": 100,
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Create grade failed: {r.status_code} {r.text}"
            data = r.json()
            self._grade_id = data.get("id")
        self._test("POST /grades/", "Grades", _create)

        def _bulk():
            r = httpx.post(self._api_url("/grades/bulk"), json={
                "grades": [{
                    "student_id": self._student_id,
                    "exam_name": "Quiz 2", "subject": "science",
                    "score": 90, "max_score": 100,
                }],
            }, headers=self._headers(), timeout=15)
            assert r.status_code in (200, 201), f"Bulk failed: {r.status_code} {r.text}"
        self._test("POST /grades/bulk", "Grades", _bulk)

        def _list():
            r = httpx.get(self._api_url(f"/grades/?student_id={self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List failed: {r.status_code}"
        self._test("GET /grades/", "Grades", _list)

        def _stats():
            r = httpx.get(self._api_url(f"/grades/stats?student_id={self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Stats failed: {r.status_code}"
        self._test("GET /grades/stats", "Grades", _stats)

    # ─── Invoices ──────────────────────────────────────────────
    def _test_invoices(self):
        def _create():
            r = httpx.post(self._api_url("/invoices/"), json={
                "student_id": self._student_id,
                "amount": 500.0, "due_date": datetime.date.today().isoformat(),
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Create invoice failed: {r.status_code} {r.text}"
            data = r.json()
            self._invoice_id = data.get("id")
        self._test("POST /invoices/", "Invoices", _create)

        def _list():
            r = httpx.get(self._api_url(f"/invoices/?student_id={self._student_id}"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List failed: {r.status_code}"
        self._test("GET /invoices/", "Invoices", _list)

        def _update():
            r = httpx.patch(self._api_url(f"/invoices/{self._invoice_id}"),
                           json={"paid": True},
                           headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Update failed: {r.status_code} {r.text}"
        self._test("PATCH /invoices/{id}", "Invoices", _update)

        def _stats():
            r = httpx.get(self._api_url("/invoices/stats"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Stats failed: {r.status_code}"
        self._test("GET /invoices/stats", "Invoices", _stats)

    # ─── Sync ──────────────────────────────────────────────────
    def _test_sync(self):
        def _push():
            payload = {
                "payload_type": "test",
                "ciphertext": "dGVzdA==",
                "iv": "dGVzdA==",
                "auth_tag": "dGVzdA==",
            }
            r = httpx.post(self._api_url("/sync/push"), json=payload,
                          headers=self._headers(), timeout=10)
            assert r.status_code in (200, 201), f"Push failed: {r.status_code} {r.text}"
        self._test("POST /sync/push", "Sync", _push)

        def _pull():
            r = httpx.get(self._api_url("/sync/pull?since=2020-01-01T00:00:00Z&limit=10"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Pull failed: {r.status_code} {r.text}"
        self._test("GET /sync/pull", "Sync", _pull)

    # ─── Exams ─────────────────────────────────────────────────
    def _test_exams(self):
        def _create():
            r = httpx.post(self._api_url("/exams/"), json={
                "title": f"Exam {self._rand_str(4)}",
                "duration_minutes": 30,
            }, headers=self._headers(), timeout=10)
            assert r.status_code in (200, 201), f"Create exam failed: {r.status_code} {r.text}"
            data = r.json()
            self._exam_id = data.get("id")
        self._test("POST /exams/", "Exams", _create)

        def _list():
            r = httpx.get(self._api_url("/exams/"), headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List exams failed: {r.status_code}"
        self._test("GET /exams/", "Exams", _list)

    # ─── Versions ──────────────────────────────────────────────
    def _test_versions(self):
        def _list():
            r = httpx.get(self._api_url("/versions/"), timeout=10)
            assert r.status_code == 200, f"List versions failed: {r.status_code}"
        self._test("GET /versions/", "Versions", _list)

        def _platform():
            r = httpx.get(self._api_url("/versions/linux"), timeout=10)
            assert r.status_code == 200, f"Platform version failed: {r.status_code}"
        self._test("GET /versions/{platform}", "Versions", _platform)

    # ─── Analytics ─────────────────────────────────────────────
    def _test_analytics(self):
        def _event():
            r = httpx.post(self._api_url("/analytics/event"), json={
                "event": "test_event", "properties": {"source": "test"},
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Event failed: {r.status_code} {r.text}"
        self._test("POST /analytics/event", "Analytics", _event)

        def _overview():
            r = httpx.get(self._api_url("/analytics/overview"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Overview failed: {r.status_code}"
        self._test("GET /analytics/overview", "Analytics", _overview)

    # ─── Audit ─────────────────────────────────────────────────
    def _test_audit(self):
        def _log():
            r = httpx.post(self._api_url("/audit/log"), json={
                "actor_type": "test", "action": "test_action",
                "actor_id": str(uuid.uuid4()), "resource_type": "test",
                "resource_id": str(uuid.uuid4()),
            }, headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"Log failed: {r.status_code} {r.text}"
        self._test("POST /audit/log", "Audit", _log)

        def _list():
            r = httpx.get(self._api_url("/audit/logs?limit=5"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"List audit failed: {r.status_code}"
        self._test("GET /audit/logs", "Audit", _list)

    # ─── Subscriptions ─────────────────────────────────────────
    def _test_subscriptions(self):
        def _plans():
            r = httpx.get(self._api_url("/subscriptions/plans"), timeout=10)
            assert r.status_code == 200, f"Plans failed: {r.status_code} {r.text}"
        self._test("GET /subscriptions/plans", "Subscriptions", _plans)

        def _my():
            r = httpx.get(self._api_url("/subscriptions/my"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 200, f"My sub failed: {r.status_code} {r.text}"
        self._test("GET /subscriptions/my", "Subscriptions", _my)

        def _check():
            r = httpx.post(self._api_url("/subscriptions/check"),
                          headers=self._headers(), timeout=10)
            assert r.status_code in (200, 403), f"Check failed: {r.status_code} {r.text}"
        self._test("POST /subscriptions/check", "Subscriptions", _check)

    # ─── Student Me ────────────────────────────────────────────
    def _test_student_me(self):
        def _login():
            r = httpx.post(self._api_url("/students/login"), json={
                "code": self._student_code, "pin": "XYZ789",
            }, timeout=10)
            assert r.status_code == 200, f"Student login failed: {r.status_code} {r.text}"
            data = r.json()
            assert "access_token" in data, f"No access_token: {data}"
            self._student_token = data["access_token"]
        self._test("POST /students/login", "Student Me", _login)

        def _student_headers():
            return {"Content-Type": "application/json",
                    "Authorization": f"Bearer {self._student_token}"}

        def _profile():
            r = httpx.get(self._api_url("/students/me"),
                          headers=_student_headers(), timeout=10)
            assert r.status_code == 200, f"Profile failed: {r.status_code} {r.text}"
        self._test("GET /students/me", "Student Me", _profile)

        def _grades():
            r = httpx.get(self._api_url("/students/me/grades"),
                          headers=_student_headers(), timeout=10)
            assert r.status_code == 200, f"My grades failed: {r.status_code}"
        self._test("GET /students/me/grades", "Student Me", _grades)

        def _attendance():
            r = httpx.get(self._api_url("/students/me/attendance"),
                          headers=_student_headers(), timeout=10)
            assert r.status_code == 200, f"My attendance failed: {r.status_code}"
        self._test("GET /students/me/attendance", "Student Me", _attendance)

        def _invoices():
            r = httpx.get(self._api_url("/students/me/invoices"),
                          headers=_student_headers(), timeout=10)
            assert r.status_code == 200, f"My invoices failed: {r.status_code}"
        self._test("GET /students/me/invoices", "Student Me", _invoices)

        def _verify_teacher():
            r = httpx.post(self._api_url("/students/verify-teacher"), json={
                "teacher_code": self._teacher_code,
            }, timeout=10)
            assert r.status_code == 200, f"Verify teacher failed: {r.status_code} {r.text}"
        self._test("POST /students/verify-teacher", "Student Me", _verify_teacher)

        def _bad_student_login():
            r = httpx.post(self._api_url("/students/login"), json={
                "code": "ST-NONEXIST", "pin": "123456",
            }, timeout=10)
            assert r.status_code == 401, f"Expected 401, got {r.status_code}"
        self._test("POST /students/login (bad code)", "Student Me - Error", _bad_student_login)

    # ─── Error Handling ────────────────────────────────────────
    def _test_error_handling(self):
        def _invalid_json():
            r = httpx.post(self._api_url("/students/"), data=b"not json",
                          headers={"Authorization": f"Bearer {self._token}",
                                   "Content-Type": "application/json"},
                          timeout=10)
            assert r.status_code in (400, 422), f"Expected 400/422, got {r.status_code}"
        self._test("POST with invalid JSON", "Error Handling", _invalid_json)

        def _not_found():
            r = httpx.get(self._api_url("/students/00000000-0000-0000-0000-000000000000"),
                          headers=self._headers(), timeout=10)
            assert r.status_code == 404, f"Expected 404, got {r.status_code}"
        self._test("GET nonexistent resource", "Error Handling", _not_found)

        def _empty_body():
            r = httpx.post(self._api_url("/auth/register"), json={},
                          timeout=10)
            assert r.status_code == 422, f"Expected 422, got {r.status_code}"
        self._test("POST with empty body", "Error Handling", _empty_body)

        def _sql_injection():
            r = httpx.get(self._api_url("/students/?search=' OR 1=1 --"),
                          headers=self._headers(), timeout=10)
            assert r.status_code in (200, 400), f"Unexpected: {r.status_code}"
            if r.status_code == 200:
                assert isinstance(r.json(), list), f"Expected list"
        self._test("SQL injection attempt", "Error Handling", _sql_injection)

    # ─── Cleanup ───────────────────────────────────────────────
    def cleanup(self):
        if self._student_id and self._token:
            try:
                httpx.delete(self._api_url(f"/students/{self._student_id}"),
                            headers=self._headers(), timeout=10)
            except Exception:
                pass

    # ─── Report ────────────────────────────────────────────────
    def generate_report(self, output_path: str = "test_report.html"):
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        failed = total - passed
        duration = time.time() - self._start_time

        categories = {}
        for r in self.results:
            categories.setdefault(r.category, []).append(r)

        cat_rows = ""
        for cat, tests in sorted(categories.items()):
            cat_passed = sum(1 for t in tests if t.passed)
            cat_total = len(tests)
            cat_rows += f"""
            <tr>
                <td>{cat}</td>
                <td>{cat_passed}/{cat_total}</td>
                <td>
                    <div class="bar"><div class="bar-fill" style="width:{cat_passed/cat_total*100:.0f}%"></div></div>
                </td>
            </tr>"""

        test_rows = ""
        for r in self.results:
            icon = "✅" if r.passed else "❌"
            cls = "pass" if r.passed else "fail"
            detail = f"<pre>{r.detail}</pre>" if r.detail and not r.passed else ""
            test_rows += f"""
            <tr class="{cls}">
                <td>{icon}</td>
                <td>{r.name}</td>
                <td>{r.category}</td>
                <td>{'Pass' if r.passed else 'Fail'}</td>
                <td>{r.duration_ms:.0f}ms</td>
            </tr>{detail}"""

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DarsakAI Test Report</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; color: #333; }}
.container {{ max-width: 1000px; margin: 0 auto; }}
.header {{ background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 30px; border-radius: 12px; margin-bottom: 20px; }}
.header h1 {{ margin: 0 0 10px 0; }}
.header p {{ margin: 5px 0; opacity: 0.9; }}
.summary {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 20px; }}
.card {{ background: white; border-radius: 10px; padding: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
.card .num {{ font-size: 36px; font-weight: bold; }}
.card .label {{ font-size: 14px; color: #666; margin-top: 5px; }}
.pass .num {{ color: #22c55e; }}
.fail .num {{ color: #ef4444; }}
.total .num {{ color: #667eea; }}
table {{ width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
th, td {{ padding: 12px 15px; text-align: left; border-bottom: 1px solid #eee; }}
th {{ background: #f8f9fa; font-weight: 600; color: #555; }}
tr.fail td {{ background: #fef2f2; }}
tr.pass td {{ background: #f0fdf4; }}
pre {{ background: #f8f9fa; padding: 10px; border-radius: 5px; font-size: 13px; overflow-x: auto; margin: 0; }}
.bar {{ height: 20px; background: #e5e7eb; border-radius: 10px; overflow: hidden; }}
.bar-fill {{ height: 100%; background: linear-gradient(90deg, #22c55e, #16a34a); border-radius: 10px; }}
.footer {{ text-align: center; margin-top: 20px; color: #999; font-size: 14px; }}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>DarsakAI Comprehensive Test Report</h1>
        <p>Target: {self.base_url}</p>
        <p>Ran: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        <p>Duration: {duration:.1f}s</p>
    </div>

    <div class="summary">
        <div class="card total"><div class="num">{total}</div><div class="label">Total Tests</div></div>
        <div class="card pass"><div class="num">{passed}</div><div class="label">Passed</div></div>
        <div class="card fail"><div class="num">{failed}</div><div class="label">Failed</div></div>
    </div>

    <h2>By Category</h2>
    <table>
        <thead><tr><th>Category</th><th>Passed</th><th>Progress</th></tr></thead>
        <tbody>{cat_rows}</tbody>
    </table>

    <h2>All Tests</h2>
    <table>
        <thead><tr><th></th><th>Test</th><th>Category</th><th>Result</th><th>Time</th></tr></thead>
        <tbody>{test_rows}</tbody>
    </table>

    <div class="footer">
        <p>DarsakAI Comprehensive Test Tool — Open Source</p>
        <p><a href="https://github.com/rootkali-cmd/Darsak-ai">github.com/rootkali-cmd/Darsak-ai</a></p>
    </div>
</div>
</body>
</html>"""

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(html)
        print(f"\n📊 Report generated: {output_path}")

        json_path = output_path.replace(".html", ".json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump({
                "target": self.base_url,
                "timestamp": datetime.datetime.now().isoformat(),
                "duration_s": round(duration, 2),
                "total": total, "passed": passed, "failed": failed,
                "results": [{"name": r.name, "category": r.category,
                            "passed": r.passed, "detail": r.detail,
                            "duration_ms": round(r.duration_ms, 1)}
                           for r in self.results],
            }, f, indent=2, ensure_ascii=False)
        print(f"📊 JSON report: {json_path}")

        return total, passed, failed

    def _print_summary(self):
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        print(f"\n{'='*60}")
        print(f"  Results: {passed}/{total} passed", end="")
        if passed < total:
            print(f" — {total - passed} FAILED ❌")
        else:
            print(" — ALL PASSED ✅")
        print(f"{'='*60}\n")

        for r in self.results:
            status = "✅" if r.passed else "❌"
            print(f"  {status} [{r.category}] {r.name} ({r.duration_ms:.0f}ms)")
            if not r.passed and r.detail:
                print(f"     └─ {r.detail[:200]}")

        print()


def main():
    parser = argparse.ArgumentParser(description="DarsakAI Comprehensive Test Tool")
    parser.add_argument("--url", default="http://localhost:8000",
                       help="Base URL (default: http://localhost:8000)")
    parser.add_argument("--report", default="test_report.html",
                       help="Output report path (default: test_report.html)")
    args = parser.parse_args()

    suite = TestSuite(base_url=args.url.rstrip("/"))
    try:
        suite.run_all()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    except Exception as e:
        print(f"\nFatal error: {e}")
        traceback.print_exc()
    finally:
        suite.cleanup()
        suite.generate_report(args.report)

    total = len(suite.results)
    passed = sum(1 for r in suite.results if r.passed)
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
