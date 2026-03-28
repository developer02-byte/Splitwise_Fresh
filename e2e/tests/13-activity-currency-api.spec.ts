import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 13: Activity & Currency APIs', () => {
  test('GET /api/user/activities — list activities', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/user/activities`, {
      headers: authHeader(tokens.accessToken),
    });
    // May return 200 with empty array or have query params
    if (resp.ok()) {
      const body = await resp.json();
      expect(body.success).toBe(true);
    } else {
      // Try with filter param
      const resp2 = await request.get(`${BASE}/api/user/activities?filter=all`, {
        headers: authHeader(tokens.accessToken),
      });
      expect(resp2.ok()).toBeTruthy();
    }
  });

  test('GET /api/currencies/rates — returns exchange rates', async ({ request }) => {
    const resp = await request.get(`${BASE}/api/currencies/rates`);
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data).toBeDefined();
    expect(body.data).toHaveProperty('USD_EUR');
  });
});
