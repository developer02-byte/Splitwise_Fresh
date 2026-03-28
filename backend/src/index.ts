import Fastify from 'fastify';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';
import rateLimit from '@fastify/rate-limit';

import authRoutes from './routes/auth';
import { verifyAccessToken } from './routes/auth';
import activityRoutes from './routes/activity';
import expensesRoutes from './routes/expenses';
import friendsRoutes from './routes/friends';
import groupsRoutes from './routes/groups';
import invitesRoutes from './routes/invites';
import settlementsRoutes from './routes/settlements';
import userRoutes from './routes/user';

const fastify = Fastify({ logger: true });

async function start() {
  // Setup Plugins
  // CORS: allow configured origins, fall back to permissive defaults for dev
  const allowedOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',')
    : ['http://localhost', 'http://localhost:8080', 'http://127.0.0.1:8080', 'http://192.168.2.6:8080'];

  await fastify.register(cors, {
    origin: allowedOrigins,
    credentials: true, // required for httpOnly cookies
  });
  await fastify.register(cookie);

  // Global rate limit: 100 req/min per IP (auth routes override with stricter limits)
  await fastify.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
  });

  fastify.decorateRequest('userId', null);
  fastify.addHook('onRequest', async (request, reply) => {
    // Skip pre-flights
    if (request.method === 'OPTIONS') return;

    // Skip public routes
    if (request.url.startsWith('/api/auth/login') || request.url.startsWith('/api/auth/signup') || request.url.startsWith('/api/auth/refresh') || request.url.startsWith('/api/currencies/rates')) {
      return;
    }

    // Check Authorization header for JWT
    const authHeader = request.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      try {
        const decoded = verifyAccessToken(token);
        (request as any).userId = decoded.sub;
        return;
      } catch {
        return reply.code(401).send({ success: false, error: 'Invalid or expired token' });
      }
    }

    return reply.code(401).send({ success: false, error: 'Unauthorized' });
  });

  // Register all routes
  // Prefixes from Phase plan
  fastify.register(authRoutes, { prefix: '/api/auth' });
  fastify.register(activityRoutes, { prefix: '/api/user/activities' });
  fastify.register(expensesRoutes, { prefix: '/api/expenses' });
  fastify.register(friendsRoutes, { prefix: '/api/user/friends' });
  fastify.register(groupsRoutes, { prefix: '/api/groups' });
  fastify.register(invitesRoutes, { prefix: '/api/invites' });
  fastify.register(settlementsRoutes, { prefix: '/api/settlements' });
  fastify.register(userRoutes, { prefix: '/api/user' });
  
  // Also register currencies for formatCurrency (mock)
  fastify.get('/api/currencies/rates', async (request, reply) => {
    return reply.send({
      success: true,
      data: { 'USD_EUR': 0.92, 'USD_GBP': 0.79, 'USD_INR': 83.15, 'USD_JPY': 149.50 }
    });
  });

  // Start Server
  try {
    const port = process.env.PORT ? parseInt(process.env.PORT) : 3000;
    await fastify.listen({ port, host: '0.0.0.0' });
    console.log(`SplitEase Backend is running safely on port ${port}!`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start();
