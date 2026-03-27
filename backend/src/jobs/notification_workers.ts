import { Worker, Job } from 'bullmq';
import { PrismaClient } from '@prisma/client';
import { sendPushNotification } from '../services/firebaseNotification';

const prisma = new PrismaClient();

const redisConnection = {
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: Number(process.env.REDIS_PORT) || 6379,
};

// ─────────────────────────────────────────────
// WORKER: Reminder Nudge (Debt Reminders)
// Debounced — won't spam same recipient twice within 24h
// ─────────────────────────────────────────────
export const reminderWorker = new Worker(
  'reminder-nudge',
  async (job: Job) => {
    const { fromUserId, toUserId, amountCents, currency } = job.data;

    // Anti-spam: Check if we sent a reminder to this person in the last 24h
    const lastReminder = await prisma.notification.findFirst({
      where: {
        recipientId: toUserId,
        referenceType: 'reminder',
        createdAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (lastReminder) {
      console.log(`[ReminderWorker] Skipping user ${toUserId} — already nudged within 24h`);
      return { skipped: true };
    }

    // Fetch device tokens for the recipient
    // In production: stored via separate `device_tokens` table with userId FK
    const deviceTokens: string[] = []; // TODO: fetch from DB

    const displayAmount = `$${(amountCents / 100).toFixed(2)} ${currency}`;

    // Store notification in DB  
    await prisma.notification.create({
      data: {
        recipientId: toUserId,
        title: 'Friendly reminder 👋',
        body: `You owe ${displayAmount}. Tap to settle up!`,
        referenceType: 'reminder',
        referenceId: fromUserId,
      }
    });

    // Send push notification
    await sendPushNotification(
      {
        userId: toUserId,
        title: 'Friendly reminder 👋',
        body: `You owe ${displayAmount}. Tap to settle up!`,
        data: {
          route: '/friends',
          fromUserId: String(fromUserId),
        }
      },
      deviceTokens
    );

    return { sent: true };
  },
  { connection: redisConnection, concurrency: 5 }
);

// ─────────────────────────────────────────────
// WORKER: Email Dispatcher
// ─────────────────────────────────────────────
export const emailWorker = new Worker(
  'email-dispatch',
  async (job: Job) => {
    const { toEmail, subject, template, templateData } = job.data;

    console.log(`[EmailWorker] Sending '${subject}' to ${toEmail} via template '${template}'`);
    // In production: use Resend, SendGrid, or nodemailer
    // await resend.emails.send({ from: 'noreply@splitease.app', to: toEmail, subject, ... });

    await prisma.emailQueue.updateMany({
      where: { toEmail, status: 'pending' },
      data: { status: 'sent', sentAt: new Date(), attempts: { increment: 1 } }
    });

    return { sent: true };
  },
  { connection: redisConnection, concurrency: 10 }
);
