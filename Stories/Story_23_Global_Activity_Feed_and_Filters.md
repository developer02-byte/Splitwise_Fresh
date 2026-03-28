# Story 07: Global Activity Feed & Filters - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide a comprehensive, searchable, and filterable ledger of every transaction involving the user. Allow them to quickly audit their history and jump straight into details without needing to remember which group or friend it was associated with.

---

## 👥 2. Target Persona & Motivation
- **The Auditor:** A user wondering, "Wait, why do I owe Bob $200?" or "How much did I spend on food this month?" They need an infinite scrollable list of interactions with quick pill-based filters.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Global Feed Load Sequence
1. **Trigger:** User taps "Activity" icon on the Bottom Navigation Bar.
2. **Action - UI Loads:** Display the `ActivityFeedScreen`. Top section contains Pill Filters. The main body is a Flutter `ListView.builder` with a `ScrollController` for cursor-based infinite scrolling.
3. **System State - Data Load:** `GET /api/user/activities/all?limit=30` loads expenses, settlements, and group joins in chronological order. The response includes a `cursor` field pointing to the last item's ID/timestamp for fetching the next page.
4. **System State - Render:** The Feed renders showing exactly who paid what, when, and the net effect on the user.

### B. The Filtering Flow
1. **Trigger:** User taps the "Date" filter pill or the "Group" filter pill.
2. **Action - Filter Selection:** A Flutter `showModalBottomSheet` pops up letting them select "Last 30 Days" or "All Groups vs 'Apartment'".
3. **Action - Apply:** The `ListView` clears, shows a `Shimmer` skeleton loader, and requests the filtered API route: `GET /api/user/activities/all?group_id=4&date_range=month&cursor=...`. The `ScrollController` resets its cursor for the new filter context.
4. **System State - Result:** Feed selectively updates.

### C. The Details Expansion (Click -> Details)
1. **Trigger:** User taps a specific Activity List Item ("Lunch at Luigi's").
2. **Action - Deep Link:** The app uses `Navigator.push` to route to the `ExpenseDetailScreen` for the given expense ID, showing the full breakdown of who was involved, the total cost, and the specific math of the split.
3. **Action - Contextual Actions:** Within this view, buttons exist (if authorized) to "Edit" or "Remove".

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`FilterPillList`:** A horizontally scrollable `SingleChildScrollView` row of `ChoiceChip` widgets. Active state: Brand Color background, White text.
- **`ActivityListRow`:** Leading `CircleAvatar` icon indicating the category (e.g., Money icon for Settlements, Knife/Fork for Food Expenses).
- **`InfiniteScroller`:** Uses a `ScrollController` with `addListener` to detect when the user scrolls near the bottom (`controller.position.maxScrollExtent`). Triggers cursor-based pagination by passing the last item's cursor to the next API call. Displays a `CircularProgressIndicator` at the bottom while loading the next page.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `GET /api/user/activities/all`
- **Handler Logic:**
  - Pulls from a unified materialization of both `expenses` mapped through `splits`, AND `settlements` involving `user_id`, sorted historically.
  - Supports cursor-based pagination: accepts `cursor` (last item timestamp or ID) and `limit` query params. Returns `next_cursor` in the response for the client `ScrollController` to use.

### Database Context (PostgreSQL):
```sql
-- Often implemented as a Database View for high performance querying
CREATE VIEW user_activity_feed AS
SELECT id, title AS description, total_amount, created_at, 'expense' AS type FROM expenses
UNION ALL
SELECT id, CONCAT('Payment to ', payee_id), amount, created_at, 'settlement' AS type FROM settlements;

-- Cursor-based pagination query
SELECT * FROM user_activity_feed
WHERE created_at < $1
ORDER BY created_at DESC
LIMIT $2;
```

### Prisma Schema Context:
```prisma
// Activity feed is queried via Prisma raw queries against the PostgreSQL view
// Parameterized queries ensure safety:
// const activities = await prisma.$queryRaw`
//   SELECT * FROM user_activity_feed
//   WHERE created_at < ${cursor}
//   ORDER BY created_at DESC
//   LIMIT ${limit}
// `
```

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **No Activity Matches Filters** | Render friendly empty-state Flutter widget with illustration: "No activity matches these filters." | Returns `data: []`, cleanly mapping to Flutter widget components. |
