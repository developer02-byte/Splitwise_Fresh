import { test as base, Page, BrowserContext } from '@playwright/test';
import { login, AuthTokens } from './auth';
import { ApiHelper } from './api';
import { attachMonitors, Monitors } from './monitors';

const BASE_URL = 'http://localhost:8080';

/**
 * Extended test fixtures providing:
 * - authTokens: The JWT tokens for API calls
 * - api: An ApiHelper instance for direct API calls
 * - authedPage: A page with auth token injected via route interception
 * - monitors: Page monitors attached to authedPage
 */
type TestFixtures = {
  authTokens: AuthTokens;
  api: ApiHelper;
  authedPage: Page;
  monitors: Monitors;
};

export const test = base.extend<TestFixtures>({
  authTokens: async ({ request }, use) => {
    const tokens = await login(request);
    await use(tokens);
  },

  api: async ({ request, authTokens }, use) => {
    const helper = new ApiHelper(request, authTokens.accessToken);
    await use(helper);
  },

  authedPage: async ({ browser, authTokens }, use) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    // Intercept API requests and inject auth header so Flutter's auth guard passes
    await page.route('**/api/**', async (route) => {
      const headers = {
        ...route.request().headers(),
        authorization: `Bearer ${authTokens.accessToken}`,
      };
      await route.fallback({ headers });
    });
    await use(page);
    await context.close();
  },

  monitors: async ({ authedPage }, use) => {
    const m = attachMonitors(authedPage);
    await use(m);
  },
});

export { expect } from '@playwright/test';
