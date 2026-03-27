# 🚀 SplitEase — Phase-by-Phase Development Prompts

*Use these prompts sequentially in your AI editor (Cursor/Claude) to build out the application. Ensure the AI has read the Master Prompts and context files before starting Phase 1.*

---

## 🛠️ Phase 1: Project Skeleton & Database Architecture
**Goal:** Scaffold the Flutter project, initialize the Fastify backend, and write the Prisma schema.

**Prompt to copy:**
```text
We are executing Phase 1 of the SplitEase master plan.

1. Initialize a Flutter project (if not done) and scaffold the `lib/` directory exactly matching `Flutter_Architecture_Plan.md` (Feature-First Clean Architecture).
2. Set up the foundational Material 3 Design System (`app_theme.dart`, `app_colors.dart`, `app_typography.dart`) using the ColorScheme.fromSeed and Google Fonts (Outfit/Inter) specifications.
3. Initialize a Node.js Fastify project for the backend. Configure Prisma to connect to a PostgreSQL database.
4. Using Section 8 of the `Complete_Execution_Plan (1).md`, write the complete `schema.prisma` file containing all tables, constraints, and relationships. 
5. Implement the composite database indexes exactly as specified in `DB_Index_Contract.md`.

Output the Flutter directory structure and the complete `schema.prisma`.
```
---

## 🔐 Phase 2: Authentication & JWT Infrastructure
**Goal:** Build the secure authentication layer on both the backend and frontend.

**Prompt to copy:**
```text
We are executing Phase 2: Authentication Infrastructure.

*Backend Requirements:*
1. Implement the JWT dual-token strategy as defined in `Auth_Contract.md`.
2. Build Fastify endpoints: `POST /api/v1/auth/signup`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, and `POST /api/v1/auth/logout`.
3. Ensure tokens are returned via `HttpOnly`, `SameSite=Strict` cookies (no local storage).
4. Implement the social login flow (Google/Apple) ensuring accounts with the same email merge seamlessly.

*Frontend (Flutter) Requirements:*
1. Build the `auth` feature layer in Flutter (`lib/features/auth/`).
2. Create the `Freezed` Auth State model.
3. Write the Riverpod Codegen `AuthNotifier` to handle login, signup, and state persistence.
4. Configure the Dio client with an Interceptor for silent JWT refreshes and `401` unauthorized handling as defined in `Error_Contract.md`.
5. Build the Login/Signup UI using the new Material 3 design system.
```
---

## 🧭 Phase 3: Dashboard & Navigation Setup
**Goal:** Set up routing, bottom navigation, and the main dashboard views.

**Prompt to copy:**
```text
We are executing Phase 3: Dashboard & Navigation.

1. Configure `go_router` in Flutter with a redirection guard: unauthenticated users are forced to `/login`, authenticated users go to `/dashboard`.
2. Create the `BottomNavBar` scaffolding with 4 tabs: Dashboard, Groups, Friends, Activity.
3. Build the Dashboard UI (`lib/features/dashboard/presentation/screens`). It must include the "Total Balance" Hero card (using the `Outfit` font and a subtle gradient) and quick action FABs.
4. Build the Backend Fastify endpoint: `GET /api/v1/user/balances` that returns the total owed/owes integers. Connect this to a Riverpod Provider to display active data on the Dashboard.
5. Implement the Skeleton Loader pattern using the `shimmer` package while dashboard data is loading.
```
---

## 🧾 Phase 4: Expense Management Core
**Goal:** Implement the ability to add and split expenses (the core product loop).

**Prompt to copy:**
```text
We are executing Phase 4: Core Expense Flow.

*Backend:*
1. Build `POST /api/v1/expenses` mapping to the schema. 
2. Implement server-side split calculation logic ensuring integer math (cents). Implement idempotency keys to prevent double-charging.

*Frontend:*
1. Build the Add Expense screen (`lib/features/expenses/presentation/screens/add_expense_screen.dart`).
2. Implement the UI for the 5 split modes (Equal, Exact, Percentage, Shares, Adjustment). 
3. The math for split previews must occur locally in Dart in real-time before submission. 
4. Implement the SQLite Offline Queue fallback: if the network drops (`connectivity_plus`), write the `create_expense` payload to local SQLite to automatically retry on reconnect, as defined in the plan.
```
---

## 👥 Phase 5: Groups & Ledgers
**Goal:** Create groups, add friends, and calculate the shortest payment paths.

**Prompt to copy:**
```text
We are executing Phase 5: Groups & Debt Simplification.

1. Build backend endpoints for creating groups, inviting members, and viewing a group ledger.
2. Implement the Debt Simplification algorithm (Graph Theory) on the backend to minimize total person-to-person transactions within a group.
3. Build the Flutter Group List and Group Detail screens. 
4. Add the ability to create "Ghost/Placeholder Users" for friends who haven't signed up yet. 
5. Ensure group lists use Flutter `ListView.builder` for virtual scrolling performance on ledgers scaling past 1,000 items.
```
---

## 🤝 Phase 6: Settlements & Optimistic UI
**Goal:** Allow users to record payments and instantly clear debts.

**Prompt to copy:**
```text
We are executing Phase 6: Settlements & Payments.

1. Build the Fastify `POST /api/v1/settlements` endpoint. Implement a pessimistic `SELECT FOR UPDATE` database lock to prevent simultaneous/duplicate settlement bugs.
2. Build the "Settle Up" modal flow in Flutter with visual confirmations.
3. Implement Optimistic UI testing with Riverpod: When a user taps "Settle", immediately shift their balance on the frontend layout *before* the API returns. 
4. If the Dio request throws an error (e.g., 500 Server Error), seamlessly roll back the Riverpod state to the prior balances and display the Error Boundary toast defined in `Error_Contract.md`.
```
---

## 📡 Phase 7: Real-Time & Event Sockets
**Goal:** Ensure multiple users seeing the same group UI receive instant updates.

**Prompt to copy:**
```text
We are executing Phase 7: Real-time Socket.io Sync.

1. Read `Realtime_Contract.md`. Implement the Fastify Socket.io server and authentication handshake using HttpOnly cookies.
2. Setup socket rooms exactly as defined (`user:{id}`, `group:{id}`).
3. Attach event broadcasters to the Expense and Settlement API routes so events correctly fire when data mutates.
4. In Flutter, initialize `socket_io_client`. Tie the incoming socket events to your Riverpod `ref.invalidate()` or `ref.update()` calls so the UI reactively updates without polling whenever another user creates an expense.
```
---

## 📝 Phase 8: Advanced Features (Multi-currency & Jobs)
**Goal:** Bring the system up to enterprise grade.

**Prompt to copy:**
```text
We are executing Phase 8: BullMQ Jobs & Multi-currency.

1. Read `Jobs_Contract.md`. Setup BullMQ and Redis on the Node backend. 
2. Create the CRON job worker to hit ExchangeRate-API every 6 hours and update the PostgreSQL rates table.
3. Create the job worker that handles parsing and injecting "Recurring Expenses" at midnight.
4. Introduce the Multi-Currency UI in Flutter. Ensure ISO 4217 minor unit rules (defined in `API_Contract.md`) are strictly enforced for fractional display rounding based on the selected group currency.
```
---

## 🔔 Phase 9: Push Notifications & Reminders
**Goal:** Engage the users when debts are due.

**Prompt to copy:**
```text
We are executing Phase 9: Firebase Push Notifications & Reminders.

1. Configure `firebase_messaging` in the Flutter app. Request permissions natively on iOS and Android. Send device tokens to Fastify upon login.
2. Create push notification trigger payloads on the backend when expenses are assigned to a user.
3. Build the "Send Reminder" button in the Flutter UI which dispatches an activity nudge. Add a BullMQ debounce job to avoid notification spamming.
4. Implement Flutter background handlers so tapping a notification deep links directly (`go_router`) to the specific Expense Details page.
```
---

## 🚀 Phase 10: Final Polish & Audit
**Goal:** Pre-flight checks before App Store deployment.

**Prompt to copy:**
```text
We are executing Phase 10: Final Audit & Polish.

1. Run an accessibility audit in Flutter. Ensure all buttons have 48x48dp minimum tap targets and semantic labels.
2. Audit all components for strictly using the Material 3 `ColorScheme.fromSeed` and ensure Dark Mode correctly swaps the theme palette instantly.
3. Ensure Global Error Boundaries (from `Error_Contract.md`) cover Image Network Failures, Unhandled Provider Exceptions, and Timeout errors.
4. Generate the Dockerfile and CI/CD workflow files to automate the building of the Node server and Flutter web output to the Hetzner target.
```
