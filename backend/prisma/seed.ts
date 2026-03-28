import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('password123', 12);

  const alice = await prisma.user.upsert({
    where: { email: 'alice@example.com' },
    update: {},
    create: {
      name: 'Alice Johnson',
      email: 'alice@example.com',
      passwordHash: hashedPassword,
      onboardingCompleted: true,
      defaultCurrency: 'USD',
    },
  });

  const bob = await prisma.user.upsert({
    where: { email: 'bob@example.com' },
    update: {},
    create: {
      name: 'Bob Smith',
      email: 'bob@example.com',
      passwordHash: hashedPassword,
      onboardingCompleted: true,
      defaultCurrency: 'USD',
    },
  });

  const charlie = await prisma.user.upsert({
    where: { email: 'charlie@example.com' },
    update: {},
    create: {
      name: 'Charlie Brown',
      email: 'charlie@example.com',
      passwordHash: hashedPassword,
      onboardingCompleted: true,
      defaultCurrency: 'EUR',
    },
  });

  console.log('Seed complete:');
  console.log(`  alice@example.com   (id: ${alice.id})`);
  console.log(`  bob@example.com     (id: ${bob.id})`);
  console.log(`  charlie@example.com (id: ${charlie.id})`);
  console.log('  Password for all: password123');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
