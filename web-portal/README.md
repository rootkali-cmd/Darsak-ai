# DarsakAI Web Portal

##  Quick Start

### 1. Install Dependencies
```bash
cd web-portal
npm install
```

### 2. Environment Setup
```bash
cp .env.local.example .env.local
# Edit .env.local with your API URL
```

### 3. Run Development Server
```bash
npm run dev
```

### 4. Access
- Website: http://localhost:3000
- Login: teacher@darsak.ai / Teacher@123456

## 🎨 Features

- **Framer Motion** - Smooth UI animations
- **Three.js / React Three Fiber** - 3D background effects
- **Anime.js** - SVG and scroll animations
- **Tailwind CSS** - Custom DarsakAI theme
- **React Query** - Data fetching & caching
- **Zod + React Hook Form** - Form validation

##  Structure

```
web-portal/
├── src/
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login/page.tsx
│   │   ├── (dashboard)/
│   │   │   ├── page.tsx              # Dashboard
│   │   │   ├── students/page.tsx     # Students list
│   │   │   ├── students/[id]/page.tsx # AI Report
│   │   │   ├── groups/page.tsx
│   │   │   ├── attendance/page.tsx
│   │   │   ├── grades/page.tsx
│   │   │   ├── invoices/page.tsx
│   │   │   ├── qr/page.tsx
│   │   │   ├── assistants/page.tsx
│   │   │   └── settings/page.tsx
│   │   ├── layout.tsx
│   │   ├── providers.tsx
│   │   └── globals.css
│   ├── components/
│   │   ├── ui/
│   │   │   ├── MotionCard.tsx
│   │   │   ├── AnimatedCounter.tsx
│   │   │   ├── StaggerList.tsx
│   │   │   └── PageTransition.tsx
│   │   ├── 3d/
│   │   │   ├── Hero3DBackground.tsx
│   │   │   └── FloatingOrb.tsx
│   │   └── layout/
│   │       ├── Sidebar.tsx
│   │       ├── Header.tsx
│   │       └── ProtectedRoute.tsx
│   └── lib/
│       ├── api.ts
│       ├── auth.ts
│       └── utils.ts
├── package.json
├── next.config.js
├── tailwind.config.ts
└── tsconfig.json
```

## 🎨 Theme Colors

| Name | Value |
|------|-------|
| Background | #0A0F1F |
| Card | #1E293B |
| Primary | #8B5CF6 |
| Text | #F1F5F9 |
| Text Muted | #94A3B8 |
| Border | #334155 |

## 🔐 Default Credentials

| Role | Email | Password |
|------|-------|----------|
| Teacher | teacher@darsak.ai | Teacher@123456 |
| Admin | admin@darsak.ai | Admin@123456 |
