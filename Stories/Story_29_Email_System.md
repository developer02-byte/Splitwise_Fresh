# Story 29: Email System - Detailed Execution Plan

## 1. Core Objective & Philosophy
Reliable transactional email delivery for password resets, group invitations, payment reminders, and notification digests. Every email is queued (never sent synchronously in an API response), templated, and logged. Users must be able to unsubscribe from non-critical emails with a single click.

---

## 2. Target Persona & Motivation
- **The Forgetful User:** Alice forgot her password. She needs a reset email within seconds, not minutes. If it does not arrive, she assumes the app is broken.
- **The Invited Friend:** Bob receives "Alice invited you to Tokyo Trip" via email. One tap should land him in the app, signed up and inside the group.
- **The Busy User:** Charlie does not check the app daily. A weekly digest email summarizing "You owe $120 across 3 groups" keeps him engaged without requiring him to open the app.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Password Reset Email (Story 06)
1. **Trigger:** User taps "Forgot Password" on login screen. Enters email. Taps "Send Reset Link."
2. **Backend:** `POST /api/auth/forgot-password` validates email exists. Generates a secure token (crypto.randomBytes, 32 bytes, hex-encoded). Stores token hash in `password_reset_tokens` table with 30-minute expiry.
3. **Queue:** Enqueues `email:send` BullMQ job with `{ template: "password-reset", to: email, data: { resetUrl, userName, expiresIn: "30 minutes" } }`.
4. **Worker:** BullMQ worker picks up job. Renders template. Sends via Resend API. Logs result to `email_log` table.
5. **User Receives:** Email with subject "Reset your Splitwise password" containing a button linking to `https://app.yourdomain.com/reset-password?token=abc123`.
6. **Expiry:** Link expires after 30 minutes. After that, clicking it shows "This link has expired. Request a new one."

### B. Group Invitation Email (Story 31)
1. **Trigger:** Group member taps "Invite via Email" in group settings. Enters recipient email.
2. **Backend:** `POST /api/groups/{id}/invite-email` creates invitation record and enqueues email job.
3. **Email Content:** "Alice invited you to join 'Tokyo Trip' on Splitwise" with a deep link button.
4. **Recipient Flow:** New user clicks link, installs app or opens web, signs up, auto-joins group. Existing user clicks link, opens app, confirms join.

### C. Payment Reminder Email (Story 37)
1. **Trigger:** Alice taps "Remind" on Bob's outstanding balance in the group ledger.
2. **Backend:** `POST /api/groups/{id}/remind` enqueues reminder email to Bob.
3. **Email Content:** "Alice is reminding you about $50.00 for Tokyo Trip." Contains deep link to settle up.
4. **Rate Limit:** Max 1 reminder email per debtor per group per 24 hours. Backend enforces.

### D. Welcome Email
1. **Trigger:** User completes signup (Story 01).
2. **Backend:** After user record creation, enqueues welcome email job.
3. **Email Content:** "Welcome to Splitwise! Here's how to get started." Contains onboarding tips and a CTA to create their first group.

### E. Notification Digest Email
1. **Trigger:** BullMQ scheduled job runs daily at 09:00 UTC (or weekly on Mondays, based on user preference from Story 11).
2. **Backend:** Queries unread notifications per user since last digest. Groups by category. Skips users with no activity.
3. **Email Content:** Summary table: "3 new expenses ($210 total), 1 settlement received ($50), 2 new comments." Each line is a deep link.
4. **Preference:** User can set digest frequency to "Daily", "Weekly", or "Off" in notification settings.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Email Template Design System
- **Width:** 600px max, responsive down to 320px mobile.
- **Header:** App logo (40px height) left-aligned. Background: white.
- **Body:** Clean, left-aligned text. Primary font: system font stack (Arial fallback for email clients). 16px body text, #333333 color.
- **CTA Button:** Rounded rectangle, 48px height, app primary color background, white text. Centered. Minimum tap target 44x44px for mobile.
- **Footer:** "You're receiving this because you have a Splitwise account. [Unsubscribe from these emails]." Muted grey text, 12px.
- **Dark mode:** Include `@media (prefers-color-scheme: dark)` styles for supporting clients.

### Unsubscribe Flow (In-App)
- **Settings > Notifications > Email Preferences** screen.
- Toggle switches for each email type: Password Reset (always on, cannot disable), Group Invitations, Payment Reminders, Digest Emails, Welcome.
- Each toggle calls `PATCH /api/users/me/email-preferences`.

---

## 5. Technical Architecture & Database

### Email Provider
- **Primary:** Resend (`resend` npm package). Simple REST API, generous free tier (100 emails/day free), excellent deliverability.
- **Fallback:** If Resend is down, queue retries handle transient failures. For permanent provider switch, swap to SendGrid by implementing the same `EmailProvider` interface.
- **Abstraction:** `EmailService` class with `send(to, template, data)` method. Internally uses provider adapter pattern.

### Configuration (.env)
```env
# Email
EMAIL_PROVIDER=resend          # resend | sendgrid | console
RESEND_API_KEY=re_xxxxx
EMAIL_FROM_ADDRESS=noreply@yourdomain.com
EMAIL_FROM_NAME=Splitwise
EMAIL_DEV_MODE=true            # true = log to console, false = actually send
```

### Template System
- **Engine:** Handlebars (`handlebars` npm package). Precompiled at server startup for performance.
- **Template files:** `src/emails/templates/{template-name}.hbs` — each file is a complete HTML email.
- **Shared partials:** `src/emails/partials/header.hbs`, `footer.hbs`, `button.hbs` — reused across templates.
- **Variables:** Each template defines its required variables in a TypeScript interface for type safety.

### Template List
| Template Name | Subject | Variables |
| --- | --- | --- |
| `password-reset` | Reset your Splitwise password | `userName`, `resetUrl`, `expiresIn` |
| `group-invitation` | {inviterName} invited you to {groupName} | `inviterName`, `groupName`, `inviteUrl` |
| `payment-reminder` | {reminderName} is reminding you about {amount} | `reminderName`, `amount`, `currency`, `groupName`, `settleUrl` |
| `welcome` | Welcome to Splitwise! | `userName` |
| `digest-daily` | Your daily Splitwise summary | `userName`, `summaryItems[]`, `totalOwed`, `dashboardUrl` |
| `digest-weekly` | Your weekly Splitwise summary | `userName`, `summaryItems[]`, `totalOwed`, `dashboardUrl` |

### BullMQ Queue Architecture
- **Queue name:** `email`
- **Job types:** `email:send` (single email), `email:digest` (batch digest generation)
- **Worker concurrency:** 5 (process 5 emails simultaneously)
- **Retry strategy:** 3 attempts with exponential backoff (1min, 5min, 15min)
- **Dead letter queue:** After 3 failures, job moves to `email:failed` queue. Alert fires via monitoring.

### Rate Limiting
- **Per-recipient limit:** Max 3 emails per hour to the same email address. Tracked in Redis with key `email:rate:{email}` and 1-hour TTL.
- **Implementation:** Before sending, worker checks Redis counter. If limit exceeded, job is delayed to next hour window.
- **Exceptions:** Password reset emails bypass rate limit (security-critical).

### Backend Endpoints

#### 1. `POST /api/auth/forgot-password`
- **Auth:** None (public endpoint).
- **Payload:** `{ email: "bob@example.com" }`.
- **Behavior:** Always returns `200 { message: "If that email exists, we sent a reset link" }` (no email enumeration).
- **Side effect:** Enqueues `email:send` job if email found.

#### 2. `POST /api/groups/{id}/invite-email`
- **Auth:** Required. Must be group member.
- **Payload:** `{ email: "friend@example.com" }`.
- **Response:** `201 { invitation_id }`.
- **Side effect:** Creates invitation record (Story 31) + enqueues invitation email.

#### 3. `PATCH /api/users/me/email-preferences`
- **Auth:** Required.
- **Payload:** `{ digest: "weekly" | "daily" | "off", reminders: boolean, invitations: boolean }`.
- **Response:** `200` with updated preferences.

#### 4. `GET /api/emails/unsubscribe?token={unsubscribe_token}&type={email_type}`
- **Auth:** None (link from email). Token is HMAC-signed user ID + email type.
- **Behavior:** Updates user's email preferences. Shows confirmation page.

### Database Schema (Prisma)
```prisma
model EmailLog {
  id             String      @id @default(uuid())
  recipientEmail String      @map("recipient_email")
  templateType   String      @map("template_type")
  subject        String
  status         EmailStatus @default(QUEUED)
  providerId     String?     @map("provider_id")    // ID from Resend/SendGrid for tracking
  sentAt         DateTime?   @map("sent_at")
  errorMessage   String?     @map("error_message")
  createdAt      DateTime    @default(now()) @map("created_at")

  @@index([recipientEmail, createdAt])
  @@index([status])
  @@map("email_log")
}

model EmailPreference {
  id          String   @id @default(uuid())
  userId      String   @unique @map("user_id")
  digest      String   @default("weekly")  // "daily" | "weekly" | "off"
  reminders   Boolean  @default(true)
  invitations Boolean  @default(true)
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  user        User     @relation(fields: [userId], references: [id])

  @@map("email_preferences")
}

enum EmailStatus {
  QUEUED
  SENT
  FAILED
  BOUNCED
}
```

### Dev Mode
- When `EMAIL_DEV_MODE=true`, the `EmailService` logs the full rendered HTML to the console (and to `logs/emails/` directory as `.html` files for visual inspection in browser).
- No external API calls are made in dev mode.
- The `email_log` table is still populated so queue behavior can be tested.

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Invalid email address** | User enters "notanemail" in forgot password. | Frontend validates with regex before submit. Backend validates with `validator` npm package. If invalid format, returns `400`. If valid format but non-existent, returns `200` anyway (no email enumeration). |
| **Bounce handling** | Email sent to `bob@nonexistent-domain.com` bounces. | Resend webhook (or polling API) reports bounce. Worker updates `email_log.status = BOUNCED`. After 3 bounces to same address, flag in `users` table: `email_bouncing = true`. Skip future non-critical emails to this address. |
| **Unsubscribed user** | Charlie unsubscribed from reminders. Alice sends a reminder. | Backend checks `email_preferences` before queuing. If reminders = false, skip email. Still allow in-app notification. API returns success to Alice (she does not need to know Charlie unsubscribed). |
| **Email provider outage** | Resend API returns 500 for all requests. | BullMQ retries 3 times with backoff. After 3 failures, job moves to dead letter queue. Monitoring alert fires. No user-facing error (emails are async). |
| **Rapid password reset requests** | Attacker spams forgot-password for a victim's email. | Rate limit: max 3 password reset emails per email per hour. After limit, silently drop (still return 200). Log attempt for security monitoring. |
| **User changes email** | User updates their email address in profile settings. | Old email receives "Your email was changed" notification (security). New email receives verification link. Email preferences carry over. |
| **HTML injection in template variables** | Attacker sets their name to `<script>alert('xss')</script>`. | Handlebars auto-escapes HTML entities by default (triple-stash `{{{var}}}` is never used for user input). Rendered output shows escaped text. |

---

## 7. Final QA Acceptance Criteria

- [ ] Password reset email arrives within 30 seconds of request.
- [ ] Password reset link expires after 30 minutes and shows a clear expiry message.
- [ ] Group invitation email contains a working deep link that opens the app (or app store if not installed).
- [ ] Payment reminder email includes correct amount, currency, and group name.
- [ ] Daily/weekly digest email summarizes all unread activity accurately.
- [ ] Unsubscribe link in every email works with a single click (no login required).
- [ ] Email preferences screen reflects current settings and saves changes immediately.
- [ ] In dev mode (`EMAIL_DEV_MODE=true`), no emails are sent externally and full HTML is logged to console.
- [ ] Rate limit prevents more than 3 emails per hour to the same address (except password reset).
- [ ] Failed emails are retried 3 times before moving to dead letter queue.
- [ ] `email_log` table records every email attempt with correct status (QUEUED, SENT, FAILED, BOUNCED).
- [ ] All email templates render correctly in Gmail, Apple Mail, and Outlook (test with Litmus or Email on Acid).
