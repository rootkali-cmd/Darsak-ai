# DarsakAI Desktop - Project Summary

## Overview
Flutter desktop app (Linux/Windows) for teacher dashboard - student management, attendance, grades, exams, invoices, QR tracking.

## Tech Stack
- **Flutter 3.44.0** / Dart 3.12.0
- **State Management**: Provider
- **HTTP**: Dio
- **Storage**: SharedPreferences (local), API (remote)
- **Offline**: Cached subscription data, sync manager

## Architecture
```
lib/
├── core/          # Theme, constants, services (subscription, update)
├── providers/     # Auth, Data, Sync providers
├── screens/       # Dashboard, Students, Groups, Attendance, Grades, etc.
└── widgets/       # Sidebar, StatCard, QuickAction, SubscriptionOverlay, etc.
```

## Known Fixes

### Gray Overlay Issue (Fixed 2026-05-29)
**Root Cause**: `_checkSubscription()` in `dashboard_screen.dart` called `isSubscriptionActive(null)` which returned `false` when the backend API was unreachable (e.g., running locally without a server). This triggered the `SubscriptionOverlay` (Positioned.fill with 40% black + blur) that covered the entire app.

**Fix**: Changed subscription check to only mark as expired when we have confirmed data:
1. If API succeeds → use live data
2. If API fails, try cached data → use cached data
3. If both fail (no backend, no cache) → do nothing (overlay stays hidden)
4. `_subscriptionExpired` defaults to `false`

## Build Output
- Linux: `build/linux/x64/release/bundle/darsak_desktop`
- Windows: Build on Windows host via Visual Studio

## Next Actions
- Test the Linux build after fix
- Verify subscription overlay appears correctly when subscription is actually expired
- Set up local test server for API integration testing
