# Story 39: Notification Preferences & Granular Controls - Detailed Execution Plan

## 1. Core Objective & Philosophy
Give users fine-grained control over what notifications they receive and how they receive them. The base notification system (Story 11) sends alerts for all events. This story adds the preference layer — letting users mute noisy groups, disable email notifications while keeping push, set quiet hours, and control per-category toggles. The goal is zero notification fatigue while ensuring critical alerts (like being added to an expense) always get through.

---

## 2. Target Persona & Motivation
- **The Overwhelmed User:** Member of 5 active groups. Gets pinged constantly — every expense, every comment, every settlement. Wants to mute the "Roommates" group's comments but still see new expenses.
- **The Email Hater:** Wants push notifications on their phone but absolutely no emails. Currently unsubscribing from each email individually.
- **The Night Owl's Roommate:** Goes to bed at 10 PM. Does not want their phone buzzing at 1 AM because someone logged a late-night pizza expense. Wants quiet hours from 10 PM to 7 AM.
- **The Minimalist:** Only wants to know about two things: when someone adds an expense that involves them, and when someone settles a debt with them. Everything else is noise.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Accessing Notification Preferences
1. **Trigger:** User navigates to Settings > Notification Preferences.
2. **UI:** A structured settings page with three sections: Global Preferences, Per-Category Toggles, and Per-Group Overrides.

### B. Global Preferences
1. **Push Notifications Master Toggle:** ON/OFF. When OFF, no push notifications are sent. Default: ON.
2. **Email Notifications Master Toggle:** ON/OFF. When OFF, no email notifications are sent (transactional emails like password reset are exempt). Default: ON.
3. **Quiet Hours:**
   - Toggle: Enable Quiet Hours (default: OFF).
   - Time pickers: "From" and "To" (e.g., 10:00 PM to 7:00 AM).
   - Timezone: Auto-detected from device, displayed for confirmation.
   - Behavior during quiet hours: push notifications are silenced (not sent), email notifications are queued and delivered after quiet hours end.
   - Critical override: Notifications tagged as "critical" (e.g., admin removed you from a group) bypass quiet hours.

### C. Per-Category Toggles
Each notification category has independent push and email toggles:

| Category | Description | Push Default | Email Default |
|----------|-------------|-------------|--------------|
| Expense Added | Someone adds an expense involving you | ON | ON |
| Expense Edited | An expense you are part of is modified | ON | OFF |
| Expense Deleted | An expense you are part of is deleted | ON | OFF |
| Settlement Received | Someone settles a debt with you | ON | ON |
| Settlement Sent | Confirmation when you settle a debt | ON | OFF |
| Comment Added | Someone comments on an expense you are part of | ON | OFF |
| Member Joined | A new member joins a group you are in | OFF | OFF |
| Member Left | A member leaves a group you are in | OFF | OFF |
| Payment Reminder | Periodic reminder about outstanding debts | ON | ON |
| Group Created | You are added to a new group | ON | ON |
| Admin Actions | Role changes, member removals, group settings changes | ON | ON |

### D. Per-Group Overrides
1. **Access:** Within each group's settings menu, a "Notification Preferences" option.
2. **Options:**
   - **Mute Group:** Suppresses ALL notifications from this group. A small mute icon appears next to the group name in the group list.
   - **Mute Comments Only:** Suppresses comment notifications from this group but keeps expense and settlement alerts.
   - **Custom:** Override individual category toggles for this specific group.
3. **Hierarchy:** Per-group settings override global per-category settings. If global "Expense Added" is ON but the group is muted, no notification is sent for expenses in that group.

### E. Unsubscribe from Email (One-Click)
1. **Trigger:** User clicks "Unsubscribe" link in the footer of any notification email.
2. **Behavior:** Opens a web page that immediately disables email notifications for that specific category.
3. **Confirmation:** Page shows: "You have been unsubscribed from [Category] emails. Manage all preferences in the app."
4. **Backend:** The unsubscribe link contains a signed token (JWT or HMAC) that identifies the user and category. No login required.

### F. Digest Mode (Future Enhancement — v2)
1. Instead of individual notifications, receive a daily or weekly summary email.
2. Noted here as a future enhancement. Not implemented in v1. Preference toggle is hidden but the database column exists for forward compatibility.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`NotificationPreferencesScreen`**:
  - `Scaffold` with `AppBar` titled "Notification Preferences".
  - Body: `SingleChildScrollView` containing three `Card` sections: Global, Categories, and Groups.
  - Each section has a header with `TextStyle(fontSize: 16, fontWeight: FontWeight.w600)` and a subtle divider below.

- **`PreferenceToggleRow`**:
  - `ListTile` with:
    - Leading: category icon (e.g., `Icons.receipt` for expenses, `Icons.comment` for comments).
    - Title: category name.
    - Trailing: Two `Switch` widgets side by side — one for Push (with a bell icon label), one for Email (with an envelope icon label).
  - Disabled state: grey, non-interactive when the parent master toggle is OFF.

- **`QuietHoursSection`**:
  - `SwitchListTile` to enable/disable.
  - When enabled, two `ListTile` rows appear with `TimePickerDialog` triggers: "Start Time" and "End Time".
  - Timezone display: `Text("Timezone: America/New_York", style: TextStyle(fontSize: 12, color: Colors.grey))` below the time pickers.

- **`GroupMuteChip`**:
  - `Chip` widget with `Icon(Icons.volume_off, size: 14)` and label "Muted".
  - Displayed next to the group name in the group list when the group is muted.
  - Tapping the chip navigates to the group's notification preferences.

- **`EmailUnsubscribePage` (Web)**:
  - Minimal server-rendered HTML page.
  - Shows confirmation message and a link to download/open the app.
  - No authentication required (signed token in URL).

---

## 5. Technical Architecture & Database

### Database Schema (PostgreSQL via Prisma):
```sql
-- Global notification preferences per user
CREATE TABLE notification_preferences (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_hours_start TIME NULL,         -- e.g., '22:00:00'
  quiet_hours_end TIME NULL,           -- e.g., '07:00:00'
  quiet_hours_timezone TEXT NULL,       -- e.g., 'America/New_York'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Per-category notification preferences
CREATE TABLE notification_category_preferences (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,              -- e.g., 'expense_added', 'comment_added'
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(user_id, category)
);

-- Per-group notification overrides
CREATE TABLE notification_group_overrides (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id INT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  muted BOOLEAN NOT NULL DEFAULT FALSE,
  mute_comments_only BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(user_id, group_id)
);

-- Indexes
CREATE INDEX idx_notif_prefs_user ON notification_preferences(user_id);
CREATE INDEX idx_notif_cat_prefs_user ON notification_category_preferences(user_id);
CREATE INDEX idx_notif_group_overrides_user ON notification_group_overrides(user_id);
```

### Prisma Schema:
```prisma
model NotificationPreference {
  id                 Int      @id @default(autoincrement())
  userId             Int      @unique @map("user_id")
  pushEnabled        Boolean  @default(true) @map("push_enabled")
  emailEnabled       Boolean  @default(true) @map("email_enabled")
  quietHoursEnabled  Boolean  @default(false) @map("quiet_hours_enabled")
  quietHoursStart    String?  @map("quiet_hours_start") @db.Time
  quietHoursEnd      String?  @map("quiet_hours_end") @db.Time
  quietHoursTimezone String?  @map("quiet_hours_timezone")
  createdAt          DateTime @default(now()) @map("created_at")
  updatedAt          DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("notification_preferences")
}

model NotificationCategoryPreference {
  id           Int     @id @default(autoincrement())
  userId       Int     @map("user_id")
  category     String
  pushEnabled  Boolean @default(true) @map("push_enabled")
  emailEnabled Boolean @default(true) @map("email_enabled")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, category])
  @@map("notification_category_preferences")
}

model NotificationGroupOverride {
  id               Int     @id @default(autoincrement())
  userId           Int     @map("user_id")
  groupId          Int     @map("group_id")
  muted            Boolean @default(false)
  muteCommentsOnly Boolean @default(false) @map("mute_comments_only")

  user  User  @relation(fields: [userId], references: [id], onDelete: Cascade)
  group Group @relation(fields: [groupId], references: [id], onDelete: Cascade)

  @@unique([userId, groupId])
  @@map("notification_group_overrides")
}
```

### Backend Endpoints (Node.js Fastify):

#### 1. `GET /api/user/notification-preferences`
- **Purpose:** Retrieve all notification preferences for the authenticated user.
- **Auth:** Requires authenticated user.
- **Response:**
```json
{
  "global": {
    "push_enabled": true,
    "email_enabled": true,
    "quiet_hours_enabled": true,
    "quiet_hours_start": "22:00",
    "quiet_hours_end": "07:00",
    "quiet_hours_timezone": "America/New_York"
  },
  "categories": [
    { "category": "expense_added", "push_enabled": true, "email_enabled": true },
    { "category": "comment_added", "push_enabled": true, "email_enabled": false }
  ],
  "group_overrides": [
    { "group_id": 5, "group_name": "Roommates", "muted": true, "mute_comments_only": false }
  ]
}
```

#### 2. `PUT /api/user/notification-preferences`
- **Purpose:** Update global notification preferences.
- **Request Payload:**
```json
{
  "push_enabled": true,
  "email_enabled": false,
  "quiet_hours_enabled": true,
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "07:00",
  "quiet_hours_timezone": "America/New_York"
}
```
- **Controller Logic:** Upsert the `notification_preferences` record for the user.
- **Response:** `200 OK` with updated preferences.

#### 3. `PUT /api/user/notification-preferences/categories`
- **Purpose:** Update per-category preferences (bulk update).
- **Request Payload:**
```json
{
  "categories": [
    { "category": "expense_added", "push_enabled": true, "email_enabled": true },
    { "category": "comment_added", "push_enabled": false, "email_enabled": false }
  ]
}
```
- **Controller Logic:** Upsert each category preference.
- **Response:** `200 OK`.

#### 4. `PUT /api/groups/:groupId/notification-preferences`
- **Purpose:** Update per-group notification override.
- **Auth:** Must be a member of the group.
- **Request Payload:**
```json
{
  "muted": true,
  "mute_comments_only": false
}
```
- **Controller Logic:** Upsert the `notification_group_overrides` record.
- **Response:** `200 OK`.

#### 5. `GET /api/notifications/unsubscribe?token=...`
- **Purpose:** One-click email unsubscribe from a notification category.
- **Auth:** No login required. Token is a signed JWT containing `{ user_id, category }`.
- **Controller Logic:** Verify token signature. Set `email_enabled = false` for the specified category.
- **Response:** HTML page confirming unsubscription.

### Notification Dispatch Logic (Modified from Story 11):
```typescript
async function shouldSendNotification(
  userId: number,
  category: string,
  groupId: number | null,
  channel: 'push' | 'email'
): Promise<boolean> {
  // 1. Check global master toggle
  const globalPrefs = await prisma.notificationPreference.findUnique({
    where: { userId },
  });

  if (channel === 'push' && globalPrefs?.pushEnabled === false) return false;
  if (channel === 'email' && globalPrefs?.emailEnabled === false) return false;

  // 2. Check quiet hours (push only)
  if (channel === 'push' && globalPrefs?.quietHoursEnabled) {
    const now = getCurrentTimeInTimezone(globalPrefs.quietHoursTimezone);
    if (isWithinQuietHours(now, globalPrefs.quietHoursStart, globalPrefs.quietHoursEnd)) {
      // Check if notification is critical (bypass quiet hours)
      if (!isCriticalCategory(category)) return false;
    }
  }

  // 3. Check per-group override
  if (groupId) {
    const groupOverride = await prisma.notificationGroupOverride.findUnique({
      where: { userId_groupId: { userId, groupId } },
    });

    if (groupOverride?.muted) return false;
    if (groupOverride?.muteCommentsOnly && category === 'comment_added') return false;
  }

  // 4. Check per-category preference
  const categoryPref = await prisma.notificationCategoryPreference.findUnique({
    where: { userId_category: { userId, category } },
  });

  if (categoryPref) {
    if (channel === 'push' && categoryPref.pushEnabled === false) return false;
    if (channel === 'email' && categoryPref.emailEnabled === false) return false;
  }

  return true;
}
```

### Critical Notification Categories (Bypass Quiet Hours):
- `admin_action` — role changes, member removal
- `group_created` — added to a new group
- `account_security` — password changed, suspicious login

### Email Unsubscribe Token:
```typescript
import jwt from 'jsonwebtoken';

function generateUnsubscribeToken(userId: number, category: string): string {
  return jwt.sign({ userId, category }, process.env.UNSUBSCRIBE_SECRET, {
    expiresIn: '90d',
  });
}

function generateUnsubscribeUrl(userId: number, category: string): string {
  const token = generateUnsubscribeToken(userId, category);
  return `${process.env.BASE_URL}/api/notifications/unsubscribe?token=${token}`;
}
```

### Flutter State Management:
```dart
class NotificationPreferencesState {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool quietHoursEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;
  final String? quietHoursTimezone;
  final Map<String, CategoryPreference> categories;
  final Map<int, GroupOverride> groupOverrides;

  // ... constructor, copyWith, fromJson, toJson
}
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
|---|---|---|
| **User disables all notifications** | Both master toggles OFF. User receives nothing. Transactional emails (password reset, account verification) are still sent — these are not "notifications." | Backend distinguishes between notification emails and transactional emails. Transactional emails bypass preference checks. |
| **Quiet hours span midnight** | Start: 10 PM, End: 7 AM. Time check correctly handles the midnight wraparound. | `isWithinQuietHours()` handles `start > end` case: current time is in quiet hours if `now >= start OR now < end`. |
| **User changes timezone** | Quiet hours adjust to new timezone on next check. | Timezone stored with preferences. Device timezone change triggers a preferences sync. |
| **Group muted, then user is removed from the group** | Override record becomes orphan. No impact — the `ON DELETE CASCADE` on `group_id` cleans it up. | Foreign key cascade handles cleanup. |
| **Unsubscribe token expired** | Web page shows: "This link has expired. Please manage your preferences in the app." | JWT expiry check. Graceful error page. |
| **New notification category added in future update** | Defaults to ON for push, OFF for email (conservative default). No row exists in `notification_category_preferences` — code treats missing row as default. | `shouldSendNotification()` returns default values when no category preference record exists. |
| **Queued email during quiet hours — user changes preference before delivery** | Email preference is re-checked at delivery time, not just at queue time. | BullMQ email job re-runs `shouldSendNotification()` before sending. |
| **Concurrent preference updates** | Last write wins. No conflict resolution needed — preferences are user-scoped and single-writer. | Standard upsert behavior. No locking required. |

---

## 7. Final QA Acceptance Criteria
- [ ] Notification Preferences screen is accessible from Settings and displays all three sections (Global, Categories, Groups).
- [ ] Master push toggle OFF stops all push notifications for the user.
- [ ] Master email toggle OFF stops all notification emails (but not transactional emails like password reset).
- [ ] Quiet hours correctly suppress push notifications during the configured window.
- [ ] Critical notifications (admin actions, security alerts) bypass quiet hours.
- [ ] Per-category toggles independently control push and email for each notification type.
- [ ] Muting a group suppresses all notifications from that group.
- [ ] "Mute comments only" suppresses comment notifications but allows expense and settlement notifications.
- [ ] A mute icon appears next to muted groups in the group list.
- [ ] One-click email unsubscribe link in notification emails works without requiring login.
- [ ] Unsubscribe correctly disables only the specific email category, not all emails.
- [ ] Default preferences are created for new users (all push ON, email ON for critical categories, OFF for others).
- [ ] Preferences sync correctly across devices for the same user account.
- [ ] Quiet hours handle midnight-spanning time ranges correctly (e.g., 10 PM to 7 AM).
- [ ] Notification dispatch logic checks preferences in the correct order: global > group override > category.
