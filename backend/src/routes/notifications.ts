import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { NotificationService } from '../services/notificationService';

const prisma = new PrismaClient();

export default async function notificationsRoutes(fastify: FastifyInstance) {
  // POST /api/notifications/register-token
  fastify.post('/register-token', async (request, reply) => {
    const userId = (request as any).userId;
    const { token, deviceId } = request.body as { token: string; deviceId?: string };

    if (!token) return reply.code(400).send({ success: false, error: 'Token is required' });

    try {
      return reply.send({ success: true, message: 'FCM Token registered' });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'SERVER_ERROR' });
    }
  });


  // GET /api/notifications
  fastify.get('/', async (request, reply) => {
    const userId = (request as any).userId;

    try {
      const notifications = await prisma.notification.findMany({
        where: { recipientId: userId },
        orderBy: { createdAt: 'desc' },
        take: 50
      });
      return reply.send({ success: true, data: notifications });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'SERVER_ERROR' });
    }
  });

  // PUT /api/notifications/:id/read
  fastify.put('/:id/read', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as { id: string };

    try {
      await prisma.notification.updateMany({
        where: { id: parseInt(id), recipientId: userId },
        data: { isRead: true }
      });
      return reply.send({ success: true, message: 'Read' });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'SERVER_ERROR' });
    }
  });

  // PUT /api/notifications/read-all
  fastify.put('/read-all', async (request, reply) => {
    const userId = (request as any).userId;

    try {
      await prisma.notification.updateMany({
        where: { recipientId: userId, isRead: false },
        data: { isRead: true }
      });
      return reply.send({ success: true, message: 'All read' });
    } catch (e) {
      return reply.code(500).send({ success: false, error: 'SERVER_ERROR' });
    }
  });

  // POST /api/notifications/remind
  fastify.post('/remind', async (request, reply) => {
    const userId = (request as any).userId;
    const { targetUserId, type, relatedId } = request.body as any;

    try {
      const requester = await prisma.user.findUnique({ where: { id: userId } });
      const target = await prisma.user.findUnique({ where: { id: Number(targetUserId) } });

      if (!target) return reply.code(404).send({ success: false, error: 'Target user not found' });

      let message = `${requester?.name || 'Someone'} reminds you to settle your outstanding balance.`;
      let title = 'Payment Reminder';

      if (type === 'expense') {
        const expense = await prisma.expense.findUnique({ where: { id: Number(relatedId) } });
        if (expense) {
          message = `${requester?.name || 'Someone'} reminds you about "${expense.title}".`;
          title = 'Expense Reminder';
        }
      }

      await NotificationService.notify({
        recipientId: Number(targetUserId),
        referenceType: 'reminder',
        title,
        message,
        referenceId: relatedId ? Number(relatedId) : undefined
      });

      return reply.send({ success: true, message: 'Reminder sent!' });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, error: 'SERVER_ERROR' });
    }
  });
}
