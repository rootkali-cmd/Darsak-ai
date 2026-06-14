# DarsakAI Database Schema

## Tables

### users
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| email | VARCHAR(255) | UNIQUE, NOT NULL, INDEX |
| full_name | VARCHAR(255) | NOT NULL |
| hashed_password | VARCHAR(255) | NOT NULL |
| role | ENUM(admin, teacher, assistant) | NOT NULL, default teacher |
| is_active | BOOLEAN | default true |
| teacher_code | VARCHAR(50) | UNIQUE, NULLABLE, INDEX |
| encryption_salt | VARCHAR(64) | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |
| updated_at | TIMESTAMPTZ | default now() |

### students
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| code | VARCHAR(50) | UNIQUE, NOT NULL, INDEX |
| full_name | VARCHAR(255) | NOT NULL |
| phone | VARCHAR(20) | NULLABLE |
| parent_phone | VARCHAR(20) | NULLABLE |
| grade_level | VARCHAR(50) | NULLABLE |
| pin_hash | VARCHAR(255) | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |
| updated_at | TIMESTAMPTZ | default now() |

### groups
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| name | VARCHAR(255) | NOT NULL |
| subject | VARCHAR(100) | NOT NULL |
| level | ENUM(preparatory, secondary) | NOT NULL |
| day_of_week | VARCHAR(20) | NOT NULL |
| time_slot | VARCHAR(50) | NOT NULL |
| created_at | TIMESTAMPTZ | default now() |
| updated_at | TIMESTAMPTZ | default now() |

### attendances
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| student_id | UUID | FK → students.id, NOT NULL, INDEX |
| group_id | UUID | FK → groups.id, NULLABLE, INDEX |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| status | ENUM(present, absent, cancelled) | NOT NULL |
| date | DATE | NOT NULL, INDEX |
| notes | VARCHAR(500) | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |

### grades
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| student_id | UUID | FK → students.id, NOT NULL, INDEX |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| exam_name | VARCHAR(255) | NOT NULL |
| subject | VARCHAR(100) | NOT NULL |
| score | FLOAT | NOT NULL |
| max_score | FLOAT | NOT NULL, default 100 |
| wrong_questions | JSONB | NULLABLE |
| notes | TEXT | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |

### invoices
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| student_id | UUID | FK → students.id, NOT NULL, INDEX |
| amount | FLOAT | NOT NULL |
| description | VARCHAR(500) | NULLABLE |
| paid | BOOLEAN | default false |
| payment_date | DATE | NULLABLE |
| signature | VARCHAR(255) | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |

### encrypted_payloads
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| teacher_id | UUID | FK → users.id, NOT NULL, INDEX |
| payload_type | ENUM(grade, attendance, invoice, ai_report, student, group) | NOT NULL |
| ciphertext | TEXT | NOT NULL |
| iv | TEXT | NOT NULL |
| auth_tag | TEXT | NOT NULL |
| sync_status | ENUM(pending, synced, failed) | default pending, INDEX |
| synced_at | TIMESTAMPTZ | NULLABLE |
| created_at | TIMESTAMPTZ | default now() |

### audit_logs
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| actor_type | ENUM(student, teacher, assistant, system) | NOT NULL |
| actor_id | UUID | NULLABLE |
| action | VARCHAR(100) | NOT NULL |
| resource_type | VARCHAR(50) | NULLABLE |
| resource_id | UUID | NULLABLE |
| ip_address | VARCHAR(45) | NULLABLE |
| user_agent | VARCHAR(500) | NULLABLE |
| timestamp | TIMESTAMPTZ | default now(), INDEX |
| metadata | JSONB | NULLABLE |
