import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import '@fastify/cookie'; // Patches FastifyRequest/FastifyReply types

const prisma = new PrismaClient();

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ACCESS_TOKEN_EXPIRY = '15m';
const BCRYPT_ROUNDS = 12;

export function signAccessToken(userId: number): string {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
}

export function verifyAccessToken(token: string): { sub: number } {
  return jwt.verify(token, JWT_SECRET) as unknown as { sub: number };
}

function hashRefreshToken(plain: string): string {
  return crypto.createHash('sha256').update(plain).digest('hex');
}

export default async function authRoutes(fastify: FastifyInstance) {

  // POST /api/auth/signup
  fastify.post('/signup', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const { name, email, password, accepted_terms } = request.body as any;

    if (!name || !email || !password) {
      return reply.code(400).send({ success: false, error: 'Name, email, and password are required' });
    }

    if (!accepted_terms) {
      return reply.code(400).send({ success: false, error: 'You must accept the Terms of Service and Privacy Policy' });
    }

    if (password.length < 6) {
      return reply.code(400).send({ success: false, error: 'Password must be at least 6 characters' });
    }

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return reply.code(400).send({ success: false, code: 'AUTH_EXISTS', error: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const user = await prisma.user.create({
      data: { 
        name, 
        email, 
        passwordHash: hashedPassword,
        acceptedTermsAt: new Date(),
        acceptedTermsVersion: process.env.CURRENT_TERMS_VERSION || '2026-03-01'
      }
    });

    const accessToken = signAccessToken(user.id);
    return reply.code(201).send({ success: true, data: { id: user.id, email: user.email, token: accessToken } });
  });

  // POST /api/auth/login
  fastify.post('/login', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const { email, password } = request.body as any;

    if (!email || !password) {
      return reply.code(400).send({ success: false, error: 'Email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash) {
      return reply.code(401).send({ success: false, code: 'AUTH_INVALID', error: 'Invalid credentials' });
    }

    const passwordValid = await bcrypt.compare(password, user.passwordHash);
    if (!passwordValid) {
      return reply.code(401).send({ success: false, code: 'AUTH_INVALID', error: 'Invalid credentials' });
    }

    // Generate tokens
    const accessToken = signAccessToken(user.id);
    const refreshTokenPlain = crypto.randomBytes(40).toString('hex');
    const refreshTokenHashed = hashRefreshToken(refreshTokenPlain);

    await prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: refreshTokenHashed,
        userAgent: request.headers['user-agent'] || null,
        ipAddress: request.ip || null,
        lastUsedAt: new Date(),
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
      }
    });

    // Set HttpOnly Cookies
    reply.cookie('access_token', accessToken, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 15 * 60 // 15 mins
    });

    reply.cookie('refresh_token', refreshTokenPlain, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      path: '/api/auth/refresh',
      maxAge: 30 * 24 * 60 * 60 // 30 days
    });

    return reply.send({
      success: true,
      data: {
        user: { id: user.id, name: user.name, email: user.email },
        token: accessToken
      }
    });
  });

  // POST /api/auth/refresh — rotate refresh token + issue new access token
  fastify.post('/refresh', async (request, reply) => {
    const refreshToken = request.cookies.refresh_token;
    if (!refreshToken) {
      return reply.code(401).send({ success: false, error: 'No refresh token' });
    }

    const tokenHash = hashRefreshToken(refreshToken);
    const session = await prisma.session.findUnique({ where: { refreshTokenHash: tokenHash } });

    if (!session || session.expiresAt < new Date()) {
      // Expired or invalid — clean up
      if (session) await prisma.session.delete({ where: { id: session.id } });
      reply.clearCookie('access_token');
      reply.clearCookie('refresh_token', { path: '/api/auth/refresh' });
      return reply.code(401).send({ success: false, error: 'Session expired' });
    }

    // Rotate: new refresh token, update session
    const newRefreshPlain = crypto.randomBytes(40).toString('hex');
    const newRefreshHash = hashRefreshToken(newRefreshPlain);

    await prisma.session.update({
      where: { id: session.id },
      data: { refreshTokenHash: newRefreshHash, lastUsedAt: new Date() }
    });

    const newAccessToken = signAccessToken(session.userId);

    reply.cookie('access_token', newAccessToken, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 15 * 60
    });

    reply.cookie('refresh_token', newRefreshPlain, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      path: '/api/auth/refresh',
      maxAge: 30 * 24 * 60 * 60
    });

    return reply.send({ success: true, data: { token: newAccessToken } });
  });

  // POST /api/auth/logout — clear cookies + delete session
  fastify.post('/logout', async (request, reply) => {
    const refreshToken = request.cookies.refresh_token;
    if (refreshToken) {
      const tokenHash = hashRefreshToken(refreshToken);
      await prisma.session.deleteMany({ where: { refreshTokenHash: tokenHash } });
    }

    reply.clearCookie('access_token');
    reply.clearCookie('refresh_token', { path: '/api/auth/refresh' });
    return reply.send({ success: true, message: 'Logged out' });
  });

  // POST /api/auth/forgot-password
  fastify.post('/forgot-password', {
    config: { rateLimit: { max: 3, timeWindow: '15 minutes' } }
  }, async (request, reply) => {
    const { email } = request.body as any;
    if (!email) return reply.code(400).send({ success: false, error: 'Email required' });

    const user = await prisma.user.findUnique({ where: { email } });
    
    // We always return success to prevent email enumeration attacks
    if (!user) return reply.send({ success: true, message: 'If an account exists, an email was sent.' });

    // Generate secure token
    const resetTokenPlain = crypto.randomBytes(32).toString('hex');
    const resetTokenHash = crypto.createHash('sha256').update(resetTokenPlain).digest('hex');

    // Upsert to DB (1 hour expiration)
    await prisma.passwordReset.upsert({
      where: { email },
      update: { tokenHash: resetTokenHash, expiresAt: new Date(Date.now() + 60 * 60 * 1000) },
      create: { email, tokenHash: resetTokenHash, expiresAt: new Date(Date.now() + 60 * 60 * 1000) }
    });

    // Mock Nodemailer Service
    const deepLink = `http://localhost:8080/reset-password/${resetTokenPlain}`;
    fastify.log.info(`[MOCK NODEMAILER] Sending Reset Password Email to ${email} -> Link: ${deepLink}`);

    return reply.send({ success: true, message: 'If an account exists, an email was sent.' });
  });

  // POST /api/auth/reset-password
  fastify.post('/reset-password', async (request, reply) => {
    const { email, token, newPassword } = request.body as any;

    if (!email || !token || !newPassword) {
      return reply.code(400).send({ success: false, error: 'Invalid payload' });
    }

    if (newPassword.length < 6) {
      return reply.code(400).send({ success: false, error: 'Password too weak' });
    }

    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const resetRecord = await prisma.passwordReset.findUnique({ where: { email } });

    if (!resetRecord || resetRecord.tokenHash !== tokenHash || resetRecord.expiresAt < new Date()) {
      return reply.code(400).send({ success: false, error: 'Invalid or expired token' });
    }

    // Hash new password and destroy active sessions for security
    const hashedPassword = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    const user = await prisma.user.update({
      where: { email },
      data: { passwordHash: hashedPassword }
    });

    await prisma.session.deleteMany({ where: { userId: user.id } });
    await prisma.passwordReset.delete({ where: { email } });

    return reply.send({ success: true, message: 'Password updated successfully' });
  });
}
