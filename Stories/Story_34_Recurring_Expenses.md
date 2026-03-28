# Story 17: Recurring Expenses - Detailed Execution Plan

## 1. Core Objective & Philosophy
Automate the monthly annoyance of logging the same rent, internet, or Netflix bill. The system should fire once and keep working silently every month — saving every roommate the "Did you add the rent yet?" argument.

---

## 2. Target Persona & Motivation
- **The Apartment Tenant:** Pays $1,200/month rent for 3 people split equally. They only want to set this up ONCE, and have the app automatically log it on the 1st of every month forever.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Creating a Recurring Expense
1. **Trigger:** User opens the "Add Expense" modal.
2. **Action - Toggle Recurring:** Below the date field, a subtle toggle switch: `[ ] Make this recurring`. User taps it ON.
3. **Action - Recurrence Options Appear:** A dropdown appears: `Every Month | Every Week | Every 2 Weeks | Custom`. User selects "Every Month".
4. **Action - Set Day:** A secondary picker appears: "On day `1` of each month." User sets `1`.
5. **Action - Set End Date (Optional):** "Ends: `Never` | `On Date` | `After N occurrences`". User leaves it as "Never".
6. **Action - Save:** The expense is saved with `is_recurring = true`, `recurrence_type = 'monthly'`, `recurrence_day = 1`.
7. **System State - Confirmation:** A small recurring badge permanently appears on this expense card in the ledger view.

### B. The Auto-Generation Job (Backend — BullMQ)
1. **Trigger:** BullMQ recurring job runs daily at `00:05 AM`.
2. **System State - Check:** Prisma query: `prisma.expense.findMany({ where: { is_recurring: true, next_due_date: today } })`.
3. **Action - Duplicate Entry:** For each matching expense, the job creates a brand new copy in `expenses` table with a fresh `id`, same title/amount/splits, and today's date.
4. **Action - Notification:** Push notification fires to all group members: "Recurring: 'Rent - March' has been added to Apartment Group."
5. **Action - Update:** The original template record's `next_due_date` is incremented by 1 month.

### BullMQ Job Setup (Node.js):
```ts
// src/jobs/recurringExpenses.ts
import { Queue, Worker } from 'bullmq';
import prisma from '../prisma';

const recurringQueue = new Queue('recurring-expenses', { connection: redis });

// Schedule: runs daily at 00:05
recurringQueue.add('generate-recurring', {}, {
  repeat: { pattern: '5 0 * * *' },
});

const worker = new Worker('recurring-expenses', async () => {
  const today = new Date().toISOString().split('T')[0];
  const templates = await prisma.expense.findMany({
    where: { is_recurring: true, next_due_date: new Date(today) },
    include: { splits: true },
  });

  for (const template of templates) {
    await prisma.$transaction(async (tx) => {
      // Duplicate expense + splits
      const newExpense = await tx.expense.create({ /* ... clone from template ... */ });
      // Update next_due_date
      await tx.expense.update({
        where: { id: template.id },
        data: { next_due_date: computeNextDueDate(template) },
      });
      // Fire push notification to group members
    });
  }
}, { connection: redis });
```

### C. Managing a Recurring Expense
1. **Trigger:** User taps the recurring badge on an expense. A context menu appears:
   - "Edit This Occurrence" (changes just this month)
   - "Edit All Future Occurrences" (changes the template going forward)
   - "Stop Recurring" (sets `is_recurring = false` on the template)

---

## 4. Ultra-Detailed UI/UX Component Specifications
- **`RecurringToggle`**: A clean Switch widget that animates expansion of sub-options via `AnimatedContainer`.
- **`RecurringBadge`**: A small pill "Monthly" in info-blue rendered inline on the expense list item to visually differentiate templates from one-off entries.

---

## 5. Technical Architecture & Database

### Database Context:
```sql
ALTER TABLE expenses
  ADD COLUMN is_recurring BOOLEAN DEFAULT FALSE,
  ADD COLUMN recurrence_type VARCHAR(20) CHECK (recurrence_type IN ('weekly', 'biweekly', 'monthly', 'custom')),
  ADD COLUMN recurrence_day SMALLINT NULL,
  ADD COLUMN next_due_date DATE NULL,
  ADD COLUMN parent_expense_id INTEGER NULL REFERENCES expenses(id);
```

---

## 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **31st of month, but February has 28 days** | Expense set to recur on 31st. Feb has no 31st. | BullMQ job defaults to the LAST day of the month. Stored as `recurrence_day = 31`, job logic uses PostgreSQL `LEAST(recurrence_day, EXTRACT(DAY FROM (date_trunc('month', NOW()) + INTERVAL '1 month - 1 day')))` to cap the day. |
| **User edits one occurrence vs all** | User adjusts one month's rent from $400 to $350 (discount). | "Edit This Occurrence" creates a new standalone `expenses` record with modified amount. Template record is untouched. The one-off record has `parent_expense_id = NULL`. |
| **User stops recurring mid-month** | User stops it on March 15th. Was set for March 1st (already generated). | March 1st entry is already in the ledger and remains. `is_recurring = false` simply prevents future generation. No historical data loss. |

---

## 7. Final QA Acceptance Criteria
- [ ] A recurring expense set for the `1st of every month` auto-generates a new ledger entry every month at midnight without user action.
- [ ] "Edit All Future Occurrences" updates the template and all subsequent generated entries.
- [ ] Stopping a recurring entry does not delete historical generated copies.
- [ ] February correctly uses the last day of month if day `> 28`.
- [ ] BullMQ job processes all due recurring expenses and correctly increments `next_due_date`.
