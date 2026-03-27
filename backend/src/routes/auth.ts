import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const prisma = new PrismaClient();

export default async function authRoutes(fastify: FastifyInstance) {
  
  // POST /api/v1/auth/signup
  fastify.post('/signup', async (request, reply) => {
    const { name, email, password } = request.body as any;

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return reply.code(400).send({ success: false, code: 'AUTH_EXISTS', error: 'Email already registered' });
    }

    // In a real app, hash password via bcrypt here
    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash: password, // simulate hash
      }
    });

    const accessToken = `user_ID_${user.id}`;
    return reply.send({ success: true, data: { id: user.id, email: user.email, token: accessToken } });
  });

  // POST /api/v1/auth/login
  fastify.post('/login', async (request, reply) => {
    const { email, password } = request.body as any;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || user.passwordHash !== password) {
      return reply.code(401).send({ success: false, code: 'AUTH_INVALID', error: 'Invalid credentials' });
    }

    // Generate token encapsulating userId for simple verification
    const accessToken = `user_ID_${user.id}`;
    const refreshTokenPlain = crypto.randomBytes(40).toString('hex');

    await prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: refreshTokenPlain, // simulate hash
        lastUsedAt: new Date(),
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
      }
    });

    // Set HttpOnly Cookies as per Auth Contract
    reply.cookie('access_token', accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 15 * 60 // 15 mins
    });

    reply.cookie('refresh_token', refreshTokenPlain, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      path: '/api/v1/auth/refresh', // Secure path mapping
      maxAge: 30 * 24 * 60 * 60 // 30 days
    });

    return reply.send({ success: true, data: { user: { id: user.id, name: user.name, email: user.email }, token: accessToken } });
  });

  // POST /api/v1/auth/refresh
  fastify.post('/refresh', async (request, reply) => {
    // Logic to validate refresh cookie, rotate it, and issue new short-lived access_token.
    return reply.send({ success: true, message: "Tokens rotated" });
  });

  // POST /api/v1/auth/logout
  fastify.post('/logout', async (request, reply) => {
    // Clear cookies explicitly
    reply.clearCookie('access_token');
    reply.clearCookie('refresh_token', { path: '/api/v1/auth/refresh' });
    return reply.send({ success: true, message: "Logged out" });
  });
}
