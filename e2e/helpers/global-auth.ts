import { APIRequestContext } from '@playwright/test';

const BASE_URL = 'http://localhost:8080';

export interface AuthTokens {
  accessToken: string;
  userId: number;
}

// Global token store shared across ALL test files via module caching
const globalTokens: Record<string, AuthTokens> = {};

const TEST_ACCOUNTS = [
  { email: 'alice@example.com', password: 'password123' },
  { email: 'bob@example.com', password: 'password123' },
  { email: 'charlie@example.com', password: 'password123' },
];

/**
 * Login with any available test account. Caches aggressively to avoid rate limits.
 * The 5 req/min rate limit means we can only login 5 times per minute per email.
 * With 3 accounts, that's 15 logins per minute.
 */
export async function getAuthTokens(request: APIRequestContext): Promise<AuthTokens> {
  // Return first cached token
  for (const account of TEST_ACCOUNTS) {
    if (globalTokens[account.email]) {
      return globalTokens[account.email];
    }
  }

  // Try each account
  for (const account of TEST_ACCOUNTS) {
    try {
      const response = await request.post(`${BASE_URL}/api/auth/login`, {
        data: { email: account.email, password: account.password },
      });
      const body = await response.json();
      if (body.success) {
        const tokens: AuthTokens = {
          accessToken: body.data.token,
          userId: body.data.user.id,
        };
        globalTokens[account.email] = tokens;
        return tokens;
      }
    } catch {}
  }

  throw new Error('All test accounts rate limited');
}
