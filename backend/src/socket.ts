import { Server as SocketIOServer } from 'socket.io';
import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import cookie from 'cookie';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();

let io: SocketIOServer;

export function setupSocketServer(fastify: FastifyInstance) {
  io = new SocketIOServer(fastify.server, {
    cors: {
      origin: true,
      credentials: true, // Necessary to receive HttpOnly cookies securely
    }
  });

  // 1. Authentication Handshake Middleware
  io.use(async (socket, next) => {
    try {
      // Parse the HttpOnly 'access_token' cookie set in Auth_Contract.md
      const cookiesStr = socket.request.headers.cookie;
      if (!cookiesStr) return next(new Error("Authentication error: No cookies"));
      
      const cookies = cookie.parse(cookiesStr);
      const token = cookies.access_token;

      if (!token) return next(new Error("Authentication error: Missing token"));

      // Verify JWT and extract userId
      let userId: number;
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret') as { sub: number };
        userId = decoded.sub;
      } catch {
        return next(new Error("Authentication error: Invalid token"));
      }

      // Attach user object to socket for later event context
      (socket as any).userId = userId;

      next();
    } catch (e) {
      next(new Error("Authentication error: Invalid signature"));
    }
  });

  // 2. Room Assignment Connection Flow
  io.on('connection', async (socket) => {
    const userId = (socket as any).userId;
    fastify.log.info(`Socket User ${userId} connected (${socket.id})`);

    // Join permanent individual user room (for 1-on-1 settlements and personal balances)
    socket.join(`user:${userId}`);

    // Fetch all active groups for this user and join their respective rooms
    try {
      const memberships = await prisma.groupMember.findMany({
        where: { userId },
        select: { groupId: true }
      });

      memberships.forEach(member => {
        socket.join(`group:${member.groupId}`);
      });
    } catch (e) {
      fastify.log.error(`Failed to join group rooms for User ${userId}`, e);
    }

    // Client explicitly requests to join a new group room (Optimistic UI created a group)
    socket.on('room:join', (groupId: number) => {
      socket.join(`group:${groupId}`);
    });

    socket.on('disconnect', () => {
      fastify.log.info(`Socket User ${userId} disconnected`);
    });
  });
}

// 3. Global Event Broadcasters (Called from routes/expenses.ts and routes/settlements.ts)
export function broadcastToGroup(groupId: number, event: string, payload: any) {
  if (io) {
    io.to(`group:${groupId}`).emit(event, { eventId: Date.now(), ...payload });
  }
}

export function broadcastToUser(userId: number, event: string, payload: any) {
  if (io) {
    io.to(`user:${userId}`).emit(event, { eventId: Date.now(), ...payload });
  }
}
