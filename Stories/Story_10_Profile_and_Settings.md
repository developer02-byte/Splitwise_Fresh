# Story 10: Profile & Settings - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide users absolute control over their account data and their way out of the app. This is crucial for privacy, security (changing passwords), and trust (clear logout/delete flows).

---

## 👥 2. Target Persona & Motivation
- **The Security-Conscious User:** Wants to update their password easily or format their display name properly.
- **The Finished User:** Paid off their debts and wants to delete their account entirely for data privacy.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Profile Edit Flow
1. **Trigger:** User taps "Profile" avatar on the top right or the bottom navigation bar.
2. **Action - UI Opens:** The `SettingsScreen` Flutter widget renders user details (Name, Email, Default Currency, Timezone).
3. **Action - Entry:** User taps "Edit Profile". A focused Flutter `showModalBottomSheet` or new screen opens. They change their name from "John" to "Johnny", select their timezone, and upload a new square avatar.
4. **Action - Submission:** User hits "Save".
5. **System State - Processing:** `PUT /api/user/me` fires with the payload. (Avatar uploaded to S3/Cloudinary, returning a URL).
6. **System State - Success:** The profile immediately reflects the new name across the app natively via the client state manager (Riverpod/Bloc).

### B. The Change Password Flow
1. **Trigger:** User taps "Change Password" in Settings.
2. **Action - Entry:** Prompted for "Current Password", "New Password", and "Confirm New Password" via Flutter `TextFormField` widgets with obscured text.
3. **Action - Submission:** User hits "Update".
4. **System State - Processing:** `POST /api/user/password/change`.
5. **System State - Success:** `SnackBar` appears indicating success. Session is optionally invalidated forcing re-login (for extreme security), or kept active.

### C. The Logout Sequence
1. **Trigger:** User taps a distinct, slightly red "Log Out" button at the bottom of the Profile page.
2. **Action - Confirmation:** A fast `AlertDialog`: "Are you sure you want to log out?"
3. **System State - Processing:** Tap -> The app immediately wipes JWT from `flutter_secure_storage` and clears any HTTP cookies. State managers drop all cache to initial state.
4. **System State - Success:** Navigator forcibly pushes user to the `LoginScreen`.

### D. The Delete Account Sequence
1. **Trigger:** Deep in Settings, user taps "Danger Zone: Delete Account".
2. **Action - Confirmation:** A sharp destructive `AlertDialog` appears warning about data deletion. Requires user to type the word "DELETE" into a `TextField` to activate the button.
3. **System State - Processing:** `DELETE /api/user/me`.
4. **System State - Success:** The backend performs a **soft delete** first, setting `deleted_at` on the user record. The user is logged out immediately. After a 30-day grace period, a scheduled job performs a hard purge of the user's data. During the grace period, the user can contact support to recover their account.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`SettingsTileItem`**: A `ListTile` widget featuring a leading `Icon`, center `Text`, and trailing `Icon(Icons.chevron_right)`. Tapping it uses `Navigator.push` to open a sub-menu or `showModalBottomSheet`.
- **`DestructiveInputWarning`**: Red outlined `TextField` (using `OutlineInputBorder` with red `borderSide`) requiring string matching ("DELETE") to enable the primary destructive action `ElevatedButton`.
- **`TimezonePicker`**: A searchable dropdown or `showModalBottomSheet` listing IANA timezone identifiers (e.g., "America/New_York", "Europe/Berlin"). Selected timezone is stored in the user profile and used for CRON jobs and date display formatting.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `PUT /api/user/me`
- **Request Payload:** `{ name: "Johnny", currency: "USD", timezone: "America/New_York", avatar_url: "..." }`
- **Handler Logic:** Validates JWT, updates the `users` table parameters via Prisma: `prisma.user.update(...)`.

#### 2. `POST /api/user/password/change`
- **Handler Logic:** Validates `current_password` via `bcrypt`. Overwrites `password_hash` with hashed `new_password` using Prisma parameterized queries.

#### 3. `DELETE /api/user/me`
- **Handler Logic:**
  - The most dangerous route. See Edge Cases below for the logic sequence.
  - Performs a **soft delete**: sets `deleted_at = NOW()` on the user record via Prisma: `prisma.user.update({ where: { id }, data: { deletedAt: new Date() } })`.
  - A scheduled Node.js job (node-cron or BullMQ recurring) runs daily, hard-purging users whose `deleted_at` is older than 30 days.
  - During the 30-day window, if the user logs in or contacts support, the `deleted_at` can be cleared to restore the account.

### Database Context (PostgreSQL):
```sql
-- Timezone and soft delete columns on users
ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT 'UTC';
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Scheduled purge query (run by node-cron or BullMQ recurring job)
-- DELETE FROM users WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '30 days';
-- Note: hard purge cascades through related tables via foreign key constraints
```

### Prisma Schema Context:
```prisma
model User {
  id           Int       @id @default(autoincrement())
  name         String
  email        String    @unique
  passwordHash String    @map("password_hash")
  currency     String    @default("USD")
  timezone     String    @default("UTC")
  avatarUrl    String?   @map("avatar_url")
  deletedAt    DateTime? @map("deleted_at")
  createdAt    DateTime  @default(now()) @map("created_at")
  updatedAt    DateTime  @updatedAt @map("updated_at")
}
```

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Delete Account with Debts** | User tries to delete an account while they Owe $40. UI prevents it: "You cannot delete your account until your debts are settled." | Backend strictly runs a balance check via Prisma before initiating the soft delete. `403 Forbidden` if balance != $0. |
| **Delete Account with Positive Balance** | User deleting while owed money? Technically allowed, but throws a harsh warning: "You are owed $40. Deleting will forfeit this tracking." | Backend soft-deletes the `users` row. `group_members`, `expenses` where `paid_by` = me are kept but the name changes to "Deleted User" to not corrupt other users' historical data mathematics. Hard purge occurs after 30 days. |
| **Account Recovery within 30 Days** | User regrets deletion and logs in within the grace period. | Backend checks if `deleted_at` is set but within 30 days. Clears `deleted_at` and restores full access. Displays a welcome-back message. |
| **Timezone Usage** | User sets timezone to "Asia/Tokyo". All notification schedules and date displays respect this. | The `timezone` field is read by CRON jobs (e.g., notification digests) and passed to the Flutter client for `DateFormat` localization. |
| **JWT Revocation on Logout** | A compromised mobile app hits Logout, but a hacker has the JWT. | (Optional enterprise security): Backend maintains a Redis blacklist of manually invalidated JWT tokens so it rejects subsequent API calls instantly. |
