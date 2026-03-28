# Auth & Onboarding Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all authentication security gaps (bcrypt, JWT, refresh rotation, rate limiting) and wire onboarding + seed data.

**Architecture:** Replace plaintext passwords with bcrypt hashing. Replace `user_ID_{id}` tokens with real JWT (access 15min + refresh 30d). Implement refresh token rotation with session invalidation. Add `@fastify/rate-limit` on auth endpoints. Wire existing onboarding screens into the router with backend endpoint. Add Prisma seed script.

**Tech Stack:** Fastify, Prisma, bcrypt, jsonwebtoken, @fastify/rate-limit, Flutter/Riverpod/GoRouter

---

### Task 1: Install Backend Dependencies

**Files:**
- Modify: `backend/package.json`

**Step 1: Install bcrypt, jsonwebtoken, and rate-limit packages**

Run:
```bash
cd backend && npm install bcrypt jsonwebtoken @fastify/rate-limit && npm install -D @types/bcrypt @types/jsonwebtoken
```

---

### Task 2: Bcrypt Password Hashing in Auth Routes

**Files:**
- Modify: `backend/src/routes/auth.ts`

**Step 1: Replace plaintext password storage with bcrypt**

In `auth.ts`, add imports and update signup + login:

```typescript
import bcrypt from 'bcrypt';

// In signup handler, replace:
//   passwordHash: password, // simulate hash
// With:
const hashedPassword = await bcrypt.hash(password, 12);
// ...
data: { name, email, passwordHash: hashedPassword }

// In login handler, replace:
//   if (!user || user.passwordHash !== password)
// With:
if (!user || !user.passwordHash) { return reply.code(401)... }
const passwordValid = await bcrypt.compare(password, user.passwordHash);
if (!passwordValid) { return reply.code(401)... }
```

---

### Task 3: Real JWT Token Generation & Verification

**Files:**
- Modify: `backend/src/routes/auth.ts`
- Modify: `backend/src/index.ts` (auth middleware)
- Modify: `backend/src/socket.ts` (socket auth)

**Step 1: Create JWT helper functions in auth.ts**

```typescript
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '30d';

function signAccessToken(userId: number): string {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
}

function verifyAccessToken(token: string): { sub: number } {
  return jwt.verify(token, JWT_SECRET) as { sub: number };
}
```

**Step 2: Update signup to return JWT**

Replace `user_ID_${user.id}` with `signAccessToken(user.id)` in both signup and login.

**Step 3: Update auth middleware in index.ts**

Replace the `user_ID_` parsing block with:
```typescript
import jwt from 'jsonwebtoken';
// ...
const token = authHeader.substring(7);
try {
  const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret') as { sub: number };
  (request as any).userId = decoded.sub;
  return;
} catch {
  return reply.code(401).send({ success: false, error: 'Invalid token' });
}
```

**Step 4: Update socket.ts to verify JWT from cookie**

Replace hardcoded `userId = 1` with:
```typescript
import jwt from 'jsonwebtoken';
// ...
const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret') as { sub: number };
(socket as any).userId = decoded.sub;
```

---

### Task 4: Refresh Token Rotation

**Files:**
- Modify: `backend/src/routes/auth.ts`

**Step 1: Implement the /refresh endpoint**

```typescript
fastify.post('/refresh', async (request, reply) => {
  const refreshToken = request.cookies.refresh_token;
  if (!refreshToken) return reply.code(401).send({ success: false, error: 'No refresh token' });

  // Find session by hashed refresh token
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  const session = await prisma.session.findUnique({ where: { refreshTokenHash: tokenHash } });

  if (!session || session.expiresAt < new Date()) {
    if (session) await prisma.session.delete({ where: { id: session.id } });
    reply.clearCookie('access_token');
    reply.clearCookie('refresh_token', { path: '/api/auth/refresh' });
    return reply.code(401).send({ success: false, error: 'Session expired' });
  }

  // Rotate: delete old session, create new one
  const newRefreshPlain = crypto.randomBytes(40).toString('hex');
  const newRefreshHash = crypto.createHash('sha256').update(newRefreshPlain).digest('hex');

  await prisma.session.update({
    where: { id: session.id },
    data: { refreshTokenHash: newRefreshHash, lastUsedAt: new Date() }
  });

  const newAccessToken = signAccessToken(session.userId);

  reply.cookie('access_token', newAccessToken, {
    httpOnly: true, secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict', maxAge: 15 * 60
  });
  reply.cookie('refresh_token', newRefreshPlain, {
    httpOnly: true, secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict', path: '/api/auth/refresh', maxAge: 30 * 24 * 60 * 60
  });

  return reply.send({ success: true, data: { token: newAccessToken } });
});
```

**Step 2: Update login to also hash the refresh token before storing**

Replace `refreshTokenPlain` storage with:
```typescript
const refreshTokenHash = crypto.createHash('sha256').update(refreshTokenPlain).digest('hex');
// Store hash in DB, send plain in cookie
```

**Step 3: Update logout to delete session from DB**

```typescript
const refreshToken = request.cookies.refresh_token;
if (refreshToken) {
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  await prisma.session.deleteMany({ where: { refreshTokenHash: tokenHash } });
}
```

---

### Task 5: Rate Limiting on Auth Endpoints

**Files:**
- Modify: `backend/src/index.ts`

**Step 1: Register rate limiter globally, apply stricter limits to auth**

```typescript
import rateLimit from '@fastify/rate-limit';

// In start() function, before route registration:
await fastify.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
});

// Auth routes get stricter limits via route-level config in auth.ts
```

**Step 2: Add route-level rate limit config in auth.ts**

```typescript
// On signup and login handlers, add config:
{ config: { rateLimit: { max: 5, timeWindow: '1 minute' } } }
```

---

### Task 6: Wire Onboarding into Frontend Router

**Files:**
- Modify: `frontend/lib/core/router/app_router.dart`
- Modify: `frontend/lib/features/auth/presentation/providers/auth_provider.dart`
- Modify: `frontend/lib/features/onboarding/presentation/screens/onboarding_screen.dart`

**Step 1: Add onboarding route to GoRouter**

Add `/onboarding` route and update redirect logic to check `onboardingCompleted`:

```dart
// In redirect:
// After confirming user is authenticated, check onboardingCompleted
// If not completed and not on /onboarding, redirect to /onboarding
```

**Step 2: Update auth provider to include onboardingCompleted**

The `/api/user/me` response needs to include `onboardingCompleted`. Update the backend `user.ts` select to include it.

**Step 3: Update onboarding screen to call backend on completion**

```dart
Future<void> _completeOnboarding() async {
  final dio = ref.read(dioProvider);
  await dio.put('/api/user/me', data: {'onboardingCompleted': true});
  if (mounted) context.go('/dashboard');
}
```

---

### Task 7: Backend Onboarding Support

**Files:**
- Modify: `backend/src/routes/user.ts`

**Step 1: Include onboardingCompleted in /me response**

Add `onboardingCompleted: true` to the select clause.

**Step 2: Allow updating onboardingCompleted in PUT /me**

Add `onboardingCompleted` to the update data.

---

### Task 8: Prisma Seed Script

**Files:**
- Create: `backend/prisma/seed.ts`
- Modify: `backend/package.json` (add prisma.seed config)

**Step 1: Create seed script with sample users**

```typescript
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('password123', 12);

  await prisma.user.upsert({
    where: { email: 'alice@example.com' },
    update: {},
    create: { name: 'Alice', email: 'alice@example.com', passwordHash: password, onboardingCompleted: true }
  });
  await prisma.user.upsert({
    where: { email: 'bob@example.com' },
    update: {},
    create: { name: 'Bob', email: 'bob@example.com', passwordHash: password, onboardingCompleted: true }
  });

  console.log('Seed complete: alice@example.com / bob@example.com (password: password123)');
}

main().finally(() => prisma.$disconnect());
```

**Step 2: Add seed config to package.json**

```json
"prisma": { "seed": "tsx prisma/seed.ts" }
```

Run: `npx prisma db seed`

---

### Task 9: Commit all changes

```bash
git add -A
git commit -m "feat: secure auth (bcrypt+JWT+refresh rotation), rate limiting, onboarding wiring, seed data"
```
