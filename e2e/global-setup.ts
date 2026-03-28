import { request } from '@playwright/test';
import fs from 'fs';
import path from 'path';

const BASE = 'http://localhost:8080';
const TOKEN_FILE = path.join(__dirname, '.auth-tokens.json');

async function globalSetup() {
  const ctx = await request.newContext();
  const tokens: Record<string, { accessToken: string; userId: number }> = {};

  for (const account of [
    { email: 'alice@example.com', password: 'password123' },
    { email: 'bob@example.com', password: 'password123' },
    { email: 'charlie@example.com', password: 'password123' },
  ]) {
    const resp = await ctx.post(`${BASE}/api/auth/login`, {
      data: { email: account.email, password: account.password },
    });
    const body = await resp.json();
    if (body.success) {
      tokens[account.email] = {
        accessToken: body.data.token,
        userId: body.data.user.id,
      };
    }
  }

  fs.writeFileSync(TOKEN_FILE, JSON.stringify(tokens));
  await ctx.dispose();
}

export default globalSetup;
