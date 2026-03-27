/**
 * start-dev.js
 * 
 * Development entry point that:
 *  1. Boots an embedded PostgreSQL server (no Docker required)
 *  2. Updates DATABASE_URL env var to point at it
 *  3. Runs prisma db push to sync schema
 *  4. Starts the Fastify backend via tsx
 */
const EmbeddedPostgres = require('embedded-postgres').default;
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const PG_PORT = 5432;
const PG_USER = 'admin';
const PG_PASSWORD = 'password123';
const PG_DB = 'splitease';
const DATA_DIR = path.join(__dirname, 'data', 'pgdata');

// Ensure data directory exists
fs.mkdirSync(DATA_DIR, { recursive: true });

async function main() {
  console.log('[startup] Booting embedded PostgreSQL...');
  
  const pg = new EmbeddedPostgres({
    databaseDir: DATA_DIR,
    user: PG_USER,
    password: PG_PASSWORD,
    port: PG_PORT,
    persistent: true,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
  });

  try {
    await pg.initialise();
  } catch (err) {
    // Already initialized — this is fine
    console.log('[startup] Database already initialized, skipping init...');
  }

  try {
    await pg.start();

    // Create database if it does not exist
    const client = pg.getPgClient();
    await client.connect();
    const res = await client.query(`SELECT 1 FROM pg_database WHERE datname = '${PG_DB}'`);
    if (res.rowCount === 0) {
      await client.query(`CREATE DATABASE "${PG_DB}"`);
      console.log(`[startup] Created database: ${PG_DB}`);
    } else {
      console.log(`[startup] Database '${PG_DB}' already exists.`);
    }
    await client.end();

    console.log(`[startup] PostgreSQL running on port ${PG_PORT}`);
  } catch (err) {
    if (err.message?.includes('EADDRINUSE') || err.message?.includes('already')) {
      console.log('[startup] PostgreSQL already running on port', PG_PORT);
    } else {
      console.error('[startup] PostgreSQL start error:', err.message);
      // Don't exit - attempt to continue with running instance
    }
  }

  // Set DATABASE_URL for the child process
  const env = {
    ...process.env,
    DATABASE_URL: `postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/${PG_DB}?schema=public`,
    REDIS_URL: process.env.REDIS_URL || 'redis://localhost:6379',
    JWT_SECRET: process.env.JWT_SECRET || 'super_secret_dev_key_change_in_prod',
    PORT: process.env.PORT || '3000',
    NODE_ENV: 'development',
  };

  // Run prisma db push to sync schema
  console.log('[startup] Syncing database schema via prisma db push...');
  await new Promise((resolve, reject) => {
    const prisma = spawn(
      'npx',
      ['prisma', 'db', 'push', '--skip-generate'],
      { env, stdio: 'inherit', cwd: __dirname, shell: true }
    );
    prisma.on('close', (code) => {
      if (code !== 0) {
        console.error(`[startup] prisma db push failed with code ${code}`);
        reject(new Error('prisma db push failed'));
      } else {
        resolve();
      }
    });
  });

  // Start the Fastify server
  console.log('[startup] Starting Fastify API server...');
  const server = spawn(
    'npx',
    ['tsx', 'src/index.ts'],
    { env, stdio: 'inherit', cwd: __dirname, shell: true }
  );

  server.on('close', (code) => {
    console.log(`[startup] Server exited with code ${code}`);
    pg.stop().catch(() => {});
    process.exit(code);
  });

  // Graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n[startup] Shutting down...');
    server.kill('SIGINT');
    try { await pg.stop(); } catch {}
    process.exit(0);
  });
}

main().catch((err) => {
  console.error('[startup] Fatal error:', err);
  process.exit(1);
});
