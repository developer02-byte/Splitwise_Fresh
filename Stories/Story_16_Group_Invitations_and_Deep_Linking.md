# Story 31: Group Invitations & Deep Linking - Detailed Execution Plan

## 1. Core Objective & Philosophy
Seamless group invitation flow — tap a link, create account in one tap, land directly in the group. The invite experience is the first impression for new users. Every extra tap or confusing redirect is a lost user. Deep linking extends beyond invitations to all notifications and shared content, ensuring every tap in the app lands the user exactly where they expect.

---

## 2. Target Persona & Motivation
- **The Inviter (Alice):** Wants to add her friends to "Tokyo Trip" with minimal friction. She should be able to share a link via WhatsApp, iMessage, email, or QR code in under 5 seconds.
- **The Invitee - New User (Bob):** Receives a link from Alice. Has never used the app. Should go from tapping the link to being inside the group in under 60 seconds (including signup).
- **The Invitee - Existing User (Charlie):** Already has the app. Taps the link, sees a confirmation, joins the group. Total time: 5 seconds.
- **The Notification Tapper:** Gets a push notification "Alice added Dinner ($60)." Taps it. Lands directly on the expense detail, not the dashboard.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Creating and Sharing an Invitation
1. **Trigger:** Alice opens "Tokyo Trip" group settings. Taps "Invite Members."
2. **UI - Invite Screen:** Shows three options:
   - **Copy Link** — copies invite URL to clipboard.
   - **Share** — opens system share sheet (WhatsApp, iMessage, email, etc.).
   - **QR Code** — displays scannable QR code (useful for in-person invites).
3. **Backend:** `POST /api/groups/{id}/invitations` generates a unique invite token (UUID v4). Returns `{ token, invite_url, expires_at }`.
4. **Invite URL format:** `https://app.yourdomain.com/invite/{token}`.
5. **Share Sheet:** Alice selects WhatsApp. Message auto-populated: "Join my group 'Tokyo Trip' on Splitwise: https://app.yourdomain.com/invite/abc123".
6. **QR Code:** Generated client-side using `qr_flutter` package. Contains the same invite URL.

### B. Accepting Invitation — New User (Bob)
1. **Bob taps link in WhatsApp.**
2. **App NOT installed:**
   - Link opens in browser. Landing page shows: "Alice invited you to 'Tokyo Trip'" with app store badges (iOS/Android) and a "Continue in Browser" option for web.
   - Deferred deep link: The invite token is stored (via Firebase Dynamic Links or custom solution with cookies). After Bob installs and opens the app, the invite context is restored.
3. **App IS installed:**
   - Universal Link (iOS) or App Link (Android) opens the app directly.
   - `go_router` intercepts the route `/invite/:token`.
4. **In-App (not logged in):**
   - App shows: "Alice invited you to 'Tokyo Trip'" with group name and member count.
   - Below: Google One-Tap signup button (Story 15) and email signup form.
   - Invite token stored in local state during auth flow.
5. **After signup:**
   - Backend automatically calls `POST /api/groups/{group_id}/join` with the invite token.
   - Bob is added to the group. Navigation redirects to the group screen.
   - Welcome message in group: "Bob joined via Alice's invitation."

### C. Accepting Invitation — Existing User (Charlie)
1. **Charlie taps link.**
2. **App opens (already logged in).**
3. **Route `/invite/:token` triggers:**
   - Backend validates token: `GET /api/invitations/{token}/validate`.
   - Response: `{ valid: true, group: { id, name, memberCount, createdBy }, invitedBy: { name, avatar } }`.
4. **UI - Join Confirmation Screen:**
   - Group cover photo (if set) as header.
   - "Alice invited you to 'Tokyo Trip'" with group avatar and member count.
   - "Join Group" primary CTA button. "Decline" secondary text button.
5. **Charlie taps "Join Group":**
   - `POST /api/invitations/{token}/accept`.
   - Backend adds Charlie to group. Emits `member:joined` Socket.io event (Story 30).
   - Navigation redirects to group screen.
6. **Already a member:** If Charlie is already in the group, UI shows "You're already a member of this group" with a "Go to Group" button.

### D. Notification Deep Linking
1. **Push notification received:** "Alice added 'Dinner' ($60) — you owe $30."
2. **Notification payload includes:** `{ type: "expense_created", groupId: "xxx", expenseId: "yyy" }`.
3. **User taps notification:**
   - App opens (or comes to foreground).
   - Flutter notification handler extracts route from payload.
   - `go_router` navigates to `/groups/{groupId}/expenses/{expenseId}`.
4. **Deep link mapping:**

| Notification Type | Deep Link Route | Screen |
| --- | --- | --- |
| `expense_created` | `/groups/{gid}/expenses/{eid}` | Expense Detail |
| `expense_updated` | `/groups/{gid}/expenses/{eid}` | Expense Detail |
| `settlement_created` | `/groups/{gid}/settlements/{sid}` | Settlement Confirmation |
| `comment_created` | `/groups/{gid}/expenses/{eid}?scrollTo=comments` | Expense Detail (comments section) |
| `payment_reminder` | `/groups/{gid}/settle-up` | Settle Up Modal |
| `group_invitation` | `/invite/{token}` | Join Confirmation |
| `member_joined` | `/groups/{gid}` | Group Ledger |

---

## 4. Ultra-Detailed UI/UX Component Specifications

### `InviteScreen`
- **Header:** Group name and cover photo (or gradient fallback).
- **Invite Link Card:** Rounded card showing the invite URL (truncated) with a "Copy" icon button. Tap copies to clipboard with haptic feedback and "Copied!" snackbar.
- **Action Buttons:** Row of three: Copy Link (icon: link), Share (icon: share), QR Code (icon: qr_code). Each 80px wide, icon + label, outlined style.
- **Active Invitations Section:** Below the action buttons. List of active invitations with: invitee name (if known) or "Pending", created date, expiry date, "Revoke" text button in red.

### `JoinConfirmationScreen`
- **Hero:** Group cover photo or gradient background. Group avatar centered (80px circle).
- **Text:** "{inviter_name} invited you to" in muted grey. "{group_name}" in bold 24px. "{member_count} members" in muted grey.
- **CTA:** "Join Group" full-width primary button. Below: "Decline" text button in muted grey.
- **Loading state:** Button shows circular progress indicator while joining.
- **Error state:** Snackbar with error message. Button re-enabled.

### `QRCodeModal`
- Bottom sheet. White background. QR code centered (250x250px). Group name below QR code. "Share QR" button to save as image.
- QR encodes the full invite URL.

### `InviteLandingPage` (Web - for users without the app)
- Responsive single-page design. App logo top-center.
- "{inviter_name} invited you to '{group_name}'" headline.
- App store badges (iOS, Android) side by side.
- "Continue in Browser" link below for web app access.
- Clean, minimal design. No navigation or distracting elements.

---

## 5. Technical Architecture & Database

### Backend Endpoints

#### 1. `POST /api/groups/{id}/invitations`
- **Auth:** Required. Must be group member.
- **Payload:** `{ maxUses: 1 | 5 | null }` (null = unlimited).
- **Response:** `{ id, token, inviteUrl, expiresAt, maxUses }`.
- **Logic:** Generates UUID v4 token. Stores in `group_invitations` table. Default expiry: 7 days.

#### 2. `GET /api/invitations/{token}/validate`
- **Auth:** Optional (works for both logged-in and anonymous users).
- **Response (valid):** `{ valid: true, group: { id, name, memberCount, coverUrl }, invitedBy: { name, avatarUrl } }`.
- **Response (invalid):** `{ valid: false, reason: "expired" | "revoked" | "max_uses_reached" | "not_found" }`.

#### 3. `POST /api/invitations/{token}/accept`
- **Auth:** Required (user must be logged in).
- **Response:** `201 { group: GroupSummary }`.
- **Logic:**
  1. Validate token (not expired, not revoked, uses remaining).
  2. Check user is not already a member.
  3. Add user to `group_members` table.
  4. Increment `use_count` on invitation.
  5. Emit `member:joined` Socket.io event.
  6. Create activity entry: "Bob joined via Alice's invitation."
- **Error Responses:** `400` already a member, `404` invalid token, `410` expired/revoked.

#### 4. `DELETE /api/groups/{id}/invitations/{invitationId}`
- **Auth:** Required. Must be group admin or invitation creator.
- **Response:** `204`.
- **Logic:** Sets `revoked_at` timestamp. Token becomes invalid immediately.

#### 5. `GET /api/groups/{id}/invitations`
- **Auth:** Required. Must be group member.
- **Response:** List of active invitations with usage stats.

### Database Schema (Prisma)
```prisma
model GroupInvitation {
  id         String    @id @default(uuid())
  groupId    String    @map("group_id")
  invitedBy  String    @map("invited_by")
  token      String    @unique
  maxUses    Int?      @map("max_uses")   // null = unlimited
  useCount   Int       @default(0) @map("use_count")
  expiresAt  DateTime  @map("expires_at")
  revokedAt  DateTime? @map("revoked_at")
  createdAt  DateTime  @default(now()) @map("created_at")

  group      Group     @relation(fields: [groupId], references: [id])
  inviter    User      @relation(fields: [invitedBy], references: [id])
  usages     InvitationUsage[]

  @@index([token])
  @@index([groupId])
  @@map("group_invitations")
}

model InvitationUsage {
  id           String   @id @default(uuid())
  invitationId String   @map("invitation_id")
  userId       String   @map("user_id")
  joinedAt     DateTime @default(now()) @map("joined_at")

  invitation   GroupInvitation @relation(fields: [invitationId], references: [id])
  user         User            @relation(fields: [userId], references: [id])

  @@unique([invitationId, userId])
  @@map("invitation_usages")
}
```

### Deep Linking Setup

#### Flutter (go_router)
```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/invite/:token',
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return JoinConfirmationScreen(token: token);
      },
      redirect: (context, state) {
        final isLoggedIn = ref.read(authProvider).isAuthenticated;
        if (!isLoggedIn) {
          // Store invite token, redirect to auth, then back
          ref.read(pendingInviteProvider.notifier).state = state.pathParameters['token'];
          return '/auth/signup';
        }
        return null; // No redirect, show join screen
      },
    ),
    // ... other routes
  ],
);
```

#### iOS Universal Links
- Host file at `https://app.yourdomain.com/.well-known/apple-app-site-association`:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.yourdomain.splitwise",
        "paths": ["/invite/*", "/groups/*", "/expenses/*"]
      }
    ]
  }
}
```

#### Android App Links
- Host file at `https://app.yourdomain.com/.well-known/assetlinks.json`:
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourdomain.splitwise",
    "sha256_cert_fingerprints": ["SHA256_FINGERPRINT"]
  }
}]
```

- AndroidManifest.xml intent filter:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="app.yourdomain.com" android:pathPrefix="/invite" />
</intent-filter>
```

### Deferred Deep Linking (New Users)
For users who do not have the app installed:
1. Invite link opens a web landing page.
2. Landing page stores the invite token in a cookie and redirects to app store.
3. After install, on first app open, client checks for the cookie (via a backend endpoint that reads the cookie) or uses Firebase Dynamic Links / Branch.io.
4. If invite token is found, auto-navigate to join confirmation after signup.

### Notification Deep Link Handling (Flutter)
```dart
// notification_handler.dart
void handleNotificationTap(Map<String, dynamic> payload) {
  final type = payload['type'];
  final groupId = payload['groupId'];
  final expenseId = payload['expenseId'];

  switch (type) {
    case 'expense_created':
    case 'expense_updated':
      router.go('/groups/$groupId/expenses/$expenseId');
      break;
    case 'settlement_created':
      router.go('/groups/$groupId/settlements/${payload['settlementId']}');
      break;
    case 'comment_created':
      router.go('/groups/$groupId/expenses/$expenseId?scrollTo=comments');
      break;
    case 'payment_reminder':
      router.go('/groups/$groupId/settle-up');
      break;
    case 'group_invitation':
      router.go('/invite/${payload['token']}');
      break;
    default:
      router.go('/dashboard');
  }
}
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Expired invitation** | Bob taps a link that is 8 days old (expired after 7). | `GET /api/invitations/{token}/validate` returns `{ valid: false, reason: "expired" }`. UI shows: "This invitation has expired. Ask {inviter_name} to send a new one." |
| **Already a member** | Charlie taps an invite link for a group he is already in. | Backend returns `400: Already a member`. UI shows: "You're already a member of 'Tokyo Trip'" with a "Go to Group" button. |
| **Max uses reached** | A single-use invite link is shared publicly and 2 people try to use it. | First person joins successfully. Second person gets `{ valid: false, reason: "max_uses_reached" }`. UI shows: "This invitation has already been used." |
| **Revoked invitation** | Admin revokes an invite while someone is on the join screen. | When user taps "Join Group", backend returns `410: Invitation revoked`. UI shows error. |
| **Invite link shared publicly** | Someone posts the invite link on social media. Hundreds of people try to join. | `maxUses` limit prevents mass joins. Additionally, groups can have a `max_members` setting (default 50). Once hit, new joins are rejected: "This group is full." |
| **App not installed (deferred deep link)** | Bob does not have the app. Taps link on Android. | Opens web landing page with app store link. Invite token stored. After install and signup, token is recovered and join flow completes. |
| **Deep link with expired session** | User taps a notification deep link but their session has expired. | App detects unauthenticated state. Redirects to login. After login, resumes navigation to the intended deep link destination (`pendingDeepLink` stored in state). |
| **Offline invite accept** | User taps "Join Group" while offline. | Button shows loading, then error snackbar: "No internet connection. Please try again." Invite token is preserved in state so user can retry without re-opening the link. |
| **Multiple pending invites** | User has invite links for 3 groups before signing up. | Only the most recent invite token is stored as pending. After joining the first group, the other invite links can be tapped again from chat history. |

---

## 7. Final QA Acceptance Criteria

- [ ] Generating an invite link returns a valid URL containing a UUID token.
- [ ] Copy Link copies the URL to clipboard and shows confirmation snackbar.
- [ ] Share button opens system share sheet with pre-populated message.
- [ ] QR code is scannable and contains the correct invite URL.
- [ ] New user: tapping invite link -> signup -> auto-joined to group in under 60 seconds.
- [ ] Existing user: tapping invite link -> join confirmation -> in group in under 5 seconds.
- [ ] Expired invitation shows clear error message with suggestion to request a new invite.
- [ ] Revoked invitation is immediately invalid (no grace period).
- [ ] Single-use invitation becomes invalid after first use.
- [ ] Already-a-member user sees a helpful redirect to the group (not an error).
- [ ] Notification deep links navigate to the correct screen for all notification types.
- [ ] Universal Links (iOS) and App Links (Android) open the app directly without browser redirect.
- [ ] Invitation management screen shows all active invites with revoke option.
- [ ] Group admin can see which members joined via which invitation.
