import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { NotificationService } from '../services/notificationService';

const prisma = new PrismaClient();
import { ExchangeRateService } from '../services/exchange_rate';
import { Decimal } from '@prisma/client/runtime/library';

export default async function expenseRoutes(fastify: FastifyInstance) {
  // ── 1. Create Expense ──────────────────────────────────────────────────────────
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; 
    const { 
      groupId, categoryId, title, totalAmount, originalCurrency, paidBy, splits, idempotencyKey,
      isRecurring, recurrenceType, recurrenceDay, receiptUrl
    } = request.body as any;

    try {
      if (idempotencyKey) {
        const existing = await prisma.expense.findUnique({ where: { idempotencyKey } });
        if (existing) return reply.send({ success: true, data: existing, message: "Idempotent hit" });
      }

      const sumOfSplits = Math.round(splits.reduce((acc: number, split: any) => acc + Number(split.owedAmount), 0));
      const totalAmountRound = Math.round(Number(totalAmount));
      
      if (sumOfSplits !== totalAmountRound) {
        return reply.code(400).send({ success: false, code: 'MATH_MISMATCH', error: `Splits sum (${sumOfSplits}) does not match total amount (${totalAmountRound})` });
      }

      // Currency Conversion logic
      let exchangeRate = 1.0;
      let totalAmountUSD = totalAmount;
      if (originalCurrency && originalCurrency !== 'USD') {
        const rates = await ExchangeRateService.getLatestRates(originalCurrency);
        exchangeRate = rates['USD'] || 1.0;
        totalAmountUSD = Math.round(totalAmount * exchangeRate);
      }

      // Calculate first due date if recurring
      let nextDueDate: Date | null = null;
      if (isRecurring) {
        const now = new Date();
        nextDueDate = new Date(now.getFullYear(), now.getMonth() + 1, recurrenceDay || now.getDate());
      }

      const expense = await prisma.$transaction(async (tx) => {
        const newExpense = await tx.expense.create({
          data: {
            groupId, categoryId, title, totalAmount, originalCurrency, paidBy, idempotencyKey,
            createdBy: userId,
            isRecurring: isRecurring || false,
            recurrenceType,
            recurrenceDay: recurrenceDay ? Number(recurrenceDay) : null,
            receiptImageUrl: receiptUrl,
            exchangeRateSnapshot: new Decimal(exchangeRate),
            nextDueDate,
            splits: {
              create: splits.map((s: any) => ({
                userId: s.userId, owedAmount: s.owedAmount,
                paidAmount: s.userId === paidBy ? totalAmount : 0,
                adjustmentAmount: s.adjustmentAmount || 0,
                shareCount: s.shareCount || 1
              }))
            }
          },
          include: { splits: true }
        });

        // Add balances
        for (const split of newExpense.splits) {
          if (split.userId === paidBy) continue;
          const owedUSD = Math.round(split.owedAmount * exchangeRate);
          await tx.balance.upsert({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: paidBy } },
            update: { netBalance: { decrement: owedUSD } },
            create: { userId: split.userId, counterpartId: paidBy, netBalance: -owedUSD }
          });
          await tx.balance.upsert({
            where: { userId_counterpartId: { userId: paidBy, counterpartId: split.userId } },
            update: { netBalance: { increment: owedUSD } },
            create: { userId: paidBy, counterpartId: split.userId, netBalance: owedUSD }
          });
        }
        return newExpense;
      });

      // ── Trigger Notifications ──────────────────────────────────────────────────
      try {
        const payerUser = await prisma.user.findUnique({ where: { id: paidBy } });
        const payerName = payerUser?.name || 'Someone';

        const notifications = expense.splits
          .filter(s => s.userId !== paidBy)
          .map(s => ({
            recipientId: s.userId,
            referenceType: 'expense' as const,
            title: 'New Expense',
            message: `${payerName} added "${title}"`,
            referenceId: expense.id
          }));
        
        if (notifications.length > 0) {
          await NotificationService.notifyBulk(notifications);
        }
      } catch (err) {
        fastify.log.error({ err }, 'Notification failed for new expense');
      }

      return reply.send({ success: true, data: expense });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // ── 2. Delete Expense (Soft Delete + Reversal) ────────────────────────────────
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as any;
    const userId = (request as any).userId;

    try {
      const expense = await prisma.expense.findUnique({
        where: { id: Number(id) }, include: { splits: true }
      });

      if (!expense || expense.deletedAt) {
        return reply.code(404).send({ success: false, error: 'Not found' });
      }

      if (expense.paidBy !== userId && expense.createdBy !== userId) {
        return reply.code(403).send({ success: false, error: 'Unauthorized to delete' });
      }

      await prisma.$transaction(async (tx) => {
        await tx.expense.update({
          where: { id: expense.id },
          data: { deletedAt: new Date() }
        });

        for (const split of expense.splits) {
          if (split.userId === expense.paidBy) continue;
          const owedUSD = Math.round(split.owedAmount * Number(expense.exchangeRateSnapshot));
          await tx.balance.update({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: expense.paidBy } },
            data: { netBalance: { increment: owedUSD } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: expense.paidBy, counterpartId: split.userId } },
            data: { netBalance: { decrement: owedUSD } }
          });
        }
      });

      return reply.send({ success: true, message: 'Expense deleted' });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'Failed to delete' });
    }
  });

  // ── 3. Edit Expense ────────────────────────────────────────────────────────────
  fastify.patch('/:id', async (request, reply) => {
    const { id } = request.params as any;
    const userId = (request as any).userId;
    const { title, totalAmount, originalCurrency, paidBy, splits, receiptUrl } = request.body as any;

    try {
      const oldExpense = await prisma.expense.findUnique({
        where: { id: Number(id) }, include: { splits: true }
      });

      if (!oldExpense || oldExpense.deletedAt) return reply.code(404).send({ success: false });

      const sumOfSplits = Math.round(splits.reduce((acc: number, split: any) => acc + Number(split.owedAmount), 0));
      const totalAmountRound = Math.round(Number(totalAmount));
      
      if (sumOfSplits !== totalAmountRound) {
        return reply.code(400).send({ success: false, error: 'Math Mismatch' });
      }

      // Currency Conversion logic
      let exchangeRate = 1.0;
      if (originalCurrency && originalCurrency !== 'USD') {
        const rates = await ExchangeRateService.getLatestRates(originalCurrency);
        exchangeRate = rates['USD'] || 1.0;
      }

      await prisma.$transaction(async (tx) => {
        for (const split of oldExpense.splits) {
          if (split.userId === oldExpense.paidBy) continue;
          const oldOwedUSD = Math.round(split.owedAmount * Number(oldExpense.exchangeRateSnapshot));
          await tx.balance.update({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: oldExpense.paidBy } },
            data: { netBalance: { increment: oldOwedUSD } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: oldExpense.paidBy, counterpartId: split.userId } },
            data: { netBalance: { decrement: oldOwedUSD } }
          });
        }

        await tx.expenseSplit.deleteMany({ where: { expenseId: oldExpense.id } });
        
        await tx.expense.update({
          where: { id: oldExpense.id },
          data: {
            title, totalAmount, originalCurrency, paidBy,
            receiptImageUrl: receiptUrl,
            exchangeRateSnapshot: new Decimal(exchangeRate),
            splits: {
              create: splits.map((s: any) => ({
                userId: s.userId, owedAmount: s.owedAmount,
                paidAmount: s.userId === paidBy ? totalAmount : 0
              }))
            }
          }
        });

        for (const newSplit of splits) {
          if (newSplit.userId === paidBy) continue;
          const newOwedUSD = Math.round(newSplit.owedAmount * exchangeRate);
          await tx.balance.update({
            where: { userId_counterpartId: { userId: newSplit.userId, counterpartId: paidBy } },
            data: { netBalance: { decrement: newOwedUSD } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: paidBy, counterpartId: newSplit.userId } },
            data: { netBalance: { increment: newOwedUSD } }
          });
        }
      });

      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/expenses/:id - Expense Details
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const expense = await prisma.expense.findUnique({
        where: { id: Number(id) },
        include: {
          splits: { include: { user: { select: { id: true, name: true, avatarUrl: true } } } },
          payer: { select: { id: true, name: true, avatarUrl: true } },
          category: true
        }
      });
      if (!expense) return reply.code(404).send({ success: false });
      return reply.send({ success: true, data: expense });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // POST /api/expenses/ocr - Story 21: Receipt OCR (Simulated)
  fastify.post('/ocr', async (request, reply) => {
    // In a real app, you'd use Tesseract or AWS TextTract/Google Vision here.
    // For Story 21, we simulate a smart extraction.
    return reply.send({
      success: true,
      data: {
        title: 'Dinner at Blue Oak',
        totalAmount: 12450, // $124.50
        categoryId: 1, // Food
        confidence: 0.95
      }
    });
  });

  // GET /api/expenses/:id/comments - List comments
  fastify.get('/:id/comments', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const comments = await prisma.expenseComment.findMany({
        where: { expenseId: Number(id) },
        include: { user: { select: { id: true, name: true, avatarUrl: true } } },
        orderBy: { createdAt: 'asc' }
      });
      return reply.send({ success: true, data: comments });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // POST /api/expenses/:id/comments - Add comment
  fastify.post('/:id/comments', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;
    const { text } = request.body as any;

    try {
      const comment = await prisma.expenseComment.create({
        data: {
          expenseId: Number(id),
          userId,
          commentText: text
        }
      });

      return reply.send({ success: true, data: comment });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // POST /api/expenses/cron/recurring - Story 34: Auto-Generate Recurring
  fastify.post('/cron/recurring', async (request, reply) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    try {
      const templates = await prisma.expense.findMany({
        where: {
          isRecurring: true,
          nextDueDate: { lte: today },
          deletedAt: null
        },
        include: { splits: true }
      });

      let generatedCount = 0;
      for (const t of templates) {
        await prisma.$transaction(async (tx) => {
          // 1. Create the new occurrence
          const nextOccurDate = t.nextDueDate || today;
          const newExpense = await tx.expense.create({
            data: {
              title: `${t.title} (${nextOccurDate.toLocaleString('default', { month: 'long' })})`,
              totalAmount: t.totalAmount,
              originalCurrency: t.originalCurrency,
              groupId: t.groupId,
              categoryId: t.categoryId,
              paidBy: t.paidBy,
              createdBy: t.createdBy,
              recurringTemplateId: t.id, // Linked to template
              splits: {
                create: t.splits.map(s => ({
                  userId: s.userId,
                  owedAmount: s.owedAmount,
                  paidAmount: s.userId === t.paidBy ? t.totalAmount : 0
                }))
              }
            }
          });

          // 2. Update balances for the new occurrence
          for (const s of t.splits) {
             if (s.userId === t.paidBy) continue;
             await tx.balance.upsert({
               where: { userId_counterpartId: { userId: s.userId, counterpartId: t.paidBy } },
               update: { netBalance: { decrement: s.owedAmount } },
               create: { userId: s.userId, counterpartId: t.paidBy, netBalance: -s.owedAmount }
             });
             await tx.balance.upsert({
               where: { userId_counterpartId: { userId: t.paidBy, counterpartId: s.userId } },
               update: { netBalance: { increment: s.owedAmount } },
               create: { userId: t.paidBy, counterpartId: s.userId, netBalance: s.owedAmount }
             });
          }

          // 3. Increment next due date on template
          const nextDate = new Date(t.nextDueDate || today);
          if (t.recurrenceType === 'monthly') {
            nextDate.setMonth(nextDate.getMonth() + 1);
          } else if (t.recurrenceType === 'weekly') {
            nextDate.setDate(nextDate.getDate() + 7);
          }
          // handle 'custom' etc...

          await tx.expense.update({
            where: { id: t.id },
            data: { nextDueDate: nextDate }
          });
          generatedCount++;
        });
      }

      return reply.send({ success: true, message: `Generated ${generatedCount} expenses.` });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false });
    }
  });

}
