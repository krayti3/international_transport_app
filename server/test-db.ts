import 'dotenv/config';
import { Client } from 'pg';

async function test() {
  const client = new Client({
    connectionString: 'postgresql://postgres.jgehdsmrmcpnvcnfrjai:KfdpK3HdchwwsDmF@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?pgbouncer=true',
  });
  try {
    await client.connect();
    console.log('CONNECTED');
    await client.end();
  } catch (error) {
    console.log('FAILED:', (error as Error).message);
    await client.end();
  }
}

test();
