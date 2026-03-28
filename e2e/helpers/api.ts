import { APIRequestContext, expect } from '@playwright/test';

const BASE_URL = 'http://localhost:8080';

/**
 * Helper for making authenticated API requests.
 */
export class ApiHelper {
  constructor(
    private request: APIRequestContext,
    private token: string
  ) {}

  private headers() {
    return { Authorization: `Bearer ${this.token}` };
  }

  async get(path: string, params?: Record<string, string>) {
    const url = new URL(`${BASE_URL}${path}`);
    if (params) {
      Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
    }
    return this.request.get(url.toString(), { headers: this.headers() });
  }

  async post(path: string, data?: any) {
    return this.request.post(`${BASE_URL}${path}`, {
      headers: this.headers(),
      data,
    });
  }

  async put(path: string, data?: any) {
    return this.request.put(`${BASE_URL}${path}`, {
      headers: this.headers(),
      data,
    });
  }

  async patch(path: string, data?: any) {
    return this.request.patch(`${BASE_URL}${path}`, {
      headers: this.headers(),
      data,
    });
  }

  async delete(path: string) {
    return this.request.delete(`${BASE_URL}${path}`, {
      headers: this.headers(),
    });
  }

  /**
   * Assert that a response is successful (2xx) and return parsed JSON.
   */
  async expectSuccess(response: any) {
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.success).toBe(true);
    return body;
  }

  /**
   * Assert that a response has the expected error status code.
   */
  async expectError(response: any, statusCode: number) {
    expect(response.status()).toBe(statusCode);
    const body = await response.json();
    expect(body.success).toBe(false);
    return body;
  }
}
