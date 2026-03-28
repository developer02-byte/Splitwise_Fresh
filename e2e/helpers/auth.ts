import { APIRequestContext } from '@playwright/test';
import fs from 'fs';
import path from 'path';

const BASE_URL = 'http://localhost:8080';
const TOKEN_FILE = path.join(__dirname, '..', '.auth-tokens.json');

export interface AuthTokens {
  accessToken: string;
  userId: number;
}

/**
 * Read pre-authenticated tokens from globalSetup cache file.
 * Falls back to live login if file doesn't exist.
 */
export async function login(
  request: APIRequestContext,
  email: string = 'alice@example.com',
  password: string = 'password123'
): Promise<AuthTokens> {
  // Try reading from cached tokens first
  try {
    if (fs.existsSync(TOKEN_FILE)) {
      const cached = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf-8'));
      // Try the requested email first, then fallbacks
      for (const tryEmail of [email, 'alice@example.com', 'bob@example.com', 'charlie@example.com']) {
        if (cached[tryEmail]) return cached[tryEmail];
      }
    }
  } catch {}

  // Fallback: live login
  const response = await request.post(`${BASE_URL}/api/auth/login`, {
    data: { email, password },
  });
  const body = await response.json();
  if (!body.success) {
    throw new Error(`Login failed for ${email}: ${body.error}`);
  }
  return {
    accessToken: body.data.token,
    userId: body.data.user.id,
  };
}

/**
 * Signup via API and return the access token + user info.
 */
export async function signup(
  request: APIRequestContext,
  name: string,
  email: string,
  password: string = 'password123'
): Promise<AuthTokens> {
  const response = await request.post(`${BASE_URL}/api/auth/signup`, {
    data: { name, email, password },
  });
  const body = await response.json();
  if (!body.success) {
    throw new Error(`Signup failed for ${email}: ${body.error}`);
  }
  return {
    accessToken: body.data.token,
    userId: body.data.id,
  };
}

/**
 * Create an Authorization header object for authenticated API calls.
 */
export function authHeader(token: string): Record<string, string> {
  return { Authorization: `Bearer ${token}` };
}

/**
 * Generate a unique test email using timestamp + random suffix.
 */
export function uniqueEmail(prefix: string = 'test'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}@e2e-test.com`;
}
