# Story 02: Dashboard & Balances - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide instantaneous, undeniable visibility into the user's financial standing across all groups and friends. The user should know exactly what they owe and what is owed to them within 0.5 seconds of opening the app. This screen dictates the entire rhythm of the application; its performance must be flawless and its hierarchy immediately sensible.

---

## 👥 2. Target Persona & Motivation
- **The Active User:** Needs to check balances after recent expenses and quickly tap "Add Expense" to start the core loop.
- **The Debtor/Creditor:** Needs a synthesized view, bypassing individual groups to instantly see their net position.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Dashboard Load Sequence
1. **Entry Point:** User successfully authenticates or re-opens the app. The system navigates to the Dashboard screen.
2. **System State - Optimistic Render:** The UI immediately renders `DashboardSkeletonLoader` using Flutter's `Shimmer` package. This consists of:
   - 1 large pulsing rectangle for Total Balance (Hero Section).
   - 2 side-by-side pulsing squares for "You Owe" / "You are Owed".
   - 3 consecutive horizontal pulsing bars for Recent Activity.
3. **Action - Background Fetch:** The client fires parallel requests via Dio:
   - `GET /api/user/balances`
   - `GET /api/user/activities?limit=15`
4. **System State - Data Arrival:** When data resolves (target < 200ms), the skeletons dissolve smoothly into actual data values (No layout shifts!).
5. **System State - Final Render:**
   - A gigantic "Total Balance: +$145.00" appears in bold Inter font, color-coded Success Green.
   - A scrollable Activity feed populates immediately below using `ListView.builder`.
   - The massive primary CTA "Add Expense" `FloatingActionButton` anchors the bottom right.

### B. The Empty State Sequence
1. **Context:** A brand new user with no friends or expenses logs in.
2. **System State:** The exact same API calls run but return `data: []` and an empty balances object.
3. **Action - Empty Render:** The dashboard suppresses the generic "You Owe: $0.00" math. Instead, it displays a highly visual `EmptyStateWidget`:
   - Vectors/Illus: A quiet, friendly illustration (e.g., empty ledger or group of friends) via SVG asset.
   - Text: "You're all settled up! No expenses or balances yet."
   - Secondary CTA Button: "Create a Group" right in the empty state center, pointing them immediately to an action.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`HeroBalanceCard`**:
  - Background: Solid white/dark surface via `Container` with `BoxDecoration`. No borders. Elevation shadow via `Material` widget for depth.
  - Total Typography: `TextStyle(fontSize: 32, fontWeight: FontWeight.w700)`, responsive via `MediaQuery`.
  - Color Logic: If > 0 -> `Color(0xFF00C853)` (Green). If < 0 -> `Color(0xFFD50000)` (Red). If === 0 -> `Color(0xFF757575)` (Grey).
- **`SummaryCards`**: Two identical cards side-by-side via `Row` with `Expanded` children.
  - Font size: `18`, medium weight. Spacing via `SizedBox(width: 8)` between cards.
- **`ActivityListItem`**:
  - Height: `72`.
  - Left Avatar: `CircleAvatar` `40x40` with initials of expense creator.
  - Middle Stack: "Dinner at Luigi's" (`TextStyle(fontSize: 16, fontWeight: FontWeight.bold)`), "You paid $45.00" (`TextStyle(fontSize: 14, color: Colors.grey)`).
  - Right Align: Date string formatted loosely: "Yesterday" or "Oct 12" via `timeago` package.
- **`PrimaryFAB`**:
  - Size: `56x56` circle `FloatingActionButton`. Positioned bottom right by `Scaffold`.
  - Icon: A thick `Icons.add` in `Colors.white`. Background: Primary Brand. Elevation shadow.
- **`NavigationBottomBar`**:
  - `BottomNavigationBar` widget, height `64`. Includes icons: Home (Active), Groups, Friends, Profile.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):

#### 1. `GET /api/user/balances`
- **Controller Logic:**
  - Execute Prisma query joining `splits` and `settlements`.
  - Calculate aggregated owed vs. paid amounts for the authenticated user.
- **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "total_balance": 145.50,
    "you_owe": 25.00,
    "you_are_owed": 170.50
  }
}
```

#### 2. `GET /api/user/activities?limit=15&offset=0`
- **Controller Logic:**
  - Prisma query fetching latest `expenses` created and latest `settlements` affecting this user, ordered by `createdAt` descending.
- **Response (200 OK):**
```json
{
  "success": true,
  "data": [
    { "id": 101, "type": "expense", "title": "Dinner at Luigi's", "amount": 45.00, "date": "2026-03-22T19:30:00Z" },
    { "id": 102, "type": "settlement", "title": "John paid you", "amount": 10.00, "date": "2026-03-21T10:15:00Z" }
  ]
}
```

### Database Context & Aggregation Rules:
To rapidly return balances, the system does not dynamically calculate millions of rows per load. It depends on an indexed `user_balances` materialization table/view updated per-transaction, or strictly indexed Prisma queries on `splits(userId, status)` + `settlements(payerId, payeeId)`.

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
| --- | --- | --- |
| **Data Sync Delay (API Lag > 3s)** | Shimmer skeleton loaders pulse smoothly indefinitely. | The Dio client implements a timeout of `10000ms`. If hit, triggers a friendly "We're having trouble loading your data right now" overlay. |
| **Massive Ledger Pagination (Load test)** | User scrolls down the latest activity list past items 1-15. As the 10th item approaches the viewport edge, a silent new API request fires for items 16-30. | Flutter `ScrollController` with `addListener` detects scroll position nearing `maxScrollExtent`. The new items are appended seamlessly to the list state via Riverpod/Bloc state update. |
| **API 500 / Service Crash** | The UI maintains standard navigation, hides the numbers with "---", and displays a slim red `SnackBar` notification: "Unable to sync balances." | Ensure UI widgets do not crash via null checks. Null-safe access heavily enforced `balances?.total ?? 0`. |
| **User Navigates Back to Dashboard** | The balances maintain their state globally (cached). | State Manager (Riverpod) holds the state. A silent background network call runs to confirm no new changes exist (stale-while-revalidate pattern). |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] After logging in, the dashboard fully renders within 500 milliseconds without harsh layout shifting.
- [ ] Mathematical totals between "Total Balance", "You Owe", and "You are Owed" perfectly align down to the cent.
- [ ] Re-opening the dashboard while offline successfully displays cached data from SQLite (sqflite/drift).
- [ ] Activities smoothly lazy-load (pagination) upon scrolling to the bottom of the feed via `ScrollController`.
- [ ] Positive balances are visually differentiated from negative balances reliably.
