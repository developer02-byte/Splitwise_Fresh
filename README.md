# SplitEase

Expense splitting app — Splitwise clone built with Flutter Web, Node.js Fastify, PostgreSQL, and Redis.

## Architecture

```
        Browser :8080
              |
         +----+-----+
         |   NGINX   |  (reverse proxy)
         +--+--+--+--+
            |  |  |
   /        |  |  |  /api/*        /socket.io/*
   v        |  |  v                v
 Frontend   |  |  Backend <---> PostgreSQL :5432
 (static)   |  |  :3000   <---> Redis :6379
```

| Service | Tech | Container |
|---------|------|-----------|
| Frontend | Flutter Web 3.27.4 (CanvasKit) | `splitease-nginx` |
| Backend | Node.js 22 + Fastify 5 + Prisma 5 | `splitease-api` |
| Database | PostgreSQL 17 Alpine | `splitease-postgres` |
| Cache/Queue | Redis 8 Alpine + BullMQ | `splitease-redis` |
| Proxy | NGINX Alpine | `splitease-nginx` |

## Quick Start

### Prerequisites

- **Docker Desktop** — that's it. No Flutter, Node.js, or PostgreSQL needed locally.

### Run

```bash
# 1. Copy environment config
cp .env.example .env

# 2. Build and start all services
docker compose up --build

# 3. (Optional) Seed test users — in a separate terminal
cd backend
npx prisma db seed
```

Open **http://localhost:8080** in your browser.

### Test Accounts (after seeding)

| Email | Password |
|-------|----------|
| alice@example.com | password123 |
| bob@example.com | password123 |
| charlie@example.com | password123 |

Or sign up as a new user — you'll go through the 3-step onboarding flow.

## Services & Ports

| Service | URL | Purpose |
|---------|-----|---------|
| App (NGINX) | http://localhost:8080 | Frontend + API proxy |
| API (direct) | http://localhost:3000 | Backend API (for debugging) |
| PostgreSQL | localhost:5432 | Database (user: admin, db: splitease) |
| Redis | localhost:6379 | Cache, BullMQ job queues |

## API Endpoints

### Public (no auth required)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/signup` | Register (name, email, password) |
| POST | `/api/auth/login` | Login (email, password) |
| POST | `/api/auth/refresh` | Rotate refresh token |
| GET | `/api/currencies/rates` | Exchange rates |

### Protected (Bearer JWT required)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/user/me` | Current user profile |
| PUT | `/api/user/me` | Update profile |
| DELETE | `/api/user/me` | Delete account |
| GET | `/api/user/balances` | Net balances |
| POST | `/api/auth/logout` | Logout + clear session |
| * | `/api/expenses/*` | Expense CRUD |
| * | `/api/groups/*` | Group management |
| * | `/api/user/friends/*` | Friend management |
| * | `/api/settlements/*` | Settlement tracking |
| * | `/api/invites/*` | Group invitations |
| * | `/api/user/activities` | Activity feed |

### Authentication

All protected routes require:
```
Authorization: Bearer <jwt-token>
```

Tokens are real JWTs (HS256, 15-min expiry) signed with `JWT_SECRET`. Refresh tokens are opaque hex strings, SHA-256 hashed in the database, rotated on each `/api/auth/refresh` call.

Rate limiting: 5 req/min on signup/login, 100 req/min globally.

## User Flow

```
Signup --> JWT issued --> GET /api/user/me
  --> onboardingCompleted = false
  --> Router redirects to /onboarding
  --> 3 slides (Add Friends / Create Group / Settle Up)
  --> "Get Started" or "Skip"
  --> PUT /api/user/me { onboardingCompleted: true }
  --> Router redirects to /dashboard
```

Returning users with `onboardingCompleted: true` skip straight to the dashboard.

## Environment Variables

Defined in `.env` (see `.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | admin | Database user |
| `POSTGRES_PASSWORD` | password123 | Database password |
| `POSTGRES_DB` | splitease | Database name |
| `DATABASE_URL` | postgresql://admin:password123@postgres:5432/splitease?schema=public | Prisma connection string |
| `REDIS_URL` | redis://redis:6379 | Redis connection |
| `JWT_SECRET` | super_secret_dev_key_change_in_prod | JWT signing key |
| `BACKEND_PORT` | 3000 | Fastify server port |
| `API_URL` | http://localhost/api | Frontend API base URL (build-time) |
| `CORS_ORIGINS` | (empty = dev defaults) | Comma-separated allowed origins |
| `EXCHANGE_RATE_API_KEY` | (empty) | ExchangeRate-API key |

## Docker Commands

```bash
# Start all services
docker compose up --build

# Start in background
docker compose up -d --build

# View logs
docker compose logs -f           # all services
docker compose logs api --tail 50 # just API

# Rebuild a single service
docker compose up -d --build api

# Stop everything
docker compose down

# Stop and wipe all data (fresh start)
docker compose down -v

# Seed database
cd backend && npx prisma db seed
```

## Project Structure

```
.
├── backend/
│   ├── src/
│   │   ├── index.ts              # Fastify entry point
│   │   ├── routes/
│   │   │   ├── auth.ts           # Signup, login, refresh, logout
│   │   │   ├── user.ts           # Profile, balances
│   │   │   ├── expenses.ts       # Expense CRUD
│   │   │   ├── groups.ts         # Group management
│   │   │   ├── friends.ts        # Friend management
│   │   │   ├── settlements.ts    # Settlements
│   │   │   ├── invites.ts        # Group invitations
│   │   │   └── activity.ts       # Activity feed
│   │   ├── socket.ts             # Socket.io real-time
│   │   └── jobs/
│   │       ├── queues.ts         # BullMQ queue definitions
│   │       └── workers.ts        # Job processors
│   ├── prisma/
│   │   ├── schema.prisma         # Database schema (15 models)
│   │   └── seed.ts               # Test data seeder
│   ├── Dockerfile
│   └── package.json
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── network/          # Dio HTTP client, auth interceptor, socket
│   │   │   ├── router/           # GoRouter with auth guard
│   │   │   └── theme/            # App theme
│   │   └── features/
│   │       ├── auth/             # Login/signup screens + providers
│   │       ├── onboarding/       # 3-step onboarding
│   │       └── dashboard/        # Main dashboard
│   ├── Dockerfile
│   └── pubspec.yaml
├── nginx/
│   └── default.conf              # Reverse proxy config
├── docker-compose.yml
├── .env.example
└── docs/
    └── plans/                    # Implementation plans
```

## Background Jobs (BullMQ)

| Queue | Schedule | Description |
|-------|----------|-------------|
| exchange-rate-refresh | Every 6 hours | Fetches currency rates from exchangerate-api.com |
| recurring-expense-spawn | Daily midnight UTC | Creates child expenses from recurring templates |
| email-dispatch | On demand | Email notification queue |
| reminder-nudge | On demand | Payment reminder notifications |

## Real-time (Socket.io)

WebSocket connections are proxied through NGINX at `/socket.io/`. Rooms:

- `user:{userId}` — personal notifications, 1-on-1 settlements
- `group:{groupId}` — group activity (expenses, settlements)

Auth: JWT extracted from `access_token` cookie on handshake.

## Testing with Playwright

Comprehensive E2E test suite in `e2e/` covering infrastructure, visual screenshots, accessibility, auth, CRUD APIs, performance, and cross-cutting concerns.

### Quick Start

```bash
# 1. Ensure Docker is running
docker compose up -d --build

# 2. Seed test data
cd backend && DATABASE_URL="postgresql://admin:password123@localhost:5432/splitease?schema=public" npx prisma db seed

# 3. Install and run tests
cd e2e && npm install && npx playwright install chromium
npx playwright test
```

### Test Accounts (after seeding)

| Email | Password |
|-------|----------|
| alice@example.com | password123 |
| bob@example.com | password123 |
| charlie@example.com | password123 |

### Test Suite (57 tests)

| Phase | File | Tests | Coverage |
|-------|------|-------|----------|
| 1. Infrastructure | `01-infrastructure.spec.ts` | 6 | Docker, PostgreSQL, Redis, NGINX proxy, frontend |
| 2. Visual Screenshots | `02-visual-screenshots.spec.ts` | 9 | Login, signup, dashboard, groups, friends, activity, onboarding (3 viewports) |
| 3. Console/Network | `03-console-network-errors.spec.ts` | 4 | JS exceptions, 5xx errors, slow requests |
| 4. Accessibility | `04-accessibility.spec.ts` | 3 | axe-core scans on login, dashboard, groups |
| 5. Auth API | `05-auth-api.spec.ts` | 11 | Signup, login, JWT, logout, rate limiting |
| 7. User API | `07-user-api.spec.ts` | 7 | Profile CRUD, balances |
| 8. Groups API | `08-groups-api.spec.ts` | 3 | Group CRUD, ledger |
| 9. Expenses API | `09-expenses-api.spec.ts` | 2 | Expense creation with splits |
| 10. Friends API | `10-friends-api.spec.ts` | 2 | Add/list friends |
| 11. Settlements | `11-settlements-api.spec.ts` | 1 | Create settlement |
| 13. Activity/Currency | `13-activity-currency-api.spec.ts` | 2 | Activity feed, exchange rates |
| 14. Performance | `14-performance.spec.ts` | 5 | Page load, API response times |
| 15. Cross-cutting | `15-cross-cutting.spec.ts` | 2 | CORS, WebSocket |

### Key Pages

| Route | Page | Auth Required |
|-------|------|---------------|
| `/login` | Login / Signup form | No |
| `/onboarding` | 3-step onboarding | Yes (new users) |
| `/dashboard` | Main dashboard | Yes |
| `/groups` | Groups list | Yes |
| `/friends` | Friends list | Yes |
| `/activity` | Activity feed | Yes |

API endpoints can be tested directly at `http://localhost:8080/api/*` (through NGINX) or `http://localhost:3000/api/*` (direct).
