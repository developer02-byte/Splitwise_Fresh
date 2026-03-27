# Complete Execution Plan — Production-Ready Expense Management System
> **Version:** 3.0 | **Updated:** March 25, 2026
> **Goal:** Build a Splitwise-grade, production-ready expense management application with such depth, structure, and quality that no foundational rework is required later. Every screen, button, API, and database decision is pre-defined.

---

## 1. Product Definition

| Attribute | Definition |
|---|---|
| **Core Purpose** | Transparent tracking, complex splitting, and rapid settlement of shared expenses |
| **Target Users** | Roommates, travel groups, couples, and individuals sharing recurring bills |
| **Success Outcome 1** | Absolute clarity on *who owes whom* and *how much* |
| **Success Outcome 2** | 1-tap settlement with guaranteed mathematical accuracy |
| **Success Outcome 3** | Zero data loss under network failure, concurrent usage, or high load |

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (Web + iOS + Android) — strictly Clean Architecture |
| **State Management** | Riverpod (Code Generation via `@riverpod`) |
| **Data Models** | Freezed (`@freezed`) + JSON Serializable |
| **HTTP Client** | Dio |
| **Routing** | go_router |
| **Backend** | Node.js with Fastify |
| **ORM** | Prisma |
| **Database** | PostgreSQL |
| **Real-time** | Socket.io |
| **Background Jobs** | BullMQ + Redis |
| **Auth** | JWT in HttpOnly cookies |
| **Hosting Path** | Local + Cloudflare Tunnel -> Hetzner VPS -> Hetzner Load Balancer |
| **Deployment** | Docker-based |

---

## 3. Thinking Framework (Non-Negotiable)

- **Start with user intent** — every screen answers one question
- **Design flow before UI** — navigation must be logical before widgets are built
- **Build system, not screens** — every UI element is a reusable widget
- **Optimize for clarity, speed, consistency** — the user must never be confused
- **Secure first** — financial data demands security-first architecture

---

## 4. Complete Feature Architecture (42 Stories — Zero Gaps)

### Authentication & Security (Stories 01, 06, 15, 26)
- Signup / Login / Logout
- Social Login (Google OAuth + Apple Sign-In)
- **Auth model:** Hybrid — signup required but frictionless via Google/Apple one-tap
- **Deep link invites:** tap link -> one-tap signup -> land in group
- Forgot Password / Reset Password (secure tokens, 30-min expiry)
- JWT in `HttpOnly` cookies (never `localStorage`)
- CSRF token validation on all mutating requests
- Rate limiting & brute-force protection (10 req/min)
- SQL Injection prevention (Prisma parameterized queries only)
- XSS prevention (helmet + DOMPurify + CSP headers)
- Session expiry with soft redirect to `/login`

### Dashboard & Balances (Story 02)
- Total Balance hero display (color-coded: Green = owed, Red = owe)
- "You Owe" and "You Are Owed" summary cards
- Recent activity preview (skeleton loaders, <200ms TTI)
- Quick FAB actions: "Add Expense" + "Settle Up"
- Empty state handling for brand new users

### Expense Management (Stories 03, 08, 20)
- Add Expense (Description, Amount, Date, Category, Payer)
- Edit Expense (pre-filled, dirty-tracking, unauthorized edit blocked)
- Delete Expense (cascading DB deletes, destructive confirmation)
- **5 Split Modes:**
  - Equal (with modulo penny-rounding)
  - Exact Amounts
  - Percentage
  - Shares (weighted: Bob drank 3 beers, Alice 1)
  - Adjustment (equal base + per-person delta, must net to zero)
- Multiple Payer support (Alice paid $60, Bob paid $40 on same bill)
- Real-time split preview (synchronous Dart math, no server latency)
- Duplicate click prevention (idempotency UUID key)
- Offline fallback queue (SQLite auto-retry on reconnect)

### Groups & Ledgers (Story 04)
- Create group (name, cover photo, group type: Trip/Home/Couple/Other)
- Add/Remove members (with ghost/placeholder user support)
- Group expense tracking with per-member balance summaries
- Prevent member removal if active debts exist
- Debt Simplification Algorithm (Graph Theory — minimizes total P2P transactions)
- Default Split Settings per group (Story 22)
- Virtual scrolling for groups with 1,000+ expenses

### Settlements & Payments (Story 05)
- Settle Up (full or partial payment)
- Optimistic UI (balance shifts instantly before server confirmation)
- Rollback on API failure (balance reverts with error toast)
- Simultaneous settlement protection (DB pessimistic `SELECT FOR UPDATE` locking)
- Payment tracking history
- Confirmation modal before every commit

### Activity & History (Story 07)
- Global unified feed (expenses + settlements merged, chronological)
- Filter pills: By Date, By Group, By Friend
- Infinite scrolling with Flutter scroll controller (cursor-based pagination)
- Deep link tap: Activity item -> Expense Details
- Expense Detail screen shows full participant math breakdown

### Friends & 1-on-1 Ledgers (Story 09)
- Friends tab with color-coded net balance per friend
- Add Friend (email or phone — creates ghost user if unregistered)
- 1-on-1 Ledger (cross-group aggregated debts between two people)
- Direct expense logging (outside any group)

### Profile & Settings (Story 10)
- Edit Profile (name, avatar, default currency)
- Change Password (validates current password first)
- Appearance toggle (Dark / Light Mode — Story 23)
- Logout (wipes tokens, clears state)
- Delete Account (blocked if active debt > $0, requires typing "DELETE")

### Notifications System (Story 11)
- Real-time push via FCM (Android/Web) + APNs (iOS)
- In-app notification center (bell icon with unread badge)
- Deep-link routing (tap notification -> relevant expense/settlement)
- Notification debouncing (50 actions batched into 1 push)
- Comment notifications (Story 21)

### Offline & Sync Resilience (Story 13)
- Offline expense entry (stores to SQLite `action_queue`)
- Auto-retry queue on connectivity restored
- Multi-device sync via Socket.io
- Last-write-wins conflict resolution with notification of conflict

### Observability & Monitoring (Story 14)
- Sentry frontend error capture (stack trace, device info, PII-redacted)
- Global Error Boundaries (no white screens of death)
- Backend request logging (method, path, status, `duration_ms`)
- Structured log format (JSON with `trace_id`)

### Social Login (Story 15)
- Google Sign-In (Web + Flutter `google_sign_in` package)
- Apple Sign-In (iOS only — mandatory per App Store guidelines)
- Same-email account merging (no duplicates)
- Social users: no "Change Password" in Settings

### Multi-Currency Support (Story 16)
- Per-user home currency setting
- **Group default currency** (all expenses default to group currency)
- **Settlement currency choice** (parties agree on settlement currency)
- Live conversion preview while typing (`~ GBP 25.41`)
- Exchange rate snapshot frozen at time of expense entry
- CRON-based rate caching (ExchangeRate-API, refreshed every 6 hours)
- All amounts stored as integers (cents) — zero floating-point errors

### Recurring Expenses (Story 17)
- Recurring toggle on Add Expense (Weekly / Biweekly / Monthly / Custom)
- BullMQ scheduled job auto-generation at midnight for due expenses
- Recurring badge on recurring expenses in ledger view
- "Edit this occurrence" vs "Edit all future occurrences"
- End-of-month edge case handled (last day logic for Feb/31st)

### Data Export (Story 19)
- CSV export (RFC 4180 compliant, opens correctly in Excel/Google Sheets)
- JSON export (GDPR-compliant full data dump)
- Filter by date range, specific group, or all activity
- Streamed response (no memory overflow for large exports)

### Expense Comments & Attachments (Story 21)
- Comment thread on every expense (chronological chat)
- Receipt image attachment via comment
- Push notification to all group members on new comment
- Cascade delete: expense deleted -> all comments deleted

### Default Split Settings per Group (Story 22)
- Group-level default split configuration (e.g., always 60/40)
- Auto-applies to new expenses (overridable per-expense)

### Dark Mode / Light Mode (Story 23)
- System auto-detects OS preference on first launch
- Manual toggle persisted in `SharedPreferences`
- Theme swap with `250ms ease` transition
- All dark mode colors verified against WCAG 4.5:1 contrast

### Search (Story 24)
- Global search (expenses, groups, friends)
- In-context search within a specific group
- 300ms debounce (no API spam)
- SQL injection protected via Prisma parameterized queries

### First-Time Onboarding (Story 25)
- 3-step guided flow (Add Friend -> Create Group -> Add Expense)
- Skippable at any step
- Shown once only (`onboarding_completed` flag)
- Spotlight pulse animation on FAB after completion

### Deployment Plan (Story 27)
- Docker-based deployment on Hetzner VPS
- Cloudflare Tunnel for local development exposure
- Prisma migration strategy (additive-only in production)
- `migrations_log` table to track deployed migrations
- Pre-deploy `pg_dump` backup + post-deploy smoke test
- Environment configuration via `.env` files

### File Storage & Image Infrastructure (Story 28)
- Centralized file upload service (receipts, avatars, cover photos)
- Image compression and format conversion (WebP)
- Storage abstraction (local filesystem -> S3-compatible)
- Signed URL generation for secure access
- File size and MIME type validation

### Email System (Story 29)
- Transactional email service (password resets, invitations, receipts)
- Email queue via BullMQ + Redis (reliable delivery)
- HTML email templates with plain-text fallback
- Rate limiting on outbound emails
- Unsubscribe/preference management

### Real-time Architecture (Story 30)
- Socket.io server integrated with Fastify
- Room-based event broadcasting (per-group, per-user)
- Live balance updates on expense/settlement changes
- Typing indicators and presence awareness
- Connection recovery and missed-event replay

### Group Invitations & Deep Linking (Story 31)
- Shareable invite links with expiry
- Deep link handling (tap link -> app opens -> land in group)
- Invite acceptance flow (existing users join immediately, new users sign up first)
- Invitation revocation and management
- QR code generation for in-person invites

### Testing Strategy (Story 32)
- Full TDD approach across frontend and backend
- Unit tests: Dart test + Jest
- Widget tests: Flutter widget testing framework
- Integration tests: Flutter integration_test + Supertest
- E2E tests: Patrol (Flutter) for mobile flows
- Coverage thresholds enforced in CI

### CI/CD Pipeline (Story 33)
- Self-hosted runner on Hetzner VPS
- Automated lint, test, build on every push
- Docker image build and push to registry
- Staged deployment: staging -> production
- Rollback strategy via Docker image tags
- Database migration as part of deploy pipeline

### Database Migration & Seeding (Story 34)
- Prisma Migrate for schema versioning
- Seed scripts for development and testing data
- Production migration safety checks (no destructive changes)
- Migration rollback procedures
- Data integrity validation post-migration

### Audit Trail & Change Log (Story 35)
- `audit_log` table capturing all mutations (create, update, delete)
- Actor, action, entity type, entity ID, before/after snapshot
- Immutable append-only log
- Queryable for dispute resolution
- Retention policy (configurable TTL)

### Accessibility — a11y (Story 36)
- Semantic labels on all interactive Flutter widgets
- Screen reader compatibility (TalkBack / VoiceOver)
- Minimum tap target sizes (48x48dp)
- Color contrast compliance (WCAG AA minimum)
- Keyboard navigation support on web
- Focus management on modals and navigation

### Reminders & Nudges (Story 37)
- Configurable payment reminders (manual or auto-scheduled)
- Push notification nudges for outstanding debts
- Reminder frequency limits (no spam)
- "Remind" button on friend/group balance screens
- BullMQ scheduled jobs for automated reminders

### Group Permissions & Roles (Story 38)
- Role system: Owner, Admin, Member
- Owner: full control (delete group, remove members, transfer ownership)
- Admin: add/remove members, edit group settings
- Member: add expenses, settle up, comment
- Role displayed in group member list
- Permission checks on all group-mutating API endpoints

### Legal / Privacy / Consent (Story 40)
- Terms of Service and Privacy Policy screens
- Consent tracking (accepted version + timestamp)
- GDPR data export (Story 19 integration)
- GDPR right to deletion (Story 10 Delete Account integration)
- Cookie consent for web platform
- Age verification (13+ minimum)

### App Versioning & Force Update (Story 41)
- Semantic versioning (major.minor.patch)
- Server-side minimum version check on app launch
- Force update dialog (blocks app usage if critically outdated)
- Soft update prompt (dismissible for minor versions)
- Version info displayed in Settings screen

### Soft Delete & Data Retention (Story 42)
- Soft delete on expenses, settlements, and groups (`deleted_at` column)
- Soft-deleted records excluded from all queries by default
- Admin/support recovery within retention window
- Hard delete CRON after configurable retention period (default 90 days)
- Cascade soft-delete logic (group deleted -> expenses soft-deleted)

### Deferred to v1.5
The following stories are out of scope for v1 and will be addressed in v1.5:
- **Story 12:** Analytics & Insights (Donut charts, spending breakdowns)
- **Story 18:** Receipt Scanning — OCR (Google ML Kit)
- **Story 43:** Contact Sync
- **Story 44:** Home Screen Widget
- **Story 45:** Custom Categories

---

## 5. UI/UX Design System (Locked — Do Not Deviate)

### Spacing Grid
All padding, margin, and gap values must be multiples of `8px`:
`4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px`

### Typography (Google Fonts: Outfit + Inter)
To avoid generic aesthetics, we use a distinct display font paired with a highly readable body font.

| Token | Size | Font Family | Usage |
|---|---|---|---|
| `text-xs` | 12px | **Inter** | Labels, captions |
| `text-sm` | 14px | **Inter** | Secondary content |
| `text-base` | 16px | **Inter** | Body text |
| `text-lg` | 20px | **Outfit** (SemiBold) | Card titles |
| `text-xl` | 24px | **Outfit** (Bold) | Section headings |
| `text-2xl` | 32px | **Outfit** (Bold) | Hero balance amounts |
| `text-3xl` | 40px | **Outfit** (Black) | Page heroes |

### Color Palette & Material 3
The following hex codes are defined strictly as **Seed Colors** to generate a coordinated `ColorScheme.fromSeed` pallet using `useMaterial3: true`. Do not hardcode raw hex values in individual widgets.

| Seed Token | Hex | Usage Constraint |
|---|---|---|
| `primary-500` | `#6366F1` | Seed for `colorScheme.primary` and `secondary` |
| `success` | `#10B981` | Positive balances, confirmations |
| `error` | `#EF4444` | Negative balances, errors |
| `warning` | `#F59E0B` | Offline states, cautions |
| `bg-dark` | `#0F172A` | Seed for Dark Mode `colorScheme.surface` |

*Note: For the Dashboard Hero Card and high-visibility areas, enrich the background using subtle noise textures or gradient meshes (using the generated primary tones) rather than plain flat colors.*

### Elevation & Shadows
Instead of generic grey shadows, use subtle colored shadows inherited from the color scheme, or crisp/brutalist borders depending on the final vibe check.
```dart
// Refined shadow examples
shadowSm: BoxShadow(offset: Offset(0, 1), blurRadius: 4, color: context.colors.shadow.withOpacity(0.04))
shadowMd: BoxShadow(offset: Offset(0, 8), blurRadius: 16, color: context.colors.shadow.withOpacity(0.08))
```

### Motion Rules
- Transitions only on `opacity`, `transform`, `background-color` (GPU-accelerated)
- Standard: `250ms ease`
- Fast (button feedback): `150ms ease`
- Never animate layout dimensions (`width`, `height`, `top`, `left`)

---

## 6. Component Dictionary (Flutter Widgets — Build Once, Reuse Everywhere)

| Widget | Variants / States |
|---|---|
| `ButtonPrimary` | Default, Pressed (scale 0.98), Loading (spinner), Disabled |
| `ButtonSecondary` | Default, Pressed, Disabled |
| `ButtonDestructive` | Default, Pressed, Confirm (2-step) |
| `InputText` | Default, Focus (ring), Error (red border + message), Success (checkmark) |
| `InputNumpad` | Numeric-only, 2 decimal max, format mask |
| `CardComponent` | Default, Elevated, Tappable, Skeleton |
| `ModalSheet` | Focus-trapped, swipe-to-dismiss, scroll-locked body |
| `ToastComponent` | Success (4s auto-dismiss), Error (manual dismiss), Warning (6s), Info (5s) |
| `SkeletonLoader` | Animated shimmer — for every async data block |
| `EmptyState` | Illustration + Headline + Supporting text + CTA button |
| `ErrorBoundary` | Branded fallback — never a blank screen |
| `FAB` | 56px circle, fixed bottom-right, elevation shadow |
| `BottomNavBar` | 4 icons: Home, Groups, Friends, Activity |
| `AvatarCircle` | Initials fallback when no photo, stacked group variant |

---

## 7. Backend Architecture (Node.js Fastify + PostgreSQL)

### API Standard Contract
Every endpoint returns uniform JSON:
```json
{
  "success": true | false,
  "data": { ... } | null,
  "error": null | "Human-readable message",
  "code": "AUTH_INVALID" | "VALIDATION_FAILED" | "SERVER_ERROR"
}
```

### Core API Endpoints (Full List)
| Method | Endpoint | Story | Purpose |
|---|---|---|---|
| `POST` | `/api/auth/signup` | 01 | Register new user |
| `POST` | `/api/auth/login` | 01 | Authenticate user |
| `POST` | `/api/auth/logout` | 10 | Invalidate session |
| `POST` | `/api/auth/google` | 15 | Google OAuth login |
| `POST` | `/api/auth/apple` | 15 | Apple Sign-In |
| `POST` | `/api/auth/forgot-password` | 06 | Request reset link |
| `POST` | `/api/auth/reset-password` | 06 | Set new password |
| `GET` | `/api/user/me` | 10 | Fetch current user profile |
| `PUT` | `/api/user/me` | 10 | Update profile |
| `DELETE` | `/api/user/me` | 10 | Delete account |
| `GET` | `/api/user/balances` | 02 | Dashboard balances |
| `GET` | `/api/user/activities` | 07 | Global activity feed |
| `GET` | `/api/user/export` | 19 | Export CSV / JSON |
| `POST` | `/api/expenses` | 03 | Create expense + splits |
| `PUT` | `/api/expenses/:id` | 08 | Edit expense |
| `DELETE` | `/api/expenses/:id` | 08 | Delete expense (soft) |
| `GET` | `/api/expenses/:id/comments` | 21 | Fetch comments |
| `POST` | `/api/expenses/:id/comments` | 21 | Post comment |
| `POST` | `/api/groups` | 04 | Create group |
| `GET` | `/api/groups/:id/ledger` | 04 | Group expense list |
| `PUT` | `/api/groups/:id/settings` | 22 | Default split settings |
| `POST` | `/api/groups/:id/invite` | 31 | Create group invitation |
| `POST` | `/api/groups/:id/join` | 31 | Accept invitation and join group |
| `PUT` | `/api/groups/:id/members/:userId/role` | 38 | Update member role |
| `POST` | `/api/settlements` | 05 | Record payment |
| `GET` | `/api/user/friends/balances` | 09 | All friends + net balances |
| `GET` | `/api/user/friends/:id/ledger` | 09 | 1-on-1 ledger |
| `GET` | `/api/currencies/rates` | 16 | Exchange rates |
| `GET` | `/api/search` | 24 | Global search |
| `POST` | `/api/uploads` | 28 | Upload file (receipt, avatar) |
| `POST` | `/api/reminders` | 37 | Send payment reminder |
| `GET` | `/api/audit-log` | 35 | Query audit trail |
| `GET` | `/api/version/check` | 41 | Check minimum app version |
| `GET` | `/api/health` | 27 | Deployment smoke test |

### WebSocket Events (Socket.io — Story 30)
| Event | Direction | Purpose |
|---|---|---|
| `expense:created` | Server -> Client | New expense in group |
| `expense:updated` | Server -> Client | Expense edited |
| `expense:deleted` | Server -> Client | Expense removed |
| `settlement:created` | Server -> Client | New settlement recorded |
| `balance:updated` | Server -> Client | Balance recalculated |
| `comment:new` | Server -> Client | New comment on expense |
| `member:joined` | Server -> Client | New member joined group |
| `reminder:received` | Server -> Client | Payment reminder nudge |

---

## 8. Finalized Database Schema (PostgreSQL)

```sql
-- Core Users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NULL,              -- NULL for social login
    provider TEXT NOT NULL DEFAULT 'email' CHECK (provider IN ('email','google','apple')),
    provider_id VARCHAR(255) NULL,
    default_currency CHAR(3) DEFAULT 'USD',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    avatar_url VARCHAR(500) NULL,
    terms_accepted_at TIMESTAMPTZ NULL,
    terms_version VARCHAR(20) NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Groups
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    type TEXT NOT NULL DEFAULT 'other' CHECK (type IN ('trip','home','couple','other')),
    cover_photo_url VARCHAR(500) NULL,
    created_by INT NOT NULL REFERENCES users(id),
    group_currency CHAR(3) DEFAULT 'USD',
    default_split_type TEXT NOT NULL DEFAULT 'equal' CHECK (default_split_type IN ('equal','percentage','shares')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

CREATE TABLE group_members (
    group_id INT NOT NULL REFERENCES groups(id),
    user_id INT NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','admin','member')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

-- Group Default Splits (Story 22)
CREATE TABLE group_default_splits (
    id SERIAL PRIMARY KEY,
    group_id INT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id),
    percentage DECIMAL(5,2) NULL,
    share_count SMALLINT DEFAULT 1,
    UNIQUE (group_id, user_id)
);

-- Group Invitations (Story 31)
CREATE TABLE group_invitations (
    id SERIAL PRIMARY KEY,
    group_id INT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    invited_by INT NOT NULL REFERENCES users(id),
    invite_token VARCHAR(255) UNIQUE NOT NULL,
    invited_email VARCHAR(150) NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Expenses
CREATE TABLE expenses (
    id SERIAL PRIMARY KEY,
    group_id INT NULL REFERENCES groups(id),
    title VARCHAR(150) NOT NULL,
    total_amount INT NOT NULL,                    -- stored in cents
    original_currency CHAR(3) DEFAULT 'USD',
    exchange_rate_snapshot DECIMAL(15,6) DEFAULT 1.0,
    category_id INT NULL,
    paid_by INT NOT NULL REFERENCES users(id),
    receipt_image_url VARCHAR(500) NULL,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_type TEXT NULL CHECK (recurrence_type IN ('weekly','biweekly','monthly','custom')),
    recurrence_day SMALLINT NULL,
    next_due_date DATE NULL,
    parent_expense_id INT NULL REFERENCES expenses(id),
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- Splits
CREATE TABLE splits (
    id SERIAL PRIMARY KEY,
    expense_id INT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id),
    owed_amount INT NOT NULL,                     -- in cents
    paid_amount INT DEFAULT 0,                    -- for multi-payer
    share_count SMALLINT DEFAULT 1,
    adjustment_amount INT DEFAULT 0
);

-- Settlements
CREATE TABLE settlements (
    id SERIAL PRIMARY KEY,
    payer_id INT NOT NULL REFERENCES users(id),
    payee_id INT NOT NULL REFERENCES users(id),
    amount INT NOT NULL,                          -- in cents
    currency CHAR(3) DEFAULT 'USD',
    group_id INT NULL REFERENCES groups(id),
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- Comments
CREATE TABLE expense_comments (
    id SERIAL PRIMARY KEY,
    expense_id INT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id),
    comment_text TEXT NULL,
    image_url VARCHAR(500) NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    title VARCHAR(100),
    body TEXT,
    reference_type TEXT NOT NULL CHECK (reference_type IN ('expense','settlement','group_invite','comment','reminder')),
    reference_id INT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Log (Story 35)
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    actor_id INT NULL REFERENCES users(id),
    action TEXT NOT NULL CHECK (action IN ('create','update','delete','restore')),
    entity_type VARCHAR(50) NOT NULL,
    entity_id INT NOT NULL,
    before_snapshot JSONB NULL,
    after_snapshot JSONB NULL,
    ip_address INET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Queue (Story 29)
CREATE TABLE email_queue (
    id SERIAL PRIMARY KEY,
    to_email VARCHAR(150) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    template VARCHAR(100) NOT NULL,
    template_data JSONB NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed')),
    attempts SMALLINT DEFAULT 0,
    last_error TEXT NULL,
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Supporting Tables
CREATE TABLE expense_categories (id INT PRIMARY KEY, name VARCHAR(50), icon VARCHAR(50));
CREATE TABLE exchange_rates (currency_code CHAR(3) PRIMARY KEY, rate_to_usd DECIMAL(15,6), updated_at TIMESTAMPTZ);
CREATE TABLE password_resets (email VARCHAR(150) PRIMARY KEY, token_hash VARCHAR(255), expires_at TIMESTAMPTZ);
CREATE TABLE migrations_log (id SERIAL PRIMARY KEY, filename VARCHAR(255) UNIQUE, executed_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE app_versions (id SERIAL PRIMARY KEY, platform TEXT NOT NULL CHECK (platform IN ('ios','android','web')), min_version VARCHAR(20) NOT NULL, force_update BOOLEAN DEFAULT FALSE, updated_at TIMESTAMPTZ DEFAULT NOW());

-- Indexes
CREATE INDEX idx_expenses_group_id ON expenses(group_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_expenses_paid_by ON expenses(paid_by) WHERE deleted_at IS NULL;
CREATE INDEX idx_splits_expense_id ON splits(expense_id);
CREATE INDEX idx_splits_user_id ON splits(user_id);
CREATE INDEX idx_settlements_payer ON settlements(payer_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_settlements_payee ON settlements(payee_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_email_queue_status ON email_queue(status, scheduled_at);
CREATE INDEX idx_group_invitations_token ON group_invitations(invite_token);
```

**Critical Rule:** ALL monetary amounts stored as `INT` (cents). `$12.50` stored as `1250`. Division done in application layer with remainder allocation. NEVER use `FLOAT` or `DOUBLE` for money.

---

## 9. Performance & Optimization Rules

| Rule | Implementation |
|---|---|
| **Pagination** | Cursor-based (`?limit=25&cursor=timestamp`) on all list endpoints |
| **Virtual Scrolling** | Flutter `ListView.builder` — renders only visible items |
| **Skeleton Loaders** | Every async block shows animated shimmer immediately — zero blank screens |
| **Optimistic UI** | State updates locally before API confirms (with rollback on failure) |
| **API Caching** | Riverpod caching with stale-while-revalidate pattern for balance and activity data |
| **Debounce** | All search inputs debounced at 300ms |
| **Request Deduplication** | Idempotency keys on all POST/PUT mutations |
| **Image Optimization** | Receipts compressed to WebP before upload, max 5MB |
| **Lazy Loading** | Images, avatars, and older ledger items load only on scroll via Flutter scroll controller |
| **Analytics Caching** | Spending analytics served from BullMQ-scheduled materialized aggregations |

---

## 10. Security Architecture

| Layer | Protection |
|---|---|
| **SQL** | 100% Prisma parameterized queries — zero string concatenation |
| **XSS** | helmet middleware + DOMPurify on user-generated content + CSP header |
| **CSRF** | Per-session CSRF token in every mutating request header |
| **Auth** | JWT in `HttpOnly; Secure; SameSite=Strict` cookies |
| **Token Expiry** | Access tokens: 15 min. Refresh tokens: 7 days (rotated on use) |
| **Rate Limiting** | 10 login attempts/min/IP before `429 Too Many Requests` (fastify-rate-limit) |
| **CORS** | Strict origin whitelist, credentials allowed, preflight cached |
| **File Upload** | MIME type verified server-side (not extension). Only `image/*` accepted |
| **HTTP Headers** | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS (via helmet) |
| **Input Validation** | Zod schemas on all Fastify route inputs |
| **Dependency Security** | `npm audit` in CI pipeline, Dependabot alerts enabled |

---

## 11. Execution Phases (Development Roadmap)

| Phase | Focus | Stories |
|---|---|---|
| **Phase 1: Foundation** | DB schema (Prisma), Auth APIs, Login/Signup UI, JWT infrastructure | 01, 06, 15, 34 |
| **Phase 2: Core Infrastructure** | File storage, email system, real-time architecture, CI/CD | 28, 29, 30, 33 |
| **Phase 3: Dashboard & Navigation** | Dashboard, sessions, balance APIs, bottom nav, onboarding, dark mode | 02, 23, 25 |
| **Phase 4: Expense Flow** | Add/Edit/Delete expenses, all 5 split modes, comments | 03, 08, 20, 21 |
| **Phase 5: Groups** | Groups, group ledger, debt simplification, default splits, invitations, roles | 04, 22, 31, 38 |
| **Phase 6: Social** | Friends, 1-on-1 ledgers, settlements, optimistic UI, concurrency locks | 05, 09 |
| **Phase 7: Activity & Discovery** | Activity feed, search, filters, notifications, reminders | 07, 11, 24, 37 |
| **Phase 8: Advanced Features** | Multi-currency, recurring expenses, data export | 16, 17, 19 |
| **Phase 9: Resilience** | Offline sync, observability, audit trail, soft delete | 13, 14, 35, 42 |
| **Phase 10: Polish & Ship** | Accessibility, legal/privacy, app versioning, testing, deployment | 26, 32, 36, 40, 41, 27 |

---

## 12. Senior-Level Non-Negotiables

- **Do not code without flow clarity** — read the Story file first
- **Do not design without purpose** — every element must answer a user question
- **Do not duplicate components** — one source of truth per UI pattern
- **Do not ignore edge cases** — offline, concurrent, and empty states are required
- **Do not use `FLOAT` for money** — integers only, remainder allocation in app logic
- **Do not store JWTs in `localStorage`** — `HttpOnly` cookies only
- **Do not trust client input** — validate all data independently on the backend (Zod schemas)
- **Do not deploy without a DB backup** — run `pg_dump` before every migration
- **Do not merge without tests** — TDD is enforced, CI blocks on failure

### Final Success Criteria
1. A first-time user understands their balance **within 5 seconds** of opening the dashboard
2. Core tasks (Add Expense) complete in **under 30 seconds**
3. Zero mathematical drift under any load condition
4. Application functions for **30 seconds offline** before gracefully alerting the user
5. All screens pass **accessibility audit** (WCAG AA compliance)

---

## 13. Documentation Index

| File | Purpose |
|---|---|
| `Master_Feature_Index.md` | Reevaluation checklist linking all 42 stories |
| `Stories_and_Scenarios/Story_01-42.md` | Full technical blueprint per feature |
| `Flutter_Architecture_Plan.md` | Mobile-specific architecture (Riverpod, Dio, go_router) |
| `UI_UX_Improvement_Plan.md` | Design system, component specs, accessibility rules |
| `Splitwise_Planning.md` | Premium feature inspiration and DB schema reference |

---

*This document is the single source of truth for the project. All implementation decisions trace back to one of the 42 Stories. Any new feature request generates a new Story file and is appended to `Master_Feature_Index.md`.*
