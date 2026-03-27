import { Queue, Worker, Job } from 'bullmq';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Redis connection config (required by BullMQ)
const redisConnection = {
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: Number(process.env.REDIS_PORT) || 6379,
};

// ─────────────────────────────────────────────
// 1. QUEUE DEFINITIONS
// ─────────────────────────────────────────────

export const exchangeRateQueue = new Queue('exchange-rate-refresh', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 60000 },
    removeOnComplete: 100,
    removeOnFail: 50,
  }
});

export const recurringExpenseQueue = new Queue('recurring-expense-spawn', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 30000 },
    removeOnComplete: 100,
    removeOnFail: 50,
  }
});

export const emailQueue = new Queue('email-dispatch', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 5000 },
  }
});

export const reminderQueue = new Queue('reminder-nudge', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 2,
    removeOnComplete: 50,
  }
});

// ─────────────────────────────────────────────
// 2. CRON SCHEDULER (Repeatable Jobs)
// ─────────────────────────────────────────────
export async function scheduleCronJobs() {
  // Refresh exchange rates every 6 hours (as per Jobs_Contract.md)
  await exchangeRateQueue.add(
    'refresh-rates',
    { triggeredBy: 'cron' },
    { repeat: { pattern: '0 */6 * * *' } }
  );

  // Spawn recurring expenses every night at midnight UTC
  await recurringExpenseQueue.add(
    'spawn-due-expenses',
    { triggeredBy: 'cron' },
    { repeat: { pattern: '0 0 * * *' } }
  );

  console.log('[BullMQ] CRON jobs scheduled: ExchangeRates (6h), Recurring (daily midnight)');
}
