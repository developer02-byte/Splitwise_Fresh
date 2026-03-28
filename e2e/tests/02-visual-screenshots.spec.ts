import { test, expect, Page } from '@playwright/test';
import { login } from '../helpers/auth';
import path from 'path';

const SCREENSHOT_DIR = path.join(__dirname, '..', 'screenshots');
const BASE = 'http://localhost:8080';

const VIEWPORTS = [
  { name: 'desktop', width: 1920, height: 1080 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 375, height: 812 },
] as const;

async function waitForFlutter(page: Page) {
  await page.waitForLoadState('domcontentloaded');
  // Wait for Flutter engine to initialize, render, and API calls to complete
  await page.waitForTimeout(6000);
}

async function screenshotPage(page: Page, name: string, viewportName: string) {
  const filePath = path.join(SCREENSHOT_DIR, `${name}-${viewportName}.png`);
  await page.screenshot({ path: filePath, fullPage: true });
  return filePath;
}

/**
 * Create a browser context with auth header injection via route interception.
 * This injects Authorization headers into all /api/ requests so Flutter's
 * auth provider sees the user as authenticated.
 */
async function createAuthedContext(
  browser: any,
  token: string,
  viewport: { width: number; height: number }
) {
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  await page.route('**/api/**', async (route: any) => {
    const headers = {
      ...route.request().headers(),
      authorization: `Bearer ${token}`,
    };
    await route.fallback({ headers });
  });
  return { context, page };
}

test.describe('Phase 2: Visual Screenshots', () => {
  // ─── Unauthenticated pages ───
  for (const vp of VIEWPORTS) {
    test(`Login page (default) — ${vp.name}`, async ({ browser }) => {
      const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
      const page = await context.newPage();
      await page.goto(`${BASE}/login`);
      await waitForFlutter(page);
      await screenshotPage(page, 'login-default', vp.name);
      await context.close();
    });
  }

  for (const vp of VIEWPORTS) {
    test(`Login page (signup mode) — ${vp.name}`, async ({ browser }) => {
      const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
      const page = await context.newPage();
      await page.goto(`${BASE}/login`);
      await waitForFlutter(page);
      try {
        const signupToggle = page.getByText('Sign Up').first();
        await signupToggle.click({ timeout: 5000 });
        await page.waitForTimeout(1000);
      } catch {}
      await screenshotPage(page, 'login-signup', vp.name);
      await context.close();
    });
  }

  test('Login page — validation errors (desktop)', async ({ browser }) => {
    const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
    const page = await context.newPage();
    await page.goto(`${BASE}/login`);
    await waitForFlutter(page);
    try {
      const submitBtn = page.getByText('Log In').first();
      await submitBtn.click({ timeout: 5000 });
      await page.waitForTimeout(1500);
    } catch {}
    await screenshotPage(page, 'login-validation', 'desktop');
    await context.close();
  });

  // ─── Authenticated pages — use route interception for auth ───
  test('Authenticated pages — all viewports', { timeout: 300_000 }, async ({ browser, request }) => {
    const tokens = await login(request);
    const token = tokens.accessToken;

    const pages = [
      { route: '/dashboard', name: 'dashboard' },
      { route: '/groups', name: 'groups' },
      { route: '/friends', name: 'friends' },
      { route: '/activity', name: 'activity' },
    ];

    for (const vp of VIEWPORTS) {
      for (const pg of pages) {
        const { context, page } = await createAuthedContext(browser, token, {
          width: vp.width,
          height: vp.height,
        });
        await page.goto(`${BASE}${pg.route}`);
        await waitForFlutter(page);
        await screenshotPage(page, pg.name, vp.name);
        await context.close();
      }
    }
  });

  // Onboarding pages — fresh user who hasn't completed onboarding
  test('Onboarding pages — desktop', async ({ browser, request }) => {
    const email = `onboard-${Date.now()}@e2e-test.com`;
    const signupResp = await request.post(`${BASE}/api/auth/signup`, {
      data: { name: 'Onboard Test', email, password: 'password123' },
    });
    const signupBody = await signupResp.json();
    const token = signupBody.data.token;

    const { context, page } = await createAuthedContext(browser, token, {
      width: 1920,
      height: 1080,
    });
    await page.goto(`${BASE}/onboarding`);
    await waitForFlutter(page);
    await screenshotPage(page, 'onboarding-page1', 'desktop');

    try {
      const nextBtn = page.getByText(/next|continue/i).first();
      await nextBtn.click({ timeout: 5000 });
      await page.waitForTimeout(1500);
      await screenshotPage(page, 'onboarding-page2', 'desktop');
      await nextBtn.click({ timeout: 5000 });
      await page.waitForTimeout(1500);
      await screenshotPage(page, 'onboarding-page3', 'desktop');
    } catch {
      await screenshotPage(page, 'onboarding-all', 'desktop');
    }

    await context.close();
  });
});
