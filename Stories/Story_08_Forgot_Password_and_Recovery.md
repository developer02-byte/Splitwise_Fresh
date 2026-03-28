# Story 06: Forgot Password & Account Recovery - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide a secure, standardized, and foolproof method for users who lost their password to regain access without compromising the security of their financial data.

---

## 👥 2. Target Persona & Motivation
- **The Locked-Out User:** Frustrated because they can't access their account to settle a debt. Needs to regain access quickly with just an email address.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The "Forgot Password" Flow
1. **Trigger:** User taps a "Forgot Password?" subtle link below the login button.
2. **Action - UI Opens:** Navigates to the Forgot Password screen.
3. **Action - Entry:** User enters their registered email address and hits "Send Recovery Link" (`ElevatedButton`).
4. **Action - Submission (Optimistic UX):** Button `CircularProgressIndicator` spins.
5. **System State - Security Response:** Crucially, whether the email exists in the system or not, the API returns a generic `200 OK` ("If your email is registered, you will receive a reset link shortly"). This prevents email scraping/enumeration by malicious bots.
6. **System State - Background:** A securely hashed, time-delimited reset token (e.g., 30 minutes validity) is generated and emailed via Node.js email service (Resend, SendGrid, or Nodemailer).

### B. The Password Reset Flow
1. **Trigger:** User taps the deep link in their email which opens the Flutter app via a registered deep link handler: `app://reset-password?token=abc...`
2. **System State:** App parses the deep link token. If no token exists, navigates to Login.
3. **Action - Entry:** User is presented with two fields: "New Password" and "Confirm New Password".
4. **Action - Submission:** User taps "Update Password".
5. **System State - Processing:** `POST /api/auth/reset-password` via Dio.
6. **System State - Success:** User identity is verified against the token, the password hash is updated, the token is invalidated, and the user is navigated to Login with a green `SnackBar` "Password successfully reset".

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`RecoveryEmailInput`:** `TextFormField` with `autofocus: true`. Validator requires `@` symbol.
- **`PasswordStrengthMeter`:** Below the "New Password" field, a dynamic 3-bar widget built with `Row` of `AnimatedContainer` elements transitioning from Red -> Yellow -> Green depending on casing, numbers, and length (>8 chars).
- **`StateMasking`:** Standard generic success message `Container` preventing identity inference.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `POST /api/auth/forgot-password`
- **Request Payload:** `{ email: "j@j.com" }`
- **Controller Logic:**
  - Lookup user via `prisma.user.findUnique({ where: { email } })`.
  - Generate `crypto_token` via Node.js `crypto.randomBytes(32).toString('hex')`.
  - Store securely as hash in DB via `prisma.passwordReset.upsert({ where: { email }, create: { email, tokenHash, expiresAt }, update: { tokenHash, expiresAt } })`.
  - Send email via email service:
    ```typescript
    // Using Resend
    import { Resend } from 'resend';
    const resend = new Resend(process.env.RESEND_API_KEY);

    await resend.emails.send({
      from: 'noreply@app.com',
      to: email,
      subject: 'Password Reset Request',
      html: `<p>Click <a href="${resetLink}">here</a> to reset your password. This link expires in 30 minutes.</p>`
    });
    ```
  - Alternatively, Nodemailer or SendGrid can be used as drop-in replacements.
  - Sanitize email input via `sanitize-html` before processing.
- **Response:** `{ success: true, message: "Link sent." }`

#### 2. `POST /api/auth/reset-password`
- **Request Payload:** `{ token: "abc...", new_password: "RawPassword1!" }`
- **Controller Logic:**
  - Hash the incoming token and look up via `prisma.passwordReset.findFirst({ where: { tokenHash, expiresAt: { gt: new Date() } } })`.
  - If not found or expired, return `401 Unauthorized: "Token expired or invalid."`.
  - Hash new password via `bcrypt.hash(newPassword, 10)`.
  - Update via `prisma.user.update({ where: { email }, data: { passwordHash } })`.
  - Invalidate token via `prisma.passwordReset.delete({ where: { email } })`.
  - Invalidate all existing sessions for this user in Redis via `@fastify/session`.

### Database Context (PostgreSQL via Prisma):
```sql
CREATE TABLE password_resets (
    email VARCHAR(150) PRIMARY KEY,
    token_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);
```

### Email Service Architecture:
The email sending is handled by a dedicated Node.js service module supporting multiple providers:
- **Primary:** Resend (modern API, good deliverability)
- **Fallback:** SendGrid or Nodemailer with SMTP
- **Configuration:** Provider selection via environment variable `EMAIL_PROVIDER`
- **Rate Limiting:** Max 3 reset emails per email address per hour, enforced via `@fastify/rate-limit`

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Token Expired** | User taps link 48 hours later. UI shows "Link Expired" with a button to "Request New Link". | Backend checks `expiresAt` via Prisma query, throws `401 Expired Token` causing app to show expiry screen. |
| **Passwords Don't Match** | Client-side blocks submission; red inline text "Passwords do not match." | Flutter `TextFormField` validator compares both fields before enabling submit button. |
| **Email Not Registered** | User enters unknown email. UI still shows generic success: "If your email is registered, you will receive a reset link shortly." | Backend silently returns `200 OK` regardless. No email is sent. Prevents enumeration attacks. |
| **Multiple Reset Requests** | User clicks "Send" 5 times. | `@fastify/rate-limit` enforces max 3 per hour per email. Subsequent requests return `429 Too Many Requests`. The `upsert` in Prisma ensures only one active token per email. |
| **Deep Link Handling** | User taps email link on a device without the app installed. | Deep link falls back to a web page with instructions to install the app and a manual token entry option. |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Submitting a registered email dispatches a password reset email within 10 seconds via the configured Node.js email service.
- [ ] Submitting an unregistered email returns the same generic success message (no enumeration).
- [ ] Reset token expires after 30 minutes and cannot be reused.
- [ ] Successfully resetting a password invalidates the token and all existing sessions.
- [ ] Password strength meter accurately reflects complexity requirements.
- [ ] Deep link from email correctly opens the Flutter app to the reset password screen.
- [ ] Rate limiting prevents abuse of the forgot password endpoint.
