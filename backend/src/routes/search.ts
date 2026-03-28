import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export default async function searchRoutes(fastify: FastifyInstance) {
  
  // GET /api/search - Global search across groups, friends, and expenses
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId;
    const { q } = request.query as any;

    if (!q || q.length < 2) return reply.send({ success: true, data: { groups: [], friends: [], expenses: [] } });

    try {
      // Search Groups
      const groups = await prisma.group.findMany({
        where: {
          deletedAt: null,
          members: { some: { userId } },
          name: { contains: q, mode: 'insensitive' }
        },
        select: { id: true, name: true, type: true },
        take: 5
      });

      // Search Friends
      const friendships = await prisma.friendship.findMany({
        where: {
          status: 'accepted',
          OR: [
            { requesterId: userId, addressee: { OR: [{ name: { contains: q, mode: 'insensitive' } }, { email: { contains: q, mode: 'insensitive' } }] } },
            { addresseeId: userId, requester: { OR: [{ name: { contains: q, mode: 'insensitive' } }, { email: { contains: q, mode: 'insensitive' } }] } }
          ]
        },
        include: {
          requester: { select: { id: true, name: true, email: true, avatarUrl: true } },
          addressee: { select: { id: true, name: true, email: true, avatarUrl: true } }
        },
        take: 5
      });
      const friends = (friendships as any[]).map(f => f.requesterId === userId ? f.addressee : f.requester);

      // Search Expenses
      const expenses = await prisma.expense.findMany({
        where: {
          deletedAt: null,
          OR: [
            { groupId: { not: null }, group: { members: { some: { userId } } } },
            { groupId: null, splits: { some: { userId } } }
          ],
          title: { contains: q, mode: 'insensitive' }
        },
        select: { id: true, title: true, totalAmount: true, createdAt: true },
        take: 10
      });

      return reply.send({
        success: true,
        data: { groups, friends, expenses }
      });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });
}
