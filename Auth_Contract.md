# Authentication Contract
> Resolves Architecture Audit Issues: #1 (JWT Lifecycle), #2 (Session Revoke)
> Version: 1.0 | March 26, 2026

---

## 1. TOKEN ARCHITECTURE

### Token Types
The system uses a **dual-token strategy:**

| Token | Type | Storage | TTL | Purpose |
|---|---|---|---|---|
| Access Token | JWT (RS256) | HttpOnly cookie (`access_token`) | **15 minutes** | Authenticate every API request |
| Refresh Token | Opaque (random 256-bit hex) | HttpOnly cookie (`refresh_token`) | **30 days** | Issue new access tokens |

### Why RS256 (Asymmetric)
Private key signs tokens on the server. Public key verifies them. This allows future microservices to verify tokens without access to the private key.

### Cookie Configuration
```
access_token:
  HttpOnly: true
  Secure: true (HTTPS only)
  SameSite: Strict
  Path: /api
  MaxAge: 900 (15 minutes)

refresh_token:
  HttpOnly: true
  Secure: true
  SameSite: Strict
  Path: /api/auth/refresh
  MaxAge: 2592000 (30 days)
```
`SameSite: Strict` + `HttpOnly` eliminates both CSRF and XSS attack vectors simultaneously.

---

## 2. TOKEN LIFECYCLE

### 2.1 Login Flow
```
POST /api/v1/auth/login
Body: { email, password }

Response (200 OK):
  Set-Cookie: access_token=<JWT>; HttpOnly; Secure; SameSite=Strict; MaxAge=900
  Set-Cookie: refresh_token=<opaque>; HttpOnly; Secure; SameSite=Strict; MaxAge=2592000; Path=/api/auth/refresh
  Body: { user: { id, name, email, avatar_url, home_currency, onboarding_completed } }
```

### 2.2 Silent Refresh (Flutter — Dio Interceptor)

Flutter has no browser so cookies must be managed via `cookie_jar` (dio_cookie_manager package).

**Dio interceptor logic:**
```
On every 401 response:
  1. Check if refresh_token cookie exists
  2. POST /api/v1/auth/refresh  (only sends refresh_token cookie — SameSite: Strict on /api/auth/refresh path)
  3. Server response:
     → 200: new access_token cookie set; retry original request once
     → 401 (refresh expired/invalid): clear both cookies → navigate to Login screen
  4. If refresh call is already in-flight: queue all incoming 401s, resolve all together after refresh completes
```

**Queueing concurrent requests during refresh:**
- Use a `Completer<void>` flag in the interceptor
- All 401s while refresh is in progress are queued (not re-fired)
- On refresh success: all queued requests are retried with the new access token
- This prevents a thundering herd of refresh calls

### 2.3 Access Token JWT Payload
```json
{
  "sub": "user_uuid",
  "email": "alice@example.com",
  "role": "user",
  "token_version": 3,
  "iat": 1711449600,
  "exp": 1711450500
}
```

**`token_version` field:** Allows immediate invalidation of all tokens for a user without a blacklist (see Section 3).

### 2.4 Token Expiry on App Launch
On cold launch, before any navigation:
1. App attempts `GET /api/v1/auth/me` (sends access_token cookie)
2. `200 OK` → navigate to Dashboard
3. `401` → interceptor triggers silent refresh (Section 2.2)
4. Refresh fails → navigate to Login

---

## 3. SESSION REVOKE MECHANISM

### Strategy: Token Versioning (No Blacklist Required)

**Why not a blacklist:**
- A blacklist requires a Redis lookup on every API request — adds 1-5ms latency per call
- Redis downtime = all auth fails
- Token versioning achieves the same result with zero external dependency

**Implementation:**

Database — `users` table: add column `token_version INTEGER DEFAULT 1`

On every JWT, include `token_version` in the payload (see Section 2.3).

**Fastify middleware verification:**
```
For every protected request:
  1. Verify JWT signature (RS256 public key)
  2. Check token not expired (standard JWT check)
  3. Query DB: SELECT token_version FROM users WHERE id = sub
  4. If jwt.token_version !== db.token_version → return 401 (token invalidated)
  5. Pass request
```

**To revoke a specific session (device):**
```
DELETE /api/v1/auth/sessions/:sessionId
```
- Increments `token_version` in the DB by 1
- All existing access tokens (all devices) for this user become invalid immediately
- Each device will silently refresh on next 401 — only the revoked device's refresh token is deleted from the `sessions` table
- Other devices successfully refresh and get new tokens with the new version

**To revoke ALL sessions (e.g., password change, account compromise):**
- Increment `token_version` AND delete all entries in the `sessions` table for this user
- All devices are logged out immediately upon next request

### Sessions Table Schema
```sql
CREATE TABLE sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,         -- "iPhone 14 Pro — iOS 18"
  device_type TEXT NOT NULL,         -- "ios" | "android" | "web"
  refresh_token_hash TEXT NOT NULL,  -- bcrypt hash of the opaque refresh token
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(refresh_token_hash)
);
```
- `device_name` is derived from the User-Agent on login
- `refresh_token_hash` → never store the raw token (same as passwords)
- `last_used_at` is updated on every successful refresh — drives the "Last active" display in Settings

---

## 4. OAUTH FLOWS

### Google OAuth (Story 15)
```
Client:  GET /api/v1/auth/google                        → redirects to Google consent screen
Google:  GET /api/v1/auth/google/callback?code=...
Server:
  1. Exchange code for id_token (PKCE — code_verifier sent in initial request)
  2. Verify id_token with Google public keys (RS256)
  3. Extract { sub, email, name, picture } from payload
  4. Upsert user: find by email OR google_id
     → New user: create record, set onboarding_completed = false
     → Existing user (same email): merge (update google_id), set onboarding_completed stays as-is
  5. Issue access_token + refresh_token cookies
  6. Redirect to /onboarding (new) or /dashboard (returning)
```

### Apple Sign-In (Story 15)
```
Same flow as Google but:
  - Uses Apple's authorization code + PKCE
  - Apple only provides name/email on FIRST login — must be cached on first use
  - Subsequent logins only provide apple_sub — must store apple_sub in users table
```

### Post-OAuth Deep Link Preservation
- Before redirecting to Google/Apple, store the pending deep link path in the session (server-side, keyed by state parameter)
- After OAuth callback, retrieve and redirect to that stored path after auth

---

## 5. RATE LIMITING (AUTH ENDPOINTS)

| Endpoint | Limit | Window | Block Duration |
|---|---|---|---|
| `POST /api/v1/auth/login` | 10 requests | 1 minute | 1 minute |
| `POST /api/v1/auth/signup` | 5 requests | 1 minute | 5 minutes |
| `POST /api/v1/auth/forgot-password` | 3 requests | 1 minute | 10 minutes |
| `POST /api/v1/auth/refresh` | 20 requests | 1 minute | 5 minutes |

Implementation: Fastify `@fastify/rate-limit` with Redis as shared store.
On limit: `HTTP 429` with `Retry-After` header (seconds until reset). Flutter UI reads `Retry-After` to drive the countdown timer.

---

## 6. onboarding_completed SOURCE OF TRUTH

**Rule:** Backend is authoritative. Local is cache only.

**Backend:** `users` table — `onboarding_completed BOOLEAN DEFAULT FALSE`

**Set to `true` when:**
- User completes step 3 of onboarding (taps "Done")
- User skips any step (skip = complete)
- User joins a group via invite link (group join = implicit completion)

**Flutter behavior:**
- On login/refresh: `onboarding_completed` is returned in the `/api/v1/auth/me` response
- Cached in Riverpod `AuthProvider` state
- Riverpod reads local cache for immediate routing decision; backend value overrides on next `/me` call
- On reinstall: no local cache → `/me` call → backend serves correct value → no re-onboarding

---

## 7. SECURITY SUMMARY

| Threat | Mitigation |
|---|---|
| XSS token theft | HttpOnly cookies — JS cannot access tokens |
| CSRF on web | SameSite=Strict — cross-origin requests don't send cookies |
| Brute force login | Rate limiting (10/min) + 1-minute lockout |
| Stolen refresh token | Stored as bcrypt hash in DB — raw token useless if DB leaked |
| Session persistence after revoke | Token versioning — revoke takes effect within 15 minutes (max access token TTL) |
| Replay attack | Short access token TTL (15 min) + JWT `exp` check |
| OAuth CSRF | `state` parameter validated + PKCE `code_verifier` |
