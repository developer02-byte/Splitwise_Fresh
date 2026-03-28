import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { attachMonitors } from '../helpers/monitors';

const BASE = 'http://localhost:8080';

async function createAuthedPage(browser: any, token: string) {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.route('**/api/**', async (route: any) => {
    const headers = { ...route.request().headers(), authorization: `Bearer ${token}` };
    await route.fallback({ headers });
  });
  return { context, page };
}

test.describe('Phase 3: Console & Network Error Monitoring', () => {
  const authedPages = ['/dashboard', '/groups', '/friends', '/activity'];
  const publicPages = ['/login'];

  test('Public pages have no JS exceptions', async ({ browser }) => {
    for (const route of publicPages) {
      const context = await browser.newContext();
      const page = await context.newPage();
      const monitors = attachMonitors(page);
      await page.goto(`${BASE}${route}`);
      await page.waitForLoadState('domcontentloaded');
      await page.waitForTimeout(5000);
      monitors.assertClean();
      await context.close();
    }
  });

  test('Authenticated pages have no JS exceptions', async ({ browser, request }) => {
    const tokens = await login(request);
    for (const route of authedPages) {
      const { context, page } = await createAuthedPage(browser, tokens.accessToken);
      const monitors = attachMonitors(page);
      await page.goto(`${BASE}${route}`);
      await page.waitForLoadState('domcontentloaded');
      await page.waitForTimeout(6000);
      monitors.assertClean();
      await context.close();
    }
  });

  test('No unexpected 5xx API errors on page load', async ({ browser, request }) => {
    const tokens = await login(request);
    const { context, page } = await createAuthedPage(browser, tokens.accessToken);
    const monitors = attachMonitors(page);
    await page.goto(`${BASE}/dashboard`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(6000);

    const failed = monitors.getFailedRequests().filter(r => r.status >= 500);
    expect(failed, `5xx errors found: ${JSON.stringify(failed)}`).toHaveLength(0);
    await context.close();
  });

  test('No requests take longer than 5 seconds', async ({ browser, request }) => {
    const tokens = await login(request);
    const { context, page } = await createAuthedPage(browser, tokens.accessToken);
    const monitors = attachMonitors(page);
    await page.goto(`${BASE}/dashboard`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(6000);

    const slow = monitors.getSlowRequests();
    expect(slow, `Slow requests: ${JSON.stringify(slow)}`).toHaveLength(0);
    await context.close();
  });
});
