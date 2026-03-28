# Story 11: Notifications System - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Keep users informed of financial changes to their accounts in real-time, without becoming spammy. Notifications should act as a verified receipt that a transaction occurred, preventing the "I thought you paid that?" miscommunications. Users have granular control over which notifications they receive and how.

---

## 👥 2. Target Persona & Motivation
- **The Receiver:** Wants to know the exact second their roommate settles a debt so they can stop worrying about it.
- **The Disengaged User:** Needs a gentle prompt if they've owed someone $50 for a month.
- **The Overwhelmed User:** Wants to mute noisy groups or switch to digest emails instead of real-time pings.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. Real-Time Push Invocations
1. **Trigger (Expense Added):** John adds an expense splitting $100 with Bob.
2. **System State - Background Worker:** Node.js Fastify backend processes the expense and fires a push notification via the `firebase-admin` SDK specifically to Bob's device token.
3. **Action - UI Interaction:** Bob's phone displays: "John added an expense: Dinner. You owe $50.00".
4. **Action - Deep Link:** Bob taps the notification and is routed instantly to the `ExpenseDetailScreen` via Flutter deep linking, bypassing the dashboard.

### B. The In-App Notification Center
1. **Trigger:** User taps the "Bell" icon on the `AppBar`. (Icon has a red badge `Container` if unread alerts exist).
2. **Action - Feed Display:** A new `NotificationListScreen` shows the chronologically sorted history of alerts (e.g., "Alice joined the Tokyo Group", "Charlie settled up with you") in a `ListView.builder`.
3. **Action - Mark as Read:** Unread items have a light blue `Container` background. Tapping an item marks it as read in the database via `PUT /api/notifications/{id}/read` and uses `Navigator.push` to route the user to the relevant context.

### C. Notification Preferences
1. **Trigger:** User navigates to Settings > Notification Preferences.
2. **Action - UI Opens:** The `NotificationPreferencesScreen` displays a list of notification types (expense added, settlement received, group invite, payment reminder) with toggle controls for each delivery channel: **Push**, **Email**, and **In-App**.
3. **Action - Granular Control:** User can enable/disable each combination independently (e.g., push ON for settlements, email OFF for expense added).
4. **System State - Save:** `PUT /api/user/notification-preferences` saves the preference matrix.

### D. Mute Group Notifications
1. **Trigger:** Inside a Group screen, user taps the overflow menu and selects "Mute Notifications".
2. **Action - Confirmation:** A quick `AlertDialog`: "Mute notifications for this group? You can unmute anytime from group settings."
3. **System State - Processing:** `PUT /api/groups/{id}/mute` sets a mute flag for this user-group pair.
4. **System State - Result:** All notifications originating from this group are suppressed for this user. The group icon shows a mute indicator.

### E. Email Notification Digests
1. **Trigger:** User navigates to Settings > Notification Preferences > Email Digest.
2. **Action - Selection:** User chooses digest frequency: **Off**, **Daily**, or **Weekly**.
3. **System State - Processing:** `PUT /api/user/notification-preferences` updates the `email_digest_frequency` field.
4. **System State - Scheduled Job:** A Node.js scheduled job (node-cron or BullMQ recurring) runs at the configured intervals, aggregating unread notifications into a summary email sent via the email service. The job respects the user's timezone setting (from Story 10) for delivery timing.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`NotificationBellIcon`**: An `IconButton(icon: Icon(Icons.notifications))` wrapped in a `Stack` with a positioned `Container` badge showing active unread count.
- **`ToastMessage`**: Utilized for transient notifications via Flutter `SnackBar` or an overlay widget (e.g., while actively in the app, if John settles up, a green `SnackBar` slides down from the top to immediately reflect the change without requiring a full screen refresh).
- **`NotificationPreferenceToggle`**: A `SwitchListTile` for each notification type + channel combination, organized in expandable `ExpansionTile` sections.
- **`MuteIndicator`**: A small muted speaker `Icon` overlay on the group avatar in the groups list.

---

## 🚀 5. Technical Architecture & Database

### Backend Requirements (Node.js Fastify):
- Integration with **Firebase Cloud Messaging (FCM)** via the `firebase-admin` Node.js SDK for push notifications to Flutter mobile clients.
- Integration with **Apple Push Notification service (APNs)** (handled transparently through FCM for Flutter).
- **`POST /api/notifications/register-token`**: Stores device tokens securely per user via Prisma.
- **`PUT /api/user/notification-preferences`**: Updates per-type, per-channel notification preferences.
- **`PUT /api/groups/{id}/mute`**: Toggles mute flag for a user-group pair.
- **Scheduled digest job**: A Node.js scheduled job (node-cron or BullMQ recurring) aggregates unread notifications and sends email digests at the user's preferred frequency, respecting their timezone.

### Database Context (PostgreSQL):
```sql
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    title VARCHAR(100),
    body TEXT,
    reference_type VARCHAR(20) NOT NULL CHECK (reference_type IN ('expense', 'settlement', 'group_invite', 'payment_reminder')),
    reference_id INT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_devices (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    fcm_token VARCHAR(255) UNIQUE,
    platform VARCHAR(10) NOT NULL CHECK (platform IN ('ios', 'android'))
);

CREATE TABLE notification_preferences (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    notification_type VARCHAR(30) NOT NULL,  -- 'expense_added', 'settlement_received', 'group_invite', 'payment_reminder'
    push_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT TRUE,
    in_app_enabled BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, notification_type)
);

CREATE TABLE user_notification_settings (
    user_id INT PRIMARY KEY REFERENCES users(id),
    email_digest_frequency VARCHAR(10) DEFAULT 'off' CHECK (email_digest_frequency IN ('off', 'daily', 'weekly')),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE group_mutes (
    user_id INT NOT NULL REFERENCES users(id),
    group_id INT NOT NULL REFERENCES groups(id),
    muted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, group_id)
);
```

### Prisma Schema Context:
```prisma
model Notification {
  id            Int      @id @default(autoincrement())
  userId        Int      @map("user_id")
  title         String?  @db.VarChar(100)
  body          String?
  referenceType String   @map("reference_type") @db.VarChar(20)
  referenceId   Int?     @map("reference_id")
  isRead        Boolean  @default(false) @map("is_read")
  createdAt     DateTime @default(now()) @map("created_at")
  user          User     @relation(fields: [userId], references: [id])
}

model UserDevice {
  id       Int    @id @default(autoincrement())
  userId   Int    @map("user_id")
  fcmToken String @unique @map("fcm_token") @db.VarChar(255)
  platform String @db.VarChar(10)
  user     User   @relation(fields: [userId], references: [id])
}

model NotificationPreference {
  id               Int     @id @default(autoincrement())
  userId           Int     @map("user_id")
  notificationType String  @map("notification_type") @db.VarChar(30)
  pushEnabled      Boolean @default(true) @map("push_enabled")
  emailEnabled     Boolean @default(true) @map("email_enabled")
  inAppEnabled     Boolean @default(true) @map("in_app_enabled")
  user             User    @relation(fields: [userId], references: [id])

  @@unique([userId, notificationType])
}

model UserNotificationSetting {
  userId               Int      @id @map("user_id")
  emailDigestFrequency String   @default("off") @map("email_digest_frequency") @db.VarChar(10)
  updatedAt            DateTime @default(now()) @updatedAt @map("updated_at")
  user                 User     @relation(fields: [userId], references: [id])
}

model GroupMute {
  userId  Int      @map("user_id")
  groupId Int      @map("group_id")
  mutedAt DateTime @default(now()) @map("muted_at")
  user    User     @relation(fields: [userId], references: [id])
  group   Group    @relation(fields: [groupId], references: [id])

  @@id([userId, groupId])
}
```

### Push Notification Sending (Node.js firebase-admin):
```javascript
import admin from 'firebase-admin';

// Initialize once at app startup
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Send push notification
async function sendPushNotification(fcmToken, title, body, data) {
  await admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data, // e.g., { referenceType: 'expense', referenceId: '123' }
  });
}
```

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Notification Spam** | A user adds 50 expenses in 1 minute. | Backend applies a debounce algorithm, merging payload: "John added 50 expenses. You owe a total of $420." |
| **Silent Discards** | Payer settles debt. Payer receives push? No. | Engine strictly filters `sender_id != recipient_id`. |
| **Muted Group Activity** | Expense added in a muted group. | Backend checks `group_mutes` table before dispatching. If muted, the notification is still stored in-app (for history) but push and email are suppressed. |
| **Digest with No Activity** | Daily digest fires but user has no new notifications. | The digest job skips sending an email if there are zero unread notifications for that period. |
| **Preference Respect** | User disables push for expense_added but keeps email on. | The notification dispatch pipeline checks `notification_preferences` per-type per-channel before each delivery. |
| **Stale FCM Token** | Device token becomes invalid after app reinstall. | The `firebase-admin` SDK returns an error for invalid tokens. Backend catches this and removes the stale token from `user_devices`. |
