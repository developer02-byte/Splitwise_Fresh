# Story 09: Friends & Individual Ledgers - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
While Groups handle trips, many debts are strictly 1-on-1 (e.g., paying a roommate for utilities outside of a specific event container). The "Friends" tab must exist to consolidate exact, direct individual debts so a user can easily answer: "What do Bob and I owe each other *in total*, across everything?"

---

## 👥 2. Target Persona & Motivation
- **The Roommate:** I don't care about the Tokyo trip group right now. I just want to know how much I owe Alice across all dinners, internet bills, and past settlements.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Friends List
1. **Trigger:** User taps "Friends" on the Bottom Navigation Bar.
2. **Action - UI Opens:** Display the `FriendsListScreen` Flutter widget.
3. **System State - Data Load:** `GET /api/user/friends/balances` loads.
4. **Action - Add Friend:** User taps a `FloatingActionButton` (or top right `+` icon in the `AppBar`). A Flutter `showModalBottomSheet` or `Dialog` prompts them to enter an email or phone number.
5. **System State - Processing:** If the friend is active, they are added to the list. If not, a ghost user is created, and the user can start applying non-group expenses to them immediately.

### B. The 1-on-1 Ledger (Friend Detail View)
1. **Trigger:** User taps "Alice" from the `FriendsListScreen`.
2. **Action - Drilldown:** The app uses `Navigator.push` to route to the `FriendDetailScreen`.
3. **System State - Render:** The top half highlights the Net Total Balance between Me and Alice (e.g., "Alice owes you $20") via a `FriendHeroSummary` widget. The bottom half is a `ListView.builder` with `ScrollController`-driven infinite scrolling of *every single interaction* between me and Alice, whether it occurred inside the "Tokyo Group" or was just a raw 1-on-1 expense.
4. **Action - Settle Up:** A prominent `ElevatedButton` labeled "Settle Up" sits at the top. Tapping it pre-fills exactly $20 to Alice.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`FriendListItem`**: `ListTile` with a leading `CircleAvatar`. Trailing state color text: "Owes you `$X`" (Green `TextStyle`) or "You owe `$X`" (Red `TextStyle`). If settled, grey text "Settled up".
- **`FriendHeroSummary`**: A Flutter `Card` or custom widget showing an interconnected graphic: "You" <--> "$20.00" <--> "Alice".
- **`CrossGroupExpenseItem`**: A ledger row `ListTile` that visually indicates context if it belongs to a group. E.g., `subtitle: Text("Dinner (Tokyo Group)")` in small grey text beneath the main title.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `GET /api/user/friends/balances`
- **Handler Logic:**
  - Performs complex grouping and sums of the `splits` materialized view specifically filtering by the paired `user_id`, aggregating all group contexts, using Prisma parameterized queries.
- **Response:**
  `[{ name: "Alice", id: 22, net_balance: -20.00 }, { name: "Bob", id: 23, net_balance: 145.00 }]`

#### 2. `GET /api/user/friends/{friend_id}/ledger`
- **Handler Logic:**
  - Selects all expenses and settlements that directly involve BOTH the active `user_id` and the `friend_id` using Prisma parameterized queries.

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **No Shared Expenses** | Tapping a friend with $0 balance and no history. Flutter empty-state widget with illustration: "You and Bob are completely settled up. Time to grab a coffee!" | Empty data array handled safely. |
| **Adding a Wrong Email** | User adds a typo email. It's treated as a ghost. The user later realizes it's wrong. | The user can tap into the friend's profile and hit "Remove Friend", which wipes the ghost (if balance is zero). |
