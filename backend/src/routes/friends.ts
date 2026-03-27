import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Helper to build friends list from balance records
async function buildFriendsList(userId: number) {
  const balancesOwed = await prisma.balance.findMany({
    where: { userId },
    include: { counterpart: { select: { id: true, name: true, avatarUrl: true, email: true } } }
  });
  const balancesOwe = await prisma.balance.findMany({
    where: { counterpartId: userId },
    include: { user: { select: { id: true, name: true, avatarUrl: true, email: true } } }
  });

  const friendsMap = new Map<number, any>();

  balancesOwed.forEach(b => {
    if (!friendsMap.has(b.counterpart.id)) {
      friendsMap.set(b.counterpart.id, {
        id: b.counterpart.id,
        name: b.counterpart.name,
        email: b.counterpart.email,
        avatarUrl: b.counterpart.avatarUrl,
        netBalanceCents: 0,
      });
    }
    friendsMap.get(b.counterpart.id).netBalanceCents += b.netBalance;
  });

  balancesOwe.forEach(b => {
    if (!friendsMap.has(b.user.id)) {
      friendsMap.set(b.user.id, {
        id: b.user.id,
        name: b.user.name,
        email: b.user.email,
        avatarUrl: b.user.avatarUrl,
        netBalanceCents: 0,
      });
    }
    friendsMap.get(b.user.id).netBalanceCents -= b.netBalance;
  });

  return Array.from(friendsMap.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export default async function friendsRoutes(fastify: FastifyInstance) {
  // GET /api/user/friends — list all friends with balances
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth
    try {
      const friendsList = await buildFriendsList(userId);
      return reply.send({ success: true, data: friendsList });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/user/friends/balances — used by Flutter friends_provider.dart
  fastify.get('/balances', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const friendsList = await buildFriendsList(userId);
      return reply.send({ success: true, data: friendsList });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // POST /api/user/friends — add a friend (Flutter calls this path)
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId;
    const { email, name } = request.body as any;
    try {
      let friendUser = await prisma.user.findUnique({ where: { email } });
      if (!friendUser) {
        friendUser = await prisma.user.create({
          data: { email, name: name || email, passwordHash: 'ghost' }
        });
      }
      await prisma.balance.upsert({
        where: { userId_counterpartId: { userId, counterpartId: friendUser.id } },
        update: {},
        create: { userId, counterpartId: friendUser.id, netBalance: 0 }
      });
      return reply.send({ success: true, data: {
        id: friendUser.id,
        name: friendUser.name,
        email: friendUser.email,
        avatarUrl: friendUser.avatarUrl,
        netBalanceCents: 0
      }});
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // POST /api/user/friends/add (legacy alias)
  fastify.post('/add', async (request, reply) => {
    const userId = (request as any).userId;
    const { email, name } = request.body as any;
    try {
      let friendUser = await prisma.user.findUnique({ where: { email } });
      if (!friendUser) {
        friendUser = await prisma.user.create({
          data: { email, name: name || email, passwordHash: 'ghost' }
        });
      }
      await prisma.balance.upsert({
        where: { userId_counterpartId: { userId, counterpartId: friendUser.id } },
        update: {},
        create: { userId, counterpartId: friendUser.id, netBalance: 0 }
      });
      return reply.send({ success: true, data: {
        id: friendUser.id,
        name: friendUser.name,
        email: friendUser.email,
        avatarUrl: friendUser.avatarUrl,
        netBalanceCents: 0
      }});
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });
}
