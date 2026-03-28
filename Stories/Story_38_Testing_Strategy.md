# Story 32: Testing Strategy (Full TDD) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Comprehensive test coverage with TDD discipline. Tests are written BEFORE implementation. Financial math accuracy is non-negotiable — the split engine, debt simplification, currency conversion, and settlement calculations must have 100% test coverage. A single rounding error in a financial app erodes all user trust.

Red -> Green -> Refactor. Write a failing test first. Implement the minimum code to make it pass. Refactor without changing behavior. Repeat.

---

## 2. Target Persona & Motivation
- **The Developer:** Wants confidence that a change to the split algorithm does not break penny rounding for 5-way splits. Runs the test suite before every commit.
- **The Reviewer:** Reads the test file to understand expected behavior before reading the implementation. Tests serve as living documentation.
- **The On-Call Engineer:** Receives an alert at 2 AM that balances are wrong. Adds a regression test reproducing the bug, fixes it, and guarantees it never recurs.

---

## 3. Comprehensive Step-by-Step User Journey

### A. TDD Workflow for a New Feature (Backend)
1. **Developer picks up story.** Reads acceptance criteria.
2. **Writes test file first:** `src/modules/expenses/__tests__/split-engine.test.ts`.
3. **Writes failing test:**
   ```typescript
   test('equal split of $100 among 3 people assigns 33.34, 33.33, 33.33', () => {
     const result = calculateEqualSplit(10000, 3); // cents
     expect(result).toEqual([3334, 3333, 3333]);
     expect(result.reduce((a, b) => a + b, 0)).toBe(10000); // must sum exactly
   });
   ```
4. **Runs test:** `npx vitest run split-engine` — RED (function does not exist).
5. **Implements minimum code** in `src/modules/expenses/split-engine.ts`.
6. **Runs test:** GREEN.
7. **Refactors** if needed. Runs test again — still GREEN.
8. **Writes next test** for the next edge case. Repeats.

### B. TDD Workflow for a New Feature (Flutter)
1. **Developer writes widget test first:**
   ```dart
   testWidgets('ExpenseCard shows correct amount and payer', (tester) async {
     await tester.pumpWidget(MaterialApp(
       home: ExpenseCard(expense: mockExpense),
     ));
     expect(find.text('\$60.00'), findsOneWidget);
     expect(find.text('Alice paid'), findsOneWidget);
   });
   ```
2. **Runs test:** `flutter test test/widgets/expense_card_test.dart` — RED.
3. **Implements widget.** Runs test — GREEN.

### C. CI Pipeline Integration
1. **On every push:** GitHub Actions runs the full test suite.
2. **Backend:** `npx vitest run --coverage` — must pass with coverage thresholds.
3. **Frontend:** `flutter test --coverage` — must pass with coverage thresholds.
4. **PR blocked** if any test fails or coverage drops below thresholds.

---

## 4. Ultra-Detailed UI/UX Component Specifications

This story has no user-facing UI. The "UI" is the developer experience:

### Test Output Format
- Vitest runs with `--reporter=verbose` in CI for detailed output.
- Local development uses default reporter (compact).
- Coverage reports generated as HTML (`coverage/index.html`) for local review and as lcov for CI integration.

### Pre-Commit Hook
- `husky` + `lint-staged` runs relevant tests on changed files before each commit.
- If a test in a changed module fails, commit is blocked with clear error output.

---

## 5. Technical Architecture & Database

### Backend Testing Stack

#### Test Runner: Vitest
- **Why Vitest:** ESM-native (matches project setup), fast parallel execution, built-in mocking, compatible with Jest API for familiarity.
- **Config:** `vitest.config.ts` at project root.

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/__tests__/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      thresholds: {
        branches: 85,
        functions: 85,
        lines: 85,
        statements: 85,
      },
      include: ['src/**/*.ts'],
      exclude: ['src/**/__tests__/**', 'src/**/types/**', 'src/generated/**'],
    },
    setupFiles: ['src/__tests__/setup.ts'],
  },
});
```

#### HTTP Testing: light-my-request
- Fastify's built-in test helper. No actual HTTP server startup needed. Directly injects requests into the Fastify instance.

```typescript
// Example integration test
import { buildApp } from '../../app';

describe('POST /api/expenses', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await buildApp({ testing: true });
  });

  afterAll(async () => {
    await app.close();
  });

  test('creates expense and returns correct splits', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/expenses',
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: {
        groupId: testGroupId,
        amount: 6000, // $60.00 in cents
        description: 'Dinner',
        splitType: 'equal',
        paidBy: [{ userId: aliceId, amount: 6000 }],
        splitWith: [aliceId, bobId, charlieId],
      },
    });

    expect(response.statusCode).toBe(201);
    const body = JSON.parse(response.body);
    expect(body.splits).toHaveLength(3);
    expect(body.splits.map(s => s.amount).reduce((a, b) => a + b, 0)).toBe(6000);
  });
});
```

#### Mocking External Services
```typescript
// Mocking email service
vi.mock('../../services/email-service', () => ({
  sendEmail: vi.fn().mockResolvedValue({ id: 'mock-email-id' }),
}));

// Mocking Firebase push notifications
vi.mock('../../services/firebase-service', () => ({
  sendPushNotification: vi.fn().mockResolvedValue(true),
}));

// Mocking exchange rate API
vi.mock('../../services/exchange-rate-service', () => ({
  getRate: vi.fn().mockResolvedValue({ from: 'USD', to: 'EUR', rate: 0.92 }),
}));
```

### Test Database Strategy

#### Setup
- Separate PostgreSQL database: `splitwise_test` (configured via `DATABASE_URL` in `.env.test`).
- Prisma migrations applied before test suite runs.
- **Global setup** (`src/__tests__/setup.ts`):

```typescript
import { PrismaClient } from '@prisma/client';
import { execSync } from 'child_process';

const prisma = new PrismaClient();

beforeAll(async () => {
  // Apply migrations to test database
  execSync('npx prisma migrate deploy', {
    env: { ...process.env, DATABASE_URL: process.env.TEST_DATABASE_URL },
  });
});

afterAll(async () => {
  await prisma.$disconnect();
});
```

#### Per-Suite Reset
```typescript
// test-helpers/reset-db.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function resetDatabase() {
  // Truncate all tables in correct order (respecting foreign keys)
  await prisma.$transaction([
    prisma.expenseComment.deleteMany(),
    prisma.expenseSplit.deleteMany(),
    prisma.expense.deleteMany(),
    prisma.settlement.deleteMany(),
    prisma.groupMember.deleteMany(),
    prisma.groupInvitation.deleteMany(),
    prisma.group.deleteMany(),
    prisma.notification.deleteMany(),
    prisma.emailLog.deleteMany(),
    prisma.file.deleteMany(),
    prisma.user.deleteMany(),
  ]);
}

export async function seedTestData() {
  // Create standard test fixtures
  const alice = await prisma.user.create({
    data: { id: 'alice-id', email: 'alice@test.com', name: 'Alice', passwordHash: '...' },
  });
  const bob = await prisma.user.create({
    data: { id: 'bob-id', email: 'bob@test.com', name: 'Bob', passwordHash: '...' },
  });
  const group = await prisma.group.create({
    data: { id: 'test-group-id', name: 'Test Group', createdBy: alice.id },
  });
  // ... add members, create sample expenses, etc.
  return { alice, bob, group };
}
```

#### Transaction Rollback Pattern (for fast unit tests)
```typescript
// For tests that should not persist changes:
describe('balance calculations', () => {
  test('within transaction', async () => {
    await prisma.$transaction(async (tx) => {
      // All operations use `tx` instead of `prisma`
      await tx.expense.create({ ... });
      const balances = await calculateBalances(tx, groupId);
      expect(balances).toEqual([...]);
      // Transaction never commits — Vitest moves on, changes are rolled back
      throw new Error('ROLLBACK'); // Force rollback
    }).catch((e) => {
      if (e.message !== 'ROLLBACK') throw e;
    });
  });
});
```

### Frontend Testing Stack (Flutter)

#### Unit Tests
```dart
// test/utils/currency_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats cents to dollar string', () {
      expect(formatCurrency(10000, 'USD'), '\$100.00');
      expect(formatCurrency(999, 'USD'), '\$9.99');
      expect(formatCurrency(1, 'USD'), '\$0.01');
    });

    test('formats zero amount', () {
      expect(formatCurrency(0, 'USD'), '\$0.00');
    });

    test('formats JPY without decimals', () {
      expect(formatCurrency(1000, 'JPY'), '¥1000');
    });
  });
}
```

#### Widget Tests
```dart
// test/widgets/balance_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/widgets/balance_card.dart';

void main() {
  group('BalanceCard', () {
    testWidgets('shows positive balance in green', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BalanceCard(amount: 5000, currency: 'USD', isOwed: true),
      ));
      expect(find.text('You are owed \$50.00'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('You are owed \$50.00'));
      expect(textWidget.style?.color, Colors.green);
    });

    testWidgets('shows negative balance in red', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BalanceCard(amount: 3000, currency: 'USD', isOwed: false),
      ));
      expect(find.text('You owe \$30.00'), findsOneWidget);
    });

    testWidgets('shows settled state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BalanceCard(amount: 0, currency: 'USD', isOwed: false),
      ));
      expect(find.text('All settled up'), findsOneWidget);
    });
  });
}
```

#### Integration Tests (E2E)
```dart
// integration_test/full_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitwise/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full flow: signup -> create group -> add expense', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Signup
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('email-field')), 'test@example.com');
    await tester.enterText(find.byKey(Key('password-field')), 'SecurePass123!');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Create group
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('group-name')), 'Test Group');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Test Group'), findsOneWidget);

    // Add expense
    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('amount-field')), '60.00');
    await tester.enterText(find.byKey(Key('description-field')), 'Dinner');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('\$60.00'), findsOneWidget);
  });
}
```

### Critical Test Suites (100% Coverage Required)

#### 1. Split Math Engine
```typescript
describe('Split Engine', () => {
  describe('Equal Split', () => {
    test('$100 / 3 = [33.34, 33.33, 33.33]', ...);
    test('$100 / 4 = [25.00, 25.00, 25.00, 25.00]', ...);
    test('$1.00 / 3 = [0.34, 0.33, 0.33]', ...);
    test('$0.01 / 3 = [0.01, 0.00, 0.00] — penny goes to first person', ...);
    test('$0.00 / 5 = [0.00, 0.00, 0.00, 0.00, 0.00]', ...);
    test('remainder cents distributed round-robin starting from first split', ...);
  });

  describe('Exact Amount Split', () => {
    test('custom amounts must sum to total', ...);
    test('rejects if amounts do not sum to total', ...);
  });

  describe('Percentage Split', () => {
    test('50/30/20 of $100 = [50.00, 30.00, 20.00]', ...);
    test('33.33/33.33/33.34 of $100 = penny rounding handled', ...);
    test('rejects percentages not summing to 100', ...);
  });

  describe('Shares Split', () => {
    test('shares [2, 1, 1] of $100 = [50.00, 25.00, 25.00]', ...);
    test('shares [1, 1, 1] equivalent to equal split', ...);
    test('shares with remainder distributed correctly', ...);
  });

  describe('Adjustment Split', () => {
    test('base equal split + Alice pays $10 more', ...);
    test('adjustments sum to zero (zero-sum validation)', ...);
  });
});
```

#### 2. Multi-Payer Calculations
```typescript
describe('Multi-Payer', () => {
  test('two payers: Alice pays $40, Bob pays $20, split equally among 3', ...);
  test('payer amounts must sum to total expense', ...);
  test('payer who is also a splitter — net calculation correct', ...);
});
```

#### 3. Debt Simplification Algorithm
```typescript
describe('Debt Simplification', () => {
  test('A owes B $10, B owes C $10 → A owes C $10 (chain reduction)', ...);
  test('circular debt: A→B $10, B→C $10, C→A $10 → all settled', ...);
  test('complex graph with 5 people reduces to minimum transactions', ...);
  test('already minimal debts are not modified', ...);
  test('empty debt graph returns empty', ...);
});
```

#### 4. Currency Conversion
```typescript
describe('Currency Conversion', () => {
  test('$100 USD at rate 0.92 = €92.00 EUR', ...);
  test('rate snapshot is stored with expense (not re-fetched)', ...);
  test('zero-decimal currencies (JPY) handled correctly', ...);
  test('conversion rounding uses bankers rounding', ...);
});
```

#### 5. Settlement Calculations
```typescript
describe('Settlements', () => {
  test('full settlement zeroes out balance between two users', ...);
  test('partial settlement reduces balance correctly', ...);
  test('settlement amount cannot exceed owed amount', ...);
  test('settlement in different currency converts correctly', ...);
});
```

#### 6. Idempotency
```typescript
describe('Idempotency', () => {
  test('duplicate POST /api/expenses with same idempotency key returns same response', ...);
  test('different idempotency key creates new expense', ...);
  test('expired idempotency key (24h) allows re-creation', ...);
});
```

### Test Environment Configuration

```env
# .env.test
DATABASE_URL=postgresql://test_user:test_pass@localhost:5432/splitwise_test
REDIS_URL=redis://localhost:6379/1
JWT_SECRET=test-secret-key-not-for-production
EMAIL_DEV_MODE=true
STORAGE_DRIVER=local
```

### CI Pipeline (GitHub Actions)
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: splitwise_test
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
      redis:
        image: redis:7
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: cd backend && npm ci
      - run: cd backend && npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/splitwise_test
      - run: cd backend && npx vitest run --coverage
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/splitwise_test
          REDIS_URL: redis://localhost:6379/1
      - uses: actions/upload-artifact@v4
        with:
          name: backend-coverage
          path: backend/coverage/

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: cd frontend && flutter pub get
      - run: cd frontend && flutter test --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: frontend-coverage
          path: frontend/coverage/
```

### Coverage Requirements

| Category | Target | Enforcement |
| --- | --- | --- |
| Split math engine (all 5 modes) | 100% | CI fails if below |
| Multi-payer calculations | 100% | CI fails if below |
| Penny rounding / remainder allocation | 100% | CI fails if below |
| Currency conversion with rate snapshots | 100% | CI fails if below |
| Debt simplification algorithm | 100% | CI fails if below |
| Settlement calculations (full + partial) | 100% | CI fails if below |
| Idempotency (duplicate request handling) | 100% | CI fails if below |
| API endpoints (integration tests) | 90%+ | CI warns below, fails below 85% |
| Flutter widgets | 80%+ | CI warns below, fails below 70% |
| Overall backend | 85%+ | CI fails if below |
| Overall frontend | 80%+ | CI fails if below |

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Flaky tests** | A test passes locally but fails intermittently in CI. | Root cause: usually timing issues or test ordering. Fix: isolate the test, add explicit waits for async operations, ensure no shared mutable state between tests. Quarantine flaky tests until fixed — do not disable. |
| **Test database contamination** | Test A creates data that causes Test B to fail. | Fix: `resetDatabase()` in `beforeEach` for integration tests. Use transaction rollback for unit tests. Tests must never depend on execution order. |
| **Slow test suite** | Full suite takes 10+ minutes. | Mitigation: Vitest parallel execution. Separate fast unit tests from slower integration tests. Run only affected tests on pre-commit (lint-staged). Full suite runs in CI. Target: unit tests < 30s, integration < 3min, total < 5min. |
| **Testing WebSocket events** | Socket.io events are asynchronous and hard to assert. | Use `socket.io-client` in test. Connect, perform action via API, assert event received within timeout. Helper: `waitForEvent(socket, 'expense:created', 5000)`. |
| **Testing file uploads** | Multipart uploads need real files. | Use test fixtures: small 1x1 pixel JPEG/PNG files in `src/__tests__/fixtures/`. Assert file is stored, MIME validated, dimensions correct. |
| **Testing email sending** | Do not send real emails in tests. | Mock the email provider. Assert `sendEmail` was called with correct template and variables. Test the template rendering separately (unit test with snapshot). |
| **Testing offline sync (Flutter)** | Hard to simulate offline in widget tests. | Mock the HTTP client to throw `SocketException`. Assert that the offline queue stores the request. Then mock success and assert queue drains correctly. |
| **Snapshot test drift** | UI snapshots break after intentional design changes. | Review snapshot diffs in PR. Update snapshots with `flutter test --update-goldens`. Never blindly update — review each diff. |

---

## 7. Final QA Acceptance Criteria

- [ ] Every business logic module has a corresponding test file written BEFORE the implementation.
- [ ] Split math engine has 100% branch coverage across all 5 split modes.
- [ ] Penny rounding test: $100 split among 3 people sums to exactly $100.00 (not $99.99 or $100.01).
- [ ] Debt simplification test: a circular debt among 3 people resolves to zero transactions.
- [ ] Idempotency test: sending the same expense creation request twice returns the same expense ID.
- [ ] All API endpoints have integration tests covering success, validation error, auth error, and not-found cases.
- [ ] Flutter widget tests cover loading, success, error, and empty states for all major components.
- [ ] E2E integration test completes the full flow: signup, create group, add expense, verify balance.
- [ ] CI pipeline runs all tests on every push and blocks merge if any test fails.
- [ ] Coverage thresholds are enforced in CI: 85%+ backend, 80%+ frontend, 100% for financial math.
- [ ] Test suite completes in under 5 minutes in CI.
- [ ] No test depends on execution order or external state (each test is fully isolated).
- [ ] Test database is separate from development database and reset between suites.
