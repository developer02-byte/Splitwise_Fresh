import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export default async function categoryRoutes(fastify: FastifyInstance) {
  
  // GET /api/categories - Get all categories
  fastify.get('/', async (request, reply) => {
    try {
      const categories = await prisma.expenseCategory.findMany({
        orderBy: { id: 'asc' }
      });
      return reply.send({ success: true, data: categories });
    } catch (e) {
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/categories/top - Get top Categories for user (analytics)
  fastify.get('/top', async (request, reply) => {
    const userId = (request as any).userId;
    try {
      // Find categories used by the user, ordered by count
      const topCategories = await prisma.$queryRaw`
        SELECT c.*, COUNT(e.id) as count
        FROM expense_categories c
        JOIN expenses e ON e.category_id = c.id
        WHERE e.paid_by = ${userId} AND e.deleted_at IS NULL
        GROUP BY c.id
        ORDER BY count DESC
        LIMIT 4
      `;
      
      return reply.send({ success: true, data: topCategories });
    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false });
    }
  });

  // GET /api/categories/predict - Story 24: Predict category from title
  fastify.get('/predict', async (request, reply) => {
    const { title } = request.query as { title: string };
    if (!title || typeof title !== 'string') return reply.send({ success: true, data: null });

    const key = title.toLowerCase();
    let predictedId: number | null = null;

    if (key.includes('pizza') || key.includes('dinner') || key.includes('restaura') || key.includes('lunch')) predictedId = 1;
    else if (key.includes('grocery') || key.includes('market') || key.includes('fruit')) predictedId = 2;
    else if (key.includes('taxi') || key.includes('uber') || key.includes('lyft') || key.includes('grab')) predictedId = 4;
    else if (key.includes('fuel') || key.includes('gas') || key.includes('petrol')) predictedId = 5;
    else if (key.includes('rent') || key.includes('bill') || key.includes('electric') || key.includes('water')) predictedId = 7;
    else if (key.includes('movie') || key.includes('netflix') || key.includes('spotify')) predictedId = 6;

    if (predictedId) {
      const category = await prisma.expenseCategory.findUnique({ where: { id: predictedId } });
      return reply.send({ success: true, data: category });
    }

    return reply.send({ success: true, data: null });
  });
}
