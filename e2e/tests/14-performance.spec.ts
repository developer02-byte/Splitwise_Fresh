import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 14: Performance Baseline', () => {
  test('Login page loads within 5 seconds', async ({ page }) => {
    const start = Date.now();
    await page.goto(`${BASE}/login`, { waitUntil: 'domcontentloaded' });
    const elapsed = Date.now() - start;
    console.log(`Login page load: ${elapsed}ms`);
    expect(elapsed).toBeLessThan(5000);
  });

  test('Dashboard API call completes within 2 seconds', async ({ request }) => {
    const tokens = await login(request);
    const start = Date.now();
    const resp = await request.get(`${BASE}/api/user/balances`, {
      headers: authHeader(tokens.accessToken),
    });
    const elapsed = Date.now() - start;
    console.log(`Balances API: ${elapsed}ms`);
    expect(resp.ok()).toBeTruthy();
    expect(elapsed).toBeLessThan(2000);
  });

  test('Groups API call completes within 2 seconds', async ({ request }) => {
    const tokens = await login(request);
    const start = Date.now();
    const resp = await request.get(`${BASE}/api/groups`, {
      headers: authHeader(tokens.accessToken),
    });
    const elapsed = Date.now() - start;
    console.log(`Groups API: ${elapsed}ms`);
    expect(resp.ok()).toBeTruthy();
    expect(elapsed).toBeLessThan(2000);
  });

  test('Friends API call completes within 2 seconds', async ({ request }) => {
    const tokens = await login(request);
    const start = Date.now();
    const resp = await request.get(`${BASE}/api/user/friends`, {
      headers: authHeader(tokens.accessToken),
    });
    const elapsed = Date.now() - start;
    console.log(`Friends API: ${elapsed}ms`);
    expect(resp.ok()).toBeTruthy();
    expect(elapsed).toBeLessThan(2000);
  });

  test('Currency rates API completes within 2 seconds', async ({ request }) => {
    const start = Date.now();
    const resp = await request.get(`${BASE}/api/currencies/rates`);
    const elapsed = Date.now() - start;
    console.log(`Currency rates API: ${elapsed}ms`);
    expect(resp.ok()).toBeTruthy();
    expect(elapsed).toBeLessThan(2000);
  });
});
