import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { Readable } from 'stream';

const prisma = new PrismaClient();

export default async function exportRoutes(fastify: FastifyInstance) {
  
  // GET /api/export/user
  fastify.get('/user', async (request, reply) => {
    const userId = (request as any).userId;
    const { format, from, to, groupId } = request.query as any;

    try {
      let fromDate = new Date(0);
      let toDate = new Date('2099-12-31');
      if (from) fromDate = new Date(from);
      if (to) toDate = new Date(to);

      let whereClause: any = {
        userId,
        expense: {
          deletedAt: null,
          createdAt: { gte: fromDate, lte: toDate }
        }
      };

      if (groupId) {
        whereClause.expense.groupId = Number(groupId);
      }

      const splits = await prisma.expenseSplit.findMany({
        where: whereClause,
        include: {
          expense: {
            include: {
              payer: { select: { name: true } },
              group: { select: { name: true } },
              category: { select: { name: true } }
            }
          }
        },
        orderBy: { expense: { createdAt: 'desc' } }
      });

      if (format === 'json') {
        const jsonOutput = splits.map(s => ({
          date: s.expense.createdAt.toISOString(),
          type: 'Expense',
          description: s.expense.title,
          totalAmount: s.expense.totalAmount / 100,
          currency: s.expense.originalCurrency || 'USD',
          paidBy: s.expense.payer?.name || 'Unknown',
          yourShare: s.owedAmount / 100,
          group: s.expense.group?.name || 'Non-group'
        }));
        
        reply.header('Content-Type', 'application/json');
        reply.header('Content-Disposition', `attachment; filename="SplitEase_Export_${Date.now()}.json"`);
        return reply.send(jsonOutput);
      }

      // CSV mode via stringify Stream
      reply.header('Content-Type', 'text/csv');
      reply.header('Content-Disposition', `attachment; filename="SplitEase_Export_${Date.now()}.csv"`);

      const csvLines = [];
      csvLines.push('Date,Type,Description,Total Amount,Currency,Paid By,Your Share,Group');

      for (const s of splits) {
        csvLines.push([
          s.expense.createdAt.toISOString().split('T')[0],
          'Expense',
          `"${(s.expense.title || '').replace(/"/g, '""')}"`,
          (s.expense.totalAmount / 100).toFixed(2),
          s.expense.originalCurrency || 'USD',
          `"${(s.expense.payer?.name || 'Unknown').replace(/"/g, '""')}"`,
          (s.owedAmount / 100).toFixed(2),
          `"${(s.expense.group?.name || 'Non-group').replace(/"/g, '""')}"`
        ].join(','));
      }

      return reply.send(csvLines.join('\\n'));
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, error: 'Failed to generate export' });
    }
  });
}
