# DarsakAI - Product Specification

## Overview
DarsakAI is an education management platform for tutoring centers (سنترات) in Egypt. It consists of:
- **Teacher App** (Android) - Manage students, grades, attendance, exams, subscriptions
- **Student App** (Android) - View grades, attendance, exams, profile
- **Backend API** (FastAPI on Fly.io) - REST API with Supabase database
- **Web Portal** (Next.js on Vercel) - Landing page, download page, admin dashboard

## Core Features

### Authentication
- Teacher registration with email/password
- Teacher login returns JWT token
- Student login with student code + PIN + teacher code
- Rate limiting: 4 failed attempts → 5min ban → 10min ban → permanent ban

### Student Management
- Add/edit/delete students
- Each student has: full_name, code (unique), pin_hash, parent_phone, group_id, teacher_id
- Student code is auto-generated (ST + 7 chars) or teacher-provided
- PIN is 6-8 alphanumeric characters, hashed with bcrypt

### Grades
- Add/edit/delete grades per student
- Fields: student_id, teacher_id, exam_name, subject, score, max_score, wrong_questions, notes

### Attendance
- Mark attendance per student per date
- Fields: student_id, teacher_id, date, status (present/absent/late)

### Exams
- Create exams with questions
- Students can take exams and submit answers

### Subscriptions
- Teachers subscribe to plans (Basic 199 EGP, Pro 499 EGP, Unlimited 999 EGP)
- Subscription codes for activation
- Student limits per plan

### Dashboard Stats
- Total students, groups, today attendance, total revenue

## API Endpoints
- POST /api/auth/register - Teacher registration
- POST /api/auth/login - Teacher login
- POST /api/students/login - Student login
- GET /api/students/ - List teacher's students
- POST /api/students/ - Create student
- PUT /api/students/{id} - Update student
- DELETE /api/students/{id} - Delete student
- POST /api/grades/ - Create grade
- GET /api/grades/ - List grades
- POST /api/attendance/ - Mark attendance
- GET /api/dashboard/stats - Dashboard statistics
- GET /api/versions/android - App version check

## Tech Stack
- Backend: Python FastAPI
- Database: Supabase (PostgreSQL)
- Auth: JWT tokens, bcrypt password hashing
- Hosting: Fly.io (backend), Vercel (web), GitHub Releases (APKs)
