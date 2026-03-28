import { test, expect } from '@playwright/test';
import { login, authHeader, uniqueEmail, signup } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 8: Group API', () => {
  let token: string;
  let createdGroupId: number;

  test.beforeAll(async ({ request }) => {
    // This won't work in beforeAll with request fixture
    // We'll login in first test instead
  });

  test('POST /api/groups — create a group', async ({ request }) => {
    const tokens = await login(request);
    token = tokens.accessToken;
    const resp = await request.post(`${BASE}/api/groups`, {
      headers: authHeader(token),
      data: { name: 'Test Group', type: 'trip' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data).toHaveProperty('id');
    createdGroupId = body.data.id;
  });

  test('GET /api/groups — list groups', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/groups`, {
      headers: authHeader(tokens.accessToken),
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(Array.isArray(body.data)).toBe(true);
  });

  test('GET /api/groups/:id/ledger — get group ledger', async ({ request }) => {
    if (!createdGroupId) test.skip();
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/groups/${createdGroupId}/ledger`, {
      headers: authHeader(tokens.accessToken),
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
  });
});
