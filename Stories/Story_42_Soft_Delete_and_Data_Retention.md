# Story 42: Soft Delete & Data Retention - Detailed Execution Plan

## 1. Core Objective & Philosophy
Financial data should never be permanently destroyed accidentally. Every deletion in the app is a soft delete — the record is flagged with a timestamp, hidden from the UI, but retained in the database for a defined retention period. This protects users from mistakes, enables undo functionality, supports audit trails, and satisfies regulatory requirements for data retention. Permanent purging happens only via a scheduled background job after the retention window expires.

---

## 2. Target Persona & Motivation
- **The Clumsy User:** Accidentally deletes an expense worth $500 that was split among 6 people. Panics. Needs a way to undo immediately or restore within a reasonable window.
- **The Group Admin:** Wants to clean up old test expenses but also wants a safety net in case they delete the wrong one.
- **The Departing User:** Deletes their account but then changes their mind 2 weeks later. Soft delete allows account recovery within 30 days.
- **The Compliance Officer (Future):** Needs to demonstrate that financial records are retained for a minimum period and that deletion follows a documented, auditable process.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Deleting an Expense
1. **Trigger:** User taps "Delete" on an expense (their own, or any expense if they are a group admin per Story 38).
2. **Confirmation:** Dialog: "Delete this expense? You can restore it within 30 days from Recently Deleted." Two buttons: "Cancel" and "Delete".
3. **Immediate UI Response:** Expense fades out of the list with a `SlideTransition` animation. A `SnackBar` appears at the bottom: "Expense deleted. [Undo]" — visible for 10 seconds.
4. **Undo (within 10 seconds):** User taps "Undo". The expense reappears in the list instantly. The `deleted_at` field is set back to `NULL` on the server.
5. **Backend Action:** `PATCH /api/expenses/:id/delete` sets `deleted_at = NOW()`. Balances are recalculated to exclude the soft-deleted expense. An audit log entry is created with the full before-snapshot of the expense.
6. **Post-Deletion State:** The expense no longer appears in the group feed, dashboard, or balance calculations. It exists only in the "Recently Deleted" section.

### B. Deleting a Settlement
1. **Trigger:** User taps "Delete" on a settlement record.
2. **Confirmation:** Dialog: "Delete this settlement? Balances will revert to their pre-settlement state."
3. **Backend Action:** `deleted_at = NOW()` on the settlement. Balances revert — the debts that were marked as settled become active again.
4. **Undo:** Same 10-second SnackBar with "Undo" button.

### C. Deleting a Group
1. **Trigger:** Admin taps "Delete Group" in group settings.
2. **Prerequisite:** All balances within the group must be $0 (Story 38).
3. **Confirmation:** Dialog: "Delete this group? All members will lose access. Expenses and settlements can be viewed in Recently Deleted for 30 days."
4. **Backend Action:** `deleted_at = NOW()` on the group. All group members see "This group was deleted" if they navigate to it. Expenses and settlements within the group are NOT individually soft-deleted — they remain accessible through the group's "Recently Deleted" state.
5. **Restoration:** Admin can restore the group within 30 days, which restores all content within it.

### D. Deleting a User Account
1. **Trigger:** User navigates to Settings > Delete Account (Story 10).
2. **Immediate Action:** `deleted_at = NOW()` on the user. Profile is anonymized immediately (name → "Deleted User", email → hashed, avatar → removed). Auth tokens are revoked.
3. **30-Day Window:** User can contact support to restore their account. Backend can set `deleted_at = NULL` and restore the original profile data from the audit log.
4. **90-Day Hard Purge:** After 90 days, all user data is permanently removed from the database.

### E. Deleting a Comment
1. **Trigger:** User deletes their own comment on an expense.
2. **Backend Action:** `deleted_at = NOW()` on the comment. Comment disappears from the expense thread.
3. **Retention:** Comments are purged with their parent expense. No separate retention period.

### F. Restoring Deleted Content
1. **Access:** Group admin navigates to group settings > "Recently Deleted".
2. **UI:** List of soft-deleted expenses and settlements within the group, sorted by deletion date (most recent first). Each item shows: title, amount, deleted date, and "Restore" button.
3. **Action:** Admin taps "Restore". The expense reappears in the group feed. Balances are recalculated to include the restored expense.
4. **Expiry:** Items older than 30 days (from `deleted_at`) are no longer restorable and are hidden from this list. They await hard purge at 90 days.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`DeleteConfirmationDialog`**:
  - `AlertDialog` with title "Delete [Entity]?", body text explaining consequences, and two buttons.
  - "Cancel" button: `TextButton`, grey. "Delete" button: `TextButton`, `Colors.red`, bold.
  - Body includes restoration info: "You can restore this within 30 days."

- **`UndoDeleteSnackBar`**:
  - `SnackBar` with `duration: Duration(seconds: 10)`.
  - Content: "Expense deleted." Action: `TextButton("Undo", onPressed: restoreExpense)`.
  - `behavior: SnackBarBehavior.floating`, `margin: EdgeInsets.all(16)`.
  - On timeout without undo: no further action (deletion is already committed server-side).

- **`RecentlyDeletedList`**:
  - `ListView.builder` showing soft-deleted items.
  - Each tile: `ListTile` with title (expense description), subtitle (deleted date in relative format: "3 days ago"), trailing "Restore" `TextButton`.
  - Empty state: `Center(child: Text("No recently deleted items"))`.
  - Items older than 30 days are filtered out client-side.

- **`DeletedGroupBanner`**:
  - When a member navigates to a deleted group (e.g., from a notification), a full-width banner at the top: "This group was deleted on [date]. Contact the group admin to restore it."
  - Background: `Colors.red.shade50`, text `Colors.red.shade900`.

---

## 5. Technical Architecture & Database

### Database Schema Changes (PostgreSQL via Prisma):
```sql
-- Add deleted_at column to all relevant tables
ALTER TABLE expenses ADD COLUMN deleted_at TIMESTAMPTZ NULL;
ALTER TABLE settlements ADD COLUMN deleted_at TIMESTAMPTZ NULL;
ALTER TABLE groups ADD COLUMN deleted_at TIMESTAMPTZ NULL;
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ NULL;
ALTER TABLE expense_comments ADD COLUMN deleted_at TIMESTAMPTZ NULL;

-- Partial indexes for efficient filtering of soft-deleted records
CREATE INDEX idx_expenses_deleted ON expenses(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_settlements_deleted ON settlements(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_groups_deleted ON groups(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_expense_comments_deleted ON expense_comments(deleted_at) WHERE deleted_at IS NOT NULL;
```

### Prisma Schema Update:
```prisma
model Expense {
  id          Int       @id @default(autoincrement())
  groupId     Int?      @map("group_id")
  title       String    @db.VarChar(150)
  totalAmount Decimal   @map("total_amount") @db.Decimal(10, 2)
  paidBy      Int       @map("paid_by")
  createdBy   Int       @map("created_by")
  createdAt   DateTime  @default(now()) @map("created_at")
  deletedAt   DateTime? @map("deleted_at")

  // ... relations
  @@map("expenses")
}

// Same pattern for Settlement, Group, User, ExpenseComment
```

### Prisma Middleware — Auto-Filter Soft-Deleted Records:
```typescript
prisma.$use(async (params, next) => {
  // Models that support soft delete
  const softDeleteModels = ['Expense', 'Settlement', 'Group', 'User', 'ExpenseComment'];

  if (softDeleteModels.includes(params.model ?? '')) {
    // Auto-filter on read operations
    if (params.action === 'findMany' || params.action === 'findFirst' || params.action === 'findUnique') {
      // Allow explicit override: pass { includeDeleted: true } in where clause
      if (params.args?.where?.includeDeleted) {
        delete params.args.where.includeDeleted;
      } else {
        params.args = params.args ?? {};
        params.args.where = { ...params.args.where, deletedAt: null };
      }
    }

    // Intercept delete operations and convert to soft delete
    if (params.action === 'delete') {
      params.action = 'update';
      params.args.data = { deletedAt: new Date() };
    }

    if (params.action === 'deleteMany') {
      params.action = 'updateMany';
      params.args.data = { deletedAt: new Date() };
    }
  }

  return next(params);
});
```

### Backend Endpoints (Node.js Fastify):

#### 1. `PATCH /api/expenses/:id/delete`
- **Purpose:** Soft-delete an expense.
- **Auth:** Expense creator or group admin.
- **Controller Logic:**
  - Set `deleted_at = NOW()` on the expense.
  - Recalculate group balances excluding this expense.
  - Create audit log entry with full expense snapshot (Story 35).
  - Emit Socket.io event `expense:deleted` to group members.
- **Response:** `200 OK` with `{ deleted_at, undo_token }`.

#### 2. `PATCH /api/expenses/:id/restore`
- **Purpose:** Restore a soft-deleted expense.
- **Auth:** Expense creator or group admin.
- **Validation:** `deleted_at` must be within 30 days.
- **Controller Logic:**
  - Set `deleted_at = NULL`.
  - Recalculate group balances to include the restored expense.
  - Create audit log entry: "Expense restored".
  - Emit Socket.io event `expense:restored` to group members.
- **Response:** `200 OK` with the restored expense.

#### 3. `GET /api/groups/:groupId/deleted`
- **Purpose:** List recently deleted items in a group (admin only).
- **Auth:** Group admin.
- **Query Parameters:** `type` (expenses, settlements), `page`, `limit`.
- **Controller Logic:**
  - Query records where `deleted_at IS NOT NULL` and `deleted_at > NOW() - INTERVAL '30 days'`.
  - Uses the `includeDeleted: true` flag to bypass Prisma middleware auto-filter.
- **Response:** Paginated list of soft-deleted items.

#### 4. `PATCH /api/settlements/:id/delete` and `PATCH /api/settlements/:id/restore`
- Same pattern as expense soft-delete/restore. Balances revert on settlement deletion.

### Hard Purge — BullMQ Recurring Job:
```typescript
import { Queue, Worker } from 'bullmq';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);
const purgeQueue = new Queue('data-purge', { connection: redis });

// Schedule daily at 2:00 AM UTC
await purgeQueue.add('hard-purge', {}, {
  repeat: { pattern: '0 2 * * *' },
});

const purgeWorker = new Worker('data-purge', async (job) => {
  const cutoffDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000); // 90 days ago

  // Hard purge expenses
  const purgedExpenses = await prisma.$executeRaw`
    DELETE FROM expenses WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoffDate}
  `;

  // Hard purge settlements
  const purgedSettlements = await prisma.$executeRaw`
    DELETE FROM settlements WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoffDate}
  `;

  // Hard purge groups (and cascade)
  const purgedGroups = await prisma.$executeRaw`
    DELETE FROM groups WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoffDate}
  `;

  // Hard purge users
  const purgedUsers = await prisma.$executeRaw`
    DELETE FROM users WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoffDate}
  `;

  // Hard purge comments
  const purgedComments = await prisma.$executeRaw`
    DELETE FROM expense_comments WHERE deleted_at IS NOT NULL AND deleted_at < ${cutoffDate}
  `;

  // Delete associated files from storage (Story 28)
  await purgeOrphanedFiles();

  console.log(`Hard purge complete: ${purgedExpenses} expenses, ${purgedSettlements} settlements, ${purgedGroups} groups, ${purgedUsers} users, ${purgedComments} comments`);
}, { connection: redis });
```

### Data Retention Policy Summary:

| Data Type | Soft-Delete Retention | Hard Purge After | Restorable Window |
|-----------|----------------------|------------------|-------------------|
| Expenses | 90 days | 90 days from deletion | 30 days |
| Settlements | 90 days | 90 days from deletion | 30 days |
| Groups | 90 days | 90 days from deletion | 30 days |
| User Accounts | 90 days | 90 days from deletion | 30 days |
| Comments | Purged with parent expense | With parent expense | Not independently restorable |
| Audit Logs | N/A (never soft-deleted) | 2 years (Story 35) | N/A |
| Email Logs | N/A | 1 year | N/A |
| Active Data | N/A | Never (while account active) | N/A |

### Balance Recalculation on Soft Delete / Restore:
When an expense is soft-deleted, the balance calculation query must exclude it. Since all queries auto-filter `deleted_at IS NULL` via Prisma middleware, balance recalculation naturally excludes soft-deleted expenses. When an expense is restored (`deleted_at` set back to `NULL`), it is automatically included again.

Critical: settlements that reference soft-deleted expenses must still be valid. The settlement records the debt transfer, not the underlying expense. Soft-deleting an expense does NOT automatically soft-delete related settlements.

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
|---|---|---|
| **Restoring expense in a deleted group** | Restore is blocked. Error: "Cannot restore — the group this expense belongs to has been deleted. Restore the group first." | Backend checks group's `deleted_at` before allowing expense restoration. |
| **Hard purge of user with audit log entries** | Audit log entries are anonymized (user_id replaced with placeholder, name replaced with "Deleted User") but not deleted. | Purge job runs anonymization on audit logs before deleting the user record. Foreign key uses `ON DELETE SET NULL`. |
| **Soft-deleted user receives a group invitation** | Invitation is rejected silently. The inviter sees "User not found." | Invitation handler checks `deleted_at IS NULL` on the target user. |
| **Cascade soft delete — delete group, what about expenses?** | Expenses within the group are NOT individually soft-deleted. They remain active but inaccessible (the group is the soft-deleted parent). Restoring the group restores access to all expenses. | Query for expenses filters by group membership, and deleted groups are excluded. No cascade needed. |
| **Undo after 10 seconds** | SnackBar has disappeared. User must go to "Recently Deleted" to restore. | Undo is a client-side convenience. Server-side restoration is always available for 30 days. |
| **Two users delete the same expense simultaneously** | First request succeeds, second gets `404` (expense already has `deleted_at` set, Prisma middleware filters it). | Idempotent behavior. No error shown to second user — the expense is already deleted. |
| **Hard purge fails midway** | Job logs the error and retries on next scheduled run. Partially purged data is fine — each DELETE is independent. | BullMQ retry mechanism with exponential backoff. Alerting via observability (Story 14). |
| **User deletes account, then expense hard-purge runs before account purge** | Expenses by the deleted user are purged if they were individually soft-deleted. If only the user was soft-deleted (not the expenses), expenses remain with `created_by` pointing to a soft-deleted user. | Display "Deleted User" for `created_by` when the user record is soft-deleted. On user hard-purge, anonymize expense records. |

---

## 7. Final QA Acceptance Criteria
- [ ] Deleting an expense sets `deleted_at` timestamp; the expense disappears from the group feed and balance calculations.
- [ ] A 10-second "Undo" SnackBar appears after deleting an expense, and tapping "Undo" restores it immediately.
- [ ] Deleting a settlement reverts the balances to their pre-settlement state.
- [ ] Group admin can view "Recently Deleted" items in group settings.
- [ ] Soft-deleted items are restorable within 30 days of deletion.
- [ ] Items older than 30 days no longer appear in the "Recently Deleted" list.
- [ ] Deleting a group shows "This group was deleted" to all members.
- [ ] Deleting a user account anonymizes the profile immediately and revokes auth tokens.
- [ ] The hard purge BullMQ job runs daily at 2 AM and permanently removes records older than 90 days.
- [ ] After hard purge, associated file storage (receipts, avatars) is also cleaned up.
- [ ] All standard queries (findMany, findFirst) auto-filter soft-deleted records via Prisma middleware.
- [ ] Direct API calls cannot read soft-deleted records unless explicitly requesting them (admin-only, for the "Recently Deleted" feature).
- [ ] Audit log entries are created for every soft-delete and restore operation.
- [ ] Balance calculations are correct after soft-delete (excluding) and restore (re-including).
- [ ] Hard purge of a user anonymizes their audit log entries rather than deleting them.
