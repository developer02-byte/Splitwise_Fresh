import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const categories = [
  { id: 100, name: 'Food & Drinks', icon: 'restaurant_rounded' },
  { id: 200, name: 'Transport', icon: 'directions_car_rounded' },
  { id: 300, name: 'Housing', icon: 'home_rounded' },
  { id: 400, name: 'Utilities', icon: 'bolt_rounded' },
  { id: 500, name: 'Education', icon: 'school_rounded' },
  { id: 600, name: 'Travel', icon: 'airplanemode_active_rounded' },
  { id: 700, name: 'Health', icon: 'medical_services_rounded' },
  { id: 800, name: 'Shopping', icon: 'shopping_bag_rounded' },
  { id: 900, name: 'Entertainment', icon: 'movie_rounded' },
  { id: 0,   name: 'Other', icon: 'category_rounded' }
];

async function main() {
  console.log('Seeding categories...');
  for (const cat of categories) {
    await prisma.expenseCategory.upsert({
      where: { id: cat.id },
      update: cat,
      create: cat,
    });
  }
  console.log('Done.');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
