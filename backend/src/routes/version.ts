import { FastifyInstance } from 'fastify';

export default async function versionRoutes(fastify: FastifyInstance) {
  fastify.get('/check', async (request, reply) => {
    return reply.code(200).send({
      success: true,
      data: {
        platform: request.headers['x-platform'] || 'web',
        min_version: '1.0.0',
        latest_version: '1.0.1',
        force_update: false,
        update_url: 'https://splitease.com/download'
      }
    });
  });
}
