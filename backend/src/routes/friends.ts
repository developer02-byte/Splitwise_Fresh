import { FastifyInstance } from 'fastify';
import { PrismaClient, FriendshipStatus } from '@prisma/client';
import { NotificationService } from '../services/notificationService';

const prisma = new PrismaClient();

export default async function friendsRoutes(fastify: FastifyInstance) {
  
  // GET /api/friends - List confirmed friends with balances
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const friendships = await prisma.friendship.findMany({
        where: {
          OR: [
            { requesterId: userId, status: 'accepted' },
            { addresseeId: userId, status: 'accepted' }
          ]
        },
        include: {
          requester: { select: { id: true, name: true, email: true, avatarUrl: true } },
          addressee: { select: { id: true, name: true, email: true, avatarUrl: true } }
        }
      });

      const friends = await Promise.all(friendships.map(async f => {
        const friend = f.requesterId === userId ? f.addressee : f.requester;
        const balance = await prisma.balance.findUnique({
          where: { userId_counterpartId: { userId, counterpartId: friend.id } }
        });
        return {
          id: friend.id,
          friendshipId: f.id,
          name: friend.name,
          email: friend.email,
          avatarUrl: friend.avatarUrl,
          netBalanceCents: balance?.netBalance || 0
        };
      }));

      return reply.send({ success: true, data: friends });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/friends/search - Search for users to add
  fastify.get('/search', async (request, reply) => {
    const userId = (request as any).userId;
    const { q } = request.query as any;
    if (!q || q.length < 2) return reply.send({ success: true, data: [] });

    try {
      const users = await prisma.user.findMany({
        where: {
          AND: [
            { id: { not: userId } },
            {
              OR: [
                { email: { contains: q, mode: 'insensitive' } },
                { name: { contains: q, mode: 'insensitive' } }
              ]
            }
          ]
        },
        select: { id: true, name: true, email: true, avatarUrl: true },
        take: 10
      });

      // Check existing friendship status for each result
      const results = await Promise.all(users.map(async u => {
        const friendship = await prisma.friendship.findFirst({
          where: {
            OR: [
              { requesterId: userId, addresseeId: u.id },
              { requesterId: u.id, addresseeId: userId }
            ]
          }
        });
        return { ...u, friendshipStatus: friendship?.status || 'none' };
      }));

      return reply.send({ success: true, data: results });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/friends/pending - List incoming and outgoing pending requests
  fastify.get('/pending', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const pending = await prisma.friendship.findMany({
        where: {
          OR: [
            { requesterId: userId, status: 'pending' },
            { addresseeId: userId, status: 'pending' }
          ]
        },
        include: {
          requester: { select: { id: true, name: true, avatarUrl: true } },
          addressee: { select: { id: true, name: true, avatarUrl: true } }
        }
      });

      return reply.send({
        success: true,
        data: pending.map(p => ({
          id: p.id,
          type: p.requesterId === userId ? 'outgoing' : 'incoming',
          user: p.requesterId === userId ? p.addressee : p.requester,
          createdAt: p.createdAt
        }))
      });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // POST /api/friends - Send friend request
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId;
    const { friendId, email } = request.body as any;

    try {
      let targetId = Number(friendId);
      if (!targetId && email) {
        const user = await prisma.user.findUnique({ where: { email } });
        if (!user) return reply.code(404).send({ success: false, error: 'User not found' });
        targetId = user.id;
      }

      if (targetId === userId) return reply.code(400).send({ success: false, error: 'Cannot add yourself' });

      // Check if already friends/pending
      const existing = await prisma.friendship.findFirst({
        where: {
          OR: [
            { requesterId: userId, addresseeId: targetId },
            { requesterId: targetId, addresseeId: userId }
          ]
        }
      });

      if (existing) return reply.code(400).send({ success: false, error: 'Relationship already exists' });

      const friendship = await prisma.friendship.create({
        data: { requesterId: userId, addresseeId: targetId, status: 'pending' }
      });

      // Send Notification
      try {
        const requester = await prisma.user.findUnique({ where: { id: userId } });
        await NotificationService.notify({
          userId: targetId,
          type: 'friend_request',
          title: 'Friend Request',
          message: `${requester?.name || 'Someone'} sent you a friend request.`,
          relatedId: friendship.id
        });
      } catch (err) { fastify.log.error(err); }

      return reply.send({ success: true, data: friendship });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false });
    }
  });

  // PATCH /api/friends/:id - Accept/Reject/Block
  fastify.patch('/:id', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;
    const { status } = request.body as any;

    try {
      const friendship = await prisma.friendship.findUnique({ 
        where: { id: Number(id) },
        include: { requester: { select: { name: true } } }
      });
      if (!friendship) return reply.code(404).send({ success: false });

      if (friendship.status === 'pending' && friendship.addresseeId !== userId && status !== 'blocked') {
        return reply.code(403).send({ success: false });
      }

      const updated = await prisma.friendship.update({
        where: { id: Number(id) },
        data: { status }
      });

      if (status === 'accepted') {
        const otherId = friendship.requesterId === userId ? friendship.addresseeId : friendship.requesterId;
        await prisma.balance.upsert({
          where: { userId_counterpartId: { userId, counterpartId: otherId } },
          update: {},
          create: { userId, counterpartId: otherId, netBalance: 0 }
        });
        await prisma.balance.upsert({
          where: { userId_counterpartId: { userId: otherId, counterpartId: userId } },
          update: {},
          create: { userId: otherId, counterpartId: userId, netBalance: 0 }
        });

        // Notify Requester
        try {
          const approver = await prisma.user.findUnique({ where: { id: userId } });
          await NotificationService.notify({
            userId: friendship.requesterId,
            type: 'friend_request',
            title: 'Friend Request Accepted',
            message: `${approver?.name || 'Someone'} accepted your friend request!`,
            relatedId: friendship.id
          });
        } catch (err) { fastify.log.error(err); }
      }

      return reply.send({ success: true, data: updated });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // DELETE /api/friends/:id - Remove friend
  fastify.delete('/:id', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;

    try {
      const friendship = await prisma.friendship.findUnique({ where: { id: Number(id) } });
      if (!friendship) return reply.code(404).send({ success: false });

      if (friendship.requesterId !== userId && friendship.addresseeId !== userId) {
        return reply.code(403).send({ success: false });
      }

      const otherId = friendship.requesterId === userId ? friendship.addresseeId : friendship.requesterId;
      
      const balance = await prisma.balance.findUnique({
        where: { userId_counterpartId: { userId, counterpartId: otherId } }
      });
      if (balance && balance.netBalance !== 0) {
        return reply.code(400).send({ success: false, error: 'Cannot remove friend with outstanding balance' });
      }

      await prisma.friendship.delete({ where: { id: Number(id) } });
      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });
}
