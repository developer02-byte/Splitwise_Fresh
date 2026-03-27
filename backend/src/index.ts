import Fastify from 'fastify';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';

import authRoutes from './routes/auth';
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
  await fastify.register(cors, {
    origin: ['http://localhost:8080', 'http://127.0.0.1:8080'],
    credentials: true, // required for httpOnly cookies
  });
  await fastify.register(cookie);

  fastify.decorateRequest('userId', null);
  fastify.addHook('onRequest', async (request, reply) => {
    // Skip pre-flights
    if (request.method === 'OPTIONS') return;

    // Skip public routes
    if (request.url.startsWith('/api/auth/login') || request.url.startsWith('/api/auth/signup') || request.url.startsWith('/api/currencies/rates')) {
      return;
    }
    
    // Check Authorization header
    const authHeader = request.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      if (token.startsWith('user_ID_')) {
        const id = parseInt(token.substring(8), 10);
        if (!isNaN(id)) {
          (request as any).userId = id;
          return;
        }
      }
    }

    // Default to fallback or reject (allowing fallback to 1 for robust testing if no token provided, but the prompt says 
    // FORCE HEADERS, so we should reject 401. However, since we are incrementally fixing, let's reject 401)
    if (!(request as any).userId) {
      return reply.code(401).send({ success: false, error: 'Unauthorized' });
    }
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
