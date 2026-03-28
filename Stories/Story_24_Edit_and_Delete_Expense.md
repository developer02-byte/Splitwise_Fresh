# Story 08: Edit & Delete Expense - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Allow users to correct mistakes (wrong amount, wrong payer, forgot someone) without fracturing trust or introducing database inconsistency. Editing an expense is technically deleting the old math and applying the new math instantly in a single transaction. All edits are tracked with before/after snapshots for a full audit trail, and deletes are soft deletes to preserve data integrity.

---

## 👥 2. Target Persona & Motivation
- **The Corrector:** A user who realized they entered "$45.00" instead of "$54.00" for dinner. Wants to quickly edit the record so the group knows it was a typo, and see the balances immediately adjust.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Edit Flow
1. **Trigger:** User opens an Expense Details view, taps the `Edit` (Pencil) icon.
2. **Action - UI Opens:** The original `AddExpenseSheet` (Flutter bottom sheet) opens, but pre-filled with the existing data.
3. **Action - Data Change:** User updates the amount from $45 to $54.
4. **Action - Submission:** User hits "Save Changes".
5. **System State - Processing:** Button shows a `CircularProgressIndicator`. UI initiates `PUT /api/expenses/{id}`.
6. **System State - Success:** The backend completely re-evaluates the math, updating the master record and the child `splits`. An audit trail entry is created storing the before/after snapshot. A `SnackBar` appears: "Expense updated." The balances visibly recalculate on the screen.

### B. The Delete Flow
1. **Trigger:** User taps the `Delete` (Trash) icon in the Expense Details view.
2. **Action - Confirmation:** A sharp Flutter `showModalBottomSheet` or `AlertDialog` triggers: "Delete this expense? This will remove it from everyone's balances. [Cancel] | [Delete]"
3. **Action - Confirmation Check:** User explicitly taps "Delete".
4. **System State - Processing:** `DELETE /api/expenses/{id}` is called.
5. **System State - Success:** The dialog closes. The list item optimistically disappears from the UI. A `SnackBar` appears. The global balances re-run their calculation to exclude the soft-deleted expense. The expense remains in the database with a `deleted_at` timestamp for audit purposes.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`DestructiveConfirmationDialog`**:
  - Built with Flutter `AlertDialog`. Requires user to explicitly tap a red `TextButton`. Default focus is on `Cancel` for accessibility and to prevent accidental deletions.
- **`PreFilledInput`**: The inputs in the Edit sheet must actively track dirtiness (e.g., if you opened Edit but made zero changes, the "Save" button should remain disabled via Flutter form state management).

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `PUT /api/expenses/{id}`
- **Request Payload:** `{ title: "Dinner", amount: 54.00, splits: [...] }`
- **Handler Logic:**
  - PostgreSQL Transaction bounds this endpoint tightly via Prisma `$transaction`.
  - Snapshot the current expense + splits state as `before` into the `expense_audit_log` table.
  - Delete old splits logic via Prisma: `prisma.split.deleteMany({ where: { expenseId: id } })`.
  - Update `expenses` row with new total via Prisma: `prisma.expense.update(...)`.
  - Re-insert new `splits` via Prisma: `prisma.split.createMany(...)`. Total new row sum validated == new amount.
  - Store the new state as `after` in the `expense_audit_log` table.
  - Recalculate materialized balances for involved users.

#### 2. `DELETE /api/expenses/{id}`
- **Handler Logic:**
  - Performs a **soft delete** by setting `deleted_at = NOW()` on the expense record via Prisma: `prisma.expense.update({ where: { id }, data: { deletedAt: new Date() } })`.
  - Associated `splits` are excluded from balance calculations by filtering on `expense.deleted_at IS NULL` in all queries.
  - An audit trail entry is created recording who deleted the expense and when.
  - Balances are recalculated for all affected users.

### Database Context (PostgreSQL):
```sql
-- Soft delete column on expenses
ALTER TABLE expenses ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Audit trail table for edit/delete tracking
CREATE TABLE expense_audit_log (
    id SERIAL PRIMARY KEY,
    expense_id INT NOT NULL REFERENCES expenses(id),
    action VARCHAR(20) NOT NULL,  -- 'edit' or 'delete'
    performed_by INT NOT NULL REFERENCES users(id),
    before_snapshot JSONB,
    after_snapshot JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- All balance queries must exclude soft-deleted expenses
-- WHERE expenses.deleted_at IS NULL
```

### Prisma Schema Context:
```prisma
model Expense {
  id        Int       @id @default(autoincrement())
  // ... other fields
  deletedAt DateTime? @map("deleted_at")
  auditLogs ExpenseAuditLog[]
}

model ExpenseAuditLog {
  id             Int      @id @default(autoincrement())
  expenseId      Int      @map("expense_id")
  action         String   // 'edit' or 'delete'
  performedBy    Int      @map("performed_by")
  beforeSnapshot Json?    @map("before_snapshot")
  afterSnapshot  Json?    @map("after_snapshot")
  createdAt      DateTime @default(now()) @map("created_at")
  expense        Expense  @relation(fields: [expenseId], references: [id])
}
```

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Unauthorized Edit Attempt** | Edit button is hidden if user didn't create the expense (unless it's an open group setting). | Backend strictly validates JWT `user_id` against `expense.created_by`. Returns `403 Forbidden` if mismatched. |
| **Edit causes balance swing** | An edit flips a user from owing $5 to being owed $10. | State manager (Riverpod/Bloc) calculates delta and smoothly animates the red number turning green in the Flutter UI. |
| **Audit trail integrity** | Every edit must be traceable. | The `expense_audit_log` stores full JSONB snapshots of before/after states, ensuring complete traceability even if the expense is later soft-deleted. |
| **Soft-deleted expense visibility** | Soft-deleted expenses should not appear in feeds or balance calculations. | All Prisma queries include `where: { deletedAt: null }` filter. A global Prisma middleware can enforce this automatically. |
