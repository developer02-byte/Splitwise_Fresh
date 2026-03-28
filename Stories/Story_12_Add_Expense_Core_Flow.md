# Story 03: Add Expense (The Core Flow) - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
This is the heart of the product. The process of adding, categorizing, and splitting an expense must be the absolute easiest action in the entire app. It must require zero cognitive load to define how a mathematically tricky check is split. The user must feel absolute trust that the system will calculate pennies completely fairly and never lose an expense to network instability.

---

## 👥 2. Target Persona & Motivation
- **The Payer/Actor:** A user out to lunch who just paid $123.45 for a table of 4 people. They don't want to calculate `$123.45 / 4` while holding a receipt. They just want to punch "123.45", select 3 friends, hit "Save," and put their phone away. They expect the system to handle remainders.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Core Invocation Sequence
1. **Trigger:** User taps the massive primary `FloatingActionButton` on the Dashboard or within a specific Group View.
2. **Action - UI Opens:** A full-screen modal or bottom sheet slides over the view immediately (`Navigator.push` with `SlideTransition`, duration `200ms`). No route reload or redirection (preventing perceived latency).
3. **Action - Core Fields Entry:**
   - **Description Field:** User types "Lunch". (Focus is active immediately so keyboard springs up via `autofocus: true`).
   - **Amount Field:** Numpad UI triggers via `TextInputType.numberWithOptions(decimal: true)`. User enters "$123.45". Format validation ensures only 2 decimal places are possible (`^\d+(\.\d{1,2})?$`).
   - **Payer Selection:** Defaults to "Paid by: You". Can tap to select "Paid by: John" via an inline dropdown or bottom sheet selector.
   - **Participants Selection:** Taps "Split with..." -> multi-select list of group members or friends. Checks Alice, Bob, Charlie.

### B. The Split Mechanics (Mathematical Interface)
1. **Action - Select Split Mode:** A `ToggleButtons` widget at the top: `[ EQUAL | EXACT | % ]`.
2. **System State - Equal Split (Default):** The UI auto-renders: `You: $30.87, Alice: $30.86, Bob: $30.86, Charlie: $30.86`. (Notice the fractional penny assigned back to the payer to hit $123.45 perfectly).
3. **Action - Adjust Exact/Custom Split:** User taps `EXACT` and manually adjusts Alice to "$40". The UI visually highlights that there is exactly `$21.73` left to allocate. Total check sum remains static at $123.45.
4. **Action - Save Submission:** User taps large "Save" `FloatingActionButton`.

### C. The Optimistic Save Sequence
1. **System State - Processing:** Button visually morphs into a `CircularProgressIndicator`. The modal begins executing an exit animation immediately, sending the user back exactly where they started on the Dashboard/Group screen.
2. **System State - Local Update:** The new expense ($123.45) appears in the top of the Activity List immediately (Optimistic Update). Balances visually tick upward.
3. **Action - API Call:** `POST /api/expenses/add` runs silently in background via Dio.
4. **System State - Success/Error:**
   - **Success:** The database fully records the transaction. Green `SnackBar` "Expense saved: Lunch" drops from top. Background sync finalizes.
   - **Error / Offline:** The API fails. The UI removes the optimistic update, reverting the balances, and drops a red `SnackBar` "Failed to save. Tap to retry.". The expense payload is queued in local SQLite (drift) for automatic retry.

### D. "Created By" Tracking
- Every expense displays a "Created by" label showing which user originally logged the expense. This is stored as `created_by` in the expense record and rendered in expense detail views as "Logged by [User Name]".

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`ExpenseModalSheet`**:
  - Behavior: Rendered as a full-screen route or `showModalBottomSheet` with `isScrollControlled: true`. Overlay background `Colors.black54`. Slides up from bottom.
  - Dismiss: Tapping backdrop or "Cancel" cleanly pops the route via `Navigator.pop`.
- **`AmountNumpadInput`**:
  - Massive typography (`TextStyle(fontSize: 48, fontWeight: FontWeight.bold)`, center-aligned). Number format mask applies immediately (e.g. typing `12` -> `$12.00`) via `TextInputFormatter`.
- **`SplitPillToggle`**:
  - 3 equal segments via `ToggleButtons`. Active segment `background: Brand Blue`, text `Colors.white`, `FontWeight.bold`. Inactive `background: Colors.grey[100]`, text `Colors.grey[700]`.
- **`ParticipantMatrixList`**:
  - Vertical `ListView` of selected users. `CircleAvatar` + Name on Left. `TextFormField` on Right for custom amounts. Color turns Red if sum of list > Total Amount.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):

#### 1. `POST /api/expenses/add`
- **Request Payload:**
```json
{
  "title": "Lunch",
  "amount": 123.45,
  "paid_by": 101,
  "created_by": 101,
  "group_id": 5,
  "splits": [
    { "user_id": 101, "amount": 30.87 },
    { "user_id": 102, "amount": 30.86 },
    { "user_id": 103, "amount": 30.86 }
  ],
  "idempotency_key": "uuid-v4-abc-123"
}
```

- **Controller & Math Engine Logic:**
  - Fastify schema validation. Does sum of `splits[].amount` === `123.45`? If `123.44` or `123.46`, strictly reject with `400 Bad Request: "Split math mismatch"`.
  - Is `idempotency_key` currently executing? If yes, throw `409 Conflict`.
  - Open Prisma transaction via `prisma.$transaction()`.
  - Insert via `prisma.expense.create({ data: { title, totalAmount, paidBy, createdBy, groupId } })`.
  - Bulk insert splits via `prisma.split.createMany({ data: splits.map(s => ({ expenseId, userId: s.user_id, owedAmount: s.amount })) })`. Trigger event to update `user_balances`.
  - Commit Prisma transaction.
  - Sanitize user-provided `title` via `sanitize-html` before storage.

### Database Context & Relational Integrity (PostgreSQL via Prisma):
```sql
CREATE TABLE expenses (
    id SERIAL PRIMARY KEY,
    group_id INT NULL,
    title VARCHAR(150),
    total_amount DECIMAL(10,2) NOT NULL,
    paid_by INT NOT NULL,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE splits (
    id SERIAL PRIMARY KEY,
    expense_id INT NOT NULL,
    user_id INT NOT NULL,
    owed_amount DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE
);
```

### Offline Queue (Flutter SQLite via drift):
When the device is offline (detected via `connectivity_plus`), the expense payload is serialized and inserted into a local SQLite `outbox` table. A background isolate monitors connectivity and automatically retries queued payloads when the connection is restored.

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
| --- | --- | --- |
| **Fractional Penny Drift** | The UI allocates extra pennies to the payer. A $10.00 split 3 ways yields `$3.34` (payer), `$3.33`, `$3.33`. | Backend strictly sums split allocations. Rejects anything not precisely equaling `total_amount`. Prevents database drift of `0.01` becoming `10.00` over years. |
| **Rapid Double Tap Spam** | "Save" button is hit 4 times during lag. State changes to `loading` instantly, hiding the button or ignoring taps. | Flutter attaches `uuidv4()` locally to payload. Backend caches the `idempotency_key` instantly via Redis or unique DB index, rejecting duplicates. |
| **"Subway Tunnel" Offline Drop** | User hits save right as LTE dies. Request hangs for 10s. The UI reverts optimism and traps error. Displays persistent top banner. | Error caught by Dio interceptor. State manager pushes the exact payload into local SQLite (drift) "Outbox" table. When `connectivity_plus` stream fires a connected event, auto-retries queued expenses. |
| **Payer owes themselves?** | Yes, the Payer's logic in the UX is treated as a split to zero out their personal responsibility of the total amount, accurately representing true debts. | The `splits` table logs the payer as owing `x` amount to the `expense`, which is nullified against the fact they paid `total_amount` in the balance view. |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] User can enter an expense of $100.00, select 3 friends, and hit Equal Split, yielding 33.34/33.33/33.33 without manual math.
- [ ] Custom Split mode strictly prevents submission if the custom inputs sum to $100.01 or $99.99.
- [ ] UI provides instant feedback when the exact amount is perfectly accounted for (e.g., green checkmark appears next to Total).
- [ ] Idempotency prevents two identical expenses from being drafted under rapid UI spamming.
- [ ] Navigating away from or dismissing the modal while typing throws a warning dialog: "Discard this expense?"
- [ ] Every expense displays "Created by [User Name]" in the detail view, accurately tracking who logged the expense.
- [ ] Offline expenses are queued locally in SQLite and automatically synced when connectivity is restored.
