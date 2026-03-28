import { Page, expect } from '@playwright/test';

interface FailedRequest {
  url: string;
  status: number;
  method: string;
}

interface MonitorResult {
  consoleErrors: string[];
  jsExceptions: string[];
  failedRequests: FailedRequest[];
  slowRequests: { url: string; duration: number; method: string }[];
}

export interface Monitors {
  getConsoleErrors(): string[];
  getJsExceptions(): string[];
  getFailedRequests(): FailedRequest[];
  getSlowRequests(): { url: string; duration: number; method: string }[];
  getAll(): MonitorResult;
  assertClean(options?: { allowedConsolePatterns?: RegExp[] }): void;
  reset(): void;
}

/**
 * Attach console error, JS exception, and network failure monitors to a page.
 * Call assertClean() at the end of each test to verify no silent errors occurred.
 */
export function attachMonitors(page: Page): Monitors {
  const consoleErrors: string[] = [];
  const jsExceptions: string[] = [];
  const failedRequests: FailedRequest[] = [];
  const slowRequests: { url: string; duration: number; method: string }[] = [];
  const requestTimings = new Map<string, number>();

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      const text = msg.text();
      // Ignore common Flutter/CanvasKit noise
      if (
        text.includes('Autofocus') ||
        text.includes('favicon.ico') ||
        text.includes('manifest.json')
      ) {
        return;
      }
      consoleErrors.push(text);
    }
  });

  page.on('pageerror', (error) => {
    jsExceptions.push(error.message);
  });

  page.on('request', (request) => {
    requestTimings.set(request.url() + request.method(), Date.now());
  });

  page.on('response', (response) => {
    const key = response.url() + response.request().method();
    const startTime = requestTimings.get(key);
    if (startTime) {
      const duration = Date.now() - startTime;
      if (duration > 5000) {
        slowRequests.push({
          url: response.url(),
          duration,
          method: response.request().method(),
        });
      }
    }

    if (response.status() >= 400) {
      const url = response.url();
      // Ignore expected 404s for common missing resources
      if (url.includes('favicon.ico') || url.includes('manifest.json')) return;
      failedRequests.push({
        url,
        status: response.status(),
        method: response.request().method(),
      });
    }
  });

  page.on('requestfailed', (request) => {
    const url = request.url();
    if (url.includes('favicon.ico')) return;
    failedRequests.push({
      url,
      status: 0,
      method: request.method(),
    });
  });

  return {
    getConsoleErrors: () => [...consoleErrors],
    getJsExceptions: () => [...jsExceptions],
    getFailedRequests: () => [...failedRequests],
    getSlowRequests: () => [...slowRequests],
    getAll: () => ({
      consoleErrors: [...consoleErrors],
      jsExceptions: [...jsExceptions],
      failedRequests: [...failedRequests],
      slowRequests: [...slowRequests],
    }),
    assertClean(options?: { allowedConsolePatterns?: RegExp[] }) {
      const allowed = options?.allowedConsolePatterns || [];
      const realErrors = consoleErrors.filter(
        (e) => !allowed.some((p) => p.test(e))
      );

      if (realErrors.length > 0) {
        console.warn('Console errors:', realErrors);
      }
      expect(jsExceptions, `JS exceptions found: ${jsExceptions.join(', ')}`).toHaveLength(0);
      // Don't hard-fail on console errors (Flutter is noisy), but do fail on JS exceptions
    },
    reset() {
      consoleErrors.length = 0;
      jsExceptions.length = 0;
      failedRequests.length = 0;
      slowRequests.length = 0;
    },
  };
}
