import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const defaultColors = [
  '#FF5252', '#FF4081', '#E040FB', '#7C4DFF', '#536DFE', 
  '#448AFF', '#40C4FF', '#18FFFF', '#64FFDA', '#69F0AE',
  '#B2FF59', '#EEFF41', '#FFFF00', '#FFD740', '#FFAB40', '#FF6E40'
];

export default async function analyticsRoutes(fastify: FastifyInstance) {
  
  // GET /api/analytics/groups/:id
  fastify.get('/groups/:id', async (request, reply) => {
    const groupId = Number((request.params as any).id);
    try {
      // Aggregate expenses by category
      const expensesByCategory = await prisma.expense.groupBy({
        by: ['categoryId'],
        where: { groupId, deletedAt: null },
        _sum: { totalAmount: true },
      });
      
      // Fetch category details
      const categories = await prisma.expenseCategory.findMany();
      const categoryMap = Object.fromEntries(categories.map(c => [c.id, c.name]));
      
      const spendingByCategory = expensesByCategory.map((item, idx) => ({
        categoryId: item.categoryId ?? 0,
        categoryName: item.categoryId ? categoryMap[item.categoryId] : 'Uncategorized',
        color: defaultColors[idx % defaultColors.length],
        totalCents: item._sum.totalAmount || 0,
      }));

      // Find who paid the most
      const expensesByPayer = await prisma.expense.groupBy({
        by: ['paidBy'],
        where: { groupId, deletedAt: null },
        _sum: { totalAmount: true },
        orderBy: { _sum: { totalAmount: 'desc' } }
      });
      
      const userIds = expensesByPayer.map(p => p.paidBy);
      const users = await prisma.user.findMany({ where: { id: { in: userIds } } });
      const userMap = Object.fromEntries(users.map(u => [u.id, u.name]));

      const leaderboard = expensesByPayer.map(payer => ({
        userId: payer.paidBy,
        userName: userMap[payer.paidBy] || 'Unknown',
        totalPaidCents: payer._sum.totalAmount || 0
      }));

      return reply.send({ success: true, data: { spendingByCategory, leaderboard } });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, error: 'Failed to fetch group analytics' });
    }
  });

  // GET /api/analytics/personal?range=ytd
  fastify.get('/personal', async (request, reply) => {
    const userId = (request as any).userId;
    const { range } = request.query as any;

    try {
      let startDate = new Date();
      if (range === 'ytd') {
        startDate = new Date(new Date().getFullYear(), 0, 1);
      } else if (range === 'month') {
        startDate = new Date();
        startDate.setMonth(startDate.getMonth() - 1);
      } else {
        startDate = new Date(0); // all time
      }

      // Aggregate personal spending timeline
      const splits = await prisma.expenseSplit.findMany({
        where: {
          userId,
          expense: {
            deletedAt: null,
            createdAt: { gte: startDate }
          }
        },
        include: { expense: true },
        orderBy: { expense: { createdAt: 'asc' } }
      });

      let cumulativeDebt = 0;
      const timeline = splits.map(split => {
         const debtDelta = split.owedAmount - split.paidAmount;
         cumulativeDebt += debtDelta;
         return {
           date: split.expense.createdAt,
           cumulativeDebtCents: cumulativeDebt
         };
      });

      return reply.send({ success: true, data: { timeline } });
    } catch(e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, error: 'Failed to fetch personal analytics' });
    }
  });
}
