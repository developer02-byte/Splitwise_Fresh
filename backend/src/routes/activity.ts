import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export default async function activityRoutes(fastify: FastifyInstance) {

  // GET /api/v1/activity
  // Returns a unified, cursor-paginated feed of expenses + settlements
  // Supports filters: ?groupId= ?friendId= ?dateFrom= ?dateTo=
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId;

    const {
      cursor,
      limit = 30,
      groupId,
      friendId,
      dateFrom,
      dateTo,
    } = request.query as any;

    try {
      // ── Expenses ──────────────────────────────────────────
      const expenseWhere: any = {
        deletedAt: null,
        splits: { some: { userId } }, // Only expenses relevant to this user
      };
      if (groupId) expenseWhere.groupId = Number(groupId);
      if (dateFrom) expenseWhere.createdAt = { gte: new Date(dateFrom) };
      if (dateTo) expenseWhere.createdAt = { ...(expenseWhere.createdAt || {}), lte: new Date(dateTo) };

      const expenses = await prisma.expense.findMany({
        where: expenseWhere,
        take: Number(limit),
        ...(cursor && { cursor: { id: Number(cursor) }, skip: 1 }),
        orderBy: { createdAt: 'desc' },
        include: {
          payer: { select: { id: true, name: true, avatarUrl: true } },
          splits: { where: { userId }, select: { owedAmount: true } },
        },
      });

      // ── Settlements ───────────────────────────────────────
      const settlementWhere: any = {
        deletedAt: null,
        OR: [{ payerId: userId }, { payeeId: userId }],
      };
      if (groupId) settlementWhere.groupId = Number(groupId);
      if (friendId) {
        settlementWhere.OR = [
          { payerId: userId, payeeId: Number(friendId) },
          { payerId: Number(friendId), payeeId: userId },
        ];
      }

      const settlements = await prisma.settlement.findMany({
        where: settlementWhere,
        take: Number(limit),
        orderBy: { createdAt: 'desc' },
        include: {
          payer: { select: { id: true, name: true, avatarUrl: true } },
          payee: { select: { id: true, name: true, avatarUrl: true } },
        },
      });

      // ── Merge & Sort by createdAt DESC ───────────────────
      const expenseFeed = expenses.map((e: any) => ({
        type: 'expense' as const,
        id: e.id,
        title: e.title,
        amountCents: e.totalAmount,
        currency: e.originalCurrency,
        paidBy: e.payer.name,
        avatarUrl: e.payer.avatarUrl,
        yourShareCents: e.splits[0]?.owedAmount ?? 0,
        youPaid: e.paidBy === userId,
        createdAt: e.createdAt,
      }));

      const settlementFeed = settlements.map((s: any) => ({
        type: 'settlement' as const,
        id: s.id,
        title: s.payerId === userId
          ? `You paid ${s.payee.name}`
          : `${s.payer.name} paid you`,
        amountCents: s.amount,
        currency: s.currency,
        paidBy: s.payer.name,
        avatarUrl: s.payerId === userId ? s.payee.avatarUrl : s.payer.avatarUrl,
        yourShareCents: 0,
        youPaid: s.payerId === userId,
        createdAt: s.createdAt,
      }));

      const merged = [...expenseFeed, ...settlementFeed]
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
        .slice(0, Number(limit));

      const nextCursor = merged.length === Number(limit)
        ? merged[merged.length - 1].id
        : null;

      return reply.send({ success: true, data: { items: merged, hasMore: merged.length === Number(limit), nextCursor } });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });
}
