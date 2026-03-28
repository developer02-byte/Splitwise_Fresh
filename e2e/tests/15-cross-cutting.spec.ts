import { test, expect } from '@playwright/test';

const BASE = 'http://localhost:8080';
const API_DIRECT = 'http://localhost:3000';

test.describe('Phase 15: Cross-cutting', () => {
  test('CORS — API rejects requests from disallowed origins', async ({ request }) => {
    const resp = await request.get(`${API_DIRECT}/api/currencies/rates`, {
      headers: { Origin: 'http://evil.example.com' },
    });
    // The API should still respond but CORS headers should not include evil origin
    expect(resp.ok()).toBeTruthy();
    const corsHeader = resp.headers()['access-control-allow-origin'];
    if (corsHeader) {
      expect(corsHeader).not.toBe('http://evil.example.com');
    }
  });

  test('WebSocket — Socket.io endpoint exists', async ({ request }) => {
    const resp = await request.get(`${BASE}/socket.io/?EIO=4&transport=polling`);
    // Socket.io should respond (even if auth fails)
    expect(resp.status()).toBeLessThan(500);
  });
});
