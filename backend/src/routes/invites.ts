import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const prisma = new PrismaClient();

export default async function inviteRoutes(fastify: FastifyInstance) {
  
  // POST /api/v1/groups/:id/invite
  // Generate a shareable invite link for a specific group
  fastify.post<{ Params: { id: string } }>('/groups/:id/invite', async (request, reply) => {
    const groupId = Number(request.params.id);
    const userId = (request as any).userId; // Simulated auth

    try {
      // 1. Verify user is in the group and has permissions
      const member = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId, userId } }
      });

      if (!member) {
        return reply.code(403).send({ success: false, error: 'Not a member of this group' });
      }

      // 2. Generate secure random token
      const token = crypto.randomBytes(16).toString('hex');
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // Valid for 7 days

      // 3. Store invite
      await prisma.groupInvite.create({
        data: {
          token,
          groupId,
          createdBy: userId,
          expiresAt
        }
      });

      // Returning the raw token to the client so it can construct deep links like "splitease://invite/:token"
      return reply.send({ success: true, data: { token, expiresAt } });

    } catch (e) {
      fastify.log.error(e);
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // GET /api/v1/invite/:token
  // Fetch group preview info for an invite link (e.g. before user clicks "Join")
  fastify.get<{ Params: { token: string } }>('/invite/:token', async (request, reply) => {
    const { token } = request.params;

    try {
      const invite = await prisma.groupInvite.findUnique({
        where: { token },
        include: {
          group: { select: { id: true, name: true, type: true } },
          creator: { select: { name: true } }
        }
      });

      if (!invite || invite.expiresAt < new Date()) {
        return reply.code(400).send({ success: false, error: 'Invite link is invalid or expired' });
      }

      return reply.send({ 
        success: true, 
        data: {
          groupName: invite.group.name,
          groupType: invite.group.type,
          invitedBy: invite.creator.name,
          expiresAt: invite.expiresAt
        }
      });
    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });

  // POST /api/v1/invite/:token/accept
  // User consumes the invite token to join the group
  fastify.post<{ Params: { token: string } }>('/invite/:token/accept', async (request, reply) => {
    const { token } = request.params;
    const userId = (request as any).userId; // Simulated auth

    try {
      const invite = await prisma.groupInvite.findUnique({
        where: { token }
      });

      if (!invite || invite.expiresAt < new Date()) {
        return reply.code(400).send({ success: false, error: 'Invite link is invalid or expired' });
      }

      // Check if already a member
      const existing = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: invite.groupId, userId } }
      });

      if (existing) {
        return reply.send({ success: true, message: 'Already a member', groupId: invite.groupId });
      }

      // Atomically add them to the group
      await prisma.groupMember.create({
        data: {
          groupId: invite.groupId,
          userId: userId,
          role: 'member'
        }
      });

      // TODO: Broadcast Socket.io event "member_joined" to group room

      return reply.send({ success: true, message: 'Joined group successfully', groupId: invite.groupId });

    } catch (e) {
      return reply.code(500).send({ success: false, code: 'SERVER_ERROR' });
    }
  });
}
