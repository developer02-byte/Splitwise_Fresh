# Story 04: Groups & Ledgers - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide organized, enclosed environments for shared expenses among specific participants ("Trip to Tokyo", "Apartment 101"). Groups act as distinct micro-ledgers, allowing users to isolate their financial relationships (e.g., I owe John $50 from the Tokyo trip, but John owes me $60 for the APARTMENT internet). This isolation ensures clarity and prevents chaotic overall math arguments.

---

## 👥 2. Target Persona & Motivation
- **Group Creators (The Facilitator):** Wants to quickly spin up a container for a weekend trip, dump all 8 friends in, and start tracking every beer and Uber. Needs effortless adding of non-registered members.
- **Group Members (The Participant):** Wants to open "Tokyo Trip", see one big number ("You Owe $450"), and scroll through the historical ledger chronologically to verify they aren't being overcharged.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Group Creation Sequence
1. **Trigger:** User taps "New Group" `FloatingActionButton` or navigation item.
2. **Action - UI Opens:** Full-screen route via `Navigator.push` to Group Creation screen.
3. **Action - Entry:**
   - **Group Name:** User enters "Tokyo 2026".
   - **Cover Photo (Optional):** User uploads or selects an avatar via `ImagePicker`.
4. **Action - Add Members Phase:** User types names or emails or phone numbers.
   - If User "jane@example.com" exists, avatar pops up, added to list.
   - If User "Bob" doesn't exist, created as a "Ghost User" (placeholder for math, tied to creator's account until claimed).
5. **System State - Success:** User hits "Save". App makes API call `POST /api/groups/create`. Navigates straight to the new Group Dashboard.

### B. The Group Dashboard & Ledger Interaction
1. **System State - Load:** Group Dashboard renders. Top half is the `GroupHeroSummary` (Total Group Expenses, My Balance). Bottom half is the `GroupLedgerList`.
2. **Action - Infinite Scroll:** User scrolls down the chronological ledger of 500 Uber rides. As they hit the bottom edge (detected by `ScrollController`), a loader spins, appending the next 25 older expenses seamlessly.
3. **Action - View Details:** User taps a specific $45.00 expense from Tuesday. An `ExpansionTile` expands or a sub-page slides in. Shows exactly: "John paid $45.00. You owe $15.00. Alice owes $15.00. John covered $15.00."

### C. The Simplify Debts Sequence
1. **Trigger:** User taps Settings (Gear icon) -> "Simplify Group Debts" toggle.
2. **System State - Math Engine:** The UI recalculates the current raw graph of debts:
   - Without Simplification: Alice owes Bob $10. Bob owes Charlie $10.
   - With Simplification: Alice owes Charlie $10.
3. **System State - Display:** UI replaces complex lists with a streamlined summary of exactly who needs to pay who, minimizing the number of actual transactions.
4. **System State - Toggle Persistence:** The debt simplification toggle is stored as a per-group setting via `PATCH /api/groups/{id}/settings` with `{ simplify_debts: true/false }`. Each group independently controls this feature.

### D. The Leave Group Flow
1. **Trigger:** User taps Settings -> "Leave Group".
2. **System State - Debt Check:** The system checks if the user has any outstanding debts (owed or owing) within this group.
   - **If debts exist:** A blocking dialog appears: "You have outstanding balances in this group. Please settle all debts before leaving." The leave action is strictly prohibited.
   - **If no debts:** A confirmation dialog appears: "Are you sure you want to leave [Group Name]? You will no longer see this group's expenses."
3. **Action - Confirmation:** User confirms. `POST /api/groups/{id}/leave` is called. User is navigated back to the Groups list. The group disappears from their view.

### E. The Delete Group Flow
1. **Trigger:** Group admin taps Settings -> "Delete Group".
2. **System State - Permission Check:** Only the group creator/admin can see this option.
3. **System State - Debt Check:** The system checks if ANY member has outstanding debts within the group.
   - **If debts exist:** A blocking dialog appears: "This group has unsettled debts. All members must settle up before the group can be deleted."
   - **If no debts:** A destructive confirmation dialog appears (red button): "This will permanently delete [Group Name] and all its expense history. This action cannot be undone."
4. **Action - Confirmation:** Admin confirms. `DELETE /api/groups/{id}` is called. All members are notified via push notification. Group is soft-deleted in the database.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`GroupHeroSummary`**:
  - Background: A gradient mapped to the cover photo or a solid brand color via `BoxDecoration(gradient: ...)`.
  - Profile Avatars: Stacked overlapping `CircleAvatar` widgets using `Stack` with `Positioned(left: -12)` showing max 4 users, plus a `+3` badge via `Container` for remainders.
- **`DebtSimplifierToggle`**: A `Switch` widget toggling the view. `activeColor: Color(0xFF00E676)` when active, with explanatory text "2 transactions hidden".
- **`ExpenseListItemComponent`**:
  - Contains an `Icon` based on category (Food, Travel, General).
  - Main text: Description. Subtext: Date & "Paid by XXX".
  - Right Align: The exact fraction relating to *ME*. If I owe, it's `$15.00` in Red. If I paid, it's `You lent $30.00` in Green.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):

#### 1. `POST /api/groups/create`
- **Controller Logic:**
  - Create group record via `prisma.group.create({ data: { name, createdBy, simplifyDebts: false } })`.
  - Loop through member emails. If found via `prisma.user.findUnique({ where: { email } })`, add to `group_members`. If not, create a placeholder user via `prisma.user.create({ data: { email, isGhost: true } })` and add.
  - Sanitize group name via `sanitize-html` before storage.

#### 2. `GET /api/groups/{id}/ledger?limit=25&offset=50`
- **Controller Logic:**
  - Query via `prisma.expense.findMany({ where: { groupId: id }, orderBy: { createdAt: 'desc' }, take: 25, skip: 50, include: { splits: true } })`.
  - Filter splits for the authenticated user to determine UI color-coding per list item.
- **Response Shape (Nested):**
```json
{
  "group_name": "Tokyo 2026",
  "expenses": [
    {
       "id": 89,
       "title": "Sushi",
       "total_amount": 100.00,
       "my_split": -25.00,
       "paid_by_name": "John"
    }
  ],
  "has_more": true
}
```

#### 3. `PATCH /api/groups/{id}/settings`
- **Request Payload:** `{ simplify_debts: true }`
- **Controller Logic:** Update via `prisma.group.update({ where: { id }, data: { simplifyDebts } })`. Only group members can modify.

#### 4. `POST /api/groups/{id}/leave`
- **Controller Logic:**
  - Check outstanding debts: query splits and settlements for the user within this group. If net balance !== 0, return `403 Forbidden: "Outstanding debts must be settled before leaving."`.
  - Remove via `prisma.groupMember.delete({ where: { groupId_userId: { groupId: id, userId } } })`.

#### 5. `DELETE /api/groups/{id}`
- **Controller Logic:**
  - Verify requester is group admin via `prisma.group.findUnique({ where: { id } })` checking `createdBy`.
  - Check ALL member debts within group. If any net balance !== 0, return `403 Forbidden: "All debts must be settled before deletion."`.
  - Soft-delete via `prisma.group.update({ where: { id }, data: { deletedAt: new Date() } })`.
  - Dispatch push notifications to all members.

### Database Context (PostgreSQL via Prisma):
```sql
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150),
    created_by INT,
    simplify_debts BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE group_members (
    group_id INT,
    user_id INT,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    PRIMARY KEY(group_id, user_id)
);
```

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
| --- | --- | --- |
| **Delete a member with existing Debt** | Admin hits "Remove Bob". UI throws a sharp destructive confirmation alert: "Bob still owes $45.00 to the group. Bob must settle up before removal." Removed from button. | Backend strictly checks aggregated splits for Bob in `groupId`. If net balance !== 0, throws explicit HTTP `403 Forbidden` halting removal. |
| **Massive Ledger Scrolling (Memory Leak)** | Group has 2000 expenses. User scrolling down. | Flutter `ListView.builder` lazily constructs only visible widgets. Widget recycling ensures constant memory usage. 60FPS guaranteed. |
| **Ghost User Claims Account** | Admin added "Jane" placeholder. Jane installs app, uses her phone number to sign up. All past Tokyo expenses instantly bind to her real account. | Backend checks unverified `users` utilizing the phone number via `prisma.user.findFirst({ where: { phone, isGhost: true } })`. Flips `isGhost = false`, merges the JWT logic, preserving historic splits accurately. |
| **The Circular Debt Loop** | A owes B $10. B owes C $10. C owes A $10. | The Debt Simplifier Graph Theory algorithm constantly evaluates connected components. Recognizes the sum absolute zero circle and collapses all three debts entirely, turning 3 settlements into 0. |
| **Leave group with debts** | User tries to leave while owing $20. | UI shows blocking dialog. Backend returns `403`. User must settle all debts first. |
| **Delete group with unsettled debts** | Admin tries to delete group where members still owe each other. | UI shows blocking dialog listing unsettled amounts. Backend returns `403`. All debts must be $0 before deletion is permitted. |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Group balances perfectly isolate from Total Dashboard Balances if viewed in a vacuum.
- [ ] Adding a Ghost/Placeholder member successfully allocates math without requiring them to install the app.
- [ ] Attempting to delete a member who has unresolved debts in the current group strictly fails.
- [ ] The Debt Simplifier Algorithm correctly reduces a 3-way chain (A->B, B->C) into a single optimized payment (A->C).
- [ ] Fetching a ledger with 500 items does not freeze or stutter the UI viewport during the initial load (Pagination proven via `ScrollController`).
- [ ] Debt simplification toggle can be independently enabled/disabled per group and persists across sessions.
- [ ] A user with outstanding debts is strictly blocked from leaving a group until all debts are settled.
- [ ] Only the group admin can delete a group, and only when all debts within the group are fully settled.
- [ ] Group deletion soft-deletes the record and notifies all members via push notification.
