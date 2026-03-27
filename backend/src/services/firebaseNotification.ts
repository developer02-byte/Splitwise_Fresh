import * as admin from 'firebase-admin';

// Initialize Firebase Admin once (singleton pattern)
let initialized = false;

export function initFirebase() {
  if (initialized) return;

  // Uses GOOGLE_APPLICATION_CREDENTIALS env var pointing to service-account.json
  // Or use admin.credential.cert(require('./service-account.json')) directly
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  initialized = true;
  console.log('[Firebase] Admin SDK initialized');
}

export interface PushPayload {
  userId: number;
  title: string;
  body: string;
  data?: Record<string, string>; // Deep-link metadata
}

/**
 * Sends a push notification to all registered devices of a user.
 * Falls back silently if the user has no device tokens.
 */
export async function sendPushNotification(
  payload: PushPayload,
  deviceTokens: string[]
): Promise<void> {
  if (!deviceTokens.length) return;

  const message: admin.messaging.MulticastMessage = {
    tokens: deviceTokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    // Deep-link data for Go_Router navigation on tap
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      ...payload.data,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'splitease_main',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `[Firebase] Sent ${response.successCount}/${deviceTokens.length} notifications for user ${payload.userId}`
    );

    // Log failed tokens for token cleanup
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.warn(`[Firebase] Token failed: ${deviceTokens[idx]} — ${resp.error?.message}`);
        }
      });
    }
  } catch (e) {
    console.error('[Firebase] Push dispatch error:', e);
  }
}
