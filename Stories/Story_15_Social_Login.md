# Story 15: Social Login (Google & Apple Sign-In) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Reduce the friction of account creation to a single tap. Financial apps live or die by first-session drop-off. Offering Google/Apple Sign-In eliminates the typing of passwords entirely, removes email validation friction, and instantly establishes trust via familiar OAuth providers. The backend verifies all social tokens server-side and issues its own JWT, keeping authentication fully under our control.

---

## 2. Target Persona & Motivation
- **The Impatient New User:** Doesn't want to create yet another password. Tapping "Continue with Google" and landing on the dashboard in 5 seconds is the goal.
- **The iOS User:** Expects "Sign in with Apple" as a first-class option per App Store guidelines. Trusts Apple's privacy-forward relay email approach.
- **The Returning Multi-Device User:** Signed up with Google on their phone, now opens the web app on their laptop. Expects the same Google login to work seamlessly.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Google Sign-In Flow (iOS & Android)
1. **Trigger:** User taps "Continue with Google" button on the Login/Signup screen.
2. **Action - Native Auth Sheet:** The `google_sign_in` Flutter package launches a native account picker (Android) or a system authentication sheet (iOS).
3. **Action - User Consent:** User selects or confirms their Google account.
4. **System State - Token Received:** The `google_sign_in` package returns a `GoogleSignInAuthentication` object containing the `idToken` (JWT).
5. **Action - API Call:** Flutter sends `{ "id_token": "..." }` to `POST /api/auth/google`.
6. **Backend Logic:** Fastify handler verifies the `id_token` using the `google-auth-library` npm package. Extracts `email`, `name`, `sub` (Google user ID). Performs Prisma upsert (see Technical Architecture).
7. **System State - Success:** Backend returns app JWT in an HttpOnly cookie. Flutter stores the refresh token in `flutter_secure_storage`. User is routed to the Dashboard.

### B. Google Sign-In Flow (Flutter Web)
1. **Trigger:** User taps "Continue with Google" on the web app.
2. **Action - Google Identity Services:** The `google_sign_in` Flutter package on web uses Google Identity Services (GIS) behind the scenes, rendering the One Tap or button flow.
3. **Action - User Consent:** User selects their Google account in the browser popup.
4. **System State - Token Received:** GIS returns a credential with the `id_token`.
5. **Remaining flow:** Identical to steps 5-7 above.

### C. Apple Sign-In Flow (iOS Only)
1. **Trigger:** User taps "Continue with Apple" on the Login/Signup screen. This button is only rendered when `Platform.isIOS` is true.
2. **Action - Native Sheet:** The `sign_in_with_apple` Flutter package triggers Apple's native authentication dialog (FaceID/TouchID/passcode).
3. **Action - User Consent:** User authenticates. Apple returns an `AuthorizationCredentialAppleID` containing `identityToken` (JWT) and optionally `givenName` + `familyName` (only provided on the very first sign-in with this app).
4. **Critical Note:** Apple only sends the user's name on the FIRST authorization. The client must capture and send it immediately; it will never be provided again.
5. **Action - API Call:** Flutter sends `{ "identity_token": "...", "name": "John Doe" }` to `POST /api/auth/apple`.
6. **Backend Logic:** Fastify handler fetches Apple's JWKS from `https://appleid.apple.com/auth/keys`, verifies the JWT signature using the `jose` npm package. Extracts `sub` (Apple user ID) and `email` (may be a privaterelay address).
7. **System State - Success:** Same as Google: app JWT in HttpOnly cookie, refresh token in `flutter_secure_storage`, route to Dashboard.

### D. Account Merging (Existing Email Conflict)
1. **Trigger:** User previously signed up with email/password as `john@example.com`. Now taps "Continue with Google" using the same `john@example.com` Gmail account.
2. **Backend Logic:** The Prisma upsert finds no matching `provider_id` for Google, but finds an existing user with matching email. Instead of creating a duplicate, the backend links the Google `provider_id` to the existing user record.
3. **System State:** User is logged into their existing account. All previous data (expenses, groups, balances) is preserved. User can now log in with either Google or their email/password.

---

## 4. UI/UX Component Specifications

### `GoogleSignInButton`
- Uses the official Google-branded button appearance per Google's branding guidelines.
- White background, Google "G" logo on the left, text: "Continue with Google".
- Height: 48px, border-radius: 8px, subtle grey border.
- Rendered on all platforms (iOS, Android, Web).

### `AppleSignInButton`
- Uses the official Apple Sign-In button per Apple's HIG guidelines.
- Black background, Apple logo, white text: "Continue with Apple".
- Height: 48px, border-radius: 8px.
- Conditionally rendered: only visible when `Platform.isIOS`. Hidden on Android and Web.

### `DividerWithText`
- A horizontal rule with "OR" label centered, separating social login buttons from the standard Email/Password form below.
- Light grey line, "OR" in muted text with small background padding to break the line.

### Login Screen Layout (top to bottom)
1. App logo and tagline
2. `GoogleSignInButton`
3. `AppleSignInButton` (iOS only)
4. `DividerWithText` ("OR")
5. Email input field
6. Password input field
7. "Log In" button
8. "Don't have an account? Sign Up" link

### Settings Screen Adjustments
- Social login users (where `password_hash` is null) do NOT see the "Change Password" option in Settings.
- Instead, the Authentication section shows: "Signed in with Google" (or Apple) with the provider icon.
- If the user has linked multiple providers, all are listed.

---

## 5. Technical Architecture

### Flutter Client Implementation

#### Google Sign-In
```dart
// lib/services/google_auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<String?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // User cancelled

      final auth = await account.authentication;
      return auth.idToken; // Send this to backend
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
```

#### Apple Sign-In
```dart
// lib/services/apple_auth_service.dart
import 'dart:io' show Platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthService {
  static bool get isAvailable => Platform.isIOS;

  Future<Map<String, String>?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Apple only provides name on FIRST sign-in ever
      final name = [
        credential.givenName,
        credential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

      return {
        'identity_token': credential.identityToken!,
        if (name.isNotEmpty) 'name': name,
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
```

#### Auth API Calls & Token Storage
```dart
// lib/services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiClient _api;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> loginWithGoogle(String idToken) async {
    final response = await _api.post('/api/auth/google', data: {
      'id_token': idToken,
    });

    // Access token comes back in HttpOnly cookie (auto-set by browser on web,
    // handled by cookie jar on mobile). Refresh token stored securely.
    await _secureStorage.write(
      key: 'refresh_token',
      value: response.data['refresh_token'],
    );
  }

  Future<void> loginWithApple(Map<String, String> credentials) async {
    final response = await _api.post('/api/auth/apple', data: credentials);

    await _secureStorage.write(
      key: 'refresh_token',
      value: response.data['refresh_token'],
    );
  }
}
```

### Node.js Fastify Backend

#### Prisma Schema
```prisma
// prisma/schema.prisma

model User {
  id            Int       @id @default(autoincrement())
  email         String    @unique
  name          String?
  passwordHash  String?   @map("password_hash")  // Nullable for social login users
  emailVerified Boolean   @default(false) @map("email_verified")
  createdAt     DateTime  @default(now()) @map("created_at")
  updatedAt     DateTime  @updatedAt @map("updated_at")

  providers     UserProvider[]
  // ... other relations (expenses, groups, etc.)

  @@map("users")
}

model UserProvider {
  id         Int      @id @default(autoincrement())
  userId     Int      @map("user_id")
  provider   String   // 'google' | 'apple'
  providerId String   @map("provider_id")
  createdAt  DateTime @default(now()) @map("created_at")

  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerId])
  @@map("user_providers")
}
```

#### Google Sign-In Endpoint
```javascript
// src/routes/auth/google.js
const { OAuth2Client } = require('google-auth-library');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

async function googleAuthRoutes(fastify) {
  fastify.post('/api/auth/google', {
    schema: {
      body: {
        type: 'object',
        required: ['id_token'],
        properties: {
          id_token: { type: 'string' },
        },
      },
    },
  }, async (request, reply) => {
    const { id_token } = request.body;

    // Verify the Google ID token
    let ticket;
    try {
      ticket = await googleClient.verifyIdToken({
        idToken: id_token,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
    } catch (error) {
      request.log.warn({ error: error.message }, 'Google token verification failed');
      return reply.code(401).send({ error: 'Invalid Google token' });
    }

    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture } = payload;

    if (!email) {
      return reply.code(400).send({ error: 'Email not provided by Google' });
    }

    // Upsert: find by provider_id first, then by email
    const user = await upsertSocialUser(fastify.prisma, {
      provider: 'google',
      providerId: googleId,
      email,
      name: name || null,
    });

    // Issue app JWT
    const { accessToken, refreshToken } = fastify.jwt.generateTokenPair(user);

    reply
      .setCookie('access_token', accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 15 * 60, // 15 minutes
      })
      .send({
        refresh_token: refreshToken,
        user: { id: user.id, email: user.email, name: user.name },
      });
  });
}

module.exports = googleAuthRoutes;
```

#### Apple Sign-In Endpoint
```javascript
// src/routes/auth/apple.js
const { createRemoteJWKSet, jwtVerify } = require('jose');

const appleJWKS = createRemoteJWKSet(
  new URL('https://appleid.apple.com/auth/keys')
);

async function appleAuthRoutes(fastify) {
  fastify.post('/api/auth/apple', {
    schema: {
      body: {
        type: 'object',
        required: ['identity_token'],
        properties: {
          identity_token: { type: 'string' },
          name: { type: 'string' },
        },
      },
    },
  }, async (request, reply) => {
    const { identity_token, name } = request.body;

    // Verify the Apple identity token
    let applePayload;
    try {
      const { payload } = await jwtVerify(identity_token, appleJWKS, {
        issuer: 'https://appleid.apple.com',
        audience: process.env.APPLE_BUNDLE_ID,
      });
      applePayload = payload;
    } catch (error) {
      request.log.warn({ error: error.message }, 'Apple token verification failed');
      return reply.code(401).send({ error: 'Invalid Apple token' });
    }

    const { sub: appleId, email } = applePayload;

    if (!email && !appleId) {
      return reply.code(400).send({ error: 'Insufficient identity data from Apple' });
    }

    // Upsert: find by provider_id first, then by email
    const user = await upsertSocialUser(fastify.prisma, {
      provider: 'apple',
      providerId: appleId,
      email: email || null,
      name: name || null,
    });

    // Issue app JWT
    const { accessToken, refreshToken } = fastify.jwt.generateTokenPair(user);

    reply
      .setCookie('access_token', accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 15 * 60, // 15 minutes
      })
      .send({
        refresh_token: refreshToken,
        user: { id: user.id, email: user.email, name: user.name },
      });
  });
}

module.exports = appleAuthRoutes;
```

#### Shared Upsert Logic (Account Merging)
```javascript
// src/services/social-auth.js

/**
 * Find or create a user from a social login.
 * Priority: match by provider_id, then by email (merge), then create new.
 */
async function upsertSocialUser(prisma, { provider, providerId, email, name }) {
  return await prisma.$transaction(async (tx) => {
    // 1. Check if this provider_id already exists (returning user)
    const existingProvider = await tx.userProvider.findUnique({
      where: {
        provider_providerId: { provider, providerId },
      },
      include: { user: true },
    });

    if (existingProvider) {
      // Update name if changed
      if (name && name !== existingProvider.user.name) {
        await tx.user.update({
          where: { id: existingProvider.user.id },
          data: { name },
        });
      }
      return existingProvider.user;
    }

    // 2. Check if email already exists (account merge)
    if (email) {
      const existingUser = await tx.user.findUnique({
        where: { email },
      });

      if (existingUser) {
        // Link new provider to existing account
        await tx.userProvider.create({
          data: {
            userId: existingUser.id,
            provider,
            providerId,
          },
        });

        // Mark email as verified (social provider confirms it)
        if (!existingUser.emailVerified) {
          await tx.user.update({
            where: { id: existingUser.id },
            data: { emailVerified: true },
          });
        }

        return existingUser;
      }
    }

    // 3. Create brand new user + provider link
    const newUser = await tx.user.create({
      data: {
        email,
        name,
        emailVerified: true, // Social provider confirms email
        providers: {
          create: { provider, providerId },
        },
      },
    });

    return newUser;
  });
}

module.exports = { upsertSocialUser };
```

### Token Flow Summary

```
Flutter Client                   Fastify Backend                 Social Provider
─────────────                   ───────────────                 ───────────────
1. User taps "Continue with X"
2. Native SDK launches ──────────────────────────────────────> Provider auth screen
3. User authenticates  <────────────────────────────────────── Returns id_token/identity_token
4. POST /api/auth/{provider} ──>
                                5. Verify token with provider's
                                   public keys (Google) or JWKS (Apple)
                                6. Prisma upsert user
                                7. Generate app JWT pair
                                <── Set HttpOnly cookie (access_token)
                                    + return refresh_token in body
8. Store refresh_token in
   flutter_secure_storage
9. Route to Dashboard
```

---

## 6. Edge Cases & Error Handling

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Same email via different providers** | User signed up with Google as `john@gmail.com`, now tries Apple Sign-In which reports the same email. | Backend matches on email, links the Apple `provider_id` to the existing user. Returns the same account. No data duplication. |
| **Apple hides real email** | Apple provides a relay address like `abc123@privaterelay.appleid.com`. | Backend stores and uses the relay email as canonical. It works for all purposes (notifications, receipts). If user later signs in with Google using their real email, account merge links both. |
| **Apple only sends name once** | Apple provides `givenName` and `familyName` only on the very first authorization. Subsequent sign-ins return null for name. | Flutter client captures the name on first sign-in and sends it to the backend. Backend stores it on user creation. If the name arrives as null on subsequent logins, the existing name is preserved. |
| **Google token expired before API hit** | Network lag causes the Google ID token to expire before the backend can verify it. | Backend returns `401 Invalid Google token`. Flutter catches the 401 and shows: "Authentication failed. Please try again." User taps the button again for a fresh token. |
| **User revokes Google access** | User goes to Google account settings and removes app permission. | On next login attempt, `google_sign_in` package either fails to get a token or returns a token that fails backend verification. User is shown: "Google sign-in failed. Please try again or use email/password." |
| **Social user taps "Change Password"** | Social-only user (no `password_hash`) navigates to Settings. | The "Change Password" option is not rendered. The Authentication section shows "Signed in with Google" (or Apple) with the provider icon. If user has both social and email/password, "Change Password" is shown. |
| **Network error during social login** | Device loses connection after Google returns the token but before the backend call completes. | Standard network error handling. Toast: "Network error. Please try again." The token is discarded; user taps the button again when connected. |
| **Multiple devices, same social account** | User logs in with Google on phone, then on tablet. | Both devices receive valid JWTs for the same user account. Socket.io handles real-time sync between them. Refresh tokens are independent per device. |
| **Backend JWKS fetch fails (Apple)** | Apple's JWKS endpoint is temporarily unreachable. | The `jose` library caches JWKS keys. If the cache is empty and fetch fails, return `503 Service Unavailable` with message: "Apple sign-in is temporarily unavailable." |

---

## 7. QA Acceptance Criteria

- [ ] "Continue with Google" successfully creates a new user with a linked `google` provider on first tap (iOS, Android, Web).
- [ ] Returning Google user is logged in without creating a duplicate `users` record.
- [ ] "Continue with Apple" button is shown ONLY on iOS builds. It is hidden on Android and Flutter Web.
- [ ] Apple Sign-In creates a new user with a linked `apple` provider, including the user's name from the first authorization.
- [ ] If a social account's email already has an email/password account, the accounts are merged (provider linked to existing user). No duplicate user records.
- [ ] Social login users see NO "Change Password" option in Settings.
- [ ] Settings shows "Signed in with Google" or "Signed in with Apple" with the appropriate provider icon.
- [ ] Google token verification uses `google-auth-library` on the backend (not client-side verification).
- [ ] Apple token verification fetches JWKS from `https://appleid.apple.com/auth/keys` and verifies JWT signature using the `jose` package.
- [ ] Backend returns app JWT in HttpOnly cookie and refresh token in response body.
- [ ] Flutter stores refresh token in `flutter_secure_storage` (not SharedPreferences or plain storage).
- [ ] Expired or invalid social tokens return `401` with a clear error message.
- [ ] `POST /api/auth/google` accepts `{ id_token }` payload and validates schema.
- [ ] `POST /api/auth/apple` accepts `{ identity_token, name }` payload and validates schema.
- [ ] Apple's relay email (`@privaterelay.appleid.com`) is stored and functions correctly as the user's email.
- [ ] A user can link multiple social providers to the same account and log in with any of them.
- [ ] All social auth endpoints include proper rate limiting to prevent abuse.
