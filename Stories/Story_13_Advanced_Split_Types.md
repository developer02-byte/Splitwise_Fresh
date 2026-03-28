# Story 20: Advanced Split Types (Shares, Adjustment, Multi-Payer) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Real-world expense splitting is almost never simple. This story covers the three most complex split scenarios that standard Equal/Exact/Percentage cannot handle: (1) Weighted Shares, (2) Adjustment Splits, and (3) bills where multiple people physically contributed payment. These are mandatory for production parity with Splitwise.

---

## 2. Target Persona & Motivation
- **The Detailed Splitter:** Bob drank 3 beers, Alice drank 1. The bill should reflect consumption, not a blind equal split.
- **The Generous User:** The group splits equally, BUT Alice always covers her elderly parent's share too → $X adjustment.
- **The Group Purchaser:** Alice paid $60, Bob paid $40 toward the same $100 team lunch.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Split by Shares
1. **Trigger:** In Add Expense modal, user selects the `SHARES` tab in the Split Pill Toggle.
2. **Action - Shares Entry:** For each participant, a stepper (`-` / `+`) sets their share count. Alice: `1`, Bob: `3`, Charlie: `2`. Total Shares: `6`.
3. **System State - Live Calculation:** Math engine runs: Total `$60.00 / 6 shares`. Alice: `$10.00` (1 share), Bob: `$30.00` (3 shares), Charlie: `$20.00` (2 shares).
4. **Action - Save:** Splits saved with calculated `owed_amount` per user.

### B. Adjustment Split
1. **Trigger:** User selects the `ADJUST` tab in the Split Pill Toggle.
2. **Action - Entry:** The group first splits equally. Then per-person ADJUSTMENT fields appear (+/-). Alice enters `+$10` (she's covering extra). Bob's adjustment: `-$5`.
3. **System State - Live Calculation:** Base equal split recalculated with adjustments layered on top. A running "Remaining to Adjust: $0" counter ensures total remains balanced.
4. **Action - Save:** Adjustments stored as a delta value per split record.

### C. Multiple Payers (Chipped In)
1. **Trigger:** User taps "Paid By" → instead of selecting one person → taps "Multiple people paid".
2. **Action - Multi-Payer Entry:** A list of all participants appears with an individual Amount input next to each name. Alice paid `$60`. Bob paid `$40`. Sum: `$100`. Green checkmark confirms total matches.
3. **Action - Split Definition:** "Who owes what" is SEPARATE from "who paid what". Both are captured independently.
4. **System State - Backend Math:** For each payer, the system calculates net: (What they paid) - (What they owe) = their net credit.

---

## 4. Ultra-Detailed UI/UX Component Specifications
- **`SplitPillToggle`**: Extended to 5 tabs: `EQUAL | EXACT | % | SHARES | ADJUST`.
- **`SharesStepper`**: A row per person with `[ - ]  [2]  [ + ]` inline. Tapping `-` below `1` is blocked (minimum 1 share).
- **`MultiPayerRow`**: Each row shows avatar + name on left, and an amount `InputComponent` on right. A sticky pinned total at the bottom shows real-time sum vs bill total.
- **`AdjustmentDeltaInput`**: Accepts positive (`+10`) or negative (`-5`) values. Displayed in muted purple color to visually distinguish from primary amounts.

---

## 5. Technical Architecture & Database

### Database Context:
```sql
-- Extend splits table for advanced split types
ALTER TABLE splits
  ADD COLUMN share_count SMALLINT DEFAULT 1,           -- for SHARES mode
  ADD COLUMN adjustment_amount INTEGER DEFAULT 0;       -- for ADJUST mode (stored in cents)

-- Extend splits to support multi-payer
ALTER TABLE splits ADD COLUMN paid_amount INTEGER DEFAULT 0;
-- owed_amount = what you owe (cents) | paid_amount = what you physically paid (cents)
```

> **Note:** All monetary amounts (`owed_amount`, `paid_amount`, `adjustment_amount`) are stored as integers representing cents/minor currency units to eliminate floating-point errors.

### Math Validation Rules (Backend — Fastify):
- **Shares:** `SUM(owed_amount)` MUST equal `expenses.total_amount`. Server recomputes shares from submitted `share_count` and validates.
- **Adjustment:** `SUM(base_split + adjustment)` MUST equal total. Adjustments must net to zero.
- **Multi-Payer:** `SUM(paid_amount)` MUST equal `total_amount`. `SUM(owed_amount)` MUST also equal `total_amount`. Two independent validations.

### Validation Example (Fastify + Prisma):
```ts
// src/routes/expenses.ts — shares validation
fastify.post('/api/expenses', async (request, reply) => {
  const { total_amount, splits } = request.body;

  const totalShares = splits.reduce((sum, s) => sum + s.share_count, 0);
  const computedSplits = splits.map((s, i) => {
    const base = Math.floor(total_amount * s.share_count / totalShares);
    // Assign remainder cents to first N splits
    return { ...s, owed_amount: base };
  });

  // Distribute remainder
  const remainder = total_amount - computedSplits.reduce((sum, s) => sum + s.owed_amount, 0);
  for (let i = 0; i < remainder; i++) {
    computedSplits[i].owed_amount += 1;
  }

  // Persist via Prisma transaction
  await prisma.$transaction(async (tx) => {
    const expense = await tx.expense.create({ data: { total_amount, /* ... */ } });
    await tx.split.createMany({ data: computedSplits.map(s => ({ expense_id: expense.id, ...s })) });
  });
});
```

---

## 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Shares mode with remainder** | 6 shares into $100 = $16.666... | Modulo math assigns $16.68 to share 1, $16.67 to shares 2-6. Total = $100.00 exactly. (Internally: 1668 cents, 1667 cents.) |
| **Multi-payer overpayment** | Alice contributes $60, Bob $50 for a $100 bill. Sum = $110. | UI highlights the overpay in red: "Total contributions ($110) exceed bill total ($100). Please adjust." Submit blocked. |
| **Adjustment doesn't net to zero** | Alice adjusts +$15, Bob adjusts -$10. Net = +$5. | UI shows persistent error banner: "Adjustments must net to zero. Remaining: $5.00." Submit blocked. |

---

## 7. Final QA Acceptance Criteria
- [ ] Shares split of 1:3:2 on a $60 bill yields $10, $30, $20 respectively with correct modulo penny handling.
- [ ] Multi-payer where two people paid on a single bill sums correctly and independently validates "who paid" vs "who owes".
- [ ] Submitting an unbalanced Adjustment split is blocked on both client and server with a descriptive error.
- [ ] All 5 split modes (Equal, Exact, %, Shares, Adjust) are accessible via the pill toggle in the Add Expense modal.
- [ ] All monetary values are stored as integers (cents) in PostgreSQL and validated server-side via Prisma.
