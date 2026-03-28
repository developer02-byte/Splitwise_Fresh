import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 9: Expense API', () => {
  let token: string;
  let userId: number;
  let groupId: number;

  test('Setup: login and create group for expenses', async ({ request }) => {
    const tokens = await login(request);
    token = tokens.accessToken;
    userId = tokens.userId;

    // Create a group
    const groupResp = await request.post(`${BASE}/api/groups`, {
      headers: authHeader(token),
      data: { name: 'Expense Test Group', type: 'home' },
    });
    const groupBody = await groupResp.json();
    expect(groupBody.success).toBe(true);
    groupId = groupBody.data.id;
  });

  test('POST /api/expenses — create expense with splits', async ({ request }) => {
    if (!groupId) test.skip();
    const resp = await request.post(`${BASE}/api/expenses`, {
      headers: authHeader(token),
      data: {
        groupId,
        title: 'Test Dinner',
        totalAmount: 5000,
        originalCurrency: 'USD',
        paidBy: userId,
        splits: [{ userId, owedAmount: 5000 }],
      },
    });
    // Accept either 200 or 201
    expect(resp.status()).toBeLessThan(300);
    const body = await resp.json();
    expect(body.success).toBe(true);
  });
});
