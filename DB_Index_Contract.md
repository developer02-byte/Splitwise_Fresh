# Database Index Contract
> Resolves Architecture Audit Issue: #11 (No DB indexes defined)
> Version: 1.0 | March 26, 2026

---

## OVERVIEW

All indexes defined here are **composite indexes aligned to production query patterns**.
Every index definition includes the SQL declaration and the query it supports.
Indexes are created after all tables exist, before any data migration.

---

## INDEXES BY TABLE

### `users`
```sql
-- Login by email (most frequent auth query)
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- Social login lookup by provider ID
CREATE UNIQUE INDEX idx_users_google_id ON users(google_id) WHERE google_id IS NOT NULL;
CREATE UNIQUE INDEX idx_users_apple_id ON users(apple_id) WHERE apple_id IS NOT NULL;
```
*Supports: login flow, OAuth upsert, ghost-user merge on join*

---

### `sessions`
```sql
-- Session lookup by refresh token hash (on every token refresh)
CREATE UNIQUE INDEX idx_sessions_refresh_token_hash ON sessions(refresh_token_hash);

-- List sessions for a user (Settings → Security → Sessions list)
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- Clean up expired sessions (background job)
CREATE INDEX idx_sessions_last_used_at ON sessions(last_used_at);
```

---

### `groups`
```sql
-- Groups list for a user (via group_members join)
CREATE INDEX idx_groups_created_at ON groups(created_at DESC);
```

---

### `group_members`
```sql
-- All members of a group (Members tab)
CREATE INDEX idx_group_members_group_id ON group_members(group_id);

-- All groups a user belongs to (Dashboard, sidebar group list)
CREATE INDEX idx_group_members_user_id ON group_members(user_id);

-- Membership check (is user X in group Y?)
CREATE UNIQUE INDEX idx_group_members_group_user ON group_members(group_id, user_id);
```

---

### `expenses`
```sql
-- Expense list per group, newest first (Group Detail → Expenses tab)
CREATE INDEX idx_expenses_group_created ON expenses(group_id, created_at DESC) WHERE deleted_at IS NULL;

-- Expense list per user for activity feed
CREATE INDEX idx_expenses_creator_created ON expenses(created_by, created_at DESC) WHERE deleted_at IS NULL;

-- Expense search within a group (full-text title search)
CREATE INDEX idx_expenses_title_trgm ON expenses USING gin(title gin_trgm_ops);

-- Soft-delete retention window query (90-day purge job)
CREATE INDEX idx_expenses_deleted_at ON expenses(deleted_at) WHERE deleted_at IS NOT NULL;

-- Recurring expense template lookup
CREATE INDEX idx_expenses_recurring_template ON expenses(recurring_template_id) WHERE recurring_template_id IS NOT NULL;
```
*Note: `pg_trgm` extension must be enabled for trigram search index.*

---

### `expense_splits`
```sql
-- All splits for one expense (Expense Detail breakdown)
CREATE INDEX idx_splits_expense_id ON expense_splits(expense_id);

-- All splits owed by one user (user's total debt calculation)
CREATE INDEX idx_splits_user_id ON expense_splits(user_id);
```

---

### `settlements`
```sql
-- Settlements within a group, newest first (Balances tab + Activity Feed)
CREATE INDEX idx_settlements_group_created ON settlements(group_id, created_at DESC);

-- Settlements between two users (Friend Ledger)
CREATE INDEX idx_settlements_payer_payee ON settlements(payer_id, payee_id, created_at DESC);

-- Settlements received by a user (notification triggers)
CREATE INDEX idx_settlements_payee_id ON settlements(payee_id, created_at DESC);
```

---

### `balances`
```sql
-- Net balance between two specific users (1-on-1 ledger, most frequent read)
CREATE UNIQUE INDEX idx_balances_user_pair ON balances(user_id, counterpart_id);

-- All balances for one user (Dashboard hero card computation)
CREATE INDEX idx_balances_user_id ON balances(user_id);
```
*Note: Recommend a materialized `balances` table that is recomputed on expense/settlement changes rather than computed on-the-fly from splits. Recomputation should be triggered via Socket.io events, not on every read.*

---

### `notifications`
```sql
-- Notifications for a user, newest first (Notifications Center)
CREATE INDEX idx_notifications_recipient_created ON notifications(recipient_id, created_at DESC);

-- Unread count (bell badge)
CREATE INDEX idx_notifications_unread ON notifications(recipient_id, is_read) WHERE is_read = FALSE;
```

---

### `audit_log`
```sql
-- Audit log per group, newest first (P16 — Audit Log page)
CREATE INDEX idx_audit_log_group_created ON audit_log(group_id, created_at DESC);

-- Audit log filter by actor
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id, created_at DESC);
```

---

### `offline_queue`
```sql
-- Queue drain: all pending items for a user, in creation order (FIFO)
CREATE INDEX idx_queue_user_status_created ON offline_queue(user_id, status, created_at ASC)
  WHERE status IN ('pending', 'failed');

-- Idempotency check (dedup on server)
CREATE UNIQUE INDEX idx_queue_idempotency_key ON offline_queue(idempotency_key);
```

---

### `exchange_rates`
```sql
-- Rate lookup by currency pair (most frequent: balance display)
CREATE UNIQUE INDEX idx_rates_currency_pair ON exchange_rates(from_currency, to_currency);

-- Freshness check (background refresh job)
CREATE INDEX idx_rates_fetched_at ON exchange_rates(fetched_at DESC);
```

---

### `group_invites`
```sql
-- Token verification by group + token hash
CREATE UNIQUE INDEX idx_invites_token_hash ON group_invites(token_hash);

-- List active invites per group (admin management)
CREATE INDEX idx_invites_group_active ON group_invites(group_id, is_revoked, expires_at)
  WHERE is_revoked = FALSE;
```

---

### `comments`
```sql
-- All comments on one expense, oldest first (P15 thread)
CREATE INDEX idx_comments_expense_created ON comments(expense_id, created_at ASC);
```

---

## PRISMA MIGRATION NOTES

1. All indexes should be created in a dedicated migration after the initial schema migration
2. Use `CREATE INDEX CONCURRENTLY` for all indexes on existing data tables to avoid lock contention during migration
3. The `pg_trgm` extension must be enabled before the trigram index: `CREATE EXTENSION IF NOT EXISTS pg_trgm;`
4. The `balances` table should use `ON CONFLICT ... DO UPDATE` (upsert) on every expense/settlement change to maintain pre-computed balances

---

## PERFORMANCE TARGETS

| Query | Target Response Time | Index Used |
|---|---|---|
| Load group expense list (50 items) | < 50ms | `idx_expenses_group_created` |
| Dashboard balance load | < 30ms | `idx_balances_user_id` |
| Notifications center (50 items) | < 40ms | `idx_notifications_recipient_created` |
| Login (email lookup) | < 10ms | `idx_users_email` |
| Token refresh (session lookup) | < 10ms | `idx_sessions_refresh_token_hash` |
| Expense full-text search | < 150ms | `idx_expenses_title_trgm` |
