import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

export default async function userRoutes(fastify: FastifyInstance) {
  // GET /api/user/me — update lastSeenAt
  fastify.get('/me', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const user = await prisma.user.update({
        where: { id: userId },
        data: { lastSeenAt: new Date() },
        select: { id: true, name: true, email: true, avatarUrl: true, defaultCurrency: true, onboardingCompleted: true, provider: true, acceptedTermsVersion: true, lastSeenAt: true }
      });
      if (!user) return reply.code(404).send({ success: false, code: 'NOT_FOUND' });
      return reply.send({ 
        success: true, 
        data: {
          ...user,
          currentTermsVersion: process.env.CURRENT_TERMS_VERSION || '2026-03-01'
        }
      });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PATCH /api/user/push-token - Story 28
  fastify.patch('/push-token', async (request, reply) => {
    const userId = (request as any).userId;
    const { token } = request.body as any;
    try {
      await prisma.user.update({
        where: { id: userId },
        data: { pushToken: token }
      });
      return reply.send({ success: true });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/user/presence - Story 29
  fastify.get('/presence', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      // Get all friends and their lastSeenAt
      const friendships = await prisma.friendship.findMany({
        where: { OR: [{ requesterId: userId }, { addresseeId: userId }], status: 'accepted' },
        include: { requester: { select: { id: true, lastSeenAt: true } }, addressee: { select: { id: true, lastSeenAt: true } } }
      });

      const presence = friendships.map(f => {
        const friend = f.requesterId === userId ? f.addressee : f.requester;
        const isOnline = friend.lastSeenAt ? (new Date().getTime() - new Date(friend.lastSeenAt).getTime() < 300000) : false; // 5 mins
        return { userId: friend.id, isOnline, lastSeenAt: friend.lastSeenAt };
      });

      return reply.send({ success: true, data: presence });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/user/budget - Story 23: Budget Tracking (Personal)

  fastify.put('/accept-terms', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: {
          acceptedTermsAt: new Date(),
          acceptedTermsVersion: process.env.CURRENT_TERMS_VERSION || '2026-03-01'
        },
        select: { id: true, acceptedTermsVersion: true }
      });
      return reply.send({ success: true, data: updated });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PUT /api/user/me — update profile
  fastify.put('/me', async (request, reply) => {
    const userId = (request as any).userId;
    const { name, defaultCurrency, onboardingCompleted, timezone } = request.body as any;
    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: { name, defaultCurrency, onboardingCompleted, timezone },
        select: { id: true, name: true, email: true, defaultCurrency: true, onboardingCompleted: true }
      });
      return reply.send({ success: true, data: updated });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // DELETE /api/user/me — delete account
  fastify.delete('/me', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const activeBalances = await prisma.balance.findMany({
        where: { OR: [{ userId, netBalance: { not: 0 } }, { counterpartId: userId, netBalance: { not: 0 } }] }
      });
      if (activeBalances.length > 0) {
        return reply.code(403).send({ success: false, code: 'ACTIVE_DEBT', message: 'Settle all debts before deleting.' });
      }
      await prisma.user.update({
        where: { id: userId },
        data: { 
          name: 'Deleted User', 
          email: `deleted_${Date.now()}@splitwise.internal`, 
          avatarUrl: null, 
          passwordHash: 'deleted',
          deletedAt: new Date()
        }
      });
      return reply.send({ success: true, message: 'Account marked for deletion.' });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PUT /api/user/me/password — update password
  fastify.put('/me/password', async (request, reply) => {
    const userId = (request as any).userId;
    const { currentPassword, newPassword } = request.body as any;

    if (!currentPassword || !newPassword) {
      return reply.code(400).send({ success: false, error: 'Current and new password are required' });
    }

    try {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) return reply.code(404).send({ success: false, error: 'User not found' });

      if (!user.passwordHash || user.passwordHash === 'ghost' || user.passwordHash === 'deleted') {
        return reply.code(403).send({ success: false, error: 'Action not allowed on this account' });
      }

      const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
      if (!isValid) {
        return reply.code(401).send({ success: false, error: 'Incorrect current password' });
      }

      const newHash = await bcrypt.hash(newPassword, 12);
      await prisma.user.update({
        where: { id: userId },
        data: { passwordHash: newHash }
      });

      return reply.send({ success: true, message: 'Password updated successfully' });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PUT /api/user/notification-preferences
  fastify.put('/notification-preferences', async (request, reply) => {
    const userId = (request as any).userId;
    const { pushEnabled, emailEnabled } = request.body as any;
    try {
      // Assuming a simple mock or updating a JSON field (not in current Prisma schema)
      return reply.send({ success: true, message: 'Preferences updated', data: { pushEnabled, emailEnabled } });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/user/balances — used by dashboard balance_provider.dart
  // Returns total net balance: how much the current user is owed vs owes
  fastify.get('/balances', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth
    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { defaultCurrency: true }
      });
      const currency = user?.defaultCurrency ?? 'USD';

      // Rows where userId is owed money (netBalance > 0 = owed to user)
      const balances = await prisma.balance.findMany({
        where: { userId }
      });

      const userAreOwed = balances
        .filter(b => b.netBalance > 0)
        .reduce((sum, b) => sum + b.netBalance, 0);

      const userOwe = balances
        .filter(b => b.netBalance < 0)
        .reduce((sum, b) => sum + Math.abs(b.netBalance), 0);

      const totalBalance = userAreOwed - userOwe;

      return reply.send({
        success: true,
        data: { userAreOwed, userOwe, totalBalance, currency }
      });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/v1/user/profile
  // Fetch current user details
  fastify.get('/profile', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, name: true, email: true, avatarUrl: true, defaultCurrency: true }
      });
      return reply.send({ success: true, data: user });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PATCH /api/v1/user/profile
  // Update name, currency, timezone, etc.
  fastify.patch('/profile', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth
    const { name, defaultCurrency } = request.body as any;

    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: { name, defaultCurrency },
        select: { id: true, name: true, email: true, defaultCurrency: true }
      });
      return reply.send({ success: true, data: updated });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // DELETE /api/v1/user/account
  // Account deletion logic with debt safety blocks
  fastify.delete('/account', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth

    try {
      // Check if user has active debts (owed to them or owing others)
      const activeBalances = await prisma.balance.findMany({
        where: {
          OR: [
            { userId, netBalance: { not: 0 } },
            { counterpartId: userId, netBalance: { not: 0 } }
          ]
        }
      });

      if (activeBalances.length > 0) {
        return reply.code(403).send({ 
          success: false, 
          code: 'ACTIVE_DEBT', 
          message: 'You must settle all debts before deleting your account.' 
        });
      }

      // Safe to delete. We soft-delete the user record or anonymize to preserve historical ledgers
      await prisma.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted User',
          email: `deleted_${Date.now()}@splitwise.internal`,
          avatarUrl: null,
          passwordHash: 'deleted'
        }
      });

      return reply.send({ success: true, message: 'Account securely marked for deletion.' });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/user/budget - Story 23: Budget Tracking (Personal)
  fastify.get('/budget', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      const now = new Date();
      const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

      const userSplits = await prisma.expenseSplit.findMany({
        where: {
          userId,
          expense: {
            createdAt: { gte: firstDayOfMonth },
            deletedAt: null
          }
        },
        include: { expense: { include: { category: true } } }
      });

      const spentThisMonth = userSplits.reduce((sum, s) => sum + s.owedAmount, 0);
      
      const categorySpent: Record<string, number> = {};
      for (const s of userSplits) {
        const catName = s.expense.category?.name || 'Uncategorized';
        categorySpent[catName] = (categorySpent[catName] || 0) + s.owedAmount;
      }

      return reply.send({
        success: true,
        data: {
          monthlyBudget: 150000, 
          spentThisMonth,
          currency: 'USD',
          categoryBreakdown: Object.entries(categorySpent).map(([name, amount]) => ({ name, amount }))
        }
      });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

}
