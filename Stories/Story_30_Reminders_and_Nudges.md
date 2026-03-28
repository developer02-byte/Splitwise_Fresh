# Story 37: Reminders & Nudges - Detailed Execution Plan

## 1. Core Objective & Philosophy
Allow users to politely remind friends about outstanding debts. "Remind Bob to pay you $50" — delivered via push notification and email, with anti-spam protections. Reminders are a social feature that must balance utility against annoyance. The system defaults to restraint: cooldowns, daily limits, and mute controls ensure no user feels harassed.

---

## 2. Target Persona & Motivation
- **Alice (The Creditor):** Has been owed $50 by Bob for two weeks. She does not want to send an awkward text — she wants a clean, in-app nudge that feels built into the system, not personal nagging.
- **Bob (The Debtor):** Genuinely forgot about the debt. A push notification with a one-tap "Settle Up" button makes it easy to resolve immediately.
- **Charlie (The Frequent Splitter):** Splits expenses with 10+ people. Wants auto-reminders enabled so he does not have to manually nudge everyone every week.
- **Diana (The Over-Reminded):** Gets too many reminders from a particular person. Wants to mute reminders from that person without blocking them entirely.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Manual Reminder Flow
1. **Trigger:** Alice opens her friend balance screen with Bob. She sees: "Bob owes you $50.00".
2. **Action:** A "Send Reminder" button (outline style, bell icon) appears below the balance amount.
3. **Confirmation:** Alice taps the button. A dialog appears: "Send Bob a reminder about $50.00?" with "Cancel" and "Confirm" buttons.
4. **System processing:** Alice taps "Confirm". The system:
   - Creates a `reminder` record in the database.
   - Enqueues a BullMQ job to deliver the reminder via three channels.
5. **Delivery (Push):** Bob receives a push notification: "Alice is reminding you about $50.00". Tapping opens the app deep-linked to the Settle Up screen with Alice.
6. **Delivery (Email):** If Bob has email notifications enabled, he receives an email:
   - Subject: "Reminder: You owe Alice $50.00"
   - Body: Friendly message with a deep link to Settle Up in the app.
7. **Delivery (In-App):** A notification appears in Bob's in-app notification center: "Alice is reminding you about $50.00" with a "Settle Up" action button.
8. **Alice's UI update:** The "Send Reminder" button changes to a disabled state showing "Reminded Mar 25" with a muted bell icon.

### B. Cooldown Enforcement
1. **Trigger:** Alice tries to remind Bob again 1 day after the last reminder.
2. **UI state:** The "Send Reminder" button is disabled (grayed out).
3. **Tooltip:** Long-pressing the disabled button shows: "Reminder sent 1 day ago. You can send another reminder in 2 days."
4. **Backend enforcement:** Even if the frontend is bypassed, `POST /api/reminders` returns `429 Too Many Requests` with `{ "error": "Cooldown period active", "nextAllowedAt": "2026-03-28T..." }`.

### C. Daily Limit Enforcement
1. **Trigger:** Alice has sent reminders to 10 different people today and tries to send an 11th.
2. **Backend:** `POST /api/reminders` returns `429 Too Many Requests` with `{ "error": "Daily reminder limit reached (10/10)", "resetsAt": "2026-03-26T00:00:00Z" }`.
3. **UI:** A snackbar appears: "Daily reminder limit reached. Try again tomorrow."

### D. Muting Reminders from a Specific Person
1. **Trigger:** Bob is tired of Alice's reminders. He opens Settings > Notification Preferences > Reminder Settings.
2. **Action:** Bob sees a list of people who have sent him reminders. He taps "Mute" next to Alice.
3. **System state:** `POST /api/reminders/mute` creates a mute record. Future reminders from Alice are silently suppressed (Alice still sees "Reminder sent" to avoid social awkwardness, but Bob receives nothing).
4. **Unmute:** Bob can unmute Alice at any time from the same settings screen.

### E. Auto-Reminders (Optional Feature)
1. **Trigger:** Alice opens Settings > Reminders > Auto-Remind.
2. **Configuration:**
   - Toggle: "Auto-remind weekly" — ON/OFF.
   - Threshold: "For debts over $" — numeric input, default $10.00.
   - Day: "Send on" — dropdown: Monday (default), Tuesday, ..., Sunday.
3. **System state:** `PUT /api/user/reminder-preferences` saves the configuration.
4. **BullMQ recurring job:** Runs every day at 9:00 AM UTC. For each user with auto-remind enabled:
   - Checks current day vs. configured day.
   - Converts 9:00 AM to user's timezone.
   - Finds all outstanding debts owed TO this user above the threshold.
   - For each debtor: checks cooldown (3-day rule). If cooldown has passed, sends reminder.
   - Skips muted pairs.
5. **Alice sees:** In her reminder history, auto-sent reminders are labeled "Auto-reminder sent Mar 25".

### F. Debt Settled After Reminder Sent
1. **Scenario:** Alice sends Bob a reminder at 2:00 PM. Bob settles the debt at 2:05 PM. At 2:10 PM, Bob opens the push notification.
2. **Behavior:** The deep link opens the Settle Up screen, which now shows "$0.00 — Settled". A message reads: "This debt has been settled."
3. **No confusion:** The reminder notification in Bob's notification center is updated with a "Settled" badge.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Send Reminder Button
```dart
// Active state — reminder can be sent
OutlinedButton.icon(
  onPressed: _canSendReminder ? _showReminderConfirmation : null,
  icon: const Icon(Icons.notifications_active, size: 18),
  label: const Text('Send Reminder'),
  style: OutlinedButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary,
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    minimumSize: const Size(44, 44),
  ),
)

// Disabled state — cooldown active
Tooltip(
  message: 'Reminder sent ${_daysSinceLastReminder} days ago. '
           'You can send another in ${_daysUntilNextReminder} days.',
  child: OutlinedButton.icon(
    onPressed: null,
    icon: const Icon(Icons.notifications_off, size: 18),
    label: Text('Reminded ${formatDate(lastReminder.sentAt)}'),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.grey,
      side: const BorderSide(color: Colors.grey),
      minimumSize: const Size(44, 44),
    ),
  ),
)
```

### Reminder Confirmation Dialog
```dart
AlertDialog(
  title: const Text('Send Reminder'),
  content: Text('Send ${recipientName} a reminder about '
                '${formatCurrency(amount, currency)}?'),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _sendReminder();
      },
      child: const Text('Confirm'),
    ),
  ],
)
```

### Bob's Notification Card (In Notification Center)
```dart
Card(
  child: ListTile(
    leading: CircleAvatar(child: Icon(Icons.notifications)),
    title: Text('${senderName} is reminding you about '
                '${formatCurrency(amount, currency)}'),
    subtitle: Text(formatRelativeDate(reminder.sentAt)),
    trailing: ElevatedButton(
      onPressed: () => _navigateToSettleUp(senderId, groupId),
      style: ElevatedButton.styleFrom(minimumSize: const Size(44, 44)),
      child: const Text('Settle Up'),
    ),
  ),
)
```

### Auto-Reminder Settings Screen
- **`AutoReminderToggle`**: A `SwitchListTile` with label "Auto-remind weekly".
- **`ThresholdInput`**: A `TextFormField` with prefix "$", numeric keyboard, default "10.00".
- **`DaySelector`**: A `DropdownButton<String>` with days of the week, default "Monday".
- **`ReminderHistory`**: A `ListView` showing past sent reminders with dates and statuses.

### Mute Reminders Screen
- **`MutedRemindersScreen`**: A list of users who have been muted for reminders.
- Each entry: avatar + name + "Unmute" `TextButton`.
- Empty state: "You haven't muted anyone. If someone sends too many reminders, you can mute them here."

---

## 5. Technical Architecture & Database

### Database Schema
```sql
CREATE TABLE reminders (
    id SERIAL PRIMARY KEY,
    sender_id INT NOT NULL REFERENCES users(id),
    recipient_id INT NOT NULL REFERENCES users(id),
    amount INT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    group_id INT NULL REFERENCES groups(id),
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivery_status VARCHAR(20) DEFAULT 'sent'
        CHECK (delivery_status IN ('sent', 'delivered', 'failed')),
    is_auto BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reminders_sender ON reminders(sender_id);
CREATE INDEX idx_reminders_recipient ON reminders(recipient_id);
CREATE INDEX idx_reminders_sender_recipient ON reminders(sender_id, recipient_id, sent_at);

CREATE TABLE reminder_mutes (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    muted_sender_id INT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, muted_sender_id)
);

CREATE TABLE reminder_preferences (
    user_id INT PRIMARY KEY REFERENCES users(id),
    auto_remind_enabled BOOLEAN DEFAULT FALSE,
    auto_remind_threshold INT DEFAULT 1000,
    auto_remind_day VARCHAR(10) DEFAULT 'monday'
        CHECK (auto_remind_day IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Prisma Schema
```prisma
model Reminder {
  id             Int      @id @default(autoincrement())
  senderId       Int      @map("sender_id")
  recipientId    Int      @map("recipient_id")
  amount         Int
  currency       String   @default("USD") @db.VarChar(3)
  groupId        Int?     @map("group_id")
  sentAt         DateTime @default(now()) @map("sent_at")
  deliveryStatus String   @default("sent") @map("delivery_status") @db.VarChar(20)
  isAuto         Boolean  @default(false) @map("is_auto")
  createdAt      DateTime @default(now()) @map("created_at")

  sender         User     @relation("ReminderSender", fields: [senderId], references: [id])
  recipient      User     @relation("ReminderRecipient", fields: [recipientId], references: [id])
  group          Group?   @relation(fields: [groupId], references: [id])

  @@index([senderId, recipientId, sentAt])
  @@map("reminders")
}

model ReminderMute {
  id            Int      @id @default(autoincrement())
  userId        Int      @map("user_id")
  mutedSenderId Int      @map("muted_sender_id")
  createdAt     DateTime @default(now()) @map("created_at")

  user          User     @relation("MuteOwner", fields: [userId], references: [id])
  mutedSender   User     @relation("MutedSender", fields: [mutedSenderId], references: [id])

  @@unique([userId, mutedSenderId])
  @@map("reminder_mutes")
}

model ReminderPreference {
  userId              Int      @id @map("user_id")
  autoRemindEnabled   Boolean  @default(false) @map("auto_remind_enabled")
  autoRemindThreshold Int      @default(1000) @map("auto_remind_threshold")
  autoRemindDay       String   @default("monday") @map("auto_remind_day") @db.VarChar(10)
  updatedAt           DateTime @default(now()) @updatedAt @map("updated_at")

  user                User     @relation(fields: [userId], references: [id])

  @@map("reminder_preferences")
}
```

### API Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/api/reminders` | Send a manual reminder |
| `GET` | `/api/reminders/sent` | List reminders sent by current user |
| `GET` | `/api/reminders/received` | List reminders received by current user |
| `GET` | `/api/reminders/cooldown/:recipientId` | Check cooldown status for a specific recipient |
| `POST` | `/api/reminders/mute` | Mute reminders from a specific sender |
| `DELETE` | `/api/reminders/mute/:senderId` | Unmute reminders from a specific sender |
| `GET` | `/api/reminders/mutes` | List all muted senders |
| `GET` | `/api/user/reminder-preferences` | Get auto-reminder preferences |
| `PUT` | `/api/user/reminder-preferences` | Update auto-reminder preferences |

### Request/Response: `POST /api/reminders`

**Request:**
```json
{
  "recipientId": 2,
  "groupId": 1
}
```
The `amount` and `currency` are calculated server-side from the current balance between sender and recipient (optionally scoped to the group).

**Success Response (201):**
```json
{
  "data": {
    "id": 42,
    "recipientId": 2,
    "recipientName": "Bob Smith",
    "amount": 5000,
    "currency": "USD",
    "sentAt": "2026-03-25T14:30:00Z",
    "deliveryStatus": "sent"
  }
}
```

**Cooldown Error Response (429):**
```json
{
  "error": "Cooldown period active",
  "lastSentAt": "2026-03-23T10:00:00Z",
  "nextAllowedAt": "2026-03-26T10:00:00Z"
}
```

**Daily Limit Error Response (429):**
```json
{
  "error": "Daily reminder limit reached (10/10)",
  "resetsAt": "2026-03-26T00:00:00Z"
}
```

### Backend Service: `src/services/reminder.service.ts`
```typescript
import { prisma } from '../lib/prisma';
import { reminderQueue } from '../queues/reminder.queue';

const COOLDOWN_DAYS = 3;
const DAILY_LIMIT = 10;

export async function sendReminder(senderId: number, recipientId: number, groupId?: number) {
  // 1. Verify sender is not reminding themselves
  if (senderId === recipientId) {
    throw new AppError(400, 'Cannot send a reminder to yourself');
  }

  // 2. Check cooldown
  const lastReminder = await prisma.reminder.findFirst({
    where: { senderId, recipientId },
    orderBy: { sentAt: 'desc' },
  });

  if (lastReminder) {
    const cooldownEnd = new Date(lastReminder.sentAt);
    cooldownEnd.setDate(cooldownEnd.getDate() + COOLDOWN_DAYS);
    if (new Date() < cooldownEnd) {
      throw new AppError(429, 'Cooldown period active', {
        lastSentAt: lastReminder.sentAt,
        nextAllowedAt: cooldownEnd,
      });
    }
  }

  // 3. Check daily limit
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayCount = await prisma.reminder.count({
    where: { senderId, sentAt: { gte: todayStart } },
  });

  if (todayCount >= DAILY_LIMIT) {
    const tomorrow = new Date(todayStart);
    tomorrow.setDate(tomorrow.getDate() + 1);
    throw new AppError(429, `Daily reminder limit reached (${todayCount}/${DAILY_LIMIT})`, {
      resetsAt: tomorrow,
    });
  }

  // 4. Calculate current balance
  const balance = await calculateBalance(senderId, recipientId, groupId);
  if (balance.amount <= 0) {
    throw new AppError(400, 'This person does not owe you money');
  }

  // 5. Check if recipient has muted sender
  const isMuted = await prisma.reminderMute.findUnique({
    where: { userId_mutedSenderId: { userId: recipientId, mutedSenderId: senderId } },
  });

  // 6. Create reminder record
  const reminder = await prisma.reminder.create({
    data: {
      senderId,
      recipientId,
      amount: balance.amount,
      currency: balance.currency,
      groupId,
      deliveryStatus: isMuted ? 'sent' : 'sent', // Always show 'sent' to sender
    },
  });

  // 7. Deliver (skip if muted)
  if (!isMuted) {
    await reminderQueue.add('deliver-reminder', {
      reminderId: reminder.id,
      senderId,
      recipientId,
      amount: balance.amount,
      currency: balance.currency,
      groupId,
    });
  }

  return reminder;
}
```

### BullMQ Reminder Worker: `src/workers/reminder.worker.ts`
```typescript
import { Worker } from 'bullmq';
import { sendPushNotification } from '../services/push.service';
import { sendEmail } from '../services/email.service';
import { prisma } from '../lib/prisma';

const reminderWorker = new Worker('reminders', async (job) => {
  const { reminderId, senderId, recipientId, amount, currency, groupId } = job.data;

  const sender = await prisma.user.findUniqueOrThrow({ where: { id: senderId } });
  const recipient = await prisma.user.findUniqueOrThrow({ where: { id: recipientId } });
  const formattedAmount = formatCurrency(amount, currency);

  // Push notification
  const devices = await prisma.userDevice.findMany({ where: { userId: recipientId } });
  for (const device of devices) {
    await sendPushNotification(device.fcmToken, {
      title: 'Payment Reminder',
      body: `${sender.name} is reminding you about ${formattedAmount}`,
      data: { type: 'reminder', senderId: String(senderId), groupId: String(groupId || '') },
    });
  }

  // Email notification (if enabled)
  const emailPref = await prisma.notificationPreference.findFirst({
    where: { userId: recipientId, notificationType: 'payment_reminder' },
  });
  if (!emailPref || emailPref.emailEnabled) {
    await sendEmail({
      to: recipient.email,
      subject: `Reminder: You owe ${sender.name} ${formattedAmount}`,
      template: 'payment-reminder',
      data: { senderName: sender.name, amount: formattedAmount, settleUpUrl: buildDeepLink(senderId, groupId) },
    });
  }

  // In-app notification
  await prisma.notification.create({
    data: {
      userId: recipientId,
      title: 'Payment Reminder',
      body: `${sender.name} is reminding you about ${formattedAmount}`,
      referenceType: 'payment_reminder',
      referenceId: reminderId,
    },
  });

  // Update delivery status
  await prisma.reminder.update({
    where: { id: reminderId },
    data: { deliveryStatus: 'delivered' },
  });
}, { connection: redisConnection });
```

### Auto-Reminder BullMQ Recurring Job
```typescript
import { Queue } from 'bullmq';

const autoReminderQueue = new Queue('auto-reminders', { connection: redisConnection });

// Schedule: runs daily at 09:00 UTC
await autoReminderQueue.add('process-auto-reminders', {}, {
  repeat: { pattern: '0 9 * * *' },
});

// Worker
const autoReminderWorker = new Worker('auto-reminders', async () => {
  const usersWithAutoRemind = await prisma.reminderPreference.findMany({
    where: { autoRemindEnabled: true },
    include: { user: true },
  });

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();

  for (const pref of usersWithAutoRemind) {
    if (pref.autoRemindDay !== today) continue;

    const debts = await getOutstandingDebtsOwedTo(pref.userId);

    for (const debt of debts) {
      if (debt.amount < pref.autoRemindThreshold) continue;

      // Check cooldown
      const canSend = await checkCooldown(pref.userId, debt.debtorId);
      if (!canSend) continue;

      // Check mute
      const isMuted = await prisma.reminderMute.findUnique({
        where: {
          userId_mutedSenderId: { userId: debt.debtorId, mutedSenderId: pref.userId },
        },
      });
      if (isMuted) continue;

      await sendReminder(pref.userId, debt.debtorId, debt.groupId);
    }
  }
}, { connection: redisConnection });
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Debt settled before Bob sees reminder** | Bob settles the $50 debt at 2:05 PM. At 2:10 PM he opens the reminder notification. | Deep link opens Settle Up screen showing $0.00 with "This debt has been settled" message. No error. |
| **Remind for very small amount ($0.50)** | Alice owes Bob $0.50. Bob taps "Send Reminder". | Reminder is sent normally. No minimum threshold for manual reminders. Auto-reminders have a configurable threshold (default $10). |
| **Reminder to deleted account** | Alice sends a reminder to Bob, but Bob deleted his account since the balance was calculated. | `POST /api/reminders` returns `404 Not Found: Recipient account no longer exists`. Balance is written off per Story 10 account deletion rules. |
| **Timezone for auto-reminders** | Alice is in UTC+9 (Tokyo). Auto-remind is set to Monday 9 AM. | The job converts "Monday 9 AM" to Alice's timezone. If it is Monday 9 AM in Tokyo (Sunday midnight UTC), the job fires at the correct time. |
| **Remind yourself** | Alice somehow tries to POST a reminder to herself. | Backend validates `senderId !== recipientId`. Returns `400 Bad Request: Cannot send a reminder to yourself`. |
| **Balance changes between reminder and settlement** | Alice reminds Bob about $50. Bob adds an expense splitting $20 with Alice before settling. Now the balance is $30. | The reminder shows the amount AT THE TIME it was sent ($50). The Settle Up screen shows the CURRENT balance ($30). No confusion — the reminder is historical context. |
| **Muted sender does not know they are muted** | Bob mutes Alice. Alice sends a reminder. | Alice sees "Reminder sent" with a success state. The reminder record is created. But Bob receives no push, no email, and no in-app notification. This avoids social conflict. |
| **Auto-reminder on a holiday** | The recurring job fires on Christmas Day, which is the configured day. | Auto-reminders have no holiday awareness. They fire on the configured day regardless. Users can disable auto-remind temporarily via settings. |
| **Concurrent reminders to same person** | Alice double-taps the Send Reminder button. | Frontend disables the button immediately on first tap (optimistic disable). Backend cooldown check uses a database-level unique constraint on `(sender_id, recipient_id, sent_at::date)` to prevent duplicates within the same second. |
| **10 reminders hit in rapid succession** | Alice sends reminders to 10 different people, then tries an 11th. | The 11th request returns `429`. Counter is based on `sent_at >= today_start` in the `reminders` table. Resets at midnight UTC. |

---

## 7. Final QA Criteria
- [ ] Tapping "Send Reminder" on a friend balance shows a confirmation dialog with the correct amount and recipient name.
- [ ] After confirming, the recipient receives a push notification, email (if enabled), and in-app notification.
- [ ] The push notification deep-links to the Settle Up screen with the correct sender pre-selected.
- [ ] After sending a reminder, the button shows "Reminded [date]" and is disabled for 3 days.
- [ ] Attempting to send a reminder during the 3-day cooldown returns a 429 with the next allowed date.
- [ ] Sending more than 10 reminders in a single day returns a 429 with the reset time.
- [ ] Muting a sender prevents all future reminders from reaching the recipient (push, email, in-app).
- [ ] The muted sender still sees "Reminder sent" — they are not informed of the mute.
- [ ] Auto-reminders fire on the configured day of the week for users who have enabled the feature.
- [ ] Auto-reminders respect the debt threshold — debts below the threshold are skipped.
- [ ] Auto-reminders respect cooldowns and mutes — no spam from automated sends.
- [ ] If a debt is settled before the recipient views the reminder, the Settle Up screen shows the correct $0.00 balance.
- [ ] The reminder amount shown in the notification matches the balance at the time the reminder was sent.
- [ ] Reminder preferences (auto-remind toggle, threshold, day) persist correctly across sessions.
- [ ] A user cannot send a reminder to themselves.
