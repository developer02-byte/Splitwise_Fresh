import { test, expect } from '@playwright/test';

const BASE = 'http://localhost:8080';
const API_DIRECT = 'http://localhost:3000';

test.describe('Phase 1: Infrastructure Health', () => {
  test('Docker containers are running — PostgreSQL accepts connections', async ({ request }) => {
    // The API connects to PostgreSQL on startup; if it responds, PG is up
    const response = await request.post(`${BASE}/api/auth/login`, {
      data: { email: 'alice@example.com', password: 'password123' },
    });
    expect(response.status()).toBeLessThan(500);
    const body = await response.json();
    expect(body.success).toBe(true);
  });

  test('Redis accepts connections — API health implies Redis is up', async ({ request }) => {
    // The API depends on Redis (BullMQ queues); successful startup means Redis is connected
    const response = await request.get(`${API_DIRECT}/api/currencies/rates`);
    expect(response.ok()).toBeTruthy();
  });

  test('API responds on :3000 (direct)', async ({ request }) => {
    const response = await request.get(`${API_DIRECT}/api/currencies/rates`);
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.success).toBe(true);
    expect(body.data).toBeDefined();
  });

  test('NGINX proxies API correctly on :8080', async ({ request }) => {
    const response = await request.get(`${BASE}/api/currencies/rates`);
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.success).toBe(true);
  });

  test('Frontend loads on :8080 (HTTP 200 with Flutter content)', async ({ request }) => {
    const response = await request.get(BASE);
    expect(response.ok()).toBeTruthy();
    const html = await response.text();
    // Flutter Web injects a script and uses CanvasKit
    expect(html).toContain('flutter');
  });

  test('NGINX proxies /api/auth/login correctly', async ({ request }) => {
    const response = await request.post(`${BASE}/api/auth/login`, {
      data: { email: 'alice@example.com', password: 'password123' },
    });
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.success).toBe(true);
    expect(body.data.token).toBeDefined();
  });
});
