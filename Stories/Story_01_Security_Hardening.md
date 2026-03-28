# Story 26: Security Hardening (CSRF, XSS, SQL Injection, JWT, Rate Limiting) - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
This is a financial application handling real money data. Security is not optional — it is a foundational layer. Every single data input entering the system must be treated as hostile. This story covers all mandatory security protections required before any production deployment, implemented using Node.js Fastify with PostgreSQL and Prisma ORM.

---

## 👥 2. Target Persona & Motivation
- **The Developer:** Needs a clear, enforceable security checklist that prevents OWASP Top 10 vulnerabilities. Every protection must be automated — not reliant on individual discipline.
- **The User:** Expects their financial data to be secure. Trusts the app to protect their sessions, passwords, and payment information.

---

## 🗺️ 3. Comprehensive Threat Models & Mitigations

### A. SQL Injection Prevention
- **Threat:** Attacker enters `' OR 1=1; DROP TABLE users; --` in a login field.
- **Protection:** Prisma ORM handles parameterization automatically for all standard queries. Raw string concatenation into SQL is impossible through the Prisma client API.

```typescript
// CORRECT — Prisma handles parameterization automatically
const user = await prisma.user.findUnique({
  where: { email: userInput },
});

// CORRECT — Tagged template literal (auto-parameterized)
const result = await prisma.$queryRaw`
  SELECT * FROM users WHERE email = ${userInput}
`;

// BANNED — NEVER use $queryRawUnsafe with user input
// await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE email = '${userInput}'`); // NEVER
```

**Rules:**
- NEVER use `prisma.$queryRawUnsafe()` with any user-supplied input.
- All raw queries MUST use `prisma.$queryRaw` with tagged template literals, which are auto-parameterized by Prisma.
- ESLint rule to flag `$queryRawUnsafe` usage in CI.

### B. XSS (Cross-Site Scripting) Prevention
- **Threat:** Attacker creates an expense titled `<script>document.cookie</script>`. If rendered unescaped in another user's browser, it executes.
- **Protection:**

```typescript
// Fastify plugin registration
import helmet from '@fastify/helmet';
import sanitizeHtml from 'sanitize-html';

await fastify.register(helmet, {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
});

// Sanitize user-generated content before storage
function sanitizeInput(dirty: string): string {
  return sanitizeHtml(dirty, {
    allowedTags: [],        // Strip ALL HTML tags
    allowedAttributes: {},  // Strip ALL attributes
  });
}
```

**Rules:**
- `@fastify/helmet` plugin sets all security headers (CSP, X-Frame-Options, etc.).
- `sanitize-html` strips HTML from all user-generated content (expense titles, notes, group names).
- Flutter auto-escapes by default — there is no `innerHTML` equivalent. `Text()` widgets render strings safely.
- CSP Header: `default-src 'self'; script-src 'self'` prevents inline script execution.

### C. CSRF (Cross-Site Request Forgery) Prevention
- **Threat:** A malicious website embeds a hidden form that fires `POST /api/settlements/pay` using the victim's active session cookie.
- **Protection:**

```typescript
import csrfProtection from '@fastify/csrf-protection';

await fastify.register(csrfProtection, {
  sessionPlugin: '@fastify/cookie',
  cookieOpts: {
    signed: true,
    sameSite: 'strict',
    secure: true,
    httpOnly: true,
  },
});

// Generate token endpoint
fastify.get('/api/csrf-token', async (request, reply) => {
  const token = reply.generateCsrf();
  return { token };
});
```

**Rules:**
- `@fastify/csrf-protection` plugin validates CSRF token on every mutating request (POST/PUT/DELETE).
- CSRF token sent in `X-CSRF-Token` header on every mutating request from the client.
- `SameSite=Strict` on all cookies handles most CSRF scenarios by default.
- Flutter mobile apps: CSRF is less critical (no cookie-based auth), but token is still validated for Flutter Web.

### D. JWT Security
- **Threat:** Token theft via XSS, token replay, or session hijacking.
- **Protection:**

```typescript
import fastifyJwt from '@fastify/jwt';

await fastify.register(fastifyJwt, {
  secret: process.env.JWT_SECRET!, // Min 64 characters
  cookie: {
    cookieName: 'access_token',
    signed: true,
  },
  sign: {
    expiresIn: '15m', // Access token: 15 minutes
  },
});

// Refresh token rotation
async function rotateRefreshToken(oldToken: string) {
  // 1. Verify old refresh token exists in PostgreSQL
  const stored = await prisma.refreshToken.findUnique({
    where: { token: oldToken },
  });
  if (!stored || stored.revoked) throw new Error('Invalid refresh token');

  // 2. Revoke old token
  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revoked: true },
  });

  // 3. Issue new refresh token (7 days)
  const newRefreshToken = generateSecureToken();
  await prisma.refreshToken.create({
    data: {
      token: newRefreshToken,
      userId: stored.userId,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    },
  });

  return newRefreshToken;
}
```

**Rules:**
- Access tokens: 15 min expiry, stored in `HttpOnly; Secure; SameSite=Strict` cookie (web).
- Refresh tokens: 7 days expiry, rotated on every use, stored in PostgreSQL `refresh_tokens` table.
- Flutter mobile: `flutter_secure_storage` for token storage (uses Keychain on iOS, EncryptedSharedPreferences on Android).
- Token blacklist on logout: Add token ID to Redis set with TTL matching remaining token lifetime.
- JWT secret: minimum 64 characters, generated via `openssl rand -base64 64`.

### E. Input Validation
- **Threat:** Malformed data bypasses business logic (negative amounts, oversized strings, malicious file uploads).
- **Protection:**

```typescript
// Fastify JSON Schema validation (built-in) — defined per route
const addExpenseSchema = {
  body: {
    type: 'object',
    required: ['amount', 'description', 'groupId', 'splits'],
    properties: {
      amount: { type: 'integer', minimum: 1 },           // Positive cents only
      description: { type: 'string', minLength: 1, maxLength: 200 },
      groupId: { type: 'string', format: 'uuid' },
      splits: {
        type: 'array',
        minItems: 1,
        items: {
          type: 'object',
          required: ['userId', 'amount'],
          properties: {
            userId: { type: 'string', format: 'uuid' },
            amount: { type: 'integer', minimum: 0 },
          },
        },
      },
    },
    additionalProperties: false,
  },
};

fastify.post('/api/expenses', { schema: addExpenseSchema }, addExpenseHandler);
```

**Rules:**
- Fastify JSON Schema validation on ALL routes (built-in, zero overhead).
- `zod` or `ajv` for complex validation rules beyond what JSON Schema supports.
- All monetary amounts validated as positive integers (cents) — no floating point.
- File uploads: MIME type verified server-side via `file-type` npm package (reads magic bytes), NOT file extension.
- `additionalProperties: false` on all schemas to reject unexpected fields.

### F. Rate Limiting
- **Threat:** Brute-force login attacks, API abuse, denial of service.
- **Protection:**

```typescript
import rateLimit from '@fastify/rate-limit';

await fastify.register(rateLimit, {
  global: true,
  max: 100,            // General API: 100 req/min/user
  timeWindow: '1 minute',
  keyGenerator: (request) => request.user?.id || request.ip,
});

// Stricter limit for auth endpoints
fastify.register(async function authRoutes(instance) {
  await instance.register(rateLimit, {
    max: 10,           // Auth endpoints: 10 req/min/IP
    timeWindow: '1 minute',
    keyGenerator: (request) => request.ip,
  });

  instance.post('/api/auth/login', loginHandler);
  instance.post('/api/auth/signup', signupHandler);
  instance.post('/api/auth/forgot-password', forgotPasswordHandler);
});
```

**Rules:**
- `@fastify/rate-limit` plugin handles all rate limiting.
- Auth endpoints: 10 req/min/IP.
- General API: 100 req/min/user (authenticated) or per IP (unauthenticated).
- Returns `429 Too Many Requests` with `Retry-After` header.
- Redis backend for rate limit storage in production (shared across instances).

### G. CORS
- **Threat:** Unauthorized origins making API requests.
- **Protection:**

```typescript
import cors from '@fastify/cors';

await fastify.register(cors, {
  origin: [
    'https://yourdomain.com',
    'https://app.yourdomain.com',
    ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000'] : []),
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  credentials: true,
  maxAge: 86400, // Preflight cache: 24 hours
});
```

**Rules:**
- `@fastify/cors` — whitelist specific origins only.
- No wildcard `*` in production. EVER.
- `credentials: true` required for cookie-based auth.

### H. Security Headers
All set via `@fastify/helmet`. Verified values:

```
Content-Security-Policy: default-src 'self'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### I. Dependency Security
- **Threat:** Vulnerable npm packages introduce exploits into the application.
- **Protection:**
  - `npm audit` runs in CI pipeline on every PR. Build fails on `critical` or `high` severity.
  - Dependabot or Renovate enabled for automated dependency update PRs.
  - `package-lock.json` always committed to pin exact versions.
  - No `*` or `latest` version ranges in `package.json`.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Flutter Client Security
- **Token Storage (Mobile):** `flutter_secure_storage` — uses iOS Keychain / Android EncryptedSharedPreferences.
- **Token Storage (Web):** Tokens stored in `HttpOnly` cookies only. Never in `localStorage` or `sessionStorage`.
- **Certificate Pinning (Optional v2):** Pin server certificate hash in HTTP client for MITM protection.
- **Debug Mode Check:** In release builds, disable all debug logging and inspector tools.

---

## 🚀 5. Technical Architecture & Database

### Prisma Schema (Refresh Tokens)
```prisma
model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  revoked   Boolean  @default(false)
  expiresAt DateTime
  createdAt DateTime @default(now())

  @@index([userId])
  @@index([token])
}
```

### Fastify Plugin Registration Order
```typescript
// Order matters — register security plugins first
await fastify.register(cookie);
await fastify.register(helmet);
await fastify.register(cors);
await fastify.register(csrf);
await fastify.register(rateLimit);
await fastify.register(jwt);
// ... then register route plugins
```

### NPM Packages Required
| Package | Purpose |
| --- | --- |
| `@fastify/helmet` | Security headers (CSP, X-Frame-Options, etc.) |
| `@fastify/cors` | CORS whitelist management |
| `@fastify/csrf-protection` | CSRF token generation and validation |
| `@fastify/rate-limit` | Rate limiting per IP/user |
| `@fastify/jwt` | JWT signing, verification, cookie integration |
| `@fastify/cookie` | Secure cookie parsing and signing |
| `sanitize-html` | Strip HTML from user-generated content |
| `file-type` | Verify file MIME type via magic bytes |
| `zod` | Complex input validation beyond JSON Schema |

---

## 🧨 6. Comprehensive Edge Cases & QA

| Threat Scenario | Expected Behavior |
| --- | --- |
| SQL injection in login field | Prisma parameterizes automatically. Query returns no results. No error leak. |
| `<script>alert(1)</script>` as expense title | `sanitize-html` strips tags on input. Even if stored, CSP blocks inline scripts. |
| Cross-origin POST to `/api/settlements/pay` | CORS rejects preflight. If bypassed, CSRF token validation returns 403. |
| Stolen JWT from network sniffing | HTTPS enforced. `HttpOnly; Secure; SameSite=Strict` prevents JS access. Short 15min expiry limits window. |
| Brute-force login attempts | Rate limiter returns 429 after 10 attempts/min. Retry-After header tells client when to retry. |
| Malicious file upload (`shell.php` as `receipt.jpg`) | `file-type` reads magic bytes, rejects non-image MIME types regardless of extension. |
| Expired refresh token replay | Token marked `revoked` in PostgreSQL. Rotation detected, all user tokens invalidated. |
| Missing CSRF token on POST request | `@fastify/csrf-protection` returns 403 Forbidden. |

---

## 📝 7. Final QA/Security Audit Criteria

- [ ] Running `sqlmap` against all API endpoints yields zero vulnerabilities.
- [ ] Entering `<script>alert(1)</script>` as an expense title never executes in any user's browser.
- [ ] Forging a cross-origin POST request to `/api/settlements/pay` returns `403 Forbidden`.
- [ ] JWTs are NOT accessible via `document.cookie` or `localStorage` in the browser console.
- [ ] Uploading a `malicious.js` file renamed as `receipt.jpg` is rejected at the MIME type validation layer.
- [ ] Rate limiting returns `429` with `Retry-After` header after exceeding threshold on auth endpoints.
- [ ] `npm audit` reports zero critical or high severity vulnerabilities.
- [ ] All security headers verified present via `securityheaders.com` scan (A+ rating).
- [ ] CORS rejects requests from unlisted origins in production.
- [ ] Refresh token rotation invalidates old token on use — replay returns 401.
