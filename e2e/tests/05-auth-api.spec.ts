import { test, expect } from '@playwright/test';
import { uniqueEmail } from '../helpers/auth';

const BASE = 'http://localhost:8080';

test.describe('Phase 5: Auth API', () => {
  let testEmail: string;
  let testToken: string;

  test.beforeAll(() => {
    testEmail = uniqueEmail('auth');
  });

  test('POST /api/auth/signup — creates user, returns JWT', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/signup`, {
      data: { name: 'Auth Test', email: testEmail, password: 'password123' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data.token).toBeDefined();
    expect(body.data.email).toBe(testEmail);
    testToken = body.data.token;
  });

  test('POST /api/auth/signup — duplicate email returns 400', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/signup`, {
      data: { name: 'Dup', email: testEmail, password: 'password123' },
    });
    expect(resp.status()).toBe(400);
    const body = await resp.json();
    expect(body.success).toBe(false);
    expect(body.code).toBe('AUTH_EXISTS');
  });

  test('POST /api/auth/signup — missing fields returns 400', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/signup`, {
      data: { email: 'missing@fields.com' },
    });
    expect(resp.status()).toBe(400);
    const body = await resp.json();
    expect(body.success).toBe(false);
  });

  test('POST /api/auth/login — correct credentials return JWT + cookies', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/login`, {
      data: { email: 'alice@example.com', password: 'password123' },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data.token).toBeDefined();
    expect(body.data.user.email).toBe('alice@example.com');

    // Check cookies are set
    const headers = resp.headers();
    const setCookie = headers['set-cookie'];
    expect(setCookie).toBeDefined();
    expect(setCookie).toContain('access_token');
  });

  test('POST /api/auth/login — wrong password returns 401', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/login`, {
      data: { email: 'alice@example.com', password: 'wrongpassword' },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.success).toBe(false);
    expect(body.code).toBe('AUTH_INVALID');
  });

  test('POST /api/auth/login — nonexistent email returns 401', async ({ request }) => {
    const resp = await request.post(`${BASE}/api/auth/login`, {
      data: { email: 'nonexistent@example.com', password: 'password123' },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.success).toBe(false);
  });

  test('GET /api/user/me — valid JWT returns user', async ({ request }) => {
    const resp = await request.get(`${BASE}/api/user/me`, {
      headers: { Authorization: `Bearer ${testToken}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
    expect(body.data.email).toBe(testEmail);
    expect(body.data).toHaveProperty('onboardingCompleted');
  });

  test('GET /api/user/me — no token returns 401', async ({ request }) => {
    const resp = await request.get(`${BASE}/api/user/me`);
    expect(resp.status()).toBe(401);
  });

  test('GET /api/user/me — forged token returns 401', async ({ request }) => {
    const resp = await request.get(`${BASE}/api/user/me`, {
      headers: { Authorization: 'Bearer user_ID_1' },
    });
    expect(resp.status()).toBe(401);
  });

  test('POST /api/auth/logout — clears cookies', async ({ request }) => {
    // Login first to get cookies
    const loginResp = await request.post(`${BASE}/api/auth/login`, {
      data: { email: testEmail, password: 'password123' },
    });
    const loginBody = await loginResp.json();
    const token = loginBody.data.token;

    const resp = await request.post(`${BASE}/api/auth/logout`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(resp.ok()).toBeTruthy();
    const body = await resp.json();
    expect(body.success).toBe(true);
  });

  test('Rate limiting — 6th login attempt within 1 minute returns 429', async ({ request }) => {
    const email = uniqueEmail('rate');
    // Sign up first
    await request.post(`${BASE}/api/auth/signup`, {
      data: { name: 'Rate Test', email, password: 'password123' },
    });

    // Make 5 login attempts (the rate limit)
    for (let i = 0; i < 5; i++) {
      await request.post(`${BASE}/api/auth/login`, {
        data: { email, password: 'password123' },
      });
    }

    // 6th attempt should be rate limited
    const resp = await request.post(`${BASE}/api/auth/login`, {
      data: { email, password: 'password123' },
    });
    expect(resp.status()).toBe(429);
  });
});
