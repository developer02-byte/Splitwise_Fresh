import Fastify from 'fastify';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';
import rateLimit from '@fastify/rate-limit';

import authRoutes from './routes/auth';
import { verifyAccessToken } from './routes/auth';
import socialAuthRoutes from './routes/socialAuth';
import activityRoutes from './routes/activity';
import expensesRoutes from './routes/expenses';
import friendsRoutes from './routes/friends';
import groupsRoutes from './routes/groups';
import invitesRoutes from './routes/invites';
import settlementsRoutes from './routes/settlements';
import userRoutes from './routes/user';
import legalRoutes from './routes/legal';
import notificationsRoutes from './routes/notifications';
import categoryRoutes from './routes/categories';
import searchRoutes from './routes/search';
import healthRoutes from './routes/health';
import versionRoutes from './routes/version';
import analyticsRoutes from './routes/analytics';
import exportRoutes from './routes/export';
import { ExchangeRateService } from './services/exchange_rate';
import traceIdPlugin from './plugins/trace_id';
import metricsPlugin from './plugins/metrics';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import path from 'path';
import { StorageService } from './services/storage';
import fileRoutes from './routes/files';

const fastify = Fastify({ 
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    serializers: {
      req(request: any) {
        return {
          method: request.method,
          url: request.url,
          hostname: request.hostname,
          trace_id: request.traceId,
        };
      },
      res(reply: any) {
        return { statusCode: reply.statusCode };
      },
    },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.body.password',
        'req.body.token',
      ],
      censor: '[REDACTED]',
    },
  } 
});

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
  
  await fastify.register(multipart, {
    limits: { fileSize: 5 * 1024 * 1024 }
  });

  await fastify.register(fastifyStatic, {
     root: path.join(__dirname, '../uploads'),
     prefix: '/uploads/',
  });

  await StorageService.init();
  
  await fastify.register(traceIdPlugin);
  await fastify.register(metricsPlugin, { prefix: '/api' });

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
    if (request.url.startsWith('/api/auth/login') ||
        request.url.startsWith('/api/auth/signup') ||
        request.url.startsWith('/api/auth/refresh') ||
        request.url.startsWith('/api/currencies/rates') ||
        request.url.startsWith('/api/health') ||
        request.url.startsWith('/api/version/check') ||
        request.url.startsWith('/api/metrics') ||
        request.url.startsWith('/uploads/')) {
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
  fastify.register(socialAuthRoutes, { prefix: '/api/auth' });
  fastify.register(activityRoutes, { prefix: '/api/user/activities' });
  fastify.register(expensesRoutes, { prefix: '/api/expenses' });
  fastify.register(friendsRoutes, { prefix: '/api/user/friends' });
  fastify.register(groupsRoutes, { prefix: '/api/groups' });
  fastify.register(invitesRoutes, { prefix: '/api/invites' });
  fastify.register(settlementsRoutes, { prefix: '/api/settlements' });
  fastify.register(userRoutes, { prefix: '/api/user' });
  fastify.register(legalRoutes, { prefix: '/api/legal' });
  fastify.register(notificationsRoutes, { prefix: '/api/notifications' });
  fastify.register(categoryRoutes, { prefix: '/api/categories' });
  fastify.register(searchRoutes, { prefix: '/api/search' });
  fastify.register(analyticsRoutes, { prefix: '/api/analytics' });
  fastify.register(healthRoutes, { prefix: '/api/health' });
  fastify.register(versionRoutes, { prefix: '/api/version' });
  fastify.register(exportRoutes, { prefix: '/api/export' });
  fastify.register(fileRoutes, { prefix: '/api/files' });
  
  // Also register currencies for formatCurrency (mock)
  fastify.get('/api/currencies/rates', async (request, reply) => {
    const base = (request.query as any).base || 'USD';
    const rates = await ExchangeRateService.getLatestRates(base);
    return reply.send({
      success: true,
      data: rates
    });
  });

  // Start Server
  try {
    // Story 11: Email Digest Scheduled Job (Mock implementation)
    setInterval(() => {
      console.log('[CRON] Executing weekly email digest job...');
    }, 7 * 24 * 60 * 60 * 1000); // Weekly
    
    const port = process.env.PORT ? parseInt(process.env.PORT) : 3000;
    await fastify.listen({ port, host: '0.0.0.0' });
    console.log(`SplitEase Backend is running safely on port ${port}!`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start();
