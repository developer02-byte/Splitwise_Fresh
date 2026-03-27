# Background Jobs Contract — BullMQ
> Resolves Architecture Audit Issue: #10 (BullMQ no DLQ, no retry policy, no worker scaling)
> Version: 1.0 | March 26, 2026

---

## 1. QUEUE ARCHITECTURE

### Queue Names
| Queue | Purpose |
|---|---|
| `expenses.recurring` | Create recurring expense instances on schedule |
| `notifications.push` | Deliver FCM/APNs push notifications |
| `notifications.email` | Deliver transactional emails (Resend) |
| `notifications.reminders` | Auto-reminder jobs per user |
| `exports.data` | User data export jobs (CSV/JSON) |
| `uploads.images` | Receipt and avatar image processing (resize, thumbnail) |
| `maintenance.purge` | Hard-delete soft-deleted records after 90 days |
| `maintenance.rates` | Fetch and update exchange rates every 6 hours |
| `dlq` | Dead Letter Queue — permanently failed jobs land here |

---

## 2. RETRY POLICY PER JOB TYPE

| Job Type | Max Retries | Backoff Strategy | Backoff Delays | DLQ After Failure |
|---|---|---|---|---|
| `push notification` | 3 | Exponential | 5s, 25s, 125s | Yes |
| `email` | 5 | Exponential | 10s, 60s, 300s, 900s, 1800s | Yes |
| `reminder` | 2 | Fixed | 30s, 30s | Yes |
| `export` | 3 | Exponential | 10s, 60s, 300s | Yes (user notified) |
| `image processing` | 3 | Fixed | 5s, 5s, 5s | Yes |
| `recurring expense` | 3 | Exponential | 60s, 300s, 900s | Yes (admin alert) |
| `purge` | 1 | None | — | Yes |
| `rate fetch` | 3 | Fixed | 300s, 300s, 300s | Yes (amber alert in UI) |

---

## 3. DEAD LETTER QUEUE (DLQ)

**All queues share one DLQ: `dlq`.**

When any job exceeds its `max_retries`, BullMQ moves it to the DLQ automatically (configured via BullMQ's `failedJobsHistoryLength` and a manual `moveToFailed` hook).

### DLQ Job Schema
```json
{
  "original_queue": "notifications.push",
  "original_job_id": "uuid",
  "job_name": "send_push",
  "data": { "...original payload..." },
  "attempts": 3,
  "last_error": "FCM token not registered",
  "failed_at": "ISO-8601",
  "should_alert": true
}
```

### DLQ Handling
- `should_alert: true` jobs → emit alert to monitoring (Sentry + Slack webhook)
- Specific cases with user-facing impact:
  - `export` job in DLQ → emit `notification:new` to user: `"Your data export failed. Please try again."`
  - `push notification` in DLQ with `FCM_TOKEN_UNREGISTERED` error → delete the stale FCM token from user record silently
  - `recurring expense` in DLQ → admin alert only (no user disruption)

---

## 4. WORKER CONFIGURATION

### Worker Scaling Strategy
Workers run as separate Node.js processes (not threads). Scale horizontally by adding worker instances.

| Queue | Initial Workers | Scale Trigger |
|---|---|---|
| `notifications.push` | 2 | Queue depth > 500 |
| `notifications.email` | 1 | Queue depth > 100 |
| `exports.data` | 1 | Queue depth > 5 |
| `uploads.images` | 2 | Queue depth > 20 |
| `maintenance.*` | 1 | No scale (scheduled, low volume) |
| `expenses.recurring` | 1 | No scale (scheduled daily) |

### Concurrency Per Worker
| Queue | Concurrency |
|---|---|
| `notifications.push` | 50 (push is fast) |
| `notifications.email` | 5 (respects Resend rate limits) |
| `exports.data` | 1 (CPU-heavy) |
| `uploads.images` | 3 (IO-heavy) |
| `maintenance.purge` | 1 (DB-heavy) |

---

## 5. JOB DEFINITIONS

### 5.1 Recurring Expense Job
```
Trigger: CRON daily at 00:01 UTC
Action:
  1. SELECT all recurring templates where next_due_date <= TODAY
  2. For each template: create a new expense record (copy of template)
  3. Update next_due_date on template (add interval)
  4. Emit expense:created socket event to group room
  5. If template.end_date is set and next_due_date > end_date: mark template as completed
```

### 5.2 Auto-Reminder Job
```
Trigger: User configures frequency in Settings → BullMQ repeatable job set with user's cron
Job data: { userId, frequency: "weekly" | "every_3_days" | "every_2_weeks" }
Action:
  1. Fetch all outstanding balances for userId where balance > 0 AND balance_age > 24h
  2. For each creditor: check last_reminded_at < NOW() - 3 days (per-contact cooldown)
  3. Eligible creditors: enqueue push notification + email reminder
  4. Update last_reminded_at for reminded contacts
```

### 5.3 Exchange Rate Fetch Job
```
Trigger: CRON every 6 hours
Action:
  1. Call Fixer.io (or Open Exchange Rates) for all active currency pairs
  2. UPSERT into exchange_rates table
  3. Invalidate Redis cache for all rate pairs
  4. If API fails: retry per policy; on DLQ: log to Sentry; keep existing rates (no UI break)
```

### 5.4 Soft-Delete Purge Job
```
Trigger: CRON daily at 03:00 UTC (low-traffic window)
Action:
  1. DELETE FROM expenses WHERE deleted_at < NOW() - INTERVAL '90 days'
  2. Cascade deletes: expense_splits, comments, receipts, audit_log entries
     (receipts: also delete from S3/R2 via signed delete)
  3. Log purge count to monitoring
```

### 5.5 Push Notification Delivery
```
Job data: { userId, title, body, deep_link, reference_id, reference_type }
Action:
  1. Fetch FCM token(s) and APNs token from user record (user may have multiple devices)
  2. Batch up to 50 notifications for same user within 5-second window (batching)
  3. Send via Firebase Admin SDK (Android/Web) and APNs (iOS)
  4. On error "TOKEN_NOT_REGISTERED": delete stale token from user record
  5. On success: mark notification record as push_sent = true
```

---

## 6. JOB MONITORING

- **BullBoard** (open-source BullMQ UI) deployed on `/admin/queues` (access-restricted to admins)
- Sentry `captureException` on every DLQ job with `should_alert: true`
- Slack webhook alert for DLQ jobs in critical queues (`exports.data`, `expenses.recurring`)
- Metrics exposed via Fastify Prometheus endpoint (`/metrics`):
  - `bullmq_queue_depth{queue}` — jobs waiting
  - `bullmq_processed_total{queue,status}` — completed vs. failed
  - `bullmq_job_duration_seconds{queue}` — processing latency
