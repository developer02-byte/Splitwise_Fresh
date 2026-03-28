import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { login } from '../helpers/auth';

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

test.describe('Phase 4: Accessibility (a11y)', () => {
  test('Login page accessibility scan', async ({ page }) => {
    await page.goto(`${BASE}/login`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(5000);

    const results = await new AxeBuilder({ page }).analyze();
    const critical = results.violations.filter(v => v.impact === 'critical');
    const serious = results.violations.filter(v => v.impact === 'serious');

    if (results.violations.length > 0) {
      console.log('A11y violations on /login:');
      for (const v of results.violations) {
        console.log(`  [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} instances)`);
      }
    }

    expect(critical, `Critical a11y violations: ${critical.map(v => v.id).join(', ')}`).toHaveLength(0);
    // Serious violations are reported but not blocking for Flutter CanvasKit
  });

  test('Dashboard accessibility scan', async ({ browser, request }) => {
    const tokens = await login(request);
    const { context, page } = await createAuthedPage(browser, tokens.accessToken);
    await page.goto(`${BASE}/dashboard`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(6000);

    const results = await new AxeBuilder({ page }).analyze();
    const critical = results.violations.filter(v => v.impact === 'critical');

    if (results.violations.length > 0) {
      console.log('A11y violations on /dashboard:');
      for (const v of results.violations) {
        console.log(`  [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} instances)`);
      }
    }

    expect(critical, `Critical a11y violations: ${critical.map(v => v.id).join(', ')}`).toHaveLength(0);
    await context.close();
  });

  test('Groups page accessibility scan', async ({ browser, request }) => {
    const tokens = await login(request);
    const { context, page } = await createAuthedPage(browser, tokens.accessToken);
    await page.goto(`${BASE}/groups`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(6000);

    const results = await new AxeBuilder({ page }).analyze();
    const critical = results.violations.filter(v => v.impact === 'critical');

    if (results.violations.length > 0) {
      console.log('A11y violations on /groups:');
      for (const v of results.violations) {
        console.log(`  [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} instances)`);
      }
    }

    expect(critical).toHaveLength(0);
    await context.close();
  });
});
