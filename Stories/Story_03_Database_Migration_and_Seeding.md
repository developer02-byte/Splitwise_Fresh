# Story 34: Database Migration & Seeding - Detailed Execution Plan

## 1. Core Objective & Philosophy
Safe, repeatable, version-controlled database schema management using Prisma Migrate. Every schema change is tracked, reversible, and testable. The database schema is never modified by hand in any environment. The `prisma/migrations/` directory is the single source of truth for how the database reached its current state.

---

## 2. Target Persona & Motivation
- **The Developer:** Wants to modify the schema confidently, knowing that migrations are auto-generated, reviewed, and applied consistently across dev, test, and production.
- **The Deployer:** Needs production migrations to run automatically during deploy with a pre-backup safety net and clear rollback instructions.
- **The New Contributor:** Wants to run a single command (`prisma migrate dev && prisma db seed`) and have a fully populated local database ready for development.

---

## 3. Comprehensive Step-by-Step Journey

### A. Development Migration Workflow
1. **Modify schema:** Developer edits `prisma/schema.prisma` to add a new model, field, or relation.
2. **Generate migration:** Run `npx prisma migrate dev --name add_reminders_table`.
3. **Prisma generates:** A new directory in `prisma/migrations/` with a timestamped name (e.g., `20260325120000_add_reminders_table/migration.sql`).
4. **Review SQL:** Developer opens the generated `migration.sql` and verifies the SQL is correct. This is a mandatory review step — never blindly trust auto-generated SQL.
5. **Test locally:** The migration is applied to the local dev database. Developer verifies the schema change works with the application.
6. **Commit together:** The `schema.prisma` change AND the `migration.sql` file are committed in the same git commit. They must never be separated.
7. **PR review:** Reviewer inspects both the schema change and the generated SQL.

### B. CI/CD Migration Flow
1. **Test environment:** CI spins up a fresh PostgreSQL container.
2. **Apply migrations:** `npx prisma migrate deploy` runs all migrations from `prisma/migrations/` in order.
3. **Run tests:** Vitest runs against the migrated test database.
4. **Production deploy:** The deploy script runs `npx prisma migrate deploy` before starting the new application version.
5. **Pre-production backup:** Before `prisma migrate deploy` on production, the deploy script runs `pg_dump` to create a timestamped backup.

### C. Seed Data for Development
1. **Trigger:** Developer runs `npx prisma db seed` after initial setup or after a database reset.
2. **Seed script:** `prisma/seed.ts` populates the database with realistic test data.
3. **Idempotent:** Seeds check for existing records before inserting (upsert pattern).
4. **Consistent:** Seeds use deterministic data so every developer has the same test users and groups.

### D. Production Migration Procedure
1. **Before deploy:** CI/CD pipeline runs `pg_dump -Fc splitwise_prod > backup_$(date +%Y%m%d_%H%M%S).dump` on the production database.
2. **Apply migration:** `npx prisma migrate deploy` applies pending migrations.
3. **Verify:** Application starts and health check passes.
4. **If failure:** Restore from backup using `pg_restore -d splitwise_prod backup_<timestamp>.dump`.

---

## 4. Ultra-Detailed UI/UX Component Specifications
This story is infrastructure-only. No user-facing UI components.

**Developer-facing artifacts:**
- `prisma/schema.prisma` — the canonical schema definition.
- `prisma/migrations/` — directory of all migration SQL files.
- `prisma/seed.ts` — development seed script.
- Migration status visible via `npx prisma migrate status`.

---

## 5. Technical Architecture & Database

### Schema Source of Truth: `prisma/schema.prisma`
The complete schema includes all tables from the application execution plan:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                 Int      @id @default(autoincrement())
  email              String   @unique @db.VarChar(255)
  passwordHash       String   @map("password_hash") @db.VarChar(255)
  name               String   @db.VarChar(100)
  avatarUrl          String?  @map("avatar_url") @db.VarChar(500)
  defaultCurrency    String   @default("USD") @map("default_currency") @db.VarChar(3)
  timezone           String   @default("UTC") @db.VarChar(50)
  isActive           Boolean  @default(true) @map("is_active")
  createdAt          DateTime @default(now()) @map("created_at")
  updatedAt          DateTime @updatedAt @map("updated_at")

  groupMembers       GroupMember[]
  expensesPaid       Expense[]        @relation("PaidByUser")
  splits             Split[]
  settlementsPaid    Settlement[]     @relation("SettlementPayer")
  settlementsReceived Settlement[]    @relation("SettlementPayee")
  notifications      Notification[]
  auditLogs          AuditLog[]
  comments           ExpenseComment[]
  passwordResets     PasswordReset[]
  files              File[]

  @@map("users")
}

model Group {
  id                Int      @id @default(autoincrement())
  name              String   @db.VarChar(100)
  description       String?  @db.VarChar(500)
  defaultCurrency   String   @default("USD") @map("default_currency") @db.VarChar(3)
  createdBy         Int      @map("created_by")
  simplifyDebts     Boolean  @default(true) @map("simplify_debts")
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")

  members           GroupMember[]
  expenses          Expense[]
  settlements       Settlement[]
  invitations       GroupInvitation[]
  defaultSplits     GroupDefaultSplit[]

  @@map("groups")
}

model GroupMember {
  id        Int      @id @default(autoincrement())
  groupId   Int      @map("group_id")
  userId    Int      @map("user_id")
  role      String   @default("member") @db.VarChar(20)
  joinedAt  DateTime @default(now()) @map("joined_at")

  group     Group    @relation(fields: [groupId], references: [id])
  user      User     @relation(fields: [userId], references: [id])

  @@unique([groupId, userId])
  @@map("group_members")
}

model Expense {
  id              Int      @id @default(autoincrement())
  groupId         Int      @map("group_id")
  paidById        Int      @map("paid_by_id")
  description     String   @db.VarChar(255)
  amount          Int      // stored in cents
  currency        String   @db.VarChar(3)
  category        String?  @db.VarChar(50)
  splitType       String   @map("split_type") @db.VarChar(20)
  receiptUrl      String?  @map("receipt_url") @db.VarChar(500)
  isRecurring     Boolean  @default(false) @map("is_recurring")
  recurringRule   String?  @map("recurring_rule") @db.VarChar(100)
  isDeleted       Boolean  @default(false) @map("is_deleted")
  deletedAt       DateTime? @map("deleted_at")
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  group           Group    @relation(fields: [groupId], references: [id])
  paidBy          User     @relation("PaidByUser", fields: [paidById], references: [id])
  splits          Split[]
  comments        ExpenseComment[]
  files           File[]

  @@map("expenses")
}

model Split {
  id         Int      @id @default(autoincrement())
  expenseId  Int      @map("expense_id")
  userId     Int      @map("user_id")
  amount     Int      // stored in cents
  percentage Decimal? @db.Decimal(5, 2)
  shares     Int?

  expense    Expense  @relation(fields: [expenseId], references: [id])
  user       User     @relation(fields: [userId], references: [id])

  @@map("splits")
}

model Settlement {
  id         Int      @id @default(autoincrement())
  groupId    Int      @map("group_id")
  payerId    Int      @map("payer_id")
  payeeId    Int      @map("payee_id")
  amount     Int      // stored in cents
  currency   String   @db.VarChar(3)
  note       String?  @db.VarChar(255)
  settledAt  DateTime @default(now()) @map("settled_at")
  createdAt  DateTime @default(now()) @map("created_at")

  group      Group    @relation(fields: [groupId], references: [id])
  payer      User     @relation("SettlementPayer", fields: [payerId], references: [id])
  payee      User     @relation("SettlementPayee", fields: [payeeId], references: [id])

  @@map("settlements")
}

model ExpenseComment {
  id         Int      @id @default(autoincrement())
  expenseId  Int      @map("expense_id")
  userId     Int      @map("user_id")
  content    String   @db.VarChar(500)
  createdAt  DateTime @default(now()) @map("created_at")

  expense    Expense  @relation(fields: [expenseId], references: [id])
  user       User     @relation(fields: [userId], references: [id])

  @@map("expense_comments")
}

model Notification {
  id            Int      @id @default(autoincrement())
  userId        Int      @map("user_id")
  title         String?  @db.VarChar(100)
  body          String?
  referenceType String   @map("reference_type") @db.VarChar(20)
  referenceId   Int?     @map("reference_id")
  isRead        Boolean  @default(false) @map("is_read")
  createdAt     DateTime @default(now()) @map("created_at")

  user          User     @relation(fields: [userId], references: [id])

  @@map("notifications")
}

model ExchangeRate {
  id           Int      @id @default(autoincrement())
  baseCurrency String   @map("base_currency") @db.VarChar(3)
  targetCurrency String @map("target_currency") @db.VarChar(3)
  rate         Decimal  @db.Decimal(12, 6)
  fetchedAt    DateTime @default(now()) @map("fetched_at")

  @@unique([baseCurrency, targetCurrency, fetchedAt])
  @@map("exchange_rates")
}

model PasswordReset {
  id        Int      @id @default(autoincrement())
  userId    Int      @map("user_id")
  token     String   @unique @db.VarChar(255)
  expiresAt DateTime @map("expires_at")
  usedAt    DateTime? @map("used_at")
  createdAt DateTime @default(now()) @map("created_at")

  user      User     @relation(fields: [userId], references: [id])

  @@map("password_resets")
}

model File {
  id         Int      @id @default(autoincrement())
  expenseId  Int?     @map("expense_id")
  userId     Int      @map("user_id")
  fileName   String   @map("file_name") @db.VarChar(255)
  fileUrl    String   @map("file_url") @db.VarChar(500)
  mimeType   String   @map("mime_type") @db.VarChar(50)
  sizeBytes  Int      @map("size_bytes")
  createdAt  DateTime @default(now()) @map("created_at")

  expense    Expense? @relation(fields: [expenseId], references: [id])
  user       User     @relation(fields: [userId], references: [id])

  @@map("files")
}

model EmailLog {
  id         Int      @id @default(autoincrement())
  recipient  String   @db.VarChar(255)
  subject    String   @db.VarChar(255)
  template   String   @db.VarChar(50)
  status     String   @db.VarChar(20)
  sentAt     DateTime @default(now()) @map("sent_at")

  @@map("email_log")
}

model AuditLog {
  id              Int      @id @default(autoincrement())
  actorId         Int      @map("actor_id")
  action          String   @db.VarChar(50)
  entityType      String   @map("entity_type") @db.VarChar(30)
  entityId        Int      @map("entity_id")
  beforeSnapshot  Json?    @map("before_snapshot")
  afterSnapshot   Json?    @map("after_snapshot")
  ipAddress       String?  @map("ip_address") @db.VarChar(45)
  userAgent       String?  @map("user_agent") @db.VarChar(500)
  createdAt       DateTime @default(now()) @map("created_at")

  actor           User     @relation(fields: [actorId], references: [id])

  @@map("audit_log")
}

model GroupInvitation {
  id          Int      @id @default(autoincrement())
  groupId     Int      @map("group_id")
  invitedEmail String  @map("invited_email") @db.VarChar(255)
  invitedBy   Int      @map("invited_by")
  token       String   @unique @db.VarChar(255)
  status      String   @default("pending") @db.VarChar(20)
  expiresAt   DateTime @map("expires_at")
  createdAt   DateTime @default(now()) @map("created_at")

  group       Group    @relation(fields: [groupId], references: [id])

  @@map("group_invitations")
}

model GroupDefaultSplit {
  id        Int      @id @default(autoincrement())
  groupId   Int      @map("group_id")
  userId    Int      @map("user_id")
  splitType String   @map("split_type") @db.VarChar(20)
  value     Decimal? @db.Decimal(10, 2)

  group     Group    @relation(fields: [groupId], references: [id])

  @@unique([groupId, userId])
  @@map("group_default_splits")
}
```

### Seed Script: `prisma/seed.ts`

```typescript
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // --- Test Users ---
  const passwordHash = await bcrypt.hash('TestPassword123!', 12);

  const users = await Promise.all([
    prisma.user.upsert({
      where: { email: 'alice@example.com' },
      update: {},
      create: {
        email: 'alice@example.com',
        passwordHash,
        name: 'Alice Johnson',
        defaultCurrency: 'USD',
        timezone: 'America/New_York',
      },
    }),
    prisma.user.upsert({
      where: { email: 'bob@example.com' },
      update: {},
      create: {
        email: 'bob@example.com',
        passwordHash,
        name: 'Bob Smith',
        defaultCurrency: 'USD',
        timezone: 'America/Chicago',
      },
    }),
    prisma.user.upsert({
      where: { email: 'charlie@example.com' },
      update: {},
      create: {
        email: 'charlie@example.com',
        passwordHash,
        name: 'Charlie Brown',
        defaultCurrency: 'EUR',
        timezone: 'Europe/London',
      },
    }),
    prisma.user.upsert({
      where: { email: 'diana@example.com' },
      update: {},
      create: {
        email: 'diana@example.com',
        passwordHash,
        name: 'Diana Prince',
        defaultCurrency: 'GBP',
        timezone: 'Europe/London',
      },
    }),
    prisma.user.upsert({
      where: { email: 'eve@example.com' },
      update: {},
      create: {
        email: 'eve@example.com',
        passwordHash,
        name: 'Eve Torres',
        defaultCurrency: 'USD',
        timezone: 'America/Los_Angeles',
      },
    }),
  ]);

  const [alice, bob, charlie, diana, eve] = users;

  // --- Groups ---
  const apartment = await prisma.group.create({
    data: {
      name: 'Apartment 4B',
      description: 'Monthly shared expenses for our apartment',
      defaultCurrency: 'USD',
      createdBy: alice.id,
      members: {
        create: [
          { userId: alice.id, role: 'admin' },
          { userId: bob.id, role: 'member' },
          { userId: charlie.id, role: 'member' },
        ],
      },
    },
  });

  const tripGroup = await prisma.group.create({
    data: {
      name: 'Tokyo Trip 2026',
      description: 'Travel expenses for our Japan trip',
      defaultCurrency: 'JPY',
      createdBy: bob.id,
      members: {
        create: [
          { userId: bob.id, role: 'admin' },
          { userId: alice.id, role: 'member' },
          { userId: diana.id, role: 'member' },
          { userId: eve.id, role: 'member' },
        ],
      },
    },
  });

  const officeGroup = await prisma.group.create({
    data: {
      name: 'Office Lunch',
      description: 'Daily lunch splits',
      defaultCurrency: 'USD',
      createdBy: charlie.id,
      members: {
        create: [
          { userId: charlie.id, role: 'admin' },
          { userId: diana.id, role: 'member' },
          { userId: eve.id, role: 'member' },
        ],
      },
    },
  });

  // --- Expenses (amounts in cents) ---
  const expenses = [
    { groupId: apartment.id, paidById: alice.id, description: 'March Rent', amount: 150000, currency: 'USD', category: 'rent', splitType: 'equal' },
    { groupId: apartment.id, paidById: bob.id, description: 'Electricity Bill', amount: 12000, currency: 'USD', category: 'utilities', splitType: 'equal' },
    { groupId: apartment.id, paidById: alice.id, description: 'Internet', amount: 7999, currency: 'USD', category: 'utilities', splitType: 'equal' },
    { groupId: apartment.id, paidById: charlie.id, description: 'Groceries', amount: 8750, currency: 'USD', category: 'groceries', splitType: 'equal' },
    { groupId: apartment.id, paidById: bob.id, description: 'Cleaning Supplies', amount: 3500, currency: 'USD', category: 'household', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: bob.id, description: 'Hotel Booking', amount: 8000000, currency: 'JPY', category: 'accommodation', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: alice.id, description: 'Shinkansen Tickets', amount: 5600000, currency: 'JPY', category: 'transport', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: diana.id, description: 'Sushi Dinner', amount: 3200000, currency: 'JPY', category: 'food', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: eve.id, description: 'Museum Tickets', amount: 800000, currency: 'JPY', category: 'entertainment', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: charlie.id, description: 'Monday Lunch', amount: 4500, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: diana.id, description: 'Tuesday Lunch', amount: 3800, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: eve.id, description: 'Wednesday Lunch', amount: 5200, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: charlie.id, description: 'Coffee Run', amount: 1800, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: diana.id, description: 'Thursday Lunch', amount: 4100, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: apartment.id, paidById: alice.id, description: 'Water Bill', amount: 4500, currency: 'USD', category: 'utilities', splitType: 'equal' },
    { groupId: apartment.id, paidById: bob.id, description: 'Trash Bags', amount: 1200, currency: 'USD', category: 'household', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: bob.id, description: 'Taxi to Airport', amount: 1200000, currency: 'JPY', category: 'transport', splitType: 'equal' },
    { groupId: tripGroup.id, paidById: alice.id, description: 'Souvenirs', amount: 500000, currency: 'JPY', category: 'shopping', splitType: 'equal' },
    { groupId: officeGroup.id, paidById: eve.id, description: 'Friday Lunch', amount: 6200, currency: 'USD', category: 'food', splitType: 'equal' },
    { groupId: apartment.id, paidById: charlie.id, description: 'Light Bulbs', amount: 2400, currency: 'USD', category: 'household', splitType: 'equal' },
  ];

  for (const exp of expenses) {
    const groupMembers = await prisma.groupMember.findMany({
      where: { groupId: exp.groupId },
    });
    const splitAmount = Math.floor(exp.amount / groupMembers.length);
    const remainder = exp.amount - splitAmount * groupMembers.length;

    await prisma.expense.create({
      data: {
        ...exp,
        splits: {
          create: groupMembers.map((member, index) => ({
            userId: member.userId,
            amount: splitAmount + (index === 0 ? remainder : 0),
          })),
        },
      },
    });
  }

  // --- Settlements ---
  await prisma.settlement.create({
    data: {
      groupId: apartment.id,
      payerId: bob.id,
      payeeId: alice.id,
      amount: 50000,
      currency: 'USD',
      note: 'Settling up for March expenses',
    },
  });

  await prisma.settlement.create({
    data: {
      groupId: officeGroup.id,
      payerId: charlie.id,
      payeeId: eve.id,
      amount: 2000,
      currency: 'USD',
      note: 'Lunch balance',
    },
  });

  console.log('Seed complete.');
  console.log(`Created: ${users.length} users, 3 groups, ${expenses.length} expenses, 2 settlements`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

### Package.json Seed Configuration
```json
{
  "prisma": {
    "seed": "ts-node --compiler-options {\"module\":\"CommonJS\"} prisma/seed.ts"
  }
}
```

### Migration Safety Rules

| Rule | Enforcement |
| --- | --- |
| Never use `prisma migrate reset` in production | CI script checks environment variable; command blocked if `NODE_ENV=production`. |
| Never drop columns without deprecation | PR review checklist item. Linter rule flags `DROP COLUMN` in migration SQL. |
| Always backup before production migration | Deploy script runs `pg_dump` before `prisma migrate deploy`. Backup stored with timestamp. |
| Migrations are forward-only in production | `prisma migrate deploy` only applies pending forward migrations. No rollback SQL generated. |
| Destructive changes are multi-step | Step 1: Add new column. Step 2: Migrate data (backfill script). Step 3: Drop old column in a separate migration after verification. |

### Deploy Script: `scripts/deploy-migrate.sh`
```bash
#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backups/splitwise_${TIMESTAMP}.dump"

echo "Creating pre-migration backup..."
mkdir -p backups
pg_dump -Fc "$DATABASE_URL" > "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"

echo "Running Prisma migrations..."
npx prisma migrate deploy

echo "Verifying migration status..."
npx prisma migrate status

echo "Migration complete. Backup available at $BACKUP_FILE for rollback if needed."
```

### Rollback Procedure
```bash
# 1. Stop the application
docker-compose down

# 2. Restore from backup
pg_restore -d "$DATABASE_URL" --clean --if-exists backups/splitwise_<TIMESTAMP>.dump

# 3. Mark the failed migration as rolled back
npx prisma migrate resolve --rolled-back <migration_name>

# 4. Restart with previous application version
docker-compose up -d
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Migration conflict between branches** | Two developers create migrations at the same timestamp or with conflicting schema changes. | Prisma detects migration history mismatch. The second developer must run `prisma migrate dev` again to reconcile. Never manually edit migration files. |
| **Production migration fails mid-way** | A migration with multiple statements fails after the first statement. | PostgreSQL transactions: each migration runs in a transaction by default. Partial application is rolled back. Restore from `pg_dump` backup if needed. Mark as rolled back with `prisma migrate resolve`. |
| **Data migration for large tables** | Adding a NOT NULL column to a table with millions of rows. | Step 1: Add column as nullable. Step 2: Backfill in batches (1000 rows at a time) via a script. Step 3: Add NOT NULL constraint in a separate migration. |
| **Schema drift between environments** | Dev database has manual changes not reflected in migrations. | Run `prisma migrate diff` to detect drift. Reset dev database with `prisma migrate reset` (dev only). Never manually alter production schema. |
| **Seed script fails on existing data** | Seed runs on a database that already has some records. | All seeds use `upsert` (check before insert). Unique constraints prevent duplicates. Seed is safe to run multiple times. |
| **Migration references deleted model** | A migration tries to add a foreign key to a table that was dropped in a previous migration. | Prisma validates schema consistency at generation time. This scenario is caught before the migration SQL is generated. |
| **Concurrent migration execution** | Two deploy processes try to run migrations simultaneously. | Prisma Migrate uses an advisory lock on the database. The second process waits until the first completes. |

---

## 7. Final QA Criteria
- [ ] Running `prisma migrate dev` generates a clean migration from any schema change.
- [ ] Running `prisma migrate deploy` on a fresh database applies all migrations in order without errors.
- [ ] Running `prisma db seed` populates the database with 5 users, 3 groups, 20 expenses, and 2 settlements.
- [ ] Running `prisma db seed` twice does not create duplicate records (idempotent).
- [ ] The deploy script creates a `pg_dump` backup before applying production migrations.
- [ ] A failed migration can be rolled back by restoring from the backup and marking the migration as rolled back.
- [ ] CI pipeline applies migrations to a fresh test database and runs all tests successfully.
- [ ] All migration SQL files are committed alongside their corresponding `schema.prisma` changes.
- [ ] No raw SQL DDL statements exist outside of the `prisma/migrations/` directory.
- [ ] `prisma migrate status` reports no pending or failed migrations after a successful deploy.
- [ ] Destructive schema changes (drop column, drop table) follow the multi-step deprecation process.
