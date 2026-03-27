# API Contract
> Resolves: API Versioning, Currency Precision, Exchange Rate Storage, File Upload Security, Invite Token, Export Progress, Offline Queue Schema, Conflict Resolution
> Version: 1.0 | March 26, 2026

---

## 1. API VERSIONING

All API routes are prefixed with `/api/v1/`.

**Rule:** Breaking changes to a response shape require a new version (`/api/v2/`). Non-breaking additions (new optional fields) may be added to the existing version.

**Flutter app behavior:** The Dio base URL is set to `/api/v1` as a constant. Version upgrades are handled via app releases + the force-update mechanism.

---

## 2. MULTI-CURRENCY PRECISION — ISO 4217 MINOR UNITS

Storing all currencies as "cents" (×100) is incorrect. The correct approach uses ISO 4217 `minor_unit` per currency.

### Storage Rule
All monetary amounts are stored as **integers in the smallest unit of the currency**, using the ISO 4217 `exponent` (minor unit factor).

| Currency | Code | Minor Unit | Example |
|---|---|---|---|
| US Dollar | USD | 2 | $12.50 → `1250` |
| Euro | EUR | 2 | €10.00 → `1000` |
| Japanese Yen | JPY | 0 | ¥500 → `500` |
| Kuwaiti Dinar | KWD | 3 | KD 1.000 → `1000` |
| Bahraini Dinar | BHD | 3 | BD 1.000 → `1000` |
| Swiss Franc | CHF | 2 | CHF 9.50 → `950` |
| British Pound | GBP | 2 | £20.00 → `2000` |

### Database: Currency Reference Table
```sql
CREATE TABLE currencies (
  code        CHAR(3) PRIMARY KEY,  -- ISO 4217 (USD, JPY, KWD)
  name        TEXT NOT NULL,         -- "US Dollar"
  symbol      TEXT NOT NULL,         -- "$"
  minor_unit  SMALLINT NOT NULL,     -- 0, 2, or 3
  is_active   BOOLEAN DEFAULT TRUE
);
```

### Display Layer Conversion
```
display_amount = stored_integer / (10 ^ currency.minor_unit)

USD 1250  →  1250 / 10^2  =  $12.50
JPY 500   →  500  / 10^0  =  ¥500
KWD 1000  →  1000 / 10^3  =  KD 1.000
```

The Flutter formatting layer always fetches `minor_unit` from the currencies table (cached in-app) and uses `NumberFormat.currency()` with the correct decimal places.

---

## 3. EXCHANGE RATE STORAGE

### Storage Location
Exchange rates are stored in **PostgreSQL** (not Redis-only) as the source of truth, with Redis as a cache layer.

```sql
CREATE TABLE exchange_rates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_currency CHAR(3) NOT NULL REFERENCES currencies(code),
  to_currency   CHAR(3) NOT NULL REFERENCES currencies(code),
  rate          NUMERIC(18, 8) NOT NULL,  -- NEVER store as FLOAT
  fetched_at    TIMESTAMPTZ NOT NULL,
  source        TEXT NOT NULL DEFAULT 'fixer.io',
  UNIQUE(from_currency, to_currency)
);
```

### Per-Expense Rate Snapshot
Each expense stores the rate at time of creation (immutable):
```sql
ALTER TABLE expenses ADD COLUMN rate_snapshot JSONB;
-- Example: { "from": "EUR", "to": "USD", "rate": 1.08432, "fetched_at": "2026-03-25T10:00:00Z" }
```

### Freshness Logic
- BullMQ job fetches rates every **6 hours** and upserts into `exchange_rates` table
- Redis caches the current rates with TTL = 6 hours (key: `rates:{from}:{to}`)
- On cache miss: read from PostgreSQL → rehydrate Redis
- If Redis is DOWN: fall back directly to PostgreSQL (no API failure)
- `fetched_at` from PostgreSQL is what drives the "Rates last updated X hours ago" UI label

### API Response — Rates Freshness Field
All balance endpoints that involve multi-currency must include:
```json
{
  "balances": [...],
  "rates_fetched_at": "2026-03-26T04:00:00Z",
  "rates_stale": false
}
```
`rates_stale: true` when `NOW() - rates_fetched_at > 6 hours`. Flutter reads this field to show the amber "Rates may be outdated" indicator.

---

## 4. GROUP INVITE TOKEN

### Token Format
Invite tokens are **signed JWTs** (HS256, separate signing secret from auth tokens):

```json
{
  "type": "group_invite",
  "group_id": "uuid",
  "created_by": "user-uuid",
  "token_id": "uuid",     // stored in DB for revocation check
  "iat": 1711449600,
  "exp": 1713254400       // 21 days expiry
}
```

### Database Table
```sql
CREATE TABLE group_invites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  created_by  UUID NOT NULL REFERENCES users(id),
  token_hash  TEXT NOT NULL,         -- SHA-256 of the full JWT
  is_revoked  BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  expires_at  TIMESTAMPTZ NOT NULL,
  use_count   INTEGER DEFAULT 0,
  max_uses    INTEGER DEFAULT NULL   -- NULL = unlimited
);
```

### Verification Flow
```
POST /api/v1/groups/:groupId/invites/verify
Body: { "token": "<JWT>" }

Server:
  1. Verify JWT signature (HS256 invite secret)
  2. Check token not expired (JWT exp)
  3. Compute SHA-256 of token → lookup in group_invites table
  4. Check is_revoked = false
  5. Check use_count < max_uses (if max_uses is set)
  6. Return group preview or error
```

### Revocation
```
DELETE /api/v1/groups/:groupId/invites/:inviteId
→ Sets is_revoked = true in DB
→ Future verification calls with this token return 410 Gone
```

### Rate Limit on Generation
- Max 5 active invite tokens per group at any time
- Max 10 invite token generation requests per hour per group admin

---

## 5. FILE UPLOAD SECURITY

### Allowed Types
```
Avatar images:    image/jpeg, image/png, image/webp
Receipt images:   image/jpeg, image/png, image/webp, image/heic, application/pdf
```
MIME type is validated **server-side** by reading the file magic bytes — not from the `Content-Type` header (which can be spoofed).

### Size Limits
| File Type | Max Size |
|---|---|
| Avatar | 5 MB |
| Receipt image | 20 MB |
| Receipt PDF | 20 MB |

### Upload Flow
```
1. Client → POST /api/v1/uploads/presigned-url
   Body: { "file_type": "receipt", "mime_type": "image/jpeg", "file_size": 2048000 }
   
2. Server validates: mime_type allowed? file_size ≤ limit?
   → Returns: { "upload_url": "<S3 presigned PUT URL>", "file_key": "receipts/uuid.jpg", "expires_in": 300 }

3. Client → PUT {upload_url}  (direct to S3/R2, server not involved)

4. Client → POST /api/v1/expenses/:id/receipt
   Body: { "file_key": "receipts/uuid.jpg" }
   → Server records the file_key on the expense, triggers thumbnail generation job
```

### Signed URL TTL for Access
| Context | TTL |
|---|---|
| Receipt thumbnail (in list) | **1 hour** (cached per list load) |
| Full-size receipt (Expense Detail) | **15 minutes** (on-demand) |
| Avatar | **24 hours** (infrequently changes) |

### Image Processing Pipeline (BullMQ Job)

On receipt upload confirmation:
1. Download from S3 to worker memory
2. Use Sharp (Node.js) to generate:
   - Thumbnail: 150×150px WebP (for expense list rows)
   - Medium: 800px width WebP (for Expense Detail full view)
3. Upload both variants back to S3 with `_thumb` and `_medium` suffixes
4. Update expense record with `receipt_thumb_key` and `receipt_medium_key`

---

## 6. OFFLINE QUEUE — COMPLETE SCHEMA

Resolved from audit gap — missing fields added:

```sql
CREATE TABLE offline_queue (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  idempotency_key UUID NOT NULL UNIQUE,   -- matches server-side idempotency check
  action_type     TEXT NOT NULL,           -- 'expense:create' | 'expense:update' | 'expense:delete' | 'settlement:create' | 'comment:create'
  endpoint        TEXT NOT NULL,           -- '/api/v1/expenses'
  http_method     TEXT NOT NULL,           -- 'POST' | 'PUT' | 'DELETE'
  payload         JSONB NOT NULL,
  dependency_ids  UUID[] DEFAULT '{}',     -- IDs of queue items this item depends on
  status          TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'processing' | 'failed' | 'succeeded'
  retry_count     SMALLINT DEFAULT 0,
  max_retries     SMALLINT DEFAULT 3,
  error_message   TEXT,                    -- populated on failure, shown in S03
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  last_attempted_at TIMESTAMPTZ
);
```

### Dependency Resolution
Before dispatching `item B`, check if all `item B.dependency_ids` have `status = 'succeeded'`.
If any dependency is `failed`: automatically fail `item B` too with `error_message = "Dependency failed: {dependency_id}"`.

### Status Transitions
```
pending → processing (on drain attempt)
processing → succeeded (200/201 from server)
processing → failed (4xx/5xx after max_retries exceeded)
failed → processing (manual Retry from S03)
failed → [deleted] (manual Discard from S03, with confirmation)
```

### Max Retry Policy
- Default: 3 automated retries with exponential backoff (1s, 4s, 16s)
- After 3 failures: status becomes `failed`, banner FS04 shown
- Manual Retry from S03 resets `retry_count` to 0

---

## 7. EXPORT PROGRESS MECHANISM

### Strategy: Background Job + Polling

**Rationale:** HTTP chunked transfer does not expose a reliable progress percentage. SSE adds complexity. Polling a status endpoint is simple, predictable, and stateless.

```
1. POST /api/v1/exports
   Body: { "format": "csv", "date_range": "all" }
   Response: { "export_id": "uuid", "status": "queued" }

2. Client polls: GET /api/v1/exports/:exportId/status  (every 2 seconds)
   Response: { "status": "queued|processing|complete|failed", "progress": 0-100, "download_url": null }

3. When status = "complete":
   Response includes: { "download_url": "<signed S3 URL, TTL 30 mins>" }
   Client shows "✓ Download Ready" button → triggers file download

4. When status = "failed":
   Client shows inline error, clears polling interval
```

### Background Job Notification (Large Exports)
If user dismisses the modal:
- Polling stops
- BullMQ job continues in background
- On completion: emits `notification:new` via Socket.io + sends push notification with download link

---

## 8. CONFLICT RESOLUTION POLICY (ALL MUTATIONS)

Extends Fix #18 (expense conflict) to all entity types:

| Entity | Strategy | Notification |
|---|---|---|
| Expense edit | Last-write-wins | Loser notified via in-app notification |
| Group settings | Last-write-wins | Toast to all current members in group room |
| Profile edit | Last-write-wins | Silent (1-user resource, unlikely conflict) |
| Group membership | First-write-wins (join) | Socket event to group room |
| Settlement | Idempotency key prevents duplicates | — |
| Comment | Append-only — no conflict possible | — |

**Implementation:** Prisma optimistic concurrency — add `updated_at` to all mutable tables. On update:
```sql
UPDATE expenses
SET ...updated fields...
WHERE id = $1 AND updated_at = $2_client_value;
-- If 0 rows affected → conflict detected → return 409 Conflict
```
Server returns `409 Conflict` → triggers conflict notification for the losing client.

---

## 9. API RATE LIMITING (ALL ENDPOINTS)

Beyond auth endpoints (defined in Auth_Contract):

| Endpoint Group | Limit | Window |
|---|---|---|
| All API endpoints (global) | 300 requests | 1 minute per user |
| `POST /api/v1/expenses` | 30 requests | 1 minute |
| `POST /api/v1/settlements` | 20 requests | 1 minute |
| `POST /api/v1/groups/:id/invites` | 10 requests | 1 hour |
| `POST /api/v1/exports` | 2 requests | 1 hour |
| `POST /api/v1/uploads/presigned-url` | 20 requests | 1 minute |

On `429`: response includes `Retry-After` header. Flutter reads this value and surfaces it contextually (not just a generic error).
