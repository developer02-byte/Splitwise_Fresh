import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { simplifyDebts, Debt } from '../services/debtSimplification';

const prisma = new PrismaClient();

// Helper to calculate raw debts for a group
async function getGroupRawDebts(groupId: number): Promise<Debt[]> {
  const expenseSplits = await prisma.expenseSplit.findMany({
    where: { expense: { groupId, deletedAt: null } },
    include: { expense: true }
  });

  return expenseSplits
    .filter(s => s.userId !== s.expense.paidBy)
    .map(s => ({
      fromUserId: s.userId,
      toUserId: s.expense.paidBy,
      amountCents: s.owedAmount
    }));
}

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

      const groups = await Promise.all(
        memberships
          .filter(m => m.group.deletedAt === null)
          .map(async m => {
            const activeInvite = await prisma.groupInvitation.findFirst({
              where: { groupId: m.group.id, isRevoked: false, expiresAt: { gt: new Date() } }
            });

            const paidSplits = await prisma.expenseSplit.findMany({
              where: { expense: { groupId: m.group.id, deletedAt: null, paidBy: userId }, userId: { not: userId } }
            });
            const amountOwedToUser = paidSplits.reduce((sum, s) => sum + s.owedAmount, 0);

            const owedSplits = await prisma.expenseSplit.findMany({
              where: { expense: { groupId: m.group.id, deletedAt: null, paidBy: { not: userId } }, userId }
            });
            const amountUserOwes = owedSplits.reduce((sum, s) => sum + s.owedAmount, 0);

            const userBalance = amountOwedToUser - amountUserOwes;

            return {
              id: m.group.id,
              name: m.group.name,
              type: m.group.type,
              coverPhotoUrl: m.group.coverPhotoUrl,
              groupCurrency: m.group.groupCurrency,
              memberCount: m.group.members.length,
              expenseCount: m.group._count.expenses,
              createdAt: m.group.createdAt,
              role: m.role,
              inviteToken: activeInvite?.tokenHash || 'no-token-available',
              userBalance: userBalance,
              simplifiedSettlement: m.group.simplifiedSettlement,
              settlementThreshold: m.group.settlementThreshold
            };
          })
      );

      return reply.send({ success: true, data: groups });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // POST /api/groups - Create a Group + Add Members
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId;
    const { name, type, membersConfig } = request.body as any;

    try {
      const memberData: any[] = [{ userId, role: 'owner' }];
      if (Array.isArray(membersConfig)) {
        for (const memberId of membersConfig) {
          if (memberId !== userId) {
            memberData.push({ userId: memberId, role: 'member' });
          }
        }
      }

      const group = await prisma.group.create({
        data: {
          name,
          type,
          createdBy: userId,
          members: {
            createMany: {
              data: memberData
            }
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

  // GET /api/v1/groups/:id/ledger - High performance Ledger
  fastify.get('/:id/ledger', async (request, reply) => {
    const { id } = request.params as any;
    const { cursor, limit = 50 } = request.query as any;

    try {
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

  // GET /api/v1/groups/:id/balances - Consolidated group balances (simplified or raw)
  fastify.get('/:id/balances', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const gId = Number(id);
      const group = await prisma.group.findUnique({ where: { id: gId } });
      if (!group) return reply.code(404).send({ success: false, error: 'Group not found' });

      const rawDebts = await getGroupRawDebts(gId);
      
      let finalBalances: Debt[];
      if (group.simplifiedSettlement) {
        finalBalances = simplifyDebts(rawDebts, group.settlementThreshold);
      } else {
        // Just consolidate raw debts (multiple debts between same pair)
        const consolidated = new Map<string, number>();
        for (const d of rawDebts) {
          const key = d.fromUserId < d.toUserId ? `${d.fromUserId}_${d.toUserId}` : `${d.toUserId}_${d.fromUserId}`;
          const sign = d.fromUserId < d.toUserId ? 1 : -1;
          consolidated.set(key, (consolidated.get(key) || 0) + (d.amountCents * sign));
        }
        finalBalances = Array.from(consolidated.entries()).map(([key, amount]) => {
          const [u1, u2] = key.split('_').map(Number);
          return amount > 0 
            ? { fromUserId: u1, toUserId: u2, amountCents: amount }
            : { fromUserId: u2, toUserId: u1, amountCents: Math.abs(amount) };
        }).filter(d => d.amountCents > group.settlementThreshold);
      }

      return reply.send({ success: true, data: finalBalances });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/v1/groups/:id/simplify - Debt Simplification service (explicit override)
  fastify.get('/:id/simplify', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const gId = Number(id);
      const rawDebts = await getGroupRawDebts(gId);
      const simplifiedTransfers = simplifyDebts(rawDebts);
      return reply.send({ success: true, data: simplifiedTransfers });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // PATCH /api/groups/:id/settings - Update group metadata & thresholds
  fastify.patch('/:id/settings', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;
    const { name, type, simplifiedSettlement, settlementThreshold, groupCurrency } = request.body as any;

    try {
      const member = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: Number(id), userId } }
      });
      if (!member || (member.role !== 'admin' && member.role !== 'owner')) return reply.code(403).send({ success: false, error: 'Unauthorized.' });

      const updated = await prisma.group.update({
        where: { id: Number(id) },
        data: { name, type, simplifiedSettlement, settlementThreshold, groupCurrency }
      });
      return reply.send({ success: true, data: updated });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/groups/:id/members - List group members
  fastify.get('/:id/members', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const members = await prisma.groupMember.findMany({
        where: { groupId: Number(id) },
        include: { user: { select: { id: true, name: true, email: true, avatarUrl: true } } }
      });
      return reply.send({ success: true, data: members });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // POST /api/groups/:id/members - Add member by email
  fastify.post('/:id/members', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;
    const { email } = request.body as any;

    try {
      const admin = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: Number(id), userId } }
      });
      if (!admin || (admin.role !== 'admin' && admin.role !== 'owner')) return reply.code(403).send({ success: false });

      const userToAdd = await prisma.user.findUnique({ where: { email } });
      if (!userToAdd) return reply.code(404).send({ success: false, error: 'User not found' });

      const newMember = await prisma.groupMember.create({
        data: { groupId: Number(id), userId: userToAdd.id, role: 'member' }
      });
      return reply.send({ success: true, data: newMember });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // DELETE /api/groups/:id/members/:targetUserId - Remove member or Leave
  fastify.delete('/:id/members/:targetUserId', async (request, reply) => {
    const userId = (request as any).userId;
    const { id, targetUserId } = request.params as any;

    try {
      const gId = Number(id);
      const tUserId = Number(targetUserId);

      const actor = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: gId, userId } }
      });
      if (!actor) return reply.code(403).send({ success: false });

      if (userId !== tUserId && actor.role !== 'admin' && actor.role !== 'owner') {
        return reply.code(403).send({ success: false });
      }

      await prisma.groupMember.delete({
        where: { groupId_userId: { groupId: gId, userId: tUserId } }
      });

      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // PATCH /api/groups/:id/members/:targetUserId/role - Manage roles
  fastify.patch('/:id/members/:targetUserId/role', async (request, reply) => {
    const userId = (request as any).userId;
    const { id, targetUserId } = request.params as any;
    const { role } = request.body as any;

    try {
      const gId = Number(id);
      const tUserId = Number(targetUserId);

      const admin = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: gId, userId } }
      });
      if (!admin || (admin.role !== 'admin' && admin.role !== 'owner')) return reply.code(403).send({ success: false });

      await prisma.groupMember.update({
        where: { groupId_userId: { groupId: gId, userId: tUserId } },
        data: { role: role.toLowerCase() }
      });

      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // DELETE /api/groups/:id - Owner Delete Group (soft delete)
  fastify.delete('/:id', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;

    try {
      const gId = Number(id);
      const member = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: gId, userId } }
      });
      if (!member || member.role !== 'owner') return reply.code(403).send({ success: false, error: 'Only Owners can delete groups.' });

      await prisma.group.update({
        where: { id: gId },
        data: { deletedAt: new Date() }
      });
      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/groups/:id/stats - Group spending analytics
  fastify.get('/:id/stats', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const gId = Number(id);
      
      const expenses = await prisma.expense.findMany({
        where: { groupId: gId, deletedAt: null },
        include: { splits: true }
      });

      const totalSpent = expenses.reduce((sum, e) => sum + e.totalAmount, 0);
      const memberStats: Map<number, { spent: number; owed: number }> = new Map();
      
      for (const e of expenses) {
        const p = memberStats.get(e.paidBy) || { spent: 0, owed: 0 };
        p.spent += e.totalAmount;
        memberStats.set(e.paidBy, p);
        
        for (const s of e.splits) {
          const m = memberStats.get(s.userId) || { spent: 0, owed: 0 };
          m.owed += s.owedAmount;
          memberStats.set(s.userId, m);
        }
      }

      return reply.send({
        success: true,
        data: {
          totalSpent,
          expenseCount: expenses.length,
          memberStats: Array.from(memberStats.entries()).map(([userId, stats]) => ({
            userId,
            ...stats
          }))
        }
      });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });
  // GET /api/groups/:id/export - Story 25: CSV Export
  fastify.get('/:id/export', async (request, reply) => {
    const { id } = request.params as any;
    try {
      const gId = Number(id);
      const group = await prisma.group.findUnique({ where: { id: gId } });
      const expenses = await prisma.expense.findMany({
        where: { groupId: gId, deletedAt: null },
        include: { payer: { select: { name: true } }, category: { select: { name: true } } },
        orderBy: { createdAt: 'desc' }
      });

      if (!group) return reply.code(404).send({ success: false });

      let csv = 'Date,Title,Category,Paid By,Amount,Currency\n';
      for (const e of expenses) {
        const date = e.createdAt.toISOString().split('T')[0];
        const title = (e.title || '').replace(/"/g, '""');
        const cat = e.category?.name || 'General';
        const payer = e.payer?.name || 'Unknown';
        const amount = (e.totalAmount / 100).toFixed(2);
        csv.concat(`${date},"${title}",${cat},${payer},${amount},${e.originalCurrency}\n`);
      }

      reply
        .header('Content-Type', 'text/csv')
        .header('Content-Disposition', `attachment; filename="SplitEase_Export_${group.name}_${Date.now()}.csv"`)
        .send(csv);
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

}
