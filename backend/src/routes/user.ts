import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export default async function userRoutes(fastify: FastifyInstance) {
  // GET /api/user/me  — used by auth check and profile page
  fastify.get('/me', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth (replace with JWT decode in production)
    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, name: true, email: true, avatarUrl: true, defaultCurrency: true, onboardingCompleted: true }
      });
      if (!user) return reply.code(404).send({ success: false, code: 'NOT_FOUND' });
      return reply.send({ success: true, data: user });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // PUT /api/user/me — update profile
  fastify.put('/me', async (request, reply) => {
    const userId = (request as any).userId;
    const { name, defaultCurrency, onboardingCompleted } = request.body as any;
    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: { name, defaultCurrency, onboardingCompleted },
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
        data: { name: 'Deleted User', email: `deleted_${Date.now()}@splitwise.internal`, avatarUrl: null, passwordHash: 'deleted' }
      });
      return reply.send({ success: true, message: 'Account marked for deletion.' });
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
}
