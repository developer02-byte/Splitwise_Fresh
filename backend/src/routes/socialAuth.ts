import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { OAuth2Client } from 'google-auth-library';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { signAccessToken } from './auth';

const prisma = new PrismaClient();
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID || 'dummy-client-id');

// Setup Apple JWKS
const appleJWKS = createRemoteJWKSet(
  new URL('https://appleid.apple.com/auth/keys')
);

export default async function socialAuthRoutes(fastify: FastifyInstance) {
  
  // POST /api/auth/google
  fastify.post('/google', async (request, reply) => {
    const { id_token } = request.body as any;
    if (!id_token) return reply.code(400).send({ success: false, error: 'id_token is required' });

    let payload;
    try {
      if (process.env.NODE_ENV === 'development' && id_token.startsWith('mock-')) {
        // Mock verification for local testing without a real Google token
        payload = {
          sub: 'google-' + id_token.replace('mock-', ''),
          email: `mock_${id_token}@example.com`,
          name: 'Mock Google User'
        };
      } else {
        const ticket = await googleClient.verifyIdToken({
          idToken: id_token,
          audience: process.env.GOOGLE_CLIENT_ID,
        });
        payload = ticket.getPayload();
      }
    } catch (e) {
      fastify.log.warn(`Google token verification failed: ${e}`);
      return reply.code(401).send({ success: false, error: 'Invalid Google token' });
    }

    if (!payload || !payload.email) {
      return reply.code(400).send({ success: false, error: 'Email not provided by Google' });
    }

    const { sub: googleId, email, name } = payload;
    const user = await upsertSocialUser('google', googleId, email, name);
    
    const accessToken = signAccessToken(user.id);
    reply.setCookie('token', accessToken, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 15 * 60, // 15 mins
    });
    
    return reply.send({ success: true, data: { id: user.id, email: user.email, name: user.name, token: accessToken } });
  });

  // POST /api/auth/apple
  fastify.post('/apple', async (request, reply) => {
    const { identity_token, name } = request.body as any;
    if (!identity_token) return reply.code(400).send({ success: false, error: 'identity_token is required' });

    let applePayload;
    try {
      if (process.env.NODE_ENV === 'development' && identity_token.startsWith('mock-')) {
        applePayload = {
          sub: 'apple-' + identity_token.replace('mock-', ''),
          email: `mock_${identity_token}@privaterelay.appleid.com`,
        };
      } else {
        const { payload } = await jwtVerify(identity_token, appleJWKS, {
          issuer: 'https://appleid.apple.com',
          audience: process.env.APPLE_BUNDLE_ID,
        });
        applePayload = payload;
      }
    } catch (e) {
      fastify.log.warn(`Apple token verification failed: ${e}`);
      return reply.code(401).send({ success: false, error: 'Invalid Apple token' });
    }

    const { sub: appleId, email } = applePayload;
    if (!email && !appleId) {
      return reply.code(400).send({ success: false, error: 'Insufficient identity data from Apple' });
    }

    const user = await upsertSocialUser('apple', appleId!, email as string, name);

    const accessToken = signAccessToken(user.id);
    reply.setCookie('token', accessToken, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 15 * 60,
    });
    
    return reply.send({ success: true, data: { id: user.id, email: user.email, name: user.name, token: accessToken } });
  });

  async function upsertSocialUser(provider: 'google' | 'apple', providerId: string, email: string, name?: string) {
    return prisma.$transaction(async (tx) => {
      // 1. Check if user already exists via provider ID
      const providerField = provider === 'google' ? { googleId: providerId } : { appleId: providerId };
      const existingUserByProvider = await tx.user.findUnique({
        where: providerField as any,
      });

      if (existingUserByProvider) {
        if (name && name !== existingUserByProvider.name) {
          return tx.user.update({
             where: { id: existingUserByProvider.id },
             data: { name }
          });
        }
        return existingUserByProvider;
      }

      const existingUserByEmail = email ? await tx.user.findUnique({ where: { email } }) : null;

      if (existingUserByEmail) {
        // Update the account to link the provider
        return tx.user.update({
          where: { id: existingUserByEmail.id },
          data: {
             ...providerField,
             provider: 'google', // Or enum mapped
          }
        });
      }

      // 3. Create brand new user
      return tx.user.create({
        data: {
          email: email || `${providerId}@${provider}.mock`,
          name: name || 'Social User',
          provider: provider === 'google' ? 'google' : 'apple',
          ...providerField,
          onboardingCompleted: false,
        }
      });
    });
  }
}
