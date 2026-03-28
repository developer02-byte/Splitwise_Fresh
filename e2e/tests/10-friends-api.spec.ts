import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 10: Friends API', () => {
  test('POST /api/user/friends — add friend by email', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.post(`${BASE}/api/user/friends`, {
      headers: authHeader(tokens.accessToken),
      data: { email: 'bob@example.com' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
  });

  test('GET /api/user/friends — list friends', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/user/friends`, {
      headers: authHeader(tokens.accessToken),
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(Array.isArray(body.data)).toBe(true);
  });
});
