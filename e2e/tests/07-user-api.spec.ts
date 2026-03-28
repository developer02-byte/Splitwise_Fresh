import { test, expect } from '@playwright/test';
import { login, authHeader } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 7: User API', () => {
  test('GET /api/user/me — returns full profile', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/user/me`, { headers: authHeader(tokens.accessToken) });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data).toHaveProperty('id');
    expect(body.data).toHaveProperty('name');
    expect(body.data).toHaveProperty('email');
    expect(body.data).toHaveProperty('defaultCurrency');
    expect(body.data).toHaveProperty('onboardingCompleted');
  });

  test('PUT /api/user/me — updates name', async ({ request }) => {
    // Use bob to avoid polluting alice's profile
    const tokens = await login(request, 'bob@example.com');
    const resp = await request.put(`${BASE}/api/user/me`, {
      headers: authHeader(tokens.accessToken),
      data: { name: 'Bob Updated' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.data.name).toBe('Bob Updated');

    // Restore original name
    await request.put(`${BASE}/api/user/me`, {
      headers: authHeader(tokens.accessToken),
      data: { name: 'Bob Smith' },
    });
  });

  test('PUT /api/user/me — updates defaultCurrency', async ({ request }) => {
    const tokens = await login(request, 'bob@example.com');
    const resp = await request.put(`${BASE}/api/user/me`, {
      headers: authHeader(tokens.accessToken),
      data: { defaultCurrency: 'EUR' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.data.defaultCurrency).toBe('EUR');

    // Restore
    await request.put(`${BASE}/api/user/me`, {
      headers: authHeader(tokens.accessToken),
      data: { defaultCurrency: 'USD' },
    });
  });

  test('PUT /api/user/me — updates onboardingCompleted', async ({ request }) => {
    const tokens = await login(request, 'charlie@example.com');
    // Charlie already has onboardingCompleted: true, verify we can toggle
    const resp = await request.put(`${BASE}/api/user/me`, {
      headers: authHeader(tokens.accessToken),
      data: { onboardingCompleted: true },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.data.onboardingCompleted).toBe(true);
  });

  test('GET /api/user/balances — returns balance structure', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/user/balances`, { headers: authHeader(tokens.accessToken) });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data).toHaveProperty('userAreOwed');
    expect(body.data).toHaveProperty('userOwe');
    expect(body.data).toHaveProperty('totalBalance');
    expect(body.data).toHaveProperty('currency');
  });

  test('GET /api/user/profile — alternate profile endpoint', async ({ request }) => {
    const tokens = await login(request);
    const resp = await request.get(`${BASE}/api/user/profile`, { headers: authHeader(tokens.accessToken) });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data).toHaveProperty('id');
    expect(body.data).toHaveProperty('name');
  });

  test('PATCH /api/user/profile — alternate update endpoint', async ({ request }) => {
    const tokens = await login(request, 'charlie@example.com');
    const resp = await request.patch(`${BASE}/api/user/profile`, {
      headers: authHeader(tokens.accessToken),
      data: { name: 'Charlie Patched' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.data.name).toBe('Charlie Patched');

    // Restore
    await request.patch(`${BASE}/api/user/profile`, {
      headers: authHeader(tokens.accessToken),
      data: { name: 'Charlie Brown' },
    });
  });
});
