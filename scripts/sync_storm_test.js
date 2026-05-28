// DarsakAI Sync Storm Stress Test
// Simulates offline accumulation + reconnect storms + parallel pushes
// k6 run --vus 200 --duration 10m scripts/sync_storm_test.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { randomIntBetween, randomItem } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'https://darsak-ai.vercel.app/api';

const FAILURE_RATE = new Rate('sync_failures');
const QUEUE_DEPTH = new Trend('sync_queue_depth');
const ACK_LATENCY = new Trend('ack_latency_ms');
const SYNC_CONFLICT_RATE = new Rate('sync_conflicts');

const TEACHERS = [
  { email: 'teacher1@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher2@darsak.ai', password: 'Teacher@123456' },
  { email: 'teacher3@darsak.ai', password: 'Teacher@123456' },
];

const tokenCache = {};

export const options = {
  stages: [
    { duration: '30s', target: 50 },    // Ramp up sync load
    { duration: '2m', target: 200 },     // Heavy sync load
    { duration: '1m', target: 200 },     // Sustained
    { duration: '30s', target: 0 },      // Cool down
    { duration: '10s', target: 200 },    // Reconnect storm (simulate mass reconnection)
    { duration: '1m', target: 100 },     // Recovery
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    sync_failures: ['rate<0.10'],
    ack_latency_ms: ['p(95)<5000'],
  },
};

function login(teacherIdx) {
  const teacher = TEACHERS[teacherIdx % TEACHERS.length];
  const res = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    email: teacher.email,
    password: teacher.password,
  }), { headers: { 'Content-Type': 'application/json' }, tags: { name: 'login' } });

  if (res.status === 200) {
    tokenCache[teacherIdx] = { token: res.json('access_token'), expires: Date.now() + 50 * 60 * 1000 };
    return res.json('access_token');
  }
  return null;
}

function getToken(teacherIdx) {
  const cached = tokenCache[teacherIdx];
  if (cached && cached.expires > Date.now()) return cached.token;
  return login(teacherIdx);
}

function generateOperationId() {
  return 'perf-' + Date.now().toString(36) + '-' + Math.random().toString(36).substr(2, 9);
}

export default function () {
  const vuId = __VU;
  const teacherIdx = vuId % TEACHERS.length;
  const token = getToken(teacherIdx);
  if (!token) { FAILURE_RATE.add(1); sleep(5); return; }

  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-Operation-Id': generateOperationId(),
  };

  // Phase 1: Accumulate offline changes (push to server queue)
  group('Offline Accumulation', () => {
    const batchSize = randomIntBetween(1, 10);
    for (let i = 0; i < batchSize; i++) {
      const pushRes = http.post(`${BASE_URL}/sync/push`, JSON.stringify({
        payload_type: randomItem(['grade', 'attendance', 'student', 'invoice']),
        ciphertext: `SYNC_STORM_${vuId}_${Date.now()}_${i}`,
        iv: `iv_${Date.now()}`,
        auth_tag: `tag_${vuId}`,
      }), { headers, tags: { name: 'sync_push' } });
      FAILURE_RATE.add(pushRes.status !== 201 ? 1 : 0);
    }
  });

  // Phase 2: Pull pending items (simulate syncFromServer)
  group('Sync Pull', () => {
    const pullRes = http.get(`${BASE_URL}/sync/pull?limit=50`, { headers, tags: { name: 'sync_pull' } });
    FAILURE_RATE.add(pullRes.status !== 200 ? 1 : 0);
    if (pullRes.status === 200) {
      const body = pullRes.json();
      if (body && body.items) {
        QUEUE_DEPTH.add(body.items.length);
      }
    }
  });

  // Phase 3: Ack received items
  group('Sync Ack', () => {
    // Simulate acking items from a previous pull
    const ackIds = Array.from({ length: randomIntBetween(1, 5) }, () => generateOperationId());
    const ackRes = http.post(`${BASE_URL}/sync/ack`, JSON.stringify({
      acked_ids: ackIds,
    }), { headers, tags: { name: 'sync_ack' } });
    ACK_LATENCY.add(ackRes.timings.duration);
    FAILURE_RATE.add(ackRes.status !== 200 ? 1 : 0);
  });

  // Phase 4: Simulate conflict scenario (concurrent edits to same resource)
  if (Math.random() < 0.15) {
    group('Concurrent Edit', () => {
      // Two VUs editing the same student at nearly the same time
      const studentCode = STU_CODES[vuId % STU_CODES.length];
      const editRes = http.patch(`${BASE_URL}/students/${studentCode}`, JSON.stringify({
        full_name: `Concurrent Edit VU${vuId} at ${Date.now()}`,
      }), { headers, tags: { name: 'concurrent_edit' } });

      if (editRes.status === 409) {
        SYNC_CONFLICT_RATE.add(1);
      }
    });
  }

  sleep(randomIntBetween(0.2, 1.5));
}

const STU_CODES = Array.from({ length: 100 }, (_, i) => `STU${String(i + 1).padStart(3, '0')}`);
