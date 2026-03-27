import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export default async function expenseRoutes(fastify: FastifyInstance) {
  // ── 1. Create Expense ──────────────────────────────────────────────────────────
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth
    const { groupId, title, totalAmount, originalCurrency, paidBy, splits, idempotencyKey } = request.body as any;

    try {
      if (idempotencyKey) {
        const existing = await prisma.expense.findUnique({ where: { idempotencyKey } });
        if (existing) return reply.send({ success: true, data: existing, message: "Idempotent hit" });
      }

      const sumOfSplits = splits.reduce((acc: number, split: any) => acc + split.owedAmount, 0);
      if (sumOfSplits !== totalAmount) {
        return reply.code(400).send({ success: false, code: 'MATH_MISMATCH', error: `Splits sum does not match` });
      }

      const expense = await prisma.$transaction(async (tx) => {
        const newExpense = await tx.expense.create({
          data: {
            groupId, title, totalAmount, originalCurrency, paidBy, idempotencyKey,
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

      return reply.send({ success: true, data: expense });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // ── 2. Delete Expense (Soft Delete + Reversal) ────────────────────────────────
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as any;
    const userId = (request as any).userId; // Simulated auth

    try {
      const expense = await prisma.expense.findUnique({
        where: { id: Number(id) }, include: { splits: true }
      });

      if (!expense || expense.deletedAt) {
        return reply.code(404).send({ success: false, error: 'Not found' });
      }

      // Check Authorization
      if (expense.paidBy !== userId && expense.createdBy !== userId) {
        return reply.code(403).send({ success: false, error: 'Unauthorized to delete' });
      }

      await prisma.$transaction(async (tx) => {
        // 1. Soft Delete the expense
        await tx.expense.update({
          where: { id: expense.id },
          data: { deletedAt: new Date() }
        });

        // 2. Reverse the balances EXACTLY as they were applied
        for (const split of expense.splits) {
          if (split.userId === expense.paidBy) continue;
          // Refund User (increment what they deducted)
          await tx.balance.update({
            where: { userId_counterpartId: { userId: split.userId, counterpartId: expense.paidBy } },
            data: { netBalance: { increment: split.owedAmount } }
          });
          // Deduct from Payer (decrement what they were credited)
          await tx.balance.update({
            where: { userId_counterpartId: { userId: expense.paidBy, counterpartId: split.userId } },
            data: { netBalance: { decrement: split.owedAmount } }
          });
        }

        // 3. Write Audit Log
        if (typeof (tx as any).auditLog !== 'undefined') {
          await (tx as any).auditLog.create({
            data: { 
              entityId: expense.id, entityType: 'expense', 
              action: 'delete', performedBy: userId 
            }
          });
        }
      });

      return reply.send({ success: true, message: 'Expense deleted and balances reversed' });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'Failed to delete' });
    }
  });

  // ── 3. Edit Expense ────────────────────────────────────────────────────────────
  // Since modifying an expense changes the math entirely:
  // We reverse the OLD splits, then apply the NEW splits atomically.
  fastify.patch('/:id', async (request, reply) => {
    const { id } = request.params as any;
    const userId = (request as any).userId;

    const { title, totalAmount, paidBy, splits } = request.body as any;

    try {
      const oldExpense = await prisma.expense.findUnique({
        where: { id: Number(id) }, include: { splits: true }
      });

      if (!oldExpense || oldExpense.deletedAt) return reply.code(404).send({ success: false });

      const sumOfSplits = splits.reduce((acc: number, split: any) => acc + split.owedAmount, 0);
      if (sumOfSplits !== totalAmount) return reply.code(400).send({ success: false, error: 'Math Mismatch' });

      await prisma.$transaction(async (tx) => {
        // 1. Reverse OLD Balances
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

        // 2. Delete OLD splits & Update Expense Data
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

        // 3. Apply NEW Balances
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
      }, { isolationLevel: 'Serializable' });

      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });
}
