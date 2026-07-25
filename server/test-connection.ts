import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  datasourceUrl: 'postgresql://postgres:y3zCAgqCnOgnV9Tg@db.jgehdsmrmcpnvcnfrjai.supabase.co:5432/postgres',
});

async function main() {
  try {
    await prisma.$connect();
    console.log('Connected successfully!');
    await prisma.$disconnect();
  } catch (error) {
    console.error('Connection failed:', error);
    await prisma.$disconnect();
    process.exit(1);
  }
}

main();
