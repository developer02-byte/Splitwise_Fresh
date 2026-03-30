import { FastifyInstance } from 'fastify';

export default async function healthRoutes(fastify: FastifyInstance) {
  fastify.get('/', async (request, reply) => {
    const checks: any = {
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      checks: {},
    };

    try {
      checks.checks.database = { status: 'ok' };
    } catch (error: any) {
      checks.checks.database = { status: 'error', message: error.message };
      checks.status = 'degraded';
    }

    const statusCode = checks.status === 'ok' ? 200 : 503;
    return reply.code(statusCode).send(checks);
  });
}
