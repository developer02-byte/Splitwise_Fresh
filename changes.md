# Changes for Story 09: Friends & Individual Ledgers

## What is Missing / Broken (from QA Report)
- **[Critical]** No `FriendDetailScreen` — tapping a friend shows SnackBar stub.
- **[Critical]** `GET /api/user/friends/{friend_id}/ledger` endpoint does not exist.
- **[High]** `FriendHeroSummary` widget does not exist.
- **[High]** Per-friend Settle Up with pre-filled amount does not exist.
- **[High]** Balance calculation in `buildFriendsList()` may double-count due to querying both directions of balance table.
- **[Medium]** "Remove Friend" for ghost users not implemented.

## What I Will Fix
1. **Friends Provider & Backend Routes**:
   - Fixed the logic flaw in `buildFriendsList` (double-counting query removed; symmetric schema row queried properly).
   - Engineered `GET /api/user/friends/:id/ledger` endpoint to pull every single `expense` intersecting the current `userId` and `friendId` simultaneously in a Prisma join constraint.
   - Built `DELETE /api/user/friends/:id` route that specifically rejects deletion if the `netBalance` remains non-zero.
   - Re-wrote `FriendsNotifier` inside Flutter to parse `deleteFriend(id)`.
2. **Settle Up Dynamics (`settle_up_screen.dart`)**:
   - Purged the `_mockDebts` placeholder list explicitly. 
   - Dynamically bound `SettleUpScreen` logic to `ref.watch(friendsNotifierProvider)` and filtered the dropdown array down ONLY to users where `netBalanceCents < 0` (You Owe money). 
   - Extended the constructor `SettleUpScreen({this.prefilledFriendId, this.prefilledAmount})` for direct deep-linking from `FriendDetailScreen`.
3. **Friend Details (`frontend/lib/features/friends/presentation/screens/friend_detail_screen.dart`)**:
   - Built `FriendDetailScreen` and bound it to `/friends/:id` along with `app_router.dart` parameters.
   - Implemented `FriendHeroSummary` header widget which dynamically prints "You owe \$X" vs "Owes you \$Y" with color tracking.
   - Wired the Ledger API hook down through a dedicated `.family` async provider.
   - Set up Action Sheet for "Remove Friend".

---

# Changes for Story 10: Profile & Settings

## What is Missing / Broken (from QA Report & Master Index)
- **[High]** "Default Currency" tile is a stub — no currency picker.
- **[High]** "Dark Mode" Switch `onChanged: (val) {}` — complete no-op.
- **[High]** "Change Password" completely absent (no UI, no backend endpoint). (Note: Actually exists but needs verification/wiring).
- **[High]** Delete account requires no typed confirmation — (Note: Code shows it exists, but needs verification).
- **[High]** Logout not awaited before `context.go('/login')` — (Note: Code shows it exists, but needs verification).
- **[Medium]** Timezone setting missing in backend and frontend.
- **[Medium]** Avatar upload stubbed/missing.
- **[Low]** No logout confirmation `AlertDialog`.

## What I Will Fix
1. **Database Schema & Backend**:
   - Add `timezone` (VARCHAR) and `deletedAt` (TIMESTAMPTZ) to `User` model in Prisma.
   - Implement true **soft delete** in `DELETE /api/user/me` (setting `deletedAt`).
   - Fix `PUT /api/user/me` to support `timezone` and ensure `avatarUrl` is updateable.
2. **Profile & Settings UI**:
   - Engineered `ThemeNotifier` to provide real-time **Dark Mode** toggling with `SharedPreferences` persistence.
   - Built `TimezonePicker` (Searchable dialog) and wired to `UserProfile` provider.
   - Implemented `AvatarUpload` mock logic with instant UI update.
   - Refined `Logout` flow with a premium `AlertDialog` confirmation.
   - Validated and refined `ChangePasswordScreen` and `DeleteAccount` flows for industrial-grade security.
