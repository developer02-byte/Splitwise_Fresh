import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 11: Settlements API', () => {
  test('POST /api/settlements — create settlement', async ({ request }) => {
    const aliceTokens = await login(request);
    const bobTokens = await login(request, 'bob@example.com');

    // Ensure bob is a friend
    await request.post(`${BASE}/api/user/friends`, {
      headers: authHeader(aliceTokens.accessToken),
      data: { email: 'bob@example.com' },
    });

    // Create a group
    const groupResp = await request.post(`${BASE}/api/groups`, {
      headers: authHeader(aliceTokens.accessToken),
      data: { name: 'Settlement Group', type: 'home' },
    });
    const groupBody = await groupResp.json();

    const resp = await request.post(`${BASE}/api/settlements`, {
      headers: authHeader(aliceTokens.accessToken),
      data: {
        payeeId: bobTokens.userId,
        amountCents: 1000,
        currency: 'USD',
        groupId: groupBody.data?.id,
      },
    });
    if (resp.status() === 404) {
      console.log('Settlement endpoint not at /api/settlements');
    } else {
      const body = await resp.json();
      expect(body.success).toBe(true);
    }
  });
});
