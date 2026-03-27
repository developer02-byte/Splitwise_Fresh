# Story 27: Deployment Plan (Docker + Cloudflare Tunnel + Hetzner VPS) - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Document the exact, repeatable process to deploy the Node.js Fastify API, PostgreSQL database, and Redis cache using Docker containers — progressing from local development through Cloudflare Tunnel to Hetzner VPS production. Without this, every deployment is a guessing game that risks downtime on a live financial application.

---

## 👥 2. Target Persona & Motivation
- **The Developer:** Needs a one-command local setup and a clear path from laptop to production. No manual server configuration, no "works on my machine" problems.
- **The Operator:** Needs automated backups, health checks, and a rollback plan that doesn't require heroics at 2 AM.

---

## 🗺️ 3. Deployment Stages

### A. Local Development Setup

**Docker Compose** provides the full stack locally with a single command.

#### `docker-compose.yml`
```yaml
version: '3.8'

services:
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - '3000:3000'
    volumes:
      - ./backend:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://splitwise:splitwise_dev@db:5432/splitwise_dev
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=dev_jwt_secret_at_least_64_characters_long_for_local_development_only
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    command: npx nodemon --watch src src/server.ts

  db:
    image: postgres:16-alpine
    ports:
      - '5432:5432'
    environment:
      POSTGRES_USER: splitwise
      POSTGRES_PASSWORD: splitwise_dev
      POSTGRES_DB: splitwise_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U splitwise']
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redisdata:/data

  adminer:
    image: adminer
    ports:
      - '8080:8080'
    depends_on:
      - db

volumes:
  pgdata:
  redisdata:
```

**Local workflow:**
1. `docker compose up -d` — starts all services.
2. `docker compose exec api npx prisma migrate dev` — runs Prisma migrations.
3. `docker compose exec api npx prisma db seed` — seeds development data.
4. API available at `http://localhost:3000`.
5. Adminer (optional DB viewer) at `http://localhost:8080`.

**Hot reload:** Volume mounts (`./backend:/app`) + `nodemon` provide instant reload on file changes. No container restart needed.

#### `.env` File (Local Development)
```env
NODE_ENV=development
DATABASE_URL=postgresql://splitwise:splitwise_dev@localhost:5432/splitwise_dev
REDIS_URL=redis://localhost:6379
JWT_SECRET=dev_jwt_secret_at_least_64_characters_long_for_local_development_only
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
```

### B. Cloudflare Tunnel (Early Production)

Expose the local or single-server Docker stack to the internet via Cloudflare Tunnel — no port forwarding, no self-managed SSL certificates.

#### Tunnel Setup
1. Install `cloudflared` on the host machine (or run as a Docker service).
2. Authenticate: `cloudflared tunnel login`.
3. Create tunnel: `cloudflared tunnel create splitwise-api`.
4. Configure tunnel:

```yaml
# ~/.cloudflared/config.yml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

5. Run tunnel: `cloudflared tunnel run splitwise-api`.
6. DNS: Cloudflare automatically creates a CNAME record for `api.yourdomain.com`.

**Benefits:**
- SSL/TLS handled entirely by Cloudflare (no Let's Encrypt, no cert renewal).
- DDoS protection included.
- No public IP or port forwarding required.

**Zero-Trust Access Policies:**
- Admin routes (`/api/admin/*`) protected by Cloudflare Access.
- Require email OTP or SSO for admin access.
- Configured via Cloudflare Zero Trust dashboard.

### C. Hetzner VPS Migration

When traffic outgrows a single machine or you need dedicated infrastructure.

#### `docker-compose.prod.yml`
```yaml
version: '3.8'

services:
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: always
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'

  db:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata_prod:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U ${DB_USER}']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - redisdata_prod:/data
    command: redis-server --requirepass ${REDIS_PASSWORD}

  caddy:
    image: caddy:2-alpine
    restart: always
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

volumes:
  pgdata_prod:
  redisdata_prod:
  caddy_data:
  caddy_config:
```

#### Caddyfile (Reverse Proxy with Auto-SSL)
```
api.yourdomain.com {
    reverse_proxy api:3000
    encode gzip
    log {
        output file /var/log/caddy/access.log
    }
}
```

#### VPS Setup Steps
1. Provision Hetzner VPS (CX21 or higher: 2 vCPU, 4GB RAM).
2. Install Docker + Docker Compose.
3. Clone repository, copy `.env.production` to server.
4. `docker compose -f docker-compose.prod.yml up -d`.
5. Verify: `curl https://api.yourdomain.com/api/health`.

#### Automated Backup (Daily CRON)
```bash
#!/bin/bash
# /opt/scripts/backup.sh — runs daily via cron
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups

# PostgreSQL dump
docker compose -f /opt/splitwise/docker-compose.prod.yml exec -T db \
  pg_dump -U ${DB_USER} ${DB_NAME} | gzip > ${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz

# Upload to Hetzner Storage Box
rsync -az ${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz \
  u123456@u123456.your-storagebox.de:backups/

# Retain only last 30 local backups
ls -t ${BACKUP_DIR}/db_*.sql.gz | tail -n +31 | xargs rm -f 2>/dev/null
```

**Crontab entry:**
```
0 3 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
```

#### Uptime Management
- Docker `restart: always` policy on all services.
- Alternative: PM2 for the Node.js process inside the container if finer control is needed.
- Health check endpoint polled by external monitoring (e.g., UptimeRobot, Hetrixtools).

### D. Hetzner Load Balancer (Scale)

When a single VPS is no longer sufficient.

**Architecture:**
- 2+ Hetzner VPS instances behind a Hetzner Load Balancer.
- Shared PostgreSQL: Hetzner Managed Database or dedicated DB VPS.
- Shared Redis cluster: Separate VPS or managed Redis.
- Load Balancer handles SSL termination.

**Socket.io Considerations:**
- Sticky sessions enabled on Hetzner LB (cookie-based affinity).
- OR: Redis adapter (`@socket.io/redis-adapter`) for cross-instance communication (preferred).

**Blue-Green Deployment:**
1. Deploy new version to "green" set of VPS instances.
2. Run smoke tests against green instances directly.
3. Switch LB target group from "blue" to "green".
4. Monitor for 15 minutes. If issues, switch back to "blue".
5. Decommission old "blue" instances after verification.

---

## 🚀 5. Technical Architecture & Database

### E. Database Migration Strategy

**Prisma Migrate** handles all schema changes.

```bash
# Development: Create and apply migration
npx prisma migrate dev --name descriptive_migration_name

# Production: Apply pending migrations (in CI/CD or on deploy)
npx prisma migrate deploy
```

**Safety Rules:**
- `pg_dump` backup taken BEFORE every production migration.
- Migration files are tracked in git (`prisma/migrations/` directory).
- Rollback procedure:
  1. `prisma migrate resolve --rolled-back <migration_name>` to mark migration as rolled back.
  2. Restore database from pre-migration backup: `gunzip < backup.sql.gz | psql -U user -d dbname`.
- NEVER manually edit migration files after they have been applied to production.
- NEVER run `prisma migrate reset` in production.

### F. Environment Management

**Environment files:**
- `.env.development` — local Docker Compose values.
- `.env.staging` — staging server values (if applicable).
- `.env.production` — production server values.

**Required variables:**
```env
NODE_ENV=production
DATABASE_URL=postgresql://user:password@db:5432/splitwise_prod
REDIS_URL=redis://:password@redis:6379
JWT_SECRET=<64+ character random string>
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
CLOUDFLARE_TUNNEL_TOKEN=<tunnel token>  # If using Cloudflare Tunnel
```

**Security rules:**
- `.env*` files listed in `.gitignore` — secrets NEVER committed to git.
- Production secrets injected via Docker secrets or environment variables on the host.
- `JWT_SECRET` generated via `openssl rand -base64 64`.
- Database passwords generated via `openssl rand -base64 32`.

### G. Smoke Test

**Health endpoint:**
```typescript
fastify.get('/api/health', async (request, reply) => {
  const dbHealthy = await checkDatabase();
  const redisHealthy = await checkRedis();

  const status = dbHealthy && redisHealthy ? 'ok' : 'degraded';
  const statusCode = status === 'ok' ? 200 : 503;

  return reply.status(statusCode).send({
    status,
    db: dbHealthy ? 'connected' : 'disconnected',
    redis: redisHealthy ? 'connected' : 'disconnected',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});
```

**Post-deploy automated smoke test (CI):**
```bash
#!/bin/bash
# Run after deployment
HEALTH_URL="https://api.yourdomain.com/api/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ "$RESPONSE" -eq 200 ]; then
  echo "Smoke test PASSED"
  exit 0
else
  echo "Smoke test FAILED — HTTP $RESPONSE"
  exit 1
fi
```

---

## 🧨 6. Comprehensive Edge Cases & QA

| Scenario | Expected Behavior |
| --- | --- |
| Database container crashes | Docker `restart: always` restarts it. API returns 503 on `/api/health` until DB is back. |
| Migration fails mid-apply | Restore from pre-migration `pg_dump` backup. Mark migration as rolled back via Prisma. |
| Secrets accidentally committed to git | Rotate ALL secrets immediately. Use `git filter-branch` or `bfg` to remove from history. |
| VPS runs out of disk | PostgreSQL volume fills up. Alert via disk monitoring. Clean old backups, expand volume. |
| Cloudflare Tunnel disconnects | `cloudflared` auto-reconnects. If persistent, check daemon status and logs. |
| SSL certificate expiry | Caddy auto-renews. Cloudflare Tunnel has no cert to manage. Monitor expiry dates as backup. |

---

## 📝 7. Final Deployment QA Checklist

- [ ] `.env` files are NOT committed to git (`.gitignore` enforced, verified via `git ls-files`).
- [ ] `docker compose up -d` starts the full stack locally without errors.
- [ ] Prisma migrations run successfully on fresh database (`prisma migrate deploy`).
- [ ] `GET /api/health` returns `200 OK` with `{ status: "ok", db: "connected", redis: "connected" }` after every deployment.
- [ ] Database backup taken and verified restorable before each production migration.
- [ ] HTTPS is active on the domain (via Cloudflare or Caddy auto-SSL).
- [ ] Rate limiting is active — exceeding threshold returns `429`.
- [ ] Smoke test script runs successfully in CI after deployment.
- [ ] Docker restart policies ensure all services recover from crashes without manual intervention.
- [ ] Hetzner Storage Box backups verified: at least 7 days of daily backups retained.
