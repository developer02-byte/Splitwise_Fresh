import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { NotificationService } from '../services/notificationService';

const prisma = new PrismaClient();

export default async function expenseRoutes(fastify: FastifyInstance) {
  // ── 1. Create Expense ──────────────────────────────────────────────────────────
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; 
    const { groupId, categoryId, title, totalAmount, originalCurrency, paidBy, splits, idempotencyKey } = request.body as any;

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

      const expense = await prisma.$transaction(async (tx) => {
        const newExpense = await tx.expense.create({
          data: {
            groupId, categoryId, title, totalAmount, originalCurrency, paidBy, idempotencyKey,
            createdBy: userId,
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
          await tx.balance.upsert({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: paidBy } },
            update: { netBalance: { decrement: split.owedAmount } },
            create: { userId: split.userId, counterpartId: paidBy, netBalance: -split.owedAmount }
          });
          await tx.balance.upsert({
            where: { userId_counterpartId: { userId: paidBy, counterpartId: split.userId } },
            update: { netBalance: { increment: split.owedAmount } },
            create: { userId: paidBy, counterpartId: split.userId, netBalance: split.owedAmount }
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
        fastify.log.error('Notification failed for new expense', err);
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
          await tx.balance.update({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: expense.paidBy } },
            data: { netBalance: { increment: split.owedAmount } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: expense.paidBy, counterpartId: split.userId } },
            data: { netBalance: { decrement: split.owedAmount } }
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
    const { title, totalAmount, paidBy, splits } = request.body as any;

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

      await prisma.$transaction(async (tx) => {
        for (const split of oldExpense.splits) {
          if (split.userId === oldExpense.paidBy) continue;
          await tx.balance.update({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: oldExpense.paidBy } },
            data: { netBalance: { increment: split.owedAmount } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: oldExpense.paidBy, counterpartId: split.userId } },
            data: { netBalance: { decrement: split.owedAmount } }
          });
        }

        await tx.expenseSplit.deleteMany({ where: { expenseId: oldExpense.id } });
        
        await tx.expense.update({
          where: { id: oldExpense.id },
          data: {
            title, totalAmount, paidBy,
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
          await tx.balance.update({
            where: { userId_counterpartId: { userId: newSplit.userId, counterpartId: paidBy } },
            data: { netBalance: { decrement: newSplit.owedAmount } }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: paidBy, counterpartId: newSplit.userId } },
            data: { netBalance: { increment: newSplit.owedAmount } }
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
}
