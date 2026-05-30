// DarsakAI Production Load Test
// Usage: k6 run scripts/load_test.js
//        k6 run --vus 100 --duration 5m scripts/load_test.js
//        k6 run --vus 1000 --duration 10m scripts/load_test.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { randomIntBetween, randomItem } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'https://darsakai.com/api';

const FAILURE_RATE = new Rate('failed_requests');
const API_LATENCY = new Trend('api_latency_ms');
const DB_QUERY_TIME = new Trend('db_query_time_ms');
const TOTAL_REQUESTS = new Counter('total_requests');

// Simulated teacher credentials
const TEACHERS = [
  { email: 'teacher1@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher2@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher3@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher4@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher5@darsak.ai', password: 'Teacher@123456' },
];

// Student codes for attendance
const STUDENT_CODES = ['STU001', 'STU002', 'STU003', 'STU004', 'STU005', 'STU006', 'STU007', 'STU008', 'STU009', 'STU010'];

// Token cache per VU
const tokenCache = {};

export const options = {
  stages: [
    // Ramp-up: gradually increase to target VUs
    { duration: '1m', target: 10 },
    { duration: '2m', target: 50 },
    { duration: '3m', target: 100 },
    // Steady-state: hold at peak
    { duration: '5m', target: 100 },
    // Scale test (higher targets if not --vus specified)
    { duration: '3m', target: 500 },
    { duration: '2m', target: 1000 },
    // Recovery
    { duration: '2m', target: 100 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    failed_requests: ['rate<0.05'],     // <5% failure rate
    api_latency_ms: ['p(95)<3000'],     // 95th percentile < 3s
    http_req_duration: ['p(95)<5000'],  // Overall request duration
    http_req_failed: ['rate<0.05'],
  },
};

function getAuthToken(teacherIdx) {
  const key = `teacher_${teacherIdx}`;
  if (tokenCache[key] && tokenCache[key].expires > Date.now()) {
    return tokenCache[key].token;
  }
  return null;
}

function setAuthToken(teacherIdx, token) {
  tokenCache[`teacher_${teacherIdx}`] = {
    token,
    expires: Date.now() + 50 * 60 * 1000, // 50 min expiry
  };
}

function doLogin(teacherIdx) {
  const teacher = TEACHERS[teacherIdx % TEACHERS.length];
  const payload = JSON.stringify({
    email: teacher.email,
    password: teacher.password,
  });

  const res = http.post(`${BASE_URL}/auth/login`, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'login' },
  });

  check(res, {
    'login status 200': (r) => r.status === 200,
    'login has token': (r) => r.json('access_token') !== undefined,
  });

  if (res.status === 200) {
    const token = res.json('access_token');
    setAuthToken(teacherIdx, token);
    return token;
  }
  return null;
}

function makeHeaders(token) {
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-Client-Id': `k6-vu-${__VU}`,
  };
}

export default function () {
  const vuId = __VU;
  const teacherIdx = vuId % TEACHERS.length;

  group('Authentication', () => {
    let token = getAuthToken(teacherIdx);
    if (!token) {
      token = doLogin(teacherIdx);
    }
    if (!token) {
      FAILURE_RATE.add(1);
      sleep(5);
      return;
    }

    // Health check
    const healthRes = http.get(`${BASE_URL.replace('/api', '')}/health`, {
      headers: makeHeaders(token),
      tags: { name: 'health' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(healthRes.timings.duration);
    check(healthRes, { 'health ok': (r) => r.status === 200 });

    // Get current user
    const meRes = http.get(`${BASE_URL}/auth/me`, {
      headers: makeHeaders(token),
      tags: { name: 'me' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(meRes.timings.duration);
    check(meRes, { 'me ok': (r) => r.status === 200 });
  });

  sleep(randomIntBetween(0.5, 2));

  group('Students CRUD', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    // List students
    const listRes = http.get(`${BASE_URL}/students/`, {
      headers: makeHeaders(token),
      tags: { name: 'list_students' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(listRes.timings.duration);
    check(listRes, { 'list students ok': (r) => r.status === 200 });

    const students = listRes.json();
    if (Array.isArray(students) && students.length > 0) {
      const student = randomItem(students);

      // Get single student
      const getRes = http.get(`${BASE_URL}/students/${student.id}`, {
        headers: makeHeaders(token),
        tags: { name: 'get_student' },
      });
      TOTAL_REQUESTS.add(1);
      API_LATENCY.add(getRes.timings.duration);

      // Analyze student (AI burst)
      if (Math.random() < 0.1) { // 10% of requests trigger AI
        const analyzeRes = http.post(`${BASE_URL}/students/analyze`, JSON.stringify({
          student_id: student.id,
          subject: 'math',
          grades: [
            { exam: 'quiz1', score: 85, max_score: 100, wrong_questions: [3, 7] },
            { exam: 'quiz2', score: 72, max_score: 100, wrong_questions: [1, 5] },
          ],
        }), {
          headers: makeHeaders(token),
          tags: { name: 'analyze_ai' },
        });
        TOTAL_REQUESTS.add(1);
        API_LATENCY.add(analyzeRes.timings.duration);
      }
    }
  });

  sleep(randomIntBetween(0.5, 1.5));

  group('Attendance', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    // Mark attendance
    const studentCode = randomItem(STUDENT_CODES);
    const attRes = http.post(`${BASE_URL}/attendance/`, JSON.stringify({
      student_id: studentCode,
      status: randomItem(['present', 'absent']),
      date: new Date().toISOString().split('T')[0],
    }), {
      headers: makeHeaders(token),
      tags: { name: 'mark_attendance' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(attRes.timings.duration);

    // Bulk attendance (spike simulation)
    if (Math.random() < 0.05) { // 5% bulk
      const bulkRecords = Array.from({ length: randomIntBetween(5, 20) }, (_, i) => ({
        student_id: STUDENT_CODES[i % STUDENT_CODES.length],
        status: randomItem(['present', 'absent', 'cancelled']),
        date: new Date().toISOString().split('T')[0],
      }));
      const bulkRes = http.post(`${BASE_URL}/attendance/bulk`, JSON.stringify({
        records: bulkRecords,
      }), {
        headers: makeHeaders(token),
        tags: { name: 'attendance_bulk' },
      });
      TOTAL_REQUESTS.add(1);
      API_LATENCY.add(bulkRes.timings.duration);
    }
  });

  sleep(randomIntBetween(0.5, 2));

  group('Grades & Exams', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    const gradeRes = http.get(`${BASE_URL}/grades/stats?subject=math`, {
      headers: makeHeaders(token),
      tags: { name: 'grade_stats' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(gradeRes.timings.duration);
  });

  sleep(randomIntBetween(0.3, 1));

  group('Groups', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    const groupsRes = http.get(`${BASE_URL}/groups/`, {
      headers: makeHeaders(token),
      tags: { name: 'list_groups' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(groupsRes.timings.duration);
  });

  sleep(randomIntBetween(0.3, 1));

  group('Invoices', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    const invRes = http.get(`${BASE_URL}/invoices/`, {
      headers: makeHeaders(token),
      tags: { name: 'list_invoices' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(invRes.timings.duration);
  });

  sleep(randomIntBetween(0.5, 2));

  group('Sync Operations', () => {
    const token = getAuthToken(teacherIdx);
    if (!token) return;

    // Push sync
    const pushRes = http.post(`${BASE_URL}/sync/push`, JSON.stringify({
      payload_type: 'grade',
      ciphertext: 'AES_TEST_CIPHER_' + __VU + '_' + Date.now(),
      iv: 'TEST_IV_16_CHARS__',
      auth_tag: 'TEST_AUTH_TAG_16',
    }), {
      headers: makeHeaders(token),
      tags: { name: 'sync_push' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(pushRes.timings.duration);

    // Pull sync
    const pullRes = http.get(`${BASE_URL}/sync/pull?limit=20`, {
      headers: makeHeaders(token),
      tags: { name: 'sync_pull' },
    });
    TOTAL_REQUESTS.add(1);
    API_LATENCY.add(pullRes.timings.duration);
  });

  // Token refresh simulation (20% chance per iteration)
  if (Math.random() < 0.2) {
    group('Token Refresh', () => {
      const token = getAuthToken(teacherIdx);
      if (!token) return;

      const refreshRes = http.post(`${BASE_URL}/auth/refresh`, {}, {
        headers: makeHeaders(token),
        tags: { name: 'token_refresh' },
      });
      TOTAL_REQUESTS.add(1);
      API_LATENCY.add(refreshRes.timings.duration);

      if (refreshRes.status === 200) {
        const newToken = refreshRes.json('access_token');
        if (newToken) setAuthToken(teacherIdx, newToken);
      }
    });
  }

  // Track failures
  FAILURE_RATE.add(0);
  sleep(randomIntBetween(1, 3));
}
