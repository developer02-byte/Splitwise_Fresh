# Story 35: Audit Trail & Change Log - Detailed Execution Plan

## 1. Core Objective & Philosophy
Track WHO changed WHAT and WHEN for all financial operations. Every expense edit, deletion, and settlement modification must have a permanent, tamper-evident record. The audit log is the legal backbone of the application — if two users disagree about a past change, the audit log is the arbiter of truth. Audit writes never block user-facing operations.

---

## 2. Target Persona & Motivation
- **The Suspicious Roommate:** Wants to verify that the $200 grocery expense was originally $150 before Alice edited it. Needs proof of who changed what.
- **The Group Admin:** Wants to see a full activity log of who joined, who left, and what settings were changed in the group.
- **The GDPR-Conscious User:** Expects that when they delete their account, their personal data in audit logs is anonymized while preserving the financial record integrity.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Viewing Expense Edit History
1. **Trigger:** Alice opens an expense detail screen for "Dinner at Mario's" ($55.00).
2. **Action:** Alice taps the "History" tab at the bottom of the expense detail.
3. **System State:** `GET /api/expenses/{id}/history` fetches all audit log entries where `entity_type = 'expense'` AND `entity_id = {id}`, ordered by `created_at DESC`.
4. **UI Display:** A chronological list of changes:
   - "Bob changed amount from $50.00 to $55.00 — March 15, 2026 at 3:42 PM"
   - "Bob changed description from 'Dinner' to 'Dinner at Mario's' — March 15, 2026 at 3:41 PM"
   - "Alice created this expense — March 14, 2026 at 7:30 PM"
5. **Detail Expansion:** Tapping a change entry expands to show before/after values for all modified fields.

### B. Viewing Group Activity Log
1. **Trigger:** Group admin taps the overflow menu in the group screen and selects "Activity Log".
2. **System State:** `GET /api/groups/{id}/activity` fetches audit entries for the group scope, including member changes, settings changes, and expense-level summaries.
3. **UI Display:**
   - "Alice added Charlie to the group — March 10, 2026"
   - "Bob changed group currency from USD to EUR — March 8, 2026"
   - "Diana left the group — March 5, 2026"

### C. Audit Entry Creation (Behind the Scenes)
1. **Trigger:** Bob edits an expense, changing the amount from $50 to $55.
2. **Service layer:** Before the update, the service reads the current expense state (before_snapshot).
3. **Database update:** Prisma updates the expense record.
4. **Audit dispatch:** After successful update, the service enqueues a BullMQ job:
   ```
   {
     queue: 'audit',
     data: {
       actorId: bob.id,
       action: 'expense.updated',
       entityType: 'expense',
       entityId: expense.id,
       beforeSnapshot: { amount: 5000, description: 'Dinner' },
       afterSnapshot: { amount: 5500, description: "Dinner at Mario's" },
       ipAddress: request.ip,
       userAgent: request.headers['user-agent']
     }
   }
   ```
5. **BullMQ worker:** Processes the job asynchronously, inserting into the `audit_log` table.
6. **User response:** The expense update response is returned to Bob immediately, without waiting for the audit write.

### D. Account Deletion and GDPR Anonymization
1. **Trigger:** Eve requests account deletion from Settings.
2. **System State:** All audit log entries where `actor_id = eve.id` have the actor reference preserved but the display name resolved to "Deleted User" at query time.
3. **Implementation:** The `actor_id` foreign key remains intact. A `users.is_active = false` and `users.name = 'Deleted User'` update handles anonymization. Audit entries are never deleted.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Expense History Tab
- **`ExpenseHistoryTab`**: A `Tab` within the `ExpenseDetailScreen` `TabBarView`.
- **`AuditEntryCard`**: A `Card` widget displaying:
  - Actor avatar (circular, 32px) + actor name.
  - Human-readable change description (e.g., "changed amount from $50.00 to $55.00").
  - Timestamp in relative format ("2 hours ago") with full datetime on tap.
- **`AuditEntryExpandedView`**: An `ExpansionTile` showing full before/after JSON diff for each changed field, formatted as a side-by-side comparison.

### Group Activity Log Screen
- **`GroupActivityLogScreen`**: A `Scaffold` with a `ListView.builder` of activity entries.
- **Filter chips** at top: "All", "Members", "Settings", "Expenses" — filter by `entity_type`.
- **Pull-to-refresh** loads the latest entries.
- **Infinite scroll** with pagination (20 entries per page).

### Change Description Rendering
The UI renders human-readable descriptions from before/after snapshots:
| Field Changed | Display |
| --- | --- |
| `amount` | "changed amount from $50.00 to $55.00" |
| `description` | "changed description from 'Dinner' to 'Dinner at Mario's'" |
| `category` | "changed category from 'food' to 'restaurant'" |
| `split_type` | "changed split type from 'equal' to 'percentage'" |
| (creation) | "created this expense" |
| (soft delete) | "deleted this expense" |

---

## 5. Technical Architecture & Database

### Database Schema
```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    actor_id INT NOT NULL REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(30) NOT NULL,
    entity_id INT NOT NULL,
    before_snapshot JSONB NULL,
    after_snapshot JSONB NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
CREATE INDEX idx_audit_log_action ON audit_log(action);
```

### Prisma Schema
```prisma
model AuditLog {
  id              Int      @id @default(autoincrement())
  actorId         Int      @map("actor_id")
  action          String   @db.VarChar(50)
  entityType      String   @map("entity_type") @db.VarChar(30)
  entityId        Int      @map("entity_id")
  beforeSnapshot  Json?    @map("before_snapshot")
  afterSnapshot   Json?    @map("after_snapshot")
  ipAddress       String?  @map("ip_address") @db.VarChar(45)
  userAgent       String?  @map("user_agent") @db.VarChar(500)
  createdAt       DateTime @default(now()) @map("created_at")

  actor           User     @relation(fields: [actorId], references: [id])

  @@index([entityType, entityId])
  @@index([actorId])
  @@index([createdAt])
  @@map("audit_log")
}
```

### Audited Actions Registry
| Action | Entity Type | Before Snapshot | After Snapshot |
| --- | --- | --- | --- |
| `expense.created` | expense | null | Full expense object |
| `expense.updated` | expense | Previous state | Updated state |
| `expense.deleted` | expense | Full expense object | null |
| `settlement.created` | settlement | null | Full settlement object |
| `settlement.updated` | settlement | Previous state | Updated state |
| `group.settings_updated` | group | Previous settings | Updated settings |
| `group.member_added` | group | null | `{ userId, role }` |
| `group.member_removed` | group | `{ userId, role }` | null |
| `group.member_role_changed` | group | `{ userId, role: 'member' }` | `{ userId, role: 'admin' }` |
| `user.profile_updated` | user | Previous profile fields | Updated profile fields |
| `user.deleted` | user | `{ name, email }` | `{ name: 'Deleted User' }` |

### Backend Implementation

#### Audit Service: `src/services/audit.service.ts`
```typescript
import { auditQueue } from '../queues/audit.queue';

interface AuditPayload {
  actorId: number;
  action: string;
  entityType: string;
  entityId: number;
  beforeSnapshot?: Record<string, unknown> | null;
  afterSnapshot?: Record<string, unknown> | null;
  ipAddress?: string;
  userAgent?: string;
}

export async function logAudit(payload: AuditPayload): Promise<void> {
  await auditQueue.add('write-audit', payload, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 },
    removeOnComplete: 100,
    removeOnFail: 500,
  });
}
```

#### Audit Queue Worker: `src/workers/audit.worker.ts`
```typescript
import { Worker } from 'bullmq';
import { prisma } from '../lib/prisma';

const auditWorker = new Worker('audit', async (job) => {
  const { actorId, action, entityType, entityId, beforeSnapshot, afterSnapshot, ipAddress, userAgent } = job.data;

  await prisma.auditLog.create({
    data: {
      actorId,
      action,
      entityType,
      entityId,
      beforeSnapshot: beforeSnapshot ?? undefined,
      afterSnapshot: afterSnapshot ?? undefined,
      ipAddress,
      userAgent,
    },
  });
}, { connection: redisConnection });
```

#### Usage in Expense Service: `src/services/expense.service.ts`
```typescript
async function updateExpense(expenseId: number, updates: UpdateExpenseDto, actor: RequestContext) {
  // Capture before state
  const before = await prisma.expense.findUniqueOrThrow({
    where: { id: expenseId },
    include: { splits: true },
  });

  // Perform update
  const after = await prisma.expense.update({
    where: { id: expenseId },
    data: updates,
    include: { splits: true },
  });

  // Async audit — does not block response
  await logAudit({
    actorId: actor.userId,
    action: 'expense.updated',
    entityType: 'expense',
    entityId: expenseId,
    beforeSnapshot: sanitizeForAudit(before),
    afterSnapshot: sanitizeForAudit(after),
    ipAddress: actor.ip,
    userAgent: actor.userAgent,
  });

  return after;
}
```

#### Fastify Hook for Request Metadata
```typescript
fastify.addHook('onRequest', async (request) => {
  request.auditContext = {
    ip: request.ip,
    userAgent: request.headers['user-agent'] || 'unknown',
  };
});
```

### API Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/api/expenses/{id}/history` | Fetch audit trail for a specific expense |
| `GET` | `/api/groups/{id}/activity` | Fetch group-scoped activity log |
| `GET` | `/api/audit?entityType=&entityId=&actorId=&from=&to=` | Admin query with filters |

#### Response Format: `GET /api/expenses/{id}/history`
```json
{
  "data": [
    {
      "id": 142,
      "actor": { "id": 2, "name": "Bob Smith", "avatarUrl": null },
      "action": "expense.updated",
      "changes": [
        { "field": "amount", "from": 5000, "to": 5500 },
        { "field": "description", "from": "Dinner", "to": "Dinner at Mario's" }
      ],
      "createdAt": "2026-03-15T15:42:00Z"
    },
    {
      "id": 98,
      "actor": { "id": 1, "name": "Alice Johnson", "avatarUrl": null },
      "action": "expense.created",
      "changes": [],
      "createdAt": "2026-03-14T19:30:00Z"
    }
  ],
  "pagination": { "page": 1, "limit": 20, "total": 2 }
}
```

### Data Retention Policy
- Audit logs are retained for a minimum of **2 years**.
- Audit logs are NEVER deleted, even if the source entity is soft-deleted.
- A scheduled job (monthly) can archive logs older than 2 years to cold storage (compressed JSON files on disk) if table size becomes a concern.
- Partitioning: If the `audit_log` table grows beyond 10 million rows, partition by `created_at` (monthly partitions) using PostgreSQL native partitioning.

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **High-frequency edits** | User rapidly edits an expense 10 times in 1 minute. | Each edit creates a separate audit entry. The BullMQ queue handles burst writes gracefully. No debouncing — every change is significant in a financial app. |
| **Bulk operations** | Admin removes 5 members from a group at once. | Each member removal generates its own audit entry with `group.member_removed` action. Bulk operations are logged individually, not as a single entry. |
| **Audit write fails** | BullMQ worker fails to write to `audit_log` (database connection error). | BullMQ retries 3 times with exponential backoff. After 3 failures, the job moves to the failed queue. Alert fires via monitoring (Story 14). The user operation itself is NOT rolled back. |
| **Large snapshot payloads** | An expense with 20 splits produces a large before/after JSONB payload. | Snapshots include only the changed entity and its direct relations (splits). No deep nesting beyond one level. JSONB storage handles variable sizes efficiently. |
| **Deleted user in audit trail** | Eve deletes her account. Her past audit entries show `actor_id = eve.id`. | Query-time join resolves `actor_id` to `users.name`. Since Eve's name is now "Deleted User", all her past actions display as "Deleted User changed...". |
| **Audit log for failed operations** | User tries to edit an expense but validation fails (negative amount). | No audit entry is created for failed operations. Only successful state changes are logged. The validation error is logged separately in application logs (not audit_log). |
| **Concurrent edits to same entity** | Alice and Bob edit the same expense simultaneously. | Database-level optimistic locking (updatedAt check) prevents lost updates. The second editor gets a conflict error. Only the successful edit is audited. |
| **IP address behind proxy** | User connects through a reverse proxy; `request.ip` shows proxy IP. | Fastify `trustProxy` configuration reads `X-Forwarded-For` header to capture the real client IP. |

---

## 7. Final QA Criteria
- [ ] Creating an expense generates an audit entry with `action = 'expense.created'` and a valid `after_snapshot`.
- [ ] Editing an expense generates an audit entry with both `before_snapshot` and `after_snapshot` reflecting the actual changes.
- [ ] Soft-deleting an expense generates an audit entry with `action = 'expense.deleted'` and a valid `before_snapshot`.
- [ ] Creating a settlement generates an audit entry with `action = 'settlement.created'`.
- [ ] Adding/removing a group member generates the corresponding `group.member_added` or `group.member_removed` audit entry.
- [ ] The expense history tab displays all changes in reverse chronological order with human-readable descriptions.
- [ ] The group activity log displays member changes, settings changes, and expense summaries.
- [ ] Audit writes are asynchronous — the API response time for expense creation is not impacted by audit logging (measured via latency metrics).
- [ ] A deleted user's audit entries display "Deleted User" instead of their real name.
- [ ] Audit log entries older than 2 years are still queryable.
- [ ] No audit entries are created for failed/rejected operations.
- [ ] The `audit_log` table has proper indexes on `(entity_type, entity_id)`, `(actor_id)`, and `(created_at)`.
