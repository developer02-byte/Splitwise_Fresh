# 🔍 SplitEase — Full QA Audit: All 42 User Stories (v2 — Corrected)

> **Audit Date:** 2026-03-28 | **Version:** v2 (corrections applied)
> **Codebase:** Splitwise_fresh — Flutter (Riverpod) + Fastify/Node.js + PostgreSQL/Prisma
>
> **⚠️ Corrections vs v1:** Six factual errors in the original report have been corrected (see §Errata at bottom).
> Claims about JWT, currency endpoint, e2e tests, seed scripts, and Socket.io client were false in v1.

---

## Legend
| Status | Meaning |
|---|---|
| ✅ Complete | Fully implemented per story spec |
| ⚠️ Partial | Core flow works but sub-flows/criteria missing |
| ❌ Missing | Does not exist in code |
| 🔴 Broken | Code exists but behavior is incorrect/non-functional |

---

## Story 01 — Onboarding & Authentication
**Status: ⚠️ Partial**

- **[Critical]** Token stored in `SharedPreferences` (unencrypted) — must be `flutter_secure_storage`.
- **[High]** "Forgot password?" button `onPressed: () {}` — dead no-op, no navigation.
- **[High]** Login/Signup combined in one screen via toggle; story requires separate Signup screen with animated push transition.
- **[High]** Login failure: SnackBar error only; password field not cleared; no inline field error.
- **[Medium]** Password validator only checks length < 6 — no complexity check, no strength meter.
- **[Medium]** Email validation only checks for `@` symbol — `john@` passes client-side.
- **[Medium]** No UI lockout or button disable after 5 failed login attempts.
- **[Low]** Signup returns `200 OK` — story requires `201 Created`.
- **[Low]** No `autofocus: true` on form fields for fast entry.
- **[Low]** 429 rate-limit response shows generic SnackBar, not "Too many attempts" copy.

**Severity: High**

---

## Story 02 — Dashboard & Balances
**Status: ⚠️ Partial**

- **[Critical]** `_showAddExpenseModal()` is a SnackBar stub — primary CTA non-functional.
- **[Critical]** `_showSettleUpModal()` is a SnackBar stub — secondary CTA non-functional.
- **[Critical]** Data contract mismatch: backend returns raw integers (cents); frontend divides by 100. $145 shows as $1.45.
- **[High]** Activity feed hardcoded to `.take(3)`; no ScrollController, no pagination.
- **[High]** "You Owe" / "You are Owed" two-card summary absent — only total balance shown.
- **[High]** Empty state is plain text only — rich illustrated empty state not implemented.
- **[High]** No offline cached data — offline shows error state instead of cached records.
- **[Medium]** Activity subtitle shows currency code (e.g., "USD") not formatted date.
- **[Medium]** Balance and activity API calls not fired in parallel as specified.

**Severity: Critical**

---

## Story 03 — Add Expense (Core Flow)
**Status: 🔴 Broken**

- **[Critical]** Participants hardcoded: `final List<int> _participants = [1, 2, 3]` — no UI to select participants.
- **[Critical]** No `paidBy` (payer) selector in the UI.
- **[Critical]** No group selector — `groupId` never sent to the API.
- **[Critical]** Split toggle (EQUAL | EXACT | %) absent — only equal split exists.
- **[Critical]** No custom amount fields for EXACT or % split modes.
- **[High]** No `idempotency_key` sent — double-tap protection broken.
- **[High]** No "Discard expense?" dialog on back navigation.
- **[High]** Amount field has no `TextInputFormatter` — user can type `123.456`.
- **[High]** Backend split-sum check uses floating-point comparison → false 400 errors.
- **[High]** No optimistic UI update after submission.
- **[High]** No offline queue integration — API failure silently drops the expense.
- **[Medium]** No `ExpenseDetailScreen` for "Created by" tracking.
- **[Medium]** No category selector (blocks Story 12 analytics).
- **[Low]** Button does not morph to circular progress indicator as spec'd.

**Severity: Critical**

---

## Story 04 — Groups & Ledger
**Status: 🔴 Broken**

- **[Critical]** "Create Group" button is a no-op everywhere.
- **[Critical]** Group list item `onTap: () {}` — tapping a group does nothing.
- **[Critical]** No `GroupDetailScreen` or `GroupLedgerScreen` exists.
- **[Critical]** No `GroupHeroSummary` widget.
- **[High]** Group creation ignores `membersConfig` — members never added at creation.
- **[High]** "Simplify Debts" toggle absent; backend endpoint exists but never called.
- **[High]** `PATCH /api/groups/{id}/settings`, Leave Group, Delete Group endpoints do not exist.
- **[High]** Group list API doesn't return per-user per-group balance.
- **[Medium]** `inviteToken` always falls back to `'no-token-available'`.
- **[Low]** Cover photo upload not implemented.

**Severity: Critical**

---

## Story 05 — Settlements & Payments
**Status: 🔴 Broken**

- **[Critical]** Settle Up modal is a SnackBar stub — settlement UI does not exist.
- **[Critical]** No `SettleUpModalContainer`, `PayeeListSelection`, or `AmountPillInput`.
- **[Critical]** `POST /api/settlements/settle-all` endpoint does not exist.
- **[High]** Settlement amount not pre-filled with exact debt.
- **[High]** Overpayment validation absent on both frontend and backend.
- **[High]** Optimistic UI (instant balance drop before response) not implemented.
- **[High]** Push notification on settlement is `// TODO:` in backend.
- **[Medium]** No confirmation step before recording payment.

**Severity: Critical**

---

## Story 06 — Forgot Password & Account Recovery
**Status: ❌ Missing**

- **[Critical]** "Forgot password?" button is `onPressed: () {}` — no navigation.
- **[Critical]** No `ForgotPasswordScreen` in frontend.
- **[Critical]** No `POST /api/auth/forgot-password` endpoint.
- **[Critical]** No `POST /api/auth/reset-password` endpoint.
- **[Critical]** No `PasswordReset` Prisma model or DB table.
- **[Critical]** No email service integration (Resend/SendGrid/Nodemailer).
- **[High]** No deep link handler for reset tokens in router.
- **[High]** No `PasswordStrengthMeter` widget.
- **[Medium]** No per-email rate limiting for reset requests.

**Severity: Critical**

---

## Story 07 — Global Activity Feed & Filters
**Status: ⚠️ Partial**

- **[Critical]** `/activity` route renders placeholder text — `ActivityScreen` widget never routed.
- **[High]** Filter button `onPressed: () {}` — filter modal not implemented.
- **[High]** No cursor-based pagination — no `ScrollController`, no next-cursor fetching.
- **[High]** Tapping an activity item `onTap: () {}` — no detail navigation.
- **[High]** Date range filters absent.
- **[Medium]** No `ExpenseDetailScreen` for drill-down.
- **[Medium]** Edit Expense from action sheet shows "coming soon" SnackBar.

**Severity: High**

---

## Story 08 — Edit & Delete Expense
**Status: ⚠️ Partial**

- **[Critical]** Edit Expense UI does not exist — action sheet shows "coming soon" SnackBar.
- **[Critical]** `PATCH /api/expenses/:id` backend exists but never called from frontend.
- **[High]** Delete works but `userId` authorization check is based on the JWT-extracted `request.userId` — verify route properly rejects non-owners.
- **[High]** `auditLog.create()` guard `typeof (tx as any).auditLog !== 'undefined'` is always false — audit trail never written.
- **[High]** List removal uses `ref.invalidate()` causing full reload flash instead of smooth optimistic removal.
- **[Medium]** No dirty-state tracking for "Save Changes" button enable/disable.

**Severity: High**

---

## Story 09 — Friends & Individual Ledgers
**Status: ⚠️ Partial**

- **[Critical]** No `FriendDetailScreen` — tapping a friend shows SnackBar stub.
- **[Critical]** `GET /api/user/friends/{friend_id}/ledger` endpoint does not exist.
- **[High]** `FriendHeroSummary` widget does not exist.
- **[High]** Per-friend Settle Up with pre-filled amount does not exist.
- **[High]** Balance calculation in `buildFriendsList()` may double-count due to querying both directions of balance table.
- **[Medium]** "Remove Friend" for ghost users not implemented.

**Severity: High**

---

## Story 10 — Profile & Settings
**Status: ⚠️ Partial**

- **[High]** "Default Currency" tile is a stub — no currency picker.
- **[High]** "Notifications" tile is a stub — no navigation.
- **[High]** "Dark Mode" Switch `onChanged: (val) {}` — complete no-op.
- **[High]** "Change Password" completely absent (no UI, no backend endpoint).
- **[High]** Delete account requires no typed confirmation — story requires "DELETE" input match.
- **[High]** Logout not awaited before `context.go('/login')` — race condition.
- **[High]** `ProfileScreen` not in `app_router.dart` — no `/profile` route.
- **[Medium]** Timezone picker absent; avatar upload absent; email not editable.
- **[Low]** No logout confirmation `AlertDialog`.

**Severity: High**

---

## Story 11 — Notifications System
**Status: ⚠️ Partial**

- **[Critical]** FCM token registration is `// TODO: dio.post(...)` — token never sent to backend.
- **[Critical]** No `POST /api/notifications/register-token` endpoint.
- **[Critical]** No `NotificationListScreen` or Bell icon with badge in any AppBar.
- **[High]** All expense/settlement handlers have `// TODO:` notification dispatch — notifications never fire.
- **[High]** No `PUT /api/user/notification-preferences` endpoint.
- **[High]** No `PUT /api/groups/{id}/mute` endpoint.
- **[High]** No `GET /api/notifications` or `PUT /api/notifications/{id}/read` endpoints.
- **[High]** No email digest scheduled job.
- **[Medium]** Mute indicator on group avatar not implemented.

**Severity: Critical**

---

## Story 12 — Analytics & Insights
**Status: ❌ Missing**
> Marked **[DEFERRED v1.5]** in story spec.

- No analytics screen or charts.
- No analytics backend endpoints.
- Expense category collection (Story 03 prerequisite) unmet.
- No materialized view or CRON refresh.

**Severity: High** (deferred)

---

## Story 13 — Offline Sync & Resilience
**Status: ⚠️ Partial**

- **[Critical]** `SQLiteQueueHelper` exists but never called from any feature screen — dead code.
- **[Critical]** No `connectivity_plus` listener at app level. No `OfflineBanner`.
- **[Critical]** No auto-sync trigger on connectivity restore.
- **[Critical]** `GET /api/sync/delta` endpoint not implemented.
- **[High]** No `SyncStatusIndicator` in any AppBar.
- **[High]** SQLite queue missing `retry_count`, `error_message`, backoff logic.
- **[High]** Socket.io server-side exists; real-time push from backend to Flutter client is wired in `socket_provider.dart` but all route handlers still have `// TODO: Dispatch Socket.io` — events never emitted.
- **[Medium]** "Pending sync" clock icon not shown on offline expense items.

**Severity: Critical**

---

## Story 14 — Observability & Monitoring
**Status: ❌ Missing**

- No Sentry/Datadog integration.
- No structured logging with correlation IDs.
- No APM or OpenTelemetry.

**Severity: Low**

---

## Story 15 — Social Login (Google & Apple)
**Status: ❌ Missing**

- **[Critical]** No "Continue with Google" or "Continue with Apple" buttons in login screen.
- **[Critical]** No `POST /api/auth/google` or `POST /api/auth/apple` endpoints.
- **[Critical]** No `UserProvider` Prisma model in any route.
- **[High]** Social auth packages not wired to any service class.
- **[High]** No "OR" divider in login screen.
- **[Medium]** No "Signed in with Google/Apple" section in settings.

**Severity: Critical**

---

## Story 16 — Multi-Currency Support
**Status: ⚠️ Partial**

- **[Critical]** No `CurrencyPicker` in `AddExpenseScreen`.
- **[Critical]** No live conversion preview.
- **[High]** `GET /api/currencies/rates` endpoint **exists** (index.ts:75-80) and returns hardcoded mock rates — no live CRON job or external API fetch yet.
- **[High]** No exchange rate CRON job pulling live rates.
- **[High]** No `exchange_rates` Prisma model/table.
- **[High]** Settlement currency picker absent.

**Severity: High**

---

## Story 17 — Recurring Expenses
**Status: ❌ Missing**

- No recurring toggle, Prisma model, scheduled job, or backend endpoints.

**Severity: Medium**

---

## Story 18 — Receipt Scanning / OCR
**Status: ❌ Missing**

- No camera integration, OCR service, or backend OCR endpoint.

**Severity: Medium**

---

## Story 19 — Data Export
**Status: ❌ Missing**

- No export UI, endpoints, or PDF/CSV library.

**Severity: Low**

---

## Story 20 — Advanced Split Types
**Status: ❌ Missing**

- **[Critical]** Only Equal split implemented — EXACT and % modes absent.
- **[High]** `SplitCalculator` likely lacks `calculateExact()` and `calculatePercentage()`.

**Severity: High**

---

## Story 21 — Expense Comments & Attachments
**Status: ❌ Missing**

- No comment input, `ExpenseDetailScreen`, `comments` model, or file upload.

**Severity: Medium**

---

## Story 22 — Default Split Settings
**Status: ❌ Missing**

- No split preference UI, storage, or backend endpoint.

**Severity: Low**

---

## Story 23 — Dark Mode / Light Mode
**Status: 🔴 Broken**

- **[Critical]** Dark Mode Switch `onChanged: (val) {}` — toggling does nothing.
- **[High]** No theme Riverpod state or provider.
- **[Medium]** No persistence of theme preference.

**Severity: High**

---

## Story 24 — Search Functionality
**Status: ❌ Missing**

- No search bar, search endpoint, or `SearchDelegate`.

**Severity: Medium**

---

## Story 25 — Onboarding Flow
**Status: ⚠️ Partial**

- Router redirect to `/onboarding` based on `onboardingCompleted` is correctly implemented.
- `OnboardingScreen` **does** call `PUT /api/user/me` with `onboardingCompleted: true` — users are not stuck in a loop.
- **[Medium]** `OnboardingScreen` multi-step design and content verification pending.

**Severity: Medium**

---

## Story 26 — Security Hardening
**Status: ⚠️ Partial**

- ✅ **JWT auth is real** — `verifyAccessToken()` (using `jwt.verify()`) runs in a global `onRequest` hook at `index.ts:38-61`. Every authenticated route receives a verified `userId`. The v1 report's critical blocker #1 was **factually incorrect**.
- **[High]** Token stored client-side in `SharedPreferences` (unencrypted) — should be `flutter_secure_storage`.
- **[High]** Cookie (backend) vs SharedPreferences (frontend) token flow inconsistent — refresh token flow via cookies not fully wired.
- **[Medium]** No CSRF protection; no input sanitization middleware.
- **[Low]** Redis JWT blacklist not implemented (logout does not invalidate server-side).

**Severity: High** *(downgraded from Critical — real JWT verification exists)*

---

## Story 27 — Deployment Plan
**Status: ⚠️ Partial**

- `docker-compose.yml` with correct containers exists.
- **[Medium]** No CI/CD workflow files. **[Low]** No env var startup validation.

**Severity: Low**

---

## Story 28 — File Storage & Image Infrastructure
**Status: ❌ Missing**

- No S3/Cloudinary SDK, upload endpoint, or multipart handling.

**Severity: Medium**

---

## Story 29 — Email System
**Status: ❌ Missing**

- No email service integrated. Blocks Forgot Password (S06) and Email Digest (S11).

**Severity: High**

---

## Story 30 — Realtime Architecture (Socket.io)
**Status: ⚠️ Partial**

- `socket.ts` server-side code exists.
- `socket_provider.dart` imports and uses `socket_io_client` — Flutter client **does** exist. The v1 report's claim of "No Socket.io client in Flutter" was **factually incorrect**.
- **[High]** All route handlers have `// TODO: Dispatch Socket.io` — events never emitted from business logic.

**Severity: High** *(downgraded from Critical — Flutter client scaffold exists)*

---

## Story 31 — Group Invitations & Deep Linking
**Status: ⚠️ Partial**

- Backend invite system well-implemented.
- **[Critical]** No deep link route `/invite/:token` in `app_router.dart`.
- **[High]** Group list doesn't return `inviteToken` — share sheet shows `'no-token-available'`.
- **[Medium]** No Accept Invite Flutter screen.

**Severity: High**

---

## Story 32 — Testing Strategy
**Status: ⚠️ Partial**

- `e2e/` directory contains **13 spec files** with substantial test coverage (not empty as v1 claimed).
- `frontend/test/` exists with Flutter unit tests.
- **[High]** No backend unit/integration tests outside e2e.
- **[Medium]** e2e tests require running infrastructure — no mock server mode.

**Severity: Medium** *(downgraded from Missing — significant e2e test suite exists)*

---

## Story 33 — CI/CD Pipeline
**Status: ❌ Missing**

- No `.github/workflows/` YAML files.

**Severity: Low**

---

## Story 34 — Database Migration & Seeding
**Status: ⚠️ Partial**

- Prisma configured with migrations.
- `backend/prisma/seed.ts` **exists** with test user seeding. The v1 report's claim of "No seed scripts" was **factually incorrect**.
- **[High]** Several routes may reference models not yet in schema.

**Severity: Medium** *(downgraded — seed script confirmed)*

---

## Story 35 — Audit Trail & Change Log
**Status: ⚠️ Partial**

- Expense soft delete with balance reversal implemented.
- **[High]** Audit trail `create()` guard is always false — **never writes**.
- **[High]** Edit audit doesn't capture before/after JSONB snapshots.
- **[Medium]** No `GET /api/expenses/{id}/audit` endpoint.

**Severity: High**

---

## Story 36 — Accessibility
**Status: ❌ Missing**

- No `Semantics` widgets, high-contrast mode, or screen reader testing.

**Severity: Medium**

---

## Story 37 — Reminders & Nudges
**Status: ❌ Missing**

- No reminder job, preference UI, or email dependency (S29 also missing).

**Severity: Medium**

---

## Story 38 — Group Permissions & Roles
**Status: ⚠️ Partial**

- `role` field exists in schema.
- **[High]** No role-based enforcement in any route handler.
- **[Medium]** No role management UI.

**Severity: High**

---

## Story 39 — Notification Preferences & Controls
**Status: ❌ Missing**

- "Notifications" tile is a stub. No screen, no backend endpoint.

**Severity: Medium**

---

## Story 40 — Legal / Privacy Consent
**Status: ⚠️ Partial**

- `legal_screens.dart` exists; profile tiles reference legal routes.
- **[High]** `/legal/privacy` and `/legal/terms` not in `app_router.dart` — GoRouter exception on tap.
- **[Medium]** No signup consent checkbox.

**Severity: Medium**

---

## Story 41 — App Versioning & Force Update
**Status: ❌ Missing**

- No version check endpoint, startup check, or force-update dialog.

**Severity: Low**

---

## Story 42 — Soft Delete & Data Retention
**Status: ⚠️ Partial**

- Expense soft delete correctly implemented.
- **[High]** User "delete" is anonymization only — no `deleted_at`, no 30-day grace/recovery.
- **[High]** No scheduled purge job.
- **[Medium]** Settlement `deletedAt` referenced but never set.

**Severity: Medium**

---

---

# 🚨 CRITICAL BLOCKERS — Revised Top 15

| # | Blocker | Story(ies) | Impact |
|---|---|---|---|
| 1 | **"Add Expense" = SnackBar stub** | S02, S03 | Zero core value |
| 2 | **"Settle Up" = SnackBar stub** | S02, S05 | Zero settlement value |
| 3 | **Group creation no-op, GroupDetailScreen missing** | S04 | Groups feature dead |
| 4 | **Hardcoded participant IDs [1,2,3]** | S03 | Expense core flow broken |
| 5 | **FCM token never registered with backend** | S11 | Push notifications broken |
| 6 | **Forgot Password fully missing** | S06 | Account recovery impossible |
| 7 | **Social Login fully missing** | S15 | Alternative auth unavailable |
| 8 | **JWT stored in SharedPreferences (unencrypted)** | S01, S26 | Security vulnerability |
| 9 | **`/activity` route renders placeholder** — ActivityScreen never shown | S07 | Screen unreachable |
| 10 | **Offline sync queue never triggered** — SQLite helpers are dead code | S13 | Offline mode non-functional |
| 11 | **Socket.io events never emitted** — all handlers have `// TODO` | S30 | Real-time sync dead |
| 12 | **Balance data contract mismatch** — raw ints treated as cents | S02 | All balances display wrong |
| 13 | **No ExpenseDetailScreen** — expense tap goes nowhere | S07, S08, S09 | Drill-down impossible |
| 14 | **Legal routes not in router** — `context.push('/legal/privacy')` throws | S40 | Navigation crash |
| 15 | **`auditLog.create()` guard always false** — audit trail never written | S35 | Silent data loss |

> ℹ️ The v1 report listed "JWT middleware simulated" as blocker #1. This was **incorrect** — JWT verification is real. The list above reflects actual blockers.

---

## Final Summary

| Status | Count | Stories |
|---|---|---|
| ✅ Complete | **0** | — |
| ⚠️ Partial | **16** | 01, 02, 07, 08, 09, 10, 11, 13, 16, 25, 27, 30, 31, 32, 34, 35, 38, 40, 42 |
| ❌ Missing | **14** | 06, 12, 14, 15, 17, 18, 19, 21, 22, 24, 28, 29, 33, 36, 37, 39, 41 |
| 🔴 Broken | **5** | 03, 04, 05, 23, 26* |
| 📝 Infrastructure/Deferred | **7** | 20, 26, 32, 35, 38, 40, 42 |

> **Zero stories pass full QA acceptance criteria.** The application has solid foundational infrastructure (real JWT auth, real e2e test suite, seed scripts, Socket.io scaffolding, currency endpoint) but core UX flows (add expense, settle up, groups, notifications) are stubbed or broken.

---

## 📋 Errata: Corrections to v1 Report

| # | v1 Claim | Correction | Evidence |
|---|---|---|---|
| 1 | "JWT middleware simulated — no real verification" (Critical Blocker #1) | **FALSE** — `verifyAccessToken()` using `jwt.verify()` runs in a real `onRequest` hook | `index.ts:38-61` |
| 2 | "`signAccessToken`/`verifyAccessToken` never used as middleware" | **FALSE** — imported at `index.ts:7` and called at `index.ts:52` on every request | `index.ts:7,52` |
| 3 | "No `GET /api/currencies/rates` endpoint" (S16 Critical) | **FALSE** — endpoint exists and returns mock exchange rates | `index.ts:75-80` |
| 4 | "`e2e/` empty" (S32) | **FALSE** — 13 spec files present in `e2e/tests/` | `e2e/tests/*.spec.ts` |
| 5 | "No seed scripts" (S34) | **FALSE** — `backend/prisma/seed.ts` exists | `backend/prisma/seed.ts` |
| 6 | "No Socket.io client in Flutter" (S30 Critical) | **FALSE** — `socket_provider.dart` imports and uses `socket_io_client` | `socket_provider.dart:2` |
