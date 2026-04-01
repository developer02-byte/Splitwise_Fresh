import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const API_KEY = process.env.EXCHANGE_RATE_API_KEY;
const BASE_URL = `https://v6.exchangerate-api.com/v6/${API_KEY}`;

export class ExchangeRateService {
  static async getLatestRates(base: string = 'USD') {
    if (!API_KEY) {
      // Fallback/Mock if no key
      return { 'EUR': 0.92, 'GBP': 0.79, 'INR': 83.15, 'JPY': 149.50 };
    }

    try {
      const response = await fetch(`${BASE_URL}/latest/${base}`);
      const data = await response.json() as any;
      if (data.result === 'success') {
        return data.conversion_rates;
      }
      throw new Error('API Error');
    } catch (e) {
       console.error('ExchangeRate API failed:', e);
       return { 'EUR': 0.92, 'GBP': 0.79, 'INR': 83.15, 'JPY': 149.50 };
    }
  }

  static async convert(amount: number, from: string, to: string): Promise<number> {
    const rates = await this.getLatestRates(from);
    const rate = rates[to];
    if (!rate) return amount;
    return Math.round(amount * rate);
  }
}
