import fp from 'fastify-plugin';
import { randomUUID } from 'crypto';
import { FastifyInstance } from 'fastify';

declare module 'fastify' {
  interface FastifyRequest {
    traceId: string;
  }
}

async function traceIdPlugin(fastify: FastifyInstance) {
  fastify.addHook('onRequest', async (request, reply) => {
    request.traceId = (request.headers['x-trace-id'] as string) || randomUUID();
    
    request.log = request.log.child({ trace_id: request.traceId });
    reply.header('X-Trace-Id', request.traceId);
  });
}

export default fp(traceIdPlugin);
