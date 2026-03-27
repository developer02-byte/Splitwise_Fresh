# Story 22: Default Split Settings per Group - Detailed Execution Plan

## 1. Core Objective & Philosophy
Allow groups with a fixed, repeating split arrangement (e.g., rent is always 60/40, utilities always equal) to pre-configure their split preference once, so it auto-applies every time a new expense is created in that group.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Configure Default Split for a Group
1. **Trigger:** Inside a Group, user taps `Settings` gear icon → "Default Split Settings".
2. **UI Opens:** A simplified split adjuster screen for that group's members.
3. **Action:** User configures: Alice `60%`, Bob `40%`. Taps "Save as Default".
4. **Backend:** `PUT /api/groups/{id}/settings` `{ default_split_type: 'percentage', default_splits: [{user_id: 1, percentage: 60}, {user_id: 2, percentage: 40}] }`.

### Fastify Route Example:
```ts
// src/routes/groups.ts
fastify.put('/api/groups/:id/settings', async (request, reply) => {
  const { id } = request.params;
  const { default_split_type, default_splits } = request.body;

  await prisma.$transaction(async (tx) => {
    await tx.group.update({
      where: { id: parseInt(id) },
      data: { default_split_type },
    });

    // Upsert each member's default split
    for (const split of default_splits) {
      await tx.groupDefaultSplit.upsert({
        where: {
          group_id_user_id: { group_id: parseInt(id), user_id: split.user_id },
        },
        update: { percentage: split.percentage, share_count: split.share_count },
        create: {
          group_id: parseInt(id),
          user_id: split.user_id,
          percentage: split.percentage,
          share_count: split.share_count ?? 1,
        },
      });
    }
  });

  return reply.send({ success: true });
});
```

### B. Auto-Apply on New Expense
1. **Trigger:** Any group member opens "Add Expense" inside this group.
2. **System State:** The split adjuster pre-fills to `60/40` automatically.
3. **Action:** User can override per-expense if needed. Default is just a starting point.

---

## 5. Technical Architecture & Database

```sql
ALTER TABLE groups
  ADD COLUMN default_split_type VARCHAR(20) DEFAULT 'equal'
    CHECK (default_split_type IN ('equal', 'percentage', 'shares'));

CREATE TABLE group_default_splits (
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    percentage DECIMAL(5,2) NULL,
    share_count SMALLINT DEFAULT 1,
    PRIMARY KEY(group_id, user_id),
    CONSTRAINT fk_group FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## 7. Final QA Acceptance Criteria
- [ ] Setting a 60/40 default causes every new expense in that group to pre-fill with 60/40.
- [ ] A group member can still override the default split on any individual expense.
- [ ] Adding a new member to a group prompts: "Update default split settings to include new member?"
- [ ] Default split settings are persisted via Prisma and survive app restarts.
