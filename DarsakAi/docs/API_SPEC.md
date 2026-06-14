# DarsakAI API Specification

## Base URL
```
http://localhost:8000/api
```

## Authentication
All endpoints (except `/auth/register`, `/auth/login`, `/auth/refresh`, `/students/login`, `/health`) require:
```
Authorization: Bearer <access_token>
```

## Error Response Format
```json
{
  "detail": "Error message here"
}
```

## Endpoints

### Authentication

#### POST /auth/register
```json
// Request
{
  "email": "teacher@example.com",
  "full_name": "Ahmed Hassan",
  "password": "securepass123",
  "role": "teacher"
}
// Response 201
{
  "id": "uuid",
  "email": "teacher@example.com",
  "full_name": "Ahmed Hassan",
  "role": "teacher",
  "teacher_code": "TCH-ABC12345",
  "is_active": true,
  "created_at": "2026-05-20T10:00:00Z"
}
```

#### POST /auth/login
```json
// Request
{ "email": "teacher@example.com", "password": "securepass123" }
// Response 200
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

### Students

#### POST /students/
```json
// Request
{
  "full_name": "Mohamed Ali",
  "phone": "01012345678",
  "parent_phone": "01098765432",
  "grade_level": "3rd Prep",
  "pin": "1234"
}
// Response 201
{
  "id": "uuid",
  "code": "STU-ABC12345",
  "full_name": "Mohamed Ali",
  ...
}
```

#### POST /students/analyze
```json
// Request
{
  "student_id": "uuid",
  "subject": "math",
  "grades": [
    {"exam": "quiz1", "score": 65, "wrong_questions": [3, 7, 12]}
  ]
}
// Response 200
{
  "strengths": ["جيد في الجبر"],
  "weaknesses": ["ضعف في الهندسة"],
  "recommended_focus": ["مراجعة قوانين المساحة"],
  "next_exercise_suggestion": "حل 10 تمارين على..."
}
```

### Sync

#### POST /sync/push
```json
// Request
{
  "payload_type": "attendance",
  "ciphertext": "base64...",
  "iv": "base64...",
  "auth_tag": "base64..."
}
// Response 201
{
  "status": "buffered",
  "queue_id": "uuid",
  "timestamp": "2026-05-20T10:00:00Z"
}
```

#### GET /sync/pull?since=2026-05-19T00:00:00Z&limit=50
```json
// Response 200
{
  "items": [
    {
      "id": "uuid",
      "type": "attendance",
      "ciphertext": "base64...",
      "iv": "base64...",
      "auth_tag": "base64...",
      "timestamp": "2026-05-20T10:00:00Z"
    }
  ],
  "total": 1
}
```
