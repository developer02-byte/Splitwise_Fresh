# Story 05: Settlements & Payments - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide absolute trust and structural rigidity in the "I paid you back" process. When a user hands cash to their friend or Venmo's them, they must be able to record that event in the app instantly, and both parties must see the math zero out in real-time. This is the ultimate "moment of truth" for the application. Any race condition or duplicate settlement here is catastrophic to user trust.

---

## 👥 2. Target Persona & Motivation
- **The Debtor (Payer in Settlement):** I just owed my roommate $145.23 for rent and utilities. I just sent it via Zelle. I open the app to click "Settle Up" to permanently clear my conscience and the red numbers off my dashboard.
- **The Creditor (Receiver in Settlement):** My roommate said they paid me. I open the app. I need to see $0.00 right now instead of +$145.23.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Settle Up Initiation
1. **Trigger:** The user taps the massive "Settle Up" prominent button on the Dashboard or Group view.
   - Note: This button is always visible, but disabled (`opacity: 0.5`) if the user literally owes nothing.
2. **Action - Select Payee:** The system does not present a complex list of 500 friends. It only shows a highly curated list: Friends they actively owe money to.
3. **Action - UI Interaction:** The user taps "Bob" from the list.
4. **Action - Define Amount:** A secondary screen slides in (or modal updates). The UI auto-populates the *entire* amount owed by default (e.g., "$145.23"). The user is given an editable Numpad to lower the number if making a partial payment.
5. **Action - Confirm:** The user taps the final "Record Payment" primary button.

### B. The "Settle All" Flow (Cross-Group)
1. **Trigger:** From the Dashboard or a friend's profile, the user taps "Settle All with [Person]".
2. **System State - Aggregation:** The system calculates the total net balance with that person across ALL groups (e.g., "You owe Bob $50 in 'Tokyo Trip' and $30 in 'Apartment' = $80 total").
3. **Action - UI Display:** A summary screen shows the breakdown per group and the total amount. The user can review and confirm.
4. **Action - Confirm:** User taps "Settle All $80.00". A single API call settles all balances with that person across every group.
5. **System State - Processing:** Multiple settlement records are created (one per group) within a single database transaction to ensure atomicity.

### C. The Optimistic Execution & Broadcast
1. **System State - Optimistic UI Shifting:** The dashboard balance instantly shifts according to the settlement before the server responds. "You Owe" drops by the settled amount. The total is recalculated instantly.
2. **Action - API Call:** `POST /api/settlements/pay` sent with Payload: `payer_id`, `payee_id`, `amount`, `idempotency_key`, `group_id_context (optional)`.
3. **System State - Success/Error:**
   - **Success:** The database registers it. Background Push Notification is dispatched to Bob ("John just paid you $145.23!"). Green success checkmark drops in UX via `SnackBar`.
   - **Error / Offline:** The API fails. The UI gracefully rolls back the local balance to -$145.23 and triggers a sharp red error overlay stating "Sync failed, please try again."

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`SettleUpModalContainer`**:
   - Built as a `showModalBottomSheet` with `borderRadius: BorderRadius.vertical(top: Radius.circular(16))`, height `auto`, focus-trapped. Transition via `AnimationController` with `Curves.easeOutCubic`.
- **`PayeeListSelection`**:
  - Horizontal scroll of avatars via `ListView(scrollDirection: Axis.horizontal)` or vertical list if > 3 payees.
  - Active payee gets a solid `Border.all(width: 2, color: primaryBrand)` ring.
- **`AmountPillInput`**:
  - Built as a `Container` with `borderRadius: BorderRadius.circular(9999)`, `padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)`, `TextStyle(fontSize: 32, fontWeight: FontWeight.bold)`.
  - Tapping it triggers the numerical keypad via `TextInputType.numberWithOptions(decimal: true)`.
- **`SettleButtonPrimary`**:
  - A bright green (`Success Color`) `ElevatedButton`.
  - State: `isLoading` -> `AnimatedContainer` morphs width from full to a circle `48` containing a white `CircularProgressIndicator`.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):

#### 1. `POST /api/settlements/pay`
- **Request Payload:**
```json
{
  "payer_id": 101,
  "payee_id": 102,
  "amount": 145.23,
  "currency": "USD",
  "idempotency_key": "uuid-settle-0001",
  "group_id": 12
}
```

- **Controller Logic (Critical Section):**
  - Check `idempotency_key` via `prisma.settlement.findUnique({ where: { idempotencyKey } })`. Reject `409 Conflict` if duplicate.
  - Start Prisma transaction via `prisma.$transaction()`.
  - **Pessimistic Lock (PostgreSQL):** `SELECT SUM(owed_amount) FROM splits WHERE user_id = $1 AND status = 'unpaid' FOR UPDATE`. This freezes the rows.
  - Validate: Does the payer *actually* owe this amount? If they owe $10, but try to settle $50, throw `400 Bad Request: "Overpayment not allowed."` (or optionally log it as a positive credit based on business rules).
  - Insert via `prisma.settlement.create({ data: { payerId, payeeId, amount, currency, groupId, idempotencyKey } })`.
  - Fire asynchronous worker/job (via Fastify hooks or BullMQ) to calculate new materialized `user_balances`.
  - Push Notification via FCM/APNS to Bob.
  - Commit Prisma transaction.

#### 2. `POST /api/settlements/settle-all`
- **Request Payload:**
```json
{
  "payer_id": 101,
  "payee_id": 102,
  "idempotency_key": "uuid-settle-all-0001"
}
```

- **Controller Logic:**
  - Calculate net balances per group between payer and payee.
  - Start Prisma transaction.
  - For each group with outstanding balance, create a settlement record via `prisma.settlement.create()`.
  - Lock rows via `SELECT ... FOR UPDATE` to prevent race conditions.
  - Update all affected balance materializations.
  - Commit transaction atomically.
- **Response (200 OK):**
```json
{
  "success": true,
  "settled": [
    { "group_id": 5, "group_name": "Tokyo Trip", "amount": 50.00 },
    { "group_id": 12, "group_name": "Apartment", "amount": 30.00 }
  ],
  "total_settled": 80.00
}
```

### Database Context (PostgreSQL via Prisma):
```sql
CREATE TABLE settlements (
    id SERIAL PRIMARY KEY,
    payer_id INT NOT NULL,
    payee_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    group_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Prevent duplicate physical clicks at DB layer manually if no Redis
    idempotency_key VARCHAR(64) UNIQUE,
    FOREIGN KEY (payer_id) REFERENCES users(id),
    FOREIGN KEY (payee_id) REFERENCES users(id)
);
```

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
| --- | --- | --- |
| **Simultaneous Settlement (Race Condition/Deadlock)** | John and Bob both open app at exactly 1:00 PM. Both tap "Settle Up" for the $50 simultaneously. | DB Transaction 1 acquires lock via PostgreSQL `SELECT ... FOR UPDATE`. Trans 1 commits. Trans 2 waits. Trans 2 reads updated balance ($0). Trans 2 aborts immediately with `400 Bad Request`. The slower user sees: "This balance is already settled." |
| **Partial Payment Settlement** | I owe $100. I type $45. | The modal accepts it. The UI recalculates the new remaining active debt as $55. A new List Item explicitly says "You paid $45 toward $100." |
| **Overpayment Typos** | I owe $10. I aggressively type $1000. | Client-side validation prevents submission, turning button disabled, showing text: "Overpayment." Backend strict validation rejects the request via Fastify schema validation. |
| **Push Notification Failure** | Send push to Payee (Bob) fails (Bob uninstalled app). | Backend worker catches FCM failure silently. Settlement remains fully committed and valid. No rollback. UX is uninterrupted. |
| **Settle All with mixed group debts** | User owes Bob $50 in one group but Bob owes user $20 in another. Net: user owes $30. | The Settle All flow calculates net per-group balances. Only groups where the user owes are included. The UI clearly shows the per-group breakdown before confirmation. |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Tapping "Settle Up" perfectly defaults to exactly the amount owed down to the cent.
- [ ] Optimistic UI immediately reflects the settlement prior to the loading spinner concluding.
- [ ] Attempting to repeatedly tap "Record Payment" via script or latency yields exactly 1 DB record.
- [ ] Firing two conflicting settlement payments from two different devices for the same debt results in exactly 1 successful commit and 1 graceful failure, enforced by PostgreSQL `SELECT ... FOR UPDATE`.
- [ ] Entering a settlement amount greater than the active debt is strictly prohibited by both Flutter client and Fastify backend validation.
- [ ] "Settle All" correctly aggregates balances across all groups with a specific person and creates atomic settlement records per group.
- [ ] "Settle All" transaction is atomic — either all group settlements commit or none do.
