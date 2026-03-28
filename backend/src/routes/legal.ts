import { FastifyInstance } from 'fastify';

export default async function legalRoutes(fastify: FastifyInstance) {
  // GET /api/legal/privacy
  fastify.get('/privacy', async (request, reply) => {
    const privacyUrl = process.env.PRIVACY_POLICY_URL || 'https://example.com/privacy';
    return reply.redirect(302, privacyUrl);
  });

  // GET /api/legal/terms
  fastify.get('/terms', async (request, reply) => {
    const termsUrl = process.env.TERMS_OF_SERVICE_URL || 'https://example.com/terms';
    return reply.redirect(302, termsUrl);
  });
}
