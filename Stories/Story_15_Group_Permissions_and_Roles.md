# Story 38: Group Permissions & Roles - Detailed Execution Plan

## 1. Core Objective & Philosophy
Define who can do what within a group. Prevent chaos — not every member should be able to delete expenses or remove other members. The permission system must be simple (two roles for v1), enforceable on the backend (never trust the client), and clearly communicated in the UI so users never wonder why a button is missing.

---

## 2. Target Persona & Motivation
- **The Group Admin (Creator):** Created the group, invited everyone. Expects full control — editing group settings, removing members who left the trip, deleting duplicate expenses anyone added by mistake.
- **The Regular Member:** Joined the group via invite. Needs to add expenses, settle debts, and comment. Does NOT expect to delete other people's expenses or kick members out. Would be confused (and alarmed) if they could.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Group Creation & Admin Assignment
1. **Trigger:** User creates a new group via the "Create Group" flow (Story 04).
2. **System State:** The creator is automatically assigned `role = 'admin'` in the `group_members` table. All invited members receive `role = 'member'`.
3. **UI Feedback:** The creator sees a small shield/crown badge next to their own name in the member list, confirming their admin status.

### B. Admin Managing the Group
1. **Action — Edit Group Settings:** Admin taps the group settings gear icon. They can change group name, default currency, default split method, and group image.
2. **Action — Remove a Member:** Admin opens the member list, long-presses or swipes on a member, and taps "Remove". Confirmation dialog: "Remove Alice from this group? Her existing expenses will remain." System checks Alice's balance — if non-zero, a warning is shown: "Alice has an outstanding balance of $12.50. Removing her will not erase this debt."
3. **Action — Delete an Expense (Others'):** Admin sees a "Delete" option on any expense in the group, not just their own. Confirmation required.
4. **Action — Edit an Expense (Others'):** Admin sees an "Edit" pencil icon on any expense. Useful for correcting mistakes.
5. **Action — Transfer Admin:** Admin navigates to group settings > "Transfer Admin Role". Selects a member from the list. Confirmation: "Transfer admin to Bob? You will become a regular member." After confirmation, admin's role flips to `member`, Bob's role flips to `admin`. Both receive a notification.
6. **Action — Delete Group:** Admin taps "Delete Group" in settings. System checks: are all balances within the group settled (all $0.00)? If yes, confirmation dialog and soft-delete proceeds. If no, error: "Cannot delete group — outstanding balances exist. Settle all debts first."

### C. Member Experience
1. **Action — Add Expense:** Member taps FAB, adds expense normally. No restrictions.
2. **Action — Edit Own Expense:** Member sees "Edit" icon on their own expenses only. Can modify description, amount, splits.
3. **Action — Attempt to Edit Others' Expense:** No "Edit" button is rendered. If the member somehow calls the API directly, they receive `403 Forbidden`.
4. **Action — Delete Own Expense:** Member sees "Delete" on their own expenses. Confirmation required.
5. **Action — Attempt to Remove a Member:** The member list does not show "Remove" buttons for other members. Only the admin sees those controls.
6. **Action — Leave Group:** Member taps "Leave Group" in the group menu. System checks their balance: if $0.00, they are removed. If non-zero, error: "You have an outstanding balance of $8.25. Settle your debts before leaving."

### D. Admin Leaving the Group
1. **Trigger:** Admin taps "Leave Group".
2. **System Check:** Admin cannot leave without first transferring admin to another member.
3. **UI Feedback:** Dialog: "You are the group admin. Transfer admin to another member before leaving." Button: "Transfer Admin" (navigates to transfer flow).

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`MemberListTile`**:
  - Renders each group member with `CircleAvatar`, display name, and balance.
  - Admin badge: A small `Icon(Icons.shield, size: 16, color: Colors.amber)` rendered to the right of the admin's name.
  - For admins viewing the list: a trailing `IconButton(Icons.more_vert)` on each non-admin member, opening a bottom sheet with "Remove Member" option.
  - For members viewing the list: no trailing action buttons on other members.

- **`RoleBadge`**:
  - Widget: `Container` with `BorderRadius.circular(4)`, background `Colors.amber.shade100`, text "Admin" in `TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w600)`.
  - Displayed next to admin's name in member list and group header.

- **`TransferAdminSheet`**:
  - Full-screen modal bottom sheet listing all non-admin members.
  - Each row: `CircleAvatar` + Name + "Select" radio button.
  - Bottom: "Confirm Transfer" button. Disabled until a member is selected.
  - Confirmation dialog before executing transfer.

- **`PermissionGatedButton`**:
  - Wrapper widget that accepts `requiredRole` and `currentUserRole`.
  - If `currentUserRole` does not meet `requiredRole`, the child widget is either hidden (`Visibility.gone`) or rendered as disabled with reduced opacity.

### Permission-Based UI Rendering:
| UI Element | Admin Sees | Member Sees |
|------------|-----------|-------------|
| Edit Group Settings button | Visible, enabled | Hidden |
| Delete Group button | Visible, enabled | Hidden |
| Remove Member button (on other members) | Visible, enabled | Hidden |
| Edit button on others' expenses | Visible, enabled | Hidden |
| Delete button on others' expenses | Visible, enabled | Hidden |
| Edit button on own expenses | Visible, enabled | Visible, enabled |
| Delete button on own expenses | Visible, enabled | Visible, enabled |
| Transfer Admin option | Visible in settings | Hidden |
| Leave Group option | Visible (blocked until transfer) | Visible (blocked if balance != 0) |

---

## 5. Technical Architecture & Database

### Permission Matrix (Enforced Server-Side):

| Action | Admin | Member |
|--------|-------|--------|
| Add expense | Yes | Yes |
| Edit own expense | Yes | Yes |
| Edit others' expense | Yes | No |
| Delete own expense | Yes | Yes |
| Delete others' expense | Yes | No |
| Settle up | Yes | Yes |
| Add comment | Yes | Yes |
| Invite members | Yes | Yes |
| Remove members | Yes | No |
| Edit group settings | Yes | No |
| Change default split | Yes | No |
| Delete group | Yes (all debts settled) | No |
| Transfer admin | Yes | No |

### Database Schema Changes (PostgreSQL via Prisma):
```sql
-- Add role column to group_members table
ALTER TABLE group_members
  ADD COLUMN role TEXT NOT NULL DEFAULT 'member'
  CHECK(role IN ('admin', 'member'));

-- Set group creator as admin (migration for existing data)
UPDATE group_members gm
SET role = 'admin'
FROM groups g
WHERE gm.group_id = g.id AND gm.user_id = g.created_by;
```

### Prisma Schema Update:
```prisma
model GroupMember {
  id        Int      @id @default(autoincrement())
  groupId   Int      @map("group_id")
  userId    Int      @map("user_id")
  role      String   @default("member") // 'admin' | 'member'
  joinedAt  DateTime @default(now()) @map("joined_at")

  group     Group    @relation(fields: [groupId], references: [id])
  user      User     @relation(fields: [userId], references: [id])

  @@unique([groupId, userId])
  @@map("group_members")
}
```

### Backend Endpoints (Node.js Fastify):

#### 1. `PUT /api/groups/:groupId/members/:userId/role`
- **Purpose:** Transfer admin role.
- **Auth:** Requires current user to be admin of the group.
- **Request Payload:**
```json
{
  "role": "admin"
}
```
- **Controller Logic:**
  - Verify requester is admin via `preHandler` hook.
  - Open Prisma transaction: set target user's role to `admin`, set current admin's role to `member`.
  - Emit Socket.io event `group:role_changed` to all group members.
  - Send push notification to the new admin: "You are now the admin of [Group Name]".
- **Response:** `200 OK` with updated member list.

#### 2. `DELETE /api/groups/:groupId/members/:userId`
- **Purpose:** Remove a member from the group.
- **Auth:** Requires admin role.
- **Controller Logic:**
  - Verify requester is admin.
  - Prevent admin from removing themselves (use "Leave Group" or "Transfer Admin" instead).
  - Remove the `group_members` record.
  - Emit Socket.io event `group:member_removed`.
  - Send notification to removed member.
- **Response:** `200 OK`.

#### 3. `POST /api/groups/:groupId/leave`
- **Purpose:** Member voluntarily leaves the group.
- **Auth:** Any group member.
- **Controller Logic:**
  - Check if user is admin. If yes, reject with `400: "Transfer admin role before leaving the group"`.
  - Check user's balance in the group. If non-zero, reject with `400: "Settle your outstanding balance before leaving"`.
  - Remove the `group_members` record.
  - Emit Socket.io event `group:member_left`.
- **Response:** `200 OK`.

### Fastify preHandler Hook for Permission Enforcement:
```typescript
// Permission check hook factory
function requireGroupRole(requiredRole: 'admin' | 'member') {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const { groupId } = request.params as { groupId: number };
    const userId = request.user.id;

    const membership = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId } },
    });

    if (!membership) {
      return reply.status(403).send({ error: 'You are not a member of this group' });
    }

    if (requiredRole === 'admin' && membership.role !== 'admin') {
      return reply.status(403).send({ error: 'Only group admins can perform this action' });
    }

    request.groupMembership = membership;
  };
}

// Usage in route registration
fastify.delete('/api/groups/:groupId/members/:userId', {
  preHandler: [authenticate, requireGroupRole('admin')],
}, removeMemberHandler);

fastify.put('/api/groups/:groupId/settings', {
  preHandler: [authenticate, requireGroupRole('admin')],
}, updateGroupSettingsHandler);
```

### Flutter State Management:
```dart
// Permission helper in group state
class GroupPermissions {
  final String currentUserRole;

  GroupPermissions(this.currentUserRole);

  bool get isAdmin => currentUserRole == 'admin';
  bool get canEditGroupSettings => isAdmin;
  bool get canRemoveMembers => isAdmin;
  bool get canDeleteOthersExpense => isAdmin;
  bool get canEditOthersExpense => isAdmin;
  bool get canTransferAdmin => isAdmin;
  bool get canDeleteGroup => isAdmin;
}
```

### Real-Time Updates (Socket.io):
- `group:role_changed` — emitted when admin is transferred. All clients update their local permission state.
- `group:member_removed` — emitted when a member is removed. Removed member's client navigates away from group.
- `group:member_left` — emitted when a member leaves voluntarily.

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
|---|---|---|
| **Last admin tries to leave** | Dialog: "You are the only admin. Transfer admin to another member before leaving." | Backend rejects with `400`. Frontend prevents the action proactively. |
| **Admin deletes their account** | System auto-transfers admin to the longest-standing member. If no other members, group is soft-deleted. | Account deletion handler checks for admin memberships and cascades transfers before proceeding. |
| **Concurrent admin transfer** | Two admins try to transfer at the same time (race condition). Only the first transaction commits. | Prisma transaction with row-level locking. Second request fails with `409 Conflict`. |
| **Member calls admin API directly** | `403 Forbidden` response with message: "Only group admins can perform this action." | `preHandler` hook enforces role check before any controller logic executes. |
| **Admin removes member with non-zero balance** | Warning shown but removal proceeds. Balance remains as a debt owed. | The removed member's balance entries remain in the database. They can still see the debt in their personal ledger. |
| **Group has only one member (the admin)** | Admin can delete the group directly (no debts possible). | Backend skips balance check when group has a single member. |
| **Admin demoted during active session** | Real-time Socket.io event triggers UI refresh. Admin-only buttons disappear immediately. | Client listens for `group:role_changed` and re-fetches membership state. |

---

## 7. Final QA Acceptance Criteria
- [ ] Group creator is automatically assigned admin role upon group creation.
- [ ] Admin badge (shield/crown icon) appears next to the admin's name in the member list.
- [ ] Admin can edit and delete any member's expense within the group.
- [ ] Regular member can only edit and delete their own expenses.
- [ ] Regular member does NOT see "Remove", "Edit Group Settings", or "Delete Group" buttons.
- [ ] Admin can transfer admin role to another member; original admin becomes a regular member.
- [ ] After admin transfer, UI updates in real-time for all group members via Socket.io.
- [ ] Member with $0 balance can leave the group successfully.
- [ ] Member with non-zero balance is blocked from leaving with a clear error message.
- [ ] Admin is blocked from leaving without transferring admin first.
- [ ] Direct API calls from non-admin members to admin-only endpoints return `403 Forbidden`.
- [ ] Group deletion is blocked if any outstanding balances exist within the group.
- [ ] All permission checks are enforced server-side, not just in the UI.
