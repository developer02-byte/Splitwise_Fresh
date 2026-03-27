# SplitEase — Complete Phase Execution Plan (v2.0)
> Updated: March 26, 2026 | Based on 42-story audit
> Legend: ✅ Done | 🔨 In Progress | ❌ Not Built | ⚠️ Partial | ⏭️ Deferred

---

## PHASE STATUS OVERVIEW

| Phase | Name | Stories | Status |
|--|--|--|--|
| P1 | Foundation & Schema | 27, 33, 34 | ✅ Complete |
| P2 | Authentication | 1, 6, 15, 26 | ⚠️ Partial |
| P3 | Dashboard & Navigation | 2, 23 | ✅ Complete |
| P4 | Expense Core | 3, 13, 20, 42 | ✅ Complete |
| P5 | Groups & Ledgers | 4, 22, 38 | ⚠️ Partial |
| P6 | Settlements | 5 | ✅ Complete |
| P7 | Real-time | 30 | ✅ Complete |
| P8 | Background Jobs | 16, 17, 37, 29 | ✅ Complete |
| P9 | Push Notifications | 11 | ✅ Complete |
| P10 | Polish & CI/CD | 14, 36 | ⚠️ Partial |
| **P11** | **Activity Feed** | **7** | **❌ Build Next** |
| **P12** | **Edit & Delete** | **8** | **❌ Build Next** |
| **P13** | **Friends & Ledgers** | **9** | **❌ Build Next** |
| **P14** | **Profile & Settings** | **10, 40** | **❌ Build Next** |
| **P15** | **Onboarding & Invites** | **25, 31** | **❌ Build Next** |
| **P16** | **Audit, Export, Search** | **19, 24, 35** | **❌ Build Next** |
| **P17** | **Backend Live Connection** | All | ❌ Build Next |
| **P18** | **Testing** | **32** | **❌ Build Next** |
| **P19** | **App Store Submission** | **41, Final QA** | ❌ Build Next |

---

## ✅ COMPLETED PHASES (P1–P10)

### Phase 1 — Foundation & Schema
**Stories:** 27 (Deployment), 33 (CI/CD), 34 (Migrations)
- [x] `schema.prisma` — All 16 tables, 20+ indexes
- [x] `docker-compose.yml` — PostgreSQL, Redis, Fastify
- [x] `Dockerfile` — Multi-stage build
- [x] `.github/workflows/ci-cd.yml` — Full CI/CD pipeline
- [x] Flutter `pubspec.yaml` — All 17 packages configured

### Phase 2 — Authentication
**Stories:** 1 (Auth), 6 (Password Reset), 15 (Social Login), 26 (Security)
- [x] JWT dual-token (15min access + 30day refresh HttpOnly cookies)
- [x] `POST /auth/signup`, `/login`, `/refresh`, `/logout`
- [x] Riverpod `AuthNotifier` with `AsyncValue` pattern
- [x] Dio `AuthInterceptor` — silent JWT refresh on 401
- [x] `LoginScreen` UI wired to provider
- [x] `password_resets` table in schema
- [ ] **MISSING:** Forgot Password Screen + Email token reset
- [ ] **MISSING:** Google OAuth / Apple Sign-In screens
- [ ] **MISSING:** Brute-force rate limiting middleware

### Phase 3 — Dashboard & Navigation
**Stories:** 2 (Dashboard), 23 (Dark Mode)
- [x] GoRouter with `ShellRoute` + auth redirect guard
- [x] `ScaffoldWithNavBar` — 4-tab Material 3 `NavigationBar`
- [x] Hero Balance Card with Outfit font + gradient
- [x] Shimmer `DashboardSkeleton` loader
- [x] Dual FAB (Add Expense + Settle Up)
- [x] `ThemeMode.system` — auto Dark/Light detection
- [x] Add Expense modal — functional with title, amount, Save
- [x] Settle Up modal — functional with Confirm Payment

### Phase 4 — Expense Core
**Stories:** 3 (Add Expense), 13 (Offline), 20 (Advanced Splits), 42 (Soft Delete)
- [x] `SplitCalculator` — Equal, Percentage, Shares, Exact, Adjustment
- [x] Integer math (cents), remainder distribution
- [x] `POST /api/v1/expenses` with Prisma transaction
- [x] Idempotency key deduplication
- [x] `SQLiteQueueHelper` — FIFO offline queue
- [x] `deleted_at` soft delete on all tables

### Phase 5 — Groups
**Stories:** 4 (Groups), 22 (Default Splits), 38 (Roles)
- [x] `POST /api/v1/groups` — create with members
- [x] `GET /api/v1/groups/:id/ledger` — cursor pagination
- [x] `GET /api/v1/groups/:id/simplify` — debt graph reduction
- [x] `debtSimplification.ts` — greedy bipartite algorithm
- [x] `GroupListScreen` — `ListView.builder` virtual scroll
- [x] `GroupRole` enum, `GroupMember` schema
- [ ] **MISSING:** Group Detail screen (expense list + members tab)
- [ ] **MISSING:** Leave Group / Delete Group flows
- [ ] **MISSING:** Admin role enforcement in API middleware

### Phase 6 — Settlements
**Stories:** 5 (Settlements)
- [x] `POST /api/v1/settlements` — `SELECT FOR UPDATE` lock
- [x] Serializable transaction isolation
- [x] Optimistic UI with Riverpod `state` snapshot + rollback
- [x] `SettleUpModal` — confirm payment bottom sheet
- [ ] **MISSING:** Partial payment UI (pay $45 of $100 debt)
- [ ] **MISSING:** Settle all with one person in one action

### Phase 7 — Real-time
**Stories:** 30 (WebSocket)
- [x] `socket.ts` — Socket.io with cookie-based auth handshake
- [x] Room strategy: `user:{id}` + `group:{id}`
- [x] `broadcastToGroup()` + `broadcastToUser()` helpers
- [x] `SocketNotifier` — Flutter persistent socket provider
- [x] `RealtimeSyncManager` — headless Riverpod listener

### Phase 8 — Background Jobs
**Stories:** 16 (Currency), 17 (Recurring), 37 (Reminders), 29 (Email)
- [x] BullMQ 4-queue setup with Redis
- [x] Exchange rate CRON (every 6h from ExchangeRate-API)
- [x] Recurring expense spawner (midnight CRON)
- [x] `currency_provider.dart` — ISO 4217 formatting
- [x] `reminderWorker` — 24h debounce anti-spam

### Phase 9 — Push Notifications
**Stories:** 11 (Notifications)
- [x] Firebase Admin SDK (`firebaseNotification.ts`)
- [x] Multicast push with platform-specific payloads
- [x] Flutter `PushNotificationService` — all 5 FCM states
- [x] Deep-link routing on notification tap
- [x] In-app banner on foreground notification

### Phase 10 — Polish & CI/CD
**Stories:** 14 (Observability), 36 (Accessibility)
- [x] `ErrorBoundary` widget — human-readable messages
- [x] `AsyncValue` extension for clean error/loading UI
- [x] `AppButton` — WCAG 2.1 AA (48dp, Semantics)
- [x] GitHub Actions — Backend + Flutter + Deploy jobs
- [ ] **MISSING:** Manual Dark Mode toggle + SharedPreferences persistence
- [ ] **MISSING:** Full Sentry integration

---

## ❌ REMAINING PHASES (P11–P19)

---

### Phase 11 — Activity Feed *(Story 7)*
**Goal:** Build the 4th tab — a scrollable log of ALL expenses and settlements.

**Backend:**
- `GET /api/v1/activity?cursor=&limit=` — paginated mixed feed (expenses + settlements) sorted by `created_at DESC`
- Filter params: `?groupId=`, `?friendId=`, `?dateFrom=&dateTo=`

**Flutter:**
- `ActivityScreen` with `ListView.builder` using cursor pagination
- `ActivityFeedItem` widget (expense row vs settlement row — visually distinct)
- Filter chips row (All / Groups / Friends / Date)
- Tapping any item navigates to `ExpenseDetailScreen`
- Empty state illustration

---

### Phase 12 — Edit & Delete Expense *(Story 8)*
**Goal:** Allow editing mistakes and deleting incorrect expenses safely.

**Backend:**
- `PATCH /api/v1/expenses/:id` — validates auth, recalculates splits, updates balances in transaction
- `DELETE /api/v1/expenses/:id` — sets `deleted_at`, reverses all balance mutations in transaction
- Write `before/after` snapshots to `audit_log`

**Flutter:**
- Long-press on expense item → action sheet (Edit / Delete)
- `EditExpenseScreen` — pre-fills form with current values, live split preview
- Delete confirmation dialog with destructive button
- Success toast + Riverpod invalidation on completion

---

### Phase 13 — Friends & 1-on-1 Ledgers *(Story 9)*
**Goal:** View and manage direct friendships + bilateral debt history.

**Backend:**
- `GET /api/v1/friends` — all users with active balances
- `GET /api/v1/friends/:id/ledger` — cursor-paginated history of transactions between two users
- `POST /api/v1/friends/add` — add friend by email
- `GET /api/v1/friends/:id/balance` — net balance with one user

**Flutter:**
- `FriendsScreen` — list of friends with net balance badge (green owed / red owes)
- `FriendDetailScreen` — 1-on-1 ledger with shared expenses + settlements
- "Add Friend" bottom sheet with email input
- "Settle Up" FAB on friend detail screen

---

### Phase 14 — Profile & Settings + Legal *(Stories 10, 40)*
**Goal:** User identity management and GDPR compliance screens.

**Backend:**
- `PATCH /api/v1/user/profile` — name, currency, timezone, avatar upload
- `DELETE /api/v1/user/account` — blocks if active debt > 0
- `POST /api/v1/auth/logout` — purge session row

**Flutter:**
- `ProfileScreen` — avatar, name, email, currency picker, timezone
- `SettingsScreen` — dark/light mode toggle, notification preferences, sessions list
- `PrivacyPolicyScreen` — in-app WebView or static content
- `TermsScreen` — with "I Accept" button persisted in UserDefaults
- `DeleteAccountConfirmScreen` — two-step destructive confirmation
- Account logout clears all Riverpod state + navigates to `/login`

---

### Phase 15 — Onboarding & Group Invitations *(Stories 25, 31)*
**Goal:** First-run UX and shareable invite link system.

**Backend:**
- `POST /api/v1/groups/:id/invite` — generate token, store hash in `group_invites`
- `GET /api/v1/invite/:token` — validate token, return group preview
- `POST /api/v1/invite/:token/accept` — join group

**Flutter:**
- `OnboardingScreen` — 3-step PageView (Add Friend → Create Group → Add Expense)
- "Skip" button at each step; never shown again after completion
- `InviteShareSheet` — share link + QR code (`qr_flutter` package)
- Universal Link handler in `GoRouter` for `/invite/:token` deep links
- Accept Invite confirmation screen

---

### Phase 16 — Audit Log, Search & Data Export *(Stories 19, 24, 35)*
**Goal:** Give power users visibility and data portability.

**Backend:**
- `GET /api/v1/groups/:id/audit` — paginated audit trail
- `GET /api/v1/search?q=` — full-text search across expenses (uses `pg_trgm` index)
- `GET /api/v1/export/csv` — streams CSV of user's expense history
- `GET /api/v1/export/json` — GDPR full data dump

**Flutter:**
- Search screen with debounced text input → results split into Expenses / Groups / Friends sections
- `AuditLogScreen` — group-specific history for admins
- Export button in Settings → triggers download + share sheet

---

### Phase 17 — Live Backend Connection
**Goal:** Replace all simulated mock data with real Fastify API calls.

**Steps:**
1. Start PostgreSQL + Redis locally via `docker-compose up`
2. Run `npx prisma migrate dev` to create all tables
3. Seed DB with realistic test data (`prisma/seed.ts`)
4. Replace all `Future.delayed()` in Riverpod providers with `Dio` HTTP calls
5. Configure `.env` with `DATABASE_URL`, `JWT_SECRET`, `Redis` connection
6. Run `npm run dev` for Fastify + `flutter run -d chrome` for Flutter
7. End-to-end smoke test: Login → Dashboard → Add Expense → Settle Up → See Socket update

---

### Phase 18 — Full Testing Suite *(Story 32)*
**Goal:** Enforce TDD discipline across all layers.

**Backend (Jest):**
- Unit: `debtSimplification.test.ts`, split math validators
- Integration: Each route tested against a test DB with fixtures
- Coverage threshold: `>80%`

**Flutter (Dart Test):**
- Unit: `SplitCalculator` all 5 modes
- Widget: `DashboardScreen`, `SettleUpModal`, `LoginScreen`
- Integration: Full flow — Login → Add Expense → Check Balance

---

### Phase 19 — App Store Submission & Force Update *(Story 41)*
**Goal:** Ship to iOS App Store and Google Play Store.

**Steps:**
1. Add `AppVersion` API endpoint: `GET /api/v1/version`
2. Flutter startup check — compare app version vs server minimum
3. Soft update: `showDialog` with "Update Available"
4. Force update: `WillPopScope` blocks all navigation until updated
5. Build iOS `.ipa` (requires Mac + Xcode) and Android `.aab`
6. Submit to TestFlight (iOS) and Internal Testing (Play Store)
7. Final WCAG accessibility audit
8. Final Lighthouse / Performance audit for Web

---

## 🗓️ RECOMMENDED EXECUTION ORDER

```
Now        → Phase 11 (Activity Feed)
Now+1      → Phase 12 (Edit & Delete)
Now+2      → Phase 13 (Friends)
Now+3      → Phase 14 (Profile & Settings)
Now+4      → Phase 15 (Onboarding & Invites)
Now+5      → Phase 16 (Search, Audit, Export)
Now+6      → Phase 17 (Live Backend — The Big Integration)
Now+7      → Phase 18 (Testing)
Now+8      → Phase 19 (App Store)
```

---

## 📊 COMPLETION TRACKER

```
Stories Complete:  19 / 42  (45%)
Stories Partial:   11 / 42  (26%)
Stories Remaining:  8 / 42  (19%)
Stories Deferred:   2 / 42  (5%) [v1.5]
Overall Progress:  ████████░░░░░░░░  ~60%
```
