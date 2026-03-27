# Story 01: Onboarding & Authentication - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide a frictionless, secure, and visually instantly-trustworthy onboarding experience for users. The login and signup process must feel robust. Since this app handles finances, security (JWT, HttpOnly cookies via `fastify-cookie`, rate-limiting) is as important as the UX (smooth transitions, inline validation).

---

## 👥 2. Target Persona & Motivation
- **The Rushed User:** Trying to create an account while at a dinner table to log a shared bill. Needs extremely fast onboarding (<10 seconds).
- **The Returning User:** Just opening the app to check if their friend paid them. Needs persisted sessions (auto-login).

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Signup Flow (New User)
1. **Entry Point:** User opens the Flutter app. If no valid stored session exists, they are routed to the Login screen.
2. **Action - Switch Context:** User taps "Create an Account" link. The UI transitions smoothly (Navigator push) to the Signup screen.
3. **Action - Input Data:**
   - **Name Field:** User types "John Doe".
   - **Email Field:** User types "john@example.com". (On focus lost, regex checks standard RFC 5322 format).
   - **Password Field:** User types a password. Password strength meter evaluates length (>8 chars) and complexity.
4. **Action - Submission:** User taps "Sign Up".
5. **System State - Loading:** The "Sign Up" button text changes to a `CircularProgressIndicator`. Button is disabled to prevent double taps.
6. **System State - Processing:** `POST /api/auth/signup` is called via Dio.
7. **System State - Success:** API returns `{ success: true, token: "jwt_string..." }`. Token is stored in `flutter_secure_storage`. User receives a green `SnackBar`: "Account created successfully!" and is instantly routed to the Dashboard screen.

### B. The Login Flow (Returning User)
1. **Action - Input Data:** User enters email and password.
2. **Action - Submission:** User taps the keyboard "Done" action or taps "Login".
3. **System State - Success/Failure:** API returns validation.
   - If Success: Routed to dashboard.
   - If Failure: Password field clears itself, email remains. Red inline text appears below password: "The email or password you entered is incorrect."

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`AuthContainerCard`**: A `Container` widget with max-width `400`, centered vertically and horizontally via `Center` + `ConstrainedBox`, with `BoxDecoration` applying a gentle shadow (`boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.1))]`), `surface` background color, `borderRadius: BorderRadius.circular(12)`.
- **`InputComponent`**:
  - Height: `48`.
  - Padding: `EdgeInsets.symmetric(horizontal: 16)`.
  - Border: `OutlineInputBorder` with `borderSide: BorderSide(color: Color(0xFFE0E0E0))`.
  - Focus State: Border transitions to Primary Brand Color with `focusedBorder`.
  - Prefix Icon: (e.g., `Icons.mail`, `Icons.lock` in `Color(0xFF9E9E9E)`).
- **`ButtonPrimary`**:
  - Height: `48`.
  - Width: `double.infinity`.
  - Font: `Inter`, `FontWeight.w600`, `16px`.
  - Background: Primary Brand Color. Uses `ElevatedButton` with `style` property.
- **`ToastNotification`**:
  - Implemented via `SnackBar` or an overlay notification package, stays for 3000ms.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):

#### 1. `POST /api/auth/signup`
- **Request Payload:** `{ name: "John", email: "j@j.com", password: "raw_password" }`
- **Controller Logic:**
  - Standardize email to lowercase.
  - Check if email exists via `prisma.user.findUnique({ where: { email } })` -> Return `409 Conflict` if existing.
  - Hash password using `bcrypt` (cost factor 10).
  - Insert via `prisma.user.create({ data: { name, email, passwordHash } })`.
  - Generate JWT via `fastify-jwt`.
  - Set HttpOnly cookie via `fastify-cookie`.
- **Response (201 Created):** `{ success: true, user: { id: 1, name: "John", email: "j@j.com" }, token: "eyJhb..." }`

#### 2. `POST /api/auth/login`
- **Request Payload:** `{ email: "j@j.com", password: "raw_password" }`
- **Controller Logic:**
  - Standardize email.
  - Find matching email via `prisma.user.findUnique({ where: { email } })` -> Return `401 Unauthorized` if null.
  - `bcrypt.compare()` raw password against hashed password -> Return `401` if false.
  - Generate JWT and set session via `@fastify/session` backed by Redis.
- **Response (200 OK):** `{ success: true, token: "eyJhb..." }`

### Database Schema (PostgreSQL via Prisma):
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
| --- | --- | --- |
| **Invalid Email Format** | Field border turns red instantly (on focus lost). Submit button disabled. Helper text: "Please enter a valid email." | Regex validation in Flutter `TextFormField` validator. Backend re-validates via Fastify schema validation and throws `400 Bad Request` if bypassed. |
| **Email Already Exists** | Form submits, spins, then stops. Inline error on email field: "An account with this email already exists. Try logging in." | Backend catches `UNIQUE` constraint violation from PostgreSQL, translates to explicit `409` JSON response. |
| **Server Offline / Timeout** | Loader spins for 10s, then stops. `SnackBar` appears: "Network error. Please check your connection." | Dio interceptor catches network drop, prevents crash, keeps form data populated. |
| **Brute Force AI / Bot** | After 5 failed logins, UI disables login button for 5 minutes. Gives error: "Too many attempts." | Backend utilizes `@fastify/rate-limit` plugin + Redis blocking IP+Email combo (HTTP 429). |
| **Old Session Token** | User opens app after 30 days. App loads momentarily, detects expired token, softly routes to Login screen. | App calls `GET /api/user/me`. Backend decodes JWT, sees expired `exp`, returns `401`. Dio interceptor catches `401` globally and forces logout, clearing `flutter_secure_storage`. |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Clicking "Sign Up" successfully creates a user and yields a valid JWT.
- [ ] User cannot sign up with heavily formatted/spaced emails (trimmed natively).
- [ ] Hitting "Done" on the keyboard inside the password field appropriately submits the form.
- [ ] There is no visual glitch or layout jump when the screen transitions from Login to Signup.
- [ ] Session persists correctly upon app restart via `flutter_secure_storage`.
