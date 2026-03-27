import { FastifyInstance } from 'fastify';
import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient();

export default async function settlementRoutes(fastify: FastifyInstance) {
  
  // POST /api/v1/settlements - Record a Payment
  fastify.post('/', async (request, reply) => {
    const userId = (request as any).userId; // Simulated auth

    const { 
      payeeId, amountCents, currency, groupId, idempotencyKey 
    } = request.body as any;

    try {
      // 1. Idempotency Check (Prevents double-charges from network jitters)
      if (idempotencyKey) {
        const existing = await prisma.settlement.findUnique({
          where: { idempotencyKey }
        });
        if (existing) {
          return reply.send({ success: true, data: existing, message: "Idempotent hit" });
        }
      }

      // 2. Strict Concurrency Control via Prisma Interactive Transaction
      // Uses Serializable isolation level to completely lock the affected rows 
      // preventing the "Double Settle" race condition if both users hit Settle simultaneously.
      const settlement = await prisma.$transaction(async (tx) => {
        
        // Execute raw row-lock (Pessimistic Locking)
        // This ensures nobody else can mutate this specific balance pair while we compute it
        await tx.$executeRaw`
          SELECT * FROM "balances" 
          WHERE 
            ("user_id" = ${userId} AND "counterpart_id" = ${payeeId}) OR 
            ("user_id" = ${payeeId} AND "counterpart_id" = ${userId})
          FOR UPDATE;
        `;

        // Create the Settlement record
        const newSettlement = await tx.settlement.create({
          data: {
            payerId: userId,
            payeeId,
            amount: amountCents,
            currency: currency || 'USD',
            groupId,
            idempotencyKey
          }
        });

        // 3. Update Materialized Balances
        // The Payer's debt decreases (they paid the money)
        await tx.balance.upsert({
          where: { userId_counterpartId: { userId, counterpartId: payeeId } },
          update: { netBalance: { increment: amountCents } }, // Moves closer to 0
          create: { userId, counterpartId: payeeId, netBalance: amountCents }
        });

        // The Payee's credit decreases (they received the money)
        await tx.balance.upsert({
          where: { userId_counterpartId: { userId: payeeId, counterpartId: userId } },
          update: { netBalance: { decrement: amountCents } }, // Moves closer to 0
          create: { userId: payeeId, counterpartId: userId, netBalance: -amountCents }
        });

        return newSettlement;

      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        maxWait: 5000,
        timeout: 10000 
      });

      // TODO: Dispatch Socket.io "settlement:created" and "balance:updated" events

      return reply.send({ success: true, data: settlement });

    } catch (e) {
      fastify.log.error(e, 'Settlement Transaction Failed:');
      return reply.code(500).send({ 
        success: false, 
        code: 'TRANSACTION_ABORTED',
        error: "Failed to securely process settlement. Please try again."
      });
    }
  });
}
