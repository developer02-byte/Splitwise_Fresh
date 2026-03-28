import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export type NotificationType = 'expense' | 'settlement' | 'group_invite' | 'comment' | 'reminder' | 'friend_request';

export class NotificationService {
  
  static async notify({
    recipientId,
    title,
    message,
    referenceType,
    referenceId
  }: {
    recipientId: number;
    title: string;
    message: string;
    referenceType: NotificationType;
    referenceId?: number;
  }) {
    try {
      const user = await prisma.user.findUnique({ where: { id: recipientId }, select: { pushToken: true } });
      
      const notification = await prisma.notification.create({
        data: {
          recipientId,
          title,
          body: message,
          referenceType: referenceType as any,
          referenceId
        }
      });

      if (user?.pushToken) {
        // Here we would call FCM/SNS/Expo
        console.log(`[PUSH]: Sending notification to token ${user.pushToken}: ${title} - ${message}`);
      }

      return notification;
    } catch (e) {
      console.error('Failed to create notification:', e);
    }
  }

  static async notifyBulk(notifications: {
    recipientId: number;
    title: string;
    message: string;
    referenceType: NotificationType;
    referenceId?: number;
  }[]) {
    try {
      return await prisma.notification.createMany({
        data: notifications.map(n => ({
          recipientId: n.recipientId,
          title: n.title,
          body: n.message,
          referenceType: n.referenceType,
          referenceId: n.referenceId
        }))
      });
    } catch (e) {
      console.error('Failed to create bulk notifications:', e);
    }
  }
}
