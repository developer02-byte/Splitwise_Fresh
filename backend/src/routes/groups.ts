import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { simplifyDebts, Debt } from '../services/debtSimplification';

const prisma = new PrismaClient();

export default async function groupRoutes(fastify: FastifyInstance) {
  
  // GET /api/groups - List all groups for current user
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const memberships = await prisma.groupMember.findMany({
        where: { userId },
        include: {
          group: {
            include: {
              members: { select: { userId: true, role: true } },
              _count: { select: { expenses: true } }
            }
          }
        }
      });

      const groups = memberships
        .filter(m => m.group.deletedAt === null)
        .map(m => ({
          id: m.group.id,
          name: m.group.name,
          type: m.group.type,
          coverPhotoUrl: m.group.coverPhotoUrl,
          groupCurrency: m.group.groupCurrency,
          memberCount: m.group.members.length,
          expenseCount: m.group._count.expenses,
          createdAt: m.group.createdAt,
          role: m.role,
        }));

      return reply.send({ success: true, data: groups });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // POST /api/groups - Create a Group + Add Members
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; // simulated auth
    const { name, type, membersConfig } = request.body as any;

    try {
      const group = await prisma.group.create({
        data: {
          name,
          type,
          createdBy: userId,
          members: {
            create: [
              { userId, role: 'owner' },
            ]
          }
        },
        include: { members: true }
      });

      return reply.send({ success: true, data: group });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/v1/groups/:id/ledger - High performance virtual scrolling ledger
  fastify.get('/:id/ledger', async (request, reply) => {
    const { id } = request.params as any;
    const { cursor, limit = 50 } = request.query as any;

    try {
      // Fetches expenses sorted by created_at DESC matching DB_Index_Contract.md
      const expenses = await prisma.expense.findMany({
        where: { groupId: Number(id), deletedAt: null },
        take: Number(limit),
        ...(cursor && { cursor: { id: Number(cursor) }, skip: 1 }),
        orderBy: { createdAt: 'desc' },
        include: { payer: { select: { name: true, avatarUrl: true } } }
      });

      return reply.send({ success: true, data: expenses });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/v1/groups/:id/simplify - Debt Simplification
  fastify.get('/:id/simplify', async (request, reply) => {
    const { id } = request.params as any;

    try {
      // 1. Fetch raw balances between all members of this group
      // Assumes balances are restricted / filterable by group, or calculated dynamically 
      // from expense splits within this specific group ID.
      const groupSplits = await prisma.expenseSplit.findMany({
        where: { expense: { groupId: Number(id), deletedAt: null } },
        include: { expense: true }
      });

      const rawDebts: Debt[] = groupSplits.map(s => ({
        fromUserId: s.userId,
        toUserId: s.expense.paidBy,
        amountCents: s.owedAmount
      }));

      // 2. Feed raw graph into Simplification Service
      const simplifiedTransfers = simplifyDebts(rawDebts);

      return reply.send({ success: true, data: simplifiedTransfers });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });
}
