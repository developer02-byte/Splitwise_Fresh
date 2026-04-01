import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';
import { NotificationService } from '../services/notificationService';
import { ExchangeRateService } from '../services/exchange_rate';

const prisma = new PrismaClient();

export default async function settlementRoutes(fastify: FastifyInstance) {
  
  // POST /api/v1/settlements - Record a Payment
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; 
    const { payeeId, amountCents, currency, groupId, idempotencyKey } = request.body as any;

    try {
      if (idempotencyKey) {
        const existing = await prisma.settlement.findUnique({ where: { idempotencyKey } });
        if (existing) return reply.send({ success: true, data: existing, message: "Idempotent hit" });
      }

      // Currency Conversion logic
      let exchangeRate = 1.0;
      let amountUSD = amountCents;
      if (currency && currency !== 'USD') {
        const rates = await ExchangeRateService.getLatestRates(currency);
        exchangeRate = rates['USD'] || 1.0;
        amountUSD = Math.round(amountCents * exchangeRate);
      }

      const settlement = await prisma.$transaction(async (tx) => {
        const currentBalance = await tx.balance.findUnique({
          where: { userId_counterpartId: { userId, counterpartId: payeeId } }
        });

        if (!currentBalance || currentBalance.netBalance >= 0) {
          throw new Error("No debt exists to settle");
        }
        
        const debtCents = Math.abs(currentBalance.netBalance);
        if (amountUSD > debtCents) {
          throw new Error(`Overpayment: You only owe ${debtCents}, tried to pay ${amountUSD}`);
        }

        const newSettlement = await tx.settlement.create({
          data: { payerId: userId, payeeId, amount: amountCents, currency: currency || 'USD', groupId, idempotencyKey }
        });

        await tx.balance.upsert({
          where: { userId_counterpartId: { userId, counterpartId: payeeId } },
          update: { netBalance: { increment: amountUSD } },
          create: { userId, counterpartId: payeeId, netBalance: amountUSD }
        });

        await tx.balance.upsert({
          where: { userId_counterpartId: { userId: payeeId, counterpartId: userId } },
          update: { netBalance: { decrement: amountUSD } },
          create: { userId: payeeId, counterpartId: userId, netBalance: -amountUSD }
        });

        return newSettlement;
      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        maxWait: 5000,
        timeout: 10000 
      });

      // ── Trigger Notifications ──────────────────────────────────────────────────
      try {
        const payerUser = await prisma.user.findUnique({ where: { id: userId } });
        const payerName = payerUser?.name || 'Someone';

        await NotificationService.notify({
          recipientId: payeeId,
          referenceType: 'settlement',
          title: 'Payment Received',
          message: `${payerName} paid you \$${(amountCents / 100).toFixed(2)}`,
          referenceId: settlement.id
        });
      } catch (err) {
        fastify.log.error({ err }, 'Notification failed for settlement');
      }

      return reply.send({ success: true, data: settlement });

    } catch (e) {
      fastify.log.error({ err: e }, 'Settlement Transaction Failed:');
      return reply.code(400).send({ 
        success: false, 
        code: 'TRANSACTION_ABORTED',
        error: e instanceof Error ? e.message : "Failed to securely process settlement."
      });
    }
  });

  // POST /api/settlements/settle-all
  fastify.post('/settle-all', async (request, reply) => {
    const userId = (request as any).userId;

    try {
      const settled = await prisma.$transaction(async (tx) => {
        const debts = await tx.balance.findMany({
          where: { userId, netBalance: { lt: 0 } }
        });

        if (debts.length === 0) return [];

        const settlements = [];
        for (const debt of debts) {
          const amount = Math.abs(debt.netBalance);
          const payeeId = debt.counterpartId;

          const s = await tx.settlement.create({
            data: {
              payerId: userId,
              payeeId,
              amount,
              currency: 'USD',
            }
          });
          settlements.push(s);

          await tx.balance.update({
            where: { userId_counterpartId: { userId, counterpartId: payeeId } },
            data: { netBalance: 0 }
          });
          await tx.balance.update({
            where: { userId_counterpartId: { userId: payeeId, counterpartId: userId } },
            data: { netBalance: 0 }
          });
        }
        return settlements;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

      // Trigger multi-notifications (simplified for settle-all)
      try {
        const payerUser = await prisma.user.findUnique({ where: { id: userId } });
        const payerName = payerUser?.name || 'Someone';
        
        const notifications = settled.map(s => ({
          recipientId: s.payeeId,
          referenceType: 'settlement' as const,
          title: 'Full Settlement',
          message: `${payerName} settled all debts with you!`,
          referenceId: s.id
        }));
        
        if (notifications.length > 0) {
          await NotificationService.notifyBulk(notifications);
        }
      } catch (err) { /* ignore */ }

      return reply.send({ success: true, data: settled });
    } catch (e) {
      return reply.code(500).send({ success: false, error: "Failed to settle all" });
    }
  });
}
