import { Worker, Job } from 'bullmq';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const redisConnection = {
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: Number(process.env.REDIS_PORT) || 6379,
};

// Supported base currencies for fetching
const BASE_CURRENCIES = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'AUD', 'CAD', 'SGD'];

// ─────────────────────────────────────────────
// WORKER: ExchangeRate Refresh
// Hits ExchangeRate-API every 6 hours
// ─────────────────────────────────────────────
export const exchangeRateWorker = new Worker(
  'exchange-rate-refresh',
  async (job: Job) => {
    console.log(`[ExchangeRateWorker] Starting refresh at ${new Date().toISOString()}`);

    try {
      const API_KEY = process.env.EXCHANGE_RATE_API_KEY;
      
      for (const base of BASE_CURRENCIES) {
        const url = `https://v6.exchangerate-api.com/v6/${API_KEY}/latest/${base}`;
        const response = await fetch(url);
        const data = (await response.json()) as any;

        if (data.result !== 'success') {
          throw new Error(`Bad response for ${base}: ${data['error-type']}`);
        }

        const rates: Record<string, number> = data.conversion_rates;
        const fetchedAt = new Date();

        // Upsert all rate pairs for the current base
        const upserts = Object.entries(rates).map(([toCurrency, rate]) =>
          prisma.exchangeRate.upsert({
            where: { fromCurrency_toCurrency: { fromCurrency: base, toCurrency } },
            update: { rate: rate.toString(), fetchedAt },
            create: { fromCurrency: base, toCurrency, rate: rate.toString(), fetchedAt }
          })
        );

        await Promise.all(upserts);
        console.log(`[ExchangeRateWorker] Updated ${Object.keys(rates).length} rates for ${base}`);
      }

      return { success: true, updatedAt: new Date().toISOString() };
    } catch (e) {
      console.error('[ExchangeRateWorker] Failed:', e);
      throw e; // BullMQ auto-retries based on `attempts` config
    }
  },
  { connection: redisConnection, concurrency: 1 }
);

// ─────────────────────────────────────────────
// WORKER: Recurring Expense Spawner
// Runs at midnight, creates expenses from templates
// ─────────────────────────────────────────────
export const recurringExpenseWorker = new Worker(
  'recurring-expense-spawn',
  async (job: Job) => {
    console.log(`[RecurringWorker] Spawning due expenses at ${new Date().toISOString()}`);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Find all recurring templates due today or overdue
    const dueTemplates = await prisma.expense.findMany({
      where: {
        isRecurring: true,
        recurringTemplateId: null,   // Only top-level templates (not children)
        nextDueDate: { lte: today }, // Due today or earlier (catches missed days)
        deletedAt: null,
      },
      include: { splits: true }
    });

    console.log(`[RecurringWorker] Found ${dueTemplates.length} templates to spawn`);

    for (const template of dueTemplates) {
      try {
        await prisma.$transaction(async (tx) => {
          // 1. Create a new child expense from the template
          await tx.expense.create({
            data: {
              groupId: template.groupId,
              title: template.title,
              totalAmount: template.totalAmount,
              originalCurrency: template.originalCurrency,
              paidBy: template.paidBy,
              categoryId: template.categoryId,
              recurringTemplateId: template.id, // Link back to parent template
              splits: {
                create: template.splits.map(s => ({
                  userId: s.userId,
                  owedAmount: s.owedAmount,
                  paidAmount: s.paidAmount,
                }))
              }
            }
          });

          // 2. Advance nextDueDate on the template (monthly = +1 month)
          const nextDue = new Date(today);
          if (template.recurrenceType === 'monthly') nextDue.setMonth(nextDue.getMonth() + 1);
          else if (template.recurrenceType === 'weekly') nextDue.setDate(nextDue.getDate() + 7);
          else if (template.recurrenceType === 'biweekly') nextDue.setDate(nextDue.getDate() + 14);

          await tx.expense.update({
            where: { id: template.id },
            data: { nextDueDate: nextDue }
          });
        });

        console.log(`[RecurringWorker] Spawned expense from template id=${template.id}`);
      } catch (e) {
        console.error(`[RecurringWorker] Failed for template id=${template.id}:`, e);
      }
    }

    return { spawned: dueTemplates.length };
  },
  { connection: redisConnection, concurrency: 1 }
);
