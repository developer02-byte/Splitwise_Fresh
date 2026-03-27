# Story 16: Multi-Currency Support - Detailed Execution Plan

## 1. Core Objective & Philosophy
Allow groups on international trips to log expenses in any local currency (JPY, EUR, GBP) while automatically converting all amounts to each user's home currency for the global balance view. Eliminate the mental arithmetic of "what's $45 in Euros?"

---

## 2. Target Persona & Motivation
- **The International Traveller:** In Tokyo, paying for ramen in JPY, flights in USD, and hostels in EUR. Wants to see their total debt in GBP (their home currency) on the dashboard — calculated automatically.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Setting Home Currency (User-Level)
1. **Trigger:** During Signup or in Profile Settings, user selects their home currency (`GBP`).
2. **Storage:** Saved to `users.default_currency = 'GBP'`.
3. **Effect:** Every balance figure shown to this user on the Dashboard and Friend Ledgers is denominated in GBP.

### B. Setting Group Default Currency
1. **Trigger:** When creating a new group (e.g., "Tokyo Trip"), the creator selects a group default currency (`JPY`) via the CurrencyPicker.
2. **Storage:** Saved to `groups.default_currency = 'JPY'`.
3. **Effect:** Every new expense added in this group defaults the currency picker to JPY instead of the user's home currency, reducing friction for trip-based groups.

### C. Logging a Foreign Currency Expense
1. **Trigger:** User is in the "Tokyo 2026" group and taps "Add Expense".
2. **Action - Currency Field:** Below the Amount field, a Currency Picker dropdown appears, defaulting to the group's `default_currency` (JPY). User can change it if needed.
3. **Action - Entry:** User enters `4500` for ramen.
4. **Action - Live Conversion Preview:** The UI immediately fetches or uses a cached exchange rate. Below the JPY field, a grey subtitle: `~ GBP 25.41` (based on today's rate) appears live.
5. **Action - Save:** Expense is saved with BOTH `original_amount = 450000` (in minor units), `original_currency = 'JPY'`, `converted_amount_home` (stored in cents using today's rate), and the `exchange_rate_snapshot` stored permanently.

### D. Dashboard Display (Home Currency Conversion)
1. **System State:** Dashboard aggregates all debts. Sum is performed using `converted_amount_home` for each split, then displayed in `users.default_currency`.
2. **UI Display:** "You Owe: GBP 142.60" — even though raw expenses were in JPY, EUR, and USD.

### E. Settlement Currency Choice
1. **Trigger:** User taps "Settle Up" with Bob.
2. **Action - Currency Picker:** A settlement currency picker appears showing the suggested amount in the user's home currency AND any currencies used in outstanding debts. E.g., "Pay Bob GBP 25.41" OR "Pay Bob JPY 4500".
3. **System State:** Backend converts at the current exchange rate when a non-home currency is selected.
4. **Storage:** Settlement records both the paid currency/amount and the converted home-currency equivalent for both parties.

---

## 4. Ultra-Detailed UI/UX Component Specifications
- **`CurrencyPicker`**: A searchable dropdown modal (Flutter `showModalBottomSheet`) with a list of all ISO 4217 currencies. Flags displayed next to currency code. Filters list as user types ("EUR" or "Euro" both find the euro).
- **`ConversionPreviewLabel`**: Grey italic text `~ GBP 25.41` shown dynamically below the amount field when a foreign currency is selected. Updates on keystroke using cached rates.
- **`SettlementCurrencySelector`**: Pill toggle allowing the settler to pick which currency to pay in, with live conversion between options.

---

## 5. Technical Architecture & Database

### Exchange Rate Strategy:
- **Source:** ExchangeRate-API or Open Exchange Rates (free tier).
- **Caching:** Node.js scheduled job (node-cron) running every 6 hours fetches latest rates and stores them in an `exchange_rates` DB table (prevents latency on every expense save).

### Exchange Rate CRON (Node.js):
```ts
// src/jobs/exchangeRates.ts — scheduled via node-cron
import cron from 'node-cron';
import prisma from '../prisma';

cron.schedule('0 */6 * * *', async () => {
  const response = await fetch('https://api.exchangerate-api.com/v4/latest/USD');
  const data = await response.json();
  for (const [code, rate] of Object.entries(data.rates)) {
    await prisma.exchangeRate.upsert({
      where: { currency_code: code },
      update: { rate_to_usd: rate as number, updated_at: new Date() },
      create: { currency_code: code, rate_to_usd: rate as number },
    });
  }
});
```

### Backend Endpoints:
#### 1. `GET /api/currencies/rates`
- **Response:** `{ base: "USD", rates: { GBP: 0.79, JPY: 149.50, EUR: 0.92 }, fetched_at: "..." }`

### Database Context:
```sql
CREATE TABLE exchange_rates (
    currency_code CHAR(3) PRIMARY KEY,
    rate_to_usd DECIMAL(15,6),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Add default currency to groups table
ALTER TABLE groups
  ADD COLUMN default_currency CHAR(3) DEFAULT 'USD';

-- Extend expenses table
ALTER TABLE expenses
  ADD COLUMN original_currency CHAR(3) DEFAULT 'USD',
  ADD COLUMN exchange_rate_snapshot DECIMAL(15,6) DEFAULT 1.0;
```

> **Critical Rule:** Financial amounts are ALWAYS stored as integers (cents/minor units) to eliminate floating-point errors. Conversion math uses `ROUND()` explicitly.

---

## 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Exchange rate changes between expense & settlement** | Settlement is made 2 weeks after expense at a different rate. | The original `exchange_rate_snapshot` is frozen at time of expense entry. Settlement uses the CURRENT rate. The difference is logged separately as an `fx_gain_loss` note. |
| **Rare or exotic currency** | User enters an expense in a very rare currency not in our rates table. | UI defaults picker to "USD" with a warning toast: "This currency is not supported. Defaulting to USD." |
| **All group members have different home currencies** | Group "Paris Trip" has members from UK, US, and Japan. | Each user's balance display converts group figures to THEIR OWN `default_currency`. Three users see three different numbers for the same debt. |
| **Settlement in non-home currency** | User chooses to pay in JPY instead of their home GBP. | Backend converts at current rate, records both currencies on the settlement, and updates balances for both parties in their respective home currencies. |
| **Group default currency mismatch** | User's home currency is USD but group default is JPY. | Currency picker defaults to group's JPY. Conversion preview shows the equivalent in user's home USD. |

---

## 7. Final QA Acceptance Criteria
- [ ] User can log an expense in JPY and see it converted to GBP instantly via live preview.
- [ ] The stored `exchange_rate_snapshot` matches the published rate at time of save.
- [ ] Changing home currency in Settings immediately re-renders all balances in the new currency.
- [ ] Dashboard totals shown in the user's home currency even when group expenses are in mixed currencies.
- [ ] Creating a group allows setting a default currency that pre-fills the currency picker for new expenses.
- [ ] Settling up allows the user to choose which currency to pay in, with backend conversion at the current rate.
- [ ] Exchange rates are refreshed every 6 hours via the node-cron scheduled job.
