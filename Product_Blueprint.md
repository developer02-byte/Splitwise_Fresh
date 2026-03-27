# Product Blueprint — Splitwise-Clone App
> **Source:** UI/UX Feature-Aligned Plan v3.0
> **Version:** 1.0 | March 26, 2026
> **Purpose:** Development-ready structural map of all pages, features, flows, and systems.

---

## SECTION 1 — COMPLETE PAGE INVENTORY

### 1.1 Main Pages (Sidebar-Accessible)
| ID | Page Name | Route |
|---|---|---|
| P01 | Dashboard | `/dashboard` |
| P02 | Groups List | `/groups` |
| P03 | Group Detail | `/groups/:id` |
| P04 | Friends List | `/friends` |
| P05 | Friend Ledger | `/friends/:id` |
| P06 | Activity Feed | `/activity` |
| P07 | Search | `/search` |
| P08 | Notifications Center | `/notifications` |
| P09 | Settings | `/settings` |

### 1.2 Auth Pages (No Sidebar)
| ID | Page Name | Route |
|---|---|---|
| P10 | Login | `/login` |
| P11 | Sign Up | `/signup` |
| P12 | Forgot Password — Step 1 | `/forgot-password` |
| P13 | Forgot Password — Step 2 | `/forgot-password/sent` |
| P14 | Onboarding Flow | `/onboarding` |

### 1.3 Sub-Pages
| ID | Page Name | Route |
|---|---|---|
| P15 | Expense Detail | `/groups/:id/expenses/:expenseId` |
| P16 | Audit Log | `/groups/:id/audit` |
| P17 | Group Preview (Invite Landing) | `/groups/:id/preview` |

### 1.4 Modals (Overlays over current page)
| ID | Modal Name | Trigger |
|---|---|---|
| M01 | Add / Edit Expense | "+ Add Expense" button or edit tap |
| M02 | Settle Up | "Settle Up" button |
| M03 | Create Group | "+ New Group" button |
| M04 | Add Friend | "+ Add Friend" button |
| M05 | Recurring Expense Choice | Edit tap on recurring expense row |
| M06 | Transfer Ownership | "Transfer Ownership" option in Members tab |
| M07 | Delete Expense Confirmation | "Delete" on expense |
| M08 | Leave Group Confirmation | "Leave Group" option |
| M09 | Delete Account — Debt Check | "Delete Account" tap (with debt) |
| M10 | Delete Account — Confirmation | "Delete Account" tap (no debt) |
| M11 | Session Revoke Confirmation | "Revoke" session button |
| M12 | Data Export | "Export My Data" in Settings |
| M13 | Group Settings | Gear icon in Group Detail header |

### 1.5 Sheets / Overlays (Bottom Sheets)
| ID | Sheet Name | Trigger |
|---|---|---|
| S01 | Push Notification Pre-Prompt | After first meaningful action |
| S02 | Soft Update Prompt | App launch — minor version available |
| S03 | Sync Issues Sheet | "Review" in sync failure banner |
| S04 | Group-Scoped Search | Magnifier icon in Expenses tab |
| S05 | Currency Conversion Breakdown | Tap "Converted from N currencies" |
| S06 | Simplify Debts Explainer Popover | ⓘ icon beside toggle |
| S07 | Per-Member Percentage Editor | "Manage per-member percentages" in Group Settings |

### 1.6 Special Full-Screen States
| ID | State Name | Trigger |
|---|---|---|
| FS01 | Force Update Screen | `force_update: true` from version API |
| FS02 | Rate Limit Lockout (Login form locked) | 10 failed login attempts |
| FS03 | Offline Banner (persistent) | Connectivity lost |
| FS04 | Sync Failure Banner (persistent) | Partial offline queue failure |

### 1.7 Web-Only Components
| ID | Name | Trigger |
|---|---|---|
| W01 | Cookie Consent Banner | First web visit |

---

## SECTION 2 — PAGE-WISE STRUCTURE

---

### P10 — Login

#### Purpose
Authenticate an existing user. Zero distractions, fast access.

#### Color Usage
- Background: `--color-bg` (off-white)
- Card surface: `--color-surface` (white)
- Primary button: `--color-primary`
- Error state: `--color-danger`
- Link color: `--color-primary`

#### Layout (Top → Bottom)
1. App logo + name — centered top
2. "Welcome back" heading
3. Email input field
4. Password field (show/hide toggle)
5. "Forgot Password?" link — right-aligned
6. "Sign In" primary button — full width
7. Divider: "or"
8. Google Sign-In button (outlined)
9. Apple Sign-In button — iOS/Web only (outlined)
10. "Don't have an account? Sign up" link

#### Components
- InputText (email, password)
- ButtonPrimary (Sign In)
- ButtonSecondary (Google, Apple — outlined)
- Error inline message
- Rate limit countdown label (FS02)

#### Features on This Page
- Email + password authentication
- Google OAuth (Story 15)
- Apple Sign-In — iOS/web only (Story 15)
- Brute-force rate limiting — 10 attempts/min (Story 01, 26)
- "Forgot Password?" navigation link
- Loading state on Sign In button

#### Rate Limit State (FS02)
- Email + password fields: disabled, greyed out
- Sign In button: disabled, label = `"Try again in 47s"` (live countdown)
- Google/Apple buttons: remain enabled
- Error message: `"Too many failed attempts. Please wait before trying again."`
- At 0s: all fields re-enable, button resets — no page refresh

#### States
- **Loading:** Sign In button shows spinner, width locked, no layout shift
- **Error (wrong credentials):** Red inline message below form — `"Incorrect email or password"`
- **Rate limited:** Form locked, live countdown on button (see FS02)
- **No internet:** Toast warning — `"No connection. Check your network."`

#### User Actions
- Submit email/password form
- Click "Forgot Password?" → P12
- Click "Sign up" → P11
- Click Google Sign-In → OAuth popup
- Click Apple Sign-In → Apple auth (iOS/web)

#### Navigation Out
- Successful login → P14 (first-time) or P01 (returning user)
- "Forgot Password?" → P12
- "Sign up" → P11
- Invite deep link preserved through auth → P17

---

### P11 — Sign Up

#### Purpose
Register a new user with minimal friction.

#### Layout (Top → Bottom)
1. App logo + name
2. "Create your account" heading
3. Full name field
4. Email field
5. Password field + strength indicator bar (4-segment, red→green)
6. Terms acceptance note (linked, Story 40)
7. "Create Account" primary button — full width
8. Divider + Google / Apple options
9. "Already have an account? Sign in" link

#### Components
- InputText (name, email, password)
- Password strength bar (4 segments, colors: red / orange / yellow / green)
- Strength label text (Weak / Fair / Good / Strong)
- ButtonPrimary
- ButtonSecondary (Google, Apple)

#### States
- **Error (duplicate email):** `"An account with this email already exists"` — inline
- **Weak password:** Strength bar red, "Create Account" button disabled
- **Loading:** Button shows spinner
- **Success:** Auto-login → P14 (Onboarding)

#### User Actions
- Submit registration form
- View password strength in real time
- Click Google/Apple → SSO registration
- Click "Sign in" → P10

---

### P12 / P13 — Forgot Password

#### Purpose
Allow secure password recovery via email token.

#### P12 Layout (Request Step)
1. Back to Login link
2. "Reset your password" heading
3. Instruction text
4. Email field
5. "Send Reset Link" button

#### P13 Layout (Sent Confirmation Step)
1. Email-sent icon (success green)
2. "Check your inbox" heading
3. Confirmation text with user's email shown
4. "Resend email" button — disabled for 60s, shows countdown
5. "Back to sign in" link

#### Anti-Scraping Rule
Same success screen shown regardless of whether email exists in system (Story 06).

#### States
- **Loading:** Button spinner
- **Resend cooldown:** Button disabled, shows `"Resend in 42s"` live countdown

---

### P14 — Onboarding Flow

#### Purpose
Guide a first-time user to take their first meaningful action.

#### Layout
- 3-step slide-based flow, centered, no sidebar
- Step 1: Add a Friend — icon + description + CTA
- Step 2: Create a Group — icon + description + CTA
- Step 3: Add an Expense — icon + description + CTA
- Skip button (top-right) at every step
- Progress dots at bottom

#### Priority Rule
- If user arrived via invite deep link: onboarding is skipped entirely, `onboarding_completed` set to true after joining group
- If mid-onboarding and invite link tapped: onboarding paused, invite flow taken, onboarding marked complete on join
- Never shown again after `onboarding_completed = true`

#### After Completion / Skip
- Navigate to P01 (Dashboard)
- If all skipped: Dashboard shows "Getting Started" card (see P01 empty state)

---

### P01 — Dashboard

#### Purpose
Instant financial clarity. User must understand total balance within 5 seconds.

#### Color Usage
- Balance Hero card background: `--color-primary`
- "You are owed" figure: `--color-success` (green)
- "You owe" figure: `--color-danger` (red)
- Settled balance: muted grey, "Settled" badge
- Activity row amounts: green or red per direction

#### Layout (Top → Bottom)
1. Navbar (60px): greeting + notification bell + avatar
2. **Balance Hero Card** — full width
   - Total net balance: large `text-display`, color-coded
   - Sub-card left: "You are owed" — green amount
   - Sub-card right: "You owe" — red amount
   - Sub-label if conversions applied: `"Converted from N currencies"` (tappable → S05)
3. Quick Actions: "+ Add Expense" primary | "Settle Up" secondary
4. **Recent Activity** section (list card)
   - Last 5 events, "View All" link → P06
5. **Balances By Friend** section (compact list)
   - Per-friend: avatar + name + net balance (color-coded) + "Settle" ghost button

#### Special Behavior
- Balance numbers: count-up animation on first load (600ms ease-out)
- Offline: cached last-known balances shown + offline banner FS03
- Mobile: FAB bottom-right for "+ Add Expense"

#### Empty State (New User / Post-Skip Onboarding)
- Hero card shows `$0.00`, neutral text
- "Getting Started" card replaces activity + friend sections:
  - ① Add a friend → [Add Friend] modal
  - ② Create a group → [Create Group] modal
  - ③ Add an expense → [Add Expense] modal
- Card disappears when user has ≥1 friend OR ≥1 group
- Card not dismissible

#### States
- **Loading:** Hero, activity, and friend sections each have independent skeleton loaders
- **Offline:** Cached data shown + FS03 banner

#### User Actions
- Tap balance hero sub-label → S05 (currency breakdown)
- Tap "+ Add Expense" → M01
- Tap "Settle Up" → M02
- Tap activity row → P15 (Expense Detail)
- Tap "View All" → P06
- Tap friend row → P05 (Friend Ledger)
- Tap "Settle" on friend → M02

---

### P02 — Groups List

#### Purpose
See all groups at a glance. Navigate to one or create a new one.

#### Layout (Top → Bottom)
1. Navbar — "Groups" title
2. "+ New Group" button — top right (primary)
3. Search input — real-time client-side filter by group name
4. Groups grid — 2 columns desktop, 1 mobile
   - Each card: cover photo | group name | type badge (color-coded) | member count | net balance pill | last activity date

#### Empty State
- Single centered card: "No groups yet. Create one to start splitting expenses." + CTA

#### Loading
- 6 skeleton cards in grid

#### User Actions
- Tap "+ New Group" → M03 (Create Group modal)
- Tap group card → P03 (Group Detail)
- Type in search → filters list in real time

---

### P03 — Group Detail

#### Purpose
Full financial picture of one group — expenses, balances, members, settings.

#### Color Usage
- Group type badge: `--color-primary-subtle` bg, `--color-primary` text
- Expense row "your share": green if paid for you, red if you owe

#### Layout (Top → Bottom)
1. **Group Header**
   - Cover photo banner (200px, gradient overlay)
   - Group name + type badge inline [Trip] [Home] [Couple] [Other]
   - Member count + last activity
   - ⚙️ Settings icon (admin/owner only) → M13
2. **Tabs:** Expenses | Balances | Members (sticky on scroll)

#### Tab: Expenses
- "+ Add Expense" button (top right) → M01
- Search magnifier icon → S04 (Group-Scoped Search)
- Filter pills: All | This Month | Settled
- Expense list rows:
  - Payer avatar + title + date | total (right) | my share (color-coded, right)
  - Tap row → P15 (Expense Detail)
  - 3-dot menu on hover/long-press (edit → M01, delete → M07) — own expenses only (or admin)
  - Recurring badge on recurring expenses

#### Tab: Balances
- "Simplify Debts" toggle at top + explainer text + ⓘ icon → S06
- Per-member balance cards: avatar + name + net amount + "Settle Up" button → M02
- Exchange rate freshness label (multi-currency groups only, amber if stale >6h)

#### Tab: Members
- Member list: avatar + name + role badge (Owner / Admin / Member)
- Ghost users: dashed avatar + "Invited — not joined yet" + "Pending" badge
- Own row: "Leave Group" option (tap → debt check → M08 if clear, or block)
- Owner's own row: "Transfer Ownership" option → M06
- Admin-only "Audit Log" link — bottom of list → P16
- "+ Invite Member" field (email) + "Send Invite" button → deep link invite (Story 31)
- Admin: remove member option (blocked if member has debt)

#### Empty States
- Expenses tab with 0 expenses: "No expenses yet in this group."
- Single-member group (Expenses tab): Add Expense button hidden, prompt card shown → "Invite Members →"
- Balances tab single-member: "Invite members to see group balances here"

#### User Actions
- Tap ⚙️ → M13
- Tap "+ Add Expense" → M01
- Tap magnifier → S04
- Tap expense row → P15
- Tap 3-dot → edit (M01) or delete (M07)
- Toggle "Simplify Debts" → recomputes balance list
- Tap ⓘ → S06
- Tap "Settle Up" → M02
- Tap "Leave Group" → M08 (or block)
- Tap "Transfer Ownership" → M06
- Tap "Audit Log" → P16 (admin only)

---

### P15 — Expense Detail

#### Purpose
Full breakdown of one expense: math, payer, splits, comments, receipt.

#### Layout (Top → Bottom)
1. Back button
2. Expense title + total amount (hero)
3. "Paid by [Name]" — with amount
4. Split breakdown table: member → owed amount (color-coded)
5. Multi-payer: "Paid" column AND "Owes" column shown separately
6. Receipt image thumbnail (full-screen on tap) — if attached
7. "Edit" / "Delete" buttons — authorized users only
8. Comments section:
   - Chronological thread: avatar + name + text + timestamp
   - Image attachments inline
   - Text input + send button (bottom)

#### States
- Deleted expense → redirect to group with toast: `"This expense was deleted"`
- Unauthorized edit attempt → blocked, error toast

#### User Actions
- Tap "Edit" → M01 (pre-filled, recurring check → M05 first if recurring)
- Tap "Delete" → M07
- Tap receipt thumbnail → full-screen image viewer
- Submit comment → appends to thread
- Attach image in comment → camera/gallery picker

---

### P04 — Friends List

#### Purpose
Manage 1-on-1 balances and direct friendships.

#### Layout (Top → Bottom)
1. Navbar — "Friends" title
2. "+ Add Friend" button (top right) → M04
3. Search input — real-time filter
4. Friends list — single column, list card
   - Each row: avatar + name + muted email | net balance (color-coded) | "Settle" ghost button → M02
   - Tap row → P05

#### Empty State
- "No friends yet. Add a friend to track who owes who." + CTA

#### User Actions
- Tap "+ Add Friend" → M04
- Type in search → filters list
- Tap friend row → P05
- Tap "Settle" → M02

---

### P05 — Friend Ledger (1-on-1)

#### Purpose
View all financial interactions with one specific friend across groups and direct.

#### Layout (Top → Bottom)
1. Back button
2. Friend's avatar + name + net balance (color-coded)
3. "+ Direct Expense" button → M01 (no group context)
4. "Settle Up" primary button → M02
5. "Remind" ghost button (debt > $0 only) — cooldown-aware
6. Full expense + settlement history list (chronological, cross-group)

#### Remind Button States
- Normal: `"Remind"` — ghost style
- Cooldown active: `"Reminded ✓"` — muted, disabled; tooltip shows days remaining
- After cooldown: resets automatically on next load

#### Empty State
- "No shared expenses yet. Add one above."

---

### P06 — Activity Feed

#### Purpose
Chronological global history of all expenses and settlements.

#### Layout (Top → Bottom)
1. Navbar — "Activity" title
2. Filter pills: All | By Group | By Friend | Date Range
3. Infinite-scroll list:
   - Each row: action icon | description | timestamp | amount (color-coded, right)
   - Deleted expense rows: muted (0.6 opacity) + strikethrough + `"[Expense deleted]"` — tapping shows inline message, no navigation
   - Settlement rows for deleted expenses: remain fully visible

#### Pagination
- Cursor-based, items load seamlessly on scroll

#### Empty State
- "No activity yet. Add your first expense."

---

### P07 — Search

#### Purpose
Find any expense, group, or friend globally.

#### Layout (Top → Bottom)
1. Search input — auto-focused, full width (300ms debounce)
2. Results by category: Expenses | Groups | Friends
3. Each result: icon + name/title + sub-context (group, amount) + navigation action

#### Zero Results State
- Search icon (muted) + `"No results for '[query]'"` + suggestion bullets (typo / try group name or email / fewer words)

#### Partial Results
- Only empty categories show `"No [X] found"` — populated categories render normally

#### Behavior
- Empty query → show recent items
- SQL injection protected via Prisma (Story 24)

---

### P08 — Notifications Center

#### Purpose
In-app notification feed with preference controls.

#### Layout (Top → Bottom)
1. Navbar — "Notifications" + "Mark all read" link (right)
2. Time-grouped rows: Today | Yesterday | This Week (sticky headers)
3. Each row: color-coded icon | title + body | timestamp (right) | unread dot (left, if unread)
   - Unread rows: slightly stronger background
   - Deleted-content rows: `"Deleted"` badge, inline sub-text on tap, no navigation
   - Group-deleted rows: `"Expired"` badge + `"This group no longer exists"`
4. Batched notification groups: collapsible header `"Rome Trip — 12 updates in the last hour"` → expands to show all rows inline

#### Notification Types + Left Accent Colors
| Type | Color |
|---|---|
| New Expense | `--color-primary` |
| Settlement Received | `--color-success` |
| Payment Reminder | `--color-warning` |
| Group Invite | `--color-primary` |
| Comment on Expense | Purple `#8B5CF6` |
| Edit Overwritten | `--color-warning` |

#### Empty State
- Bell icon (muted) + "You're all caught up" + "No new notifications"

#### User Actions
- Tap "Mark all read" → all rows marked read
- Tap valid row → deep link to relevant screen
- Tap deleted-content row → shows inline explanation, no navigation

---

### P09 — Settings

#### Purpose
Account identity, preferences, security, data, and danger zone.

#### Layout — Two-Column Desktop (Left Nav + Right Content)

**Left Navigation Pills:** Profile | Preferences | Appearance | Security | Danger Zone

**Profile Section**
- Avatar (80px, upload-enabled)
- Name field (editable)
- Email (read-only for social login + "via Google/Apple" badge)
- Default currency dropdown
- Timezone dropdown
- "Save Changes" button

**Preferences Section**
- Default split type dropdown (Equal / Percentage / Shares)
- Home currency dropdown (if separate from default)
- Language selector
- **Reminders sub-section:** Auto-remind frequency dropdown (Off / Every 3 days / Weekly / Every 2 weeks) — BullMQ job trigger; shows "Next reminders on [Date]" when active

**Appearance Section**
- "Dark Mode" toggle (ON = `--color-success` track)
- "Compact view" toggle
- Theme switches instantly `250ms ease` — no reload

**Security Section**
- "Change Password" — email users: current + new + confirm
- Social login users: "Set a Password" option + modal; "via Google/Apple" badge persists after adding
- Sessions list: device + date + "Revoke" button (current session has no button)
- Each "Revoke" → M11 (confirmation)
- "Notifications are blocked" warning if OS permission denied

**Data & Privacy Section**
- "Export My Data" → M12
- "Privacy Policy" link (Story 40)
- "Terms of Service" link (Story 40)
- App version display (e.g., v2.1.0 — Story 41)

**Danger Zone Section**
- Red bordered card
- "Delete Account" danger button → M09 (debt check) or M10 (no debt)

---

### P16 — Audit Log

#### Purpose
Admin-only read-only log of all group mutations.

#### Access
Group Detail → Members tab → "Audit Log" link (hidden from non-admins entirely)

#### Layout (Top → Bottom)
1. Back button + "Audit Log — [Group Name]" title
2. Filter bar: "All actions" dropdown | Date range picker
3. Table rows (newest first): Time | Actor | Action | Detail
4. Tap row → expands inline to show "Before" / "After" field diff

#### Empty State
- "No recorded actions yet in this group."

---

### P17 — Group Preview (Invite Landing)

#### Purpose
Landing screen for users tapping a group invite link.

#### Content
- Group name + cover photo + member count + creator name
- Single primary CTA button

#### States
- Already a member: `"You're already a member of this group"` + "Go to Group" button
- Invitation expired/revoked: full error state + message + suggestion to ask admin

---

## SECTION 3 — MODAL STRUCTURES

---

### M01 — Add / Edit Expense

#### Fields (Top → Bottom)
1. Title (required)
2. Amount (numeric, cents-accurate)
3. Date picker (defaults to today)
4. Category selector (icon chips)
5. "Paid by" — single or multi-payer
   - Multi-payer: each gets amount field; running total shown; Save disabled until sum matches
   - Multi-payer total mismatch: inline error
6. Split mode pills: Equal | Exact | % | Shares | Adjustment
7. Split preview table (live-updating; "Paid" + "Owes" columns in multi-payer)
8. Penny-rounding note (if applicable)
9. Receipt attachment — camera/gallery
10. "Recurring expense" toggle → frequency options (Weekly / Monthly / Custom)
11. Currency field — shows conversion preview if different from group default

#### Recurring Edit Intercept (M05)
- If editing a recurring expense: M05 modal appears FIRST (choice: this occurrence / all future)

#### Error States
- $0 amount: `"Amount must be greater than zero"`
- Multi-payer sum mismatch: `"Payer amounts must add up to $X"`
- Duplicate save: idempotency key prevents (Story 03)
- Offline: saves to local queue, toast `"Saved offline — will sync when connected"`
- Unauthorized edit: blocked + error toast

---

### M02 — Settle Up

#### Fields
1. Payer → Payee display (arrows + avatars)
2. Pre-filled amount (full debt, editable for partial)
3. Currency dropdown — visible only in multi-currency context
4. Optional note field
5. "Confirm Settlement" primary | Cancel ghost

#### Behavior
- Optimistic UI: balance updates instantly
- Server success: silent
- Server failure: amber flash on balance figure (400ms) + error toast (manual dismiss) + button re-enables
- User navigated away before failure: in-app notification with deep link to balance

---

### M03 — Create Group

#### Fields
1. Group name (required)
2. Group type dropdown (Trip / Home / Couple / Other)
3. Cover photo upload (optional)
4. Currency selector
5. Add members: search by name/email, inline chip tags

---

### M04 — Add Friend

#### Fields
1. Name or email (autocomplete from user DB)
2. If not found: "Send invite to [email]" option (creates ghost user)

---

### M05 — Recurring Expense Choice

#### Content
- Shows expense title + recurrence type
- Two options: "Edit this occurrence only" | "Edit this and all future occurrences"
- Cancel

---

### M06 — Transfer Ownership

#### Content
- Member list (radio selection): admins + members only (no ghost users)
- "Transfer Ownership" button — disabled until selection made
- On confirm: previous owner → Member; selected → Owner; toast to all

---

### M07 — Delete Expense Confirmation

#### Copy (exact)
- Heading: `Delete "[Expense Title]"?`
- Body: member count, cascade warning (comments + receipts deleted)
- "This action cannot be undone."
- Buttons: Cancel | "Delete Expense" (danger-red)

---

### M08 — Leave Group

#### Step 1 (Debt Check)
- If balance ≠ $0: shows exact outstanding amounts + "View Balances" + "OK"
- Owner with balance = $0 but no transfer done: `"Transfer ownership before leaving"` + "Go to Members" button

#### Step 2 (Confirmation)
- Shows group name + access loss warning
- "Leave Group" danger | Cancel

---

### M09 / M10 — Delete Account

#### M09 (Debt block — shown first)
- Lists specific debts (max 3, "+ N more")
- "View My Balances" → Dashboard | "Close"

#### M10 (No debt — confirmation)
- Type "DELETE" field
- "Delete My Account" button disabled until exact match
- Post-deletion: tokens wiped, redirect to Login with toast

---

### M11 — Session Revoke Confirmation

#### Content
- Device name + last active date
- "Sign Out Device" danger | Cancel
- Post-confirm: row removed, toast `"Device signed out"`, device silently logged out on next API call

---

### M12 — Data Export

#### Fields
- Format selector: CSV | JSON
- Date range: All time | Custom range picker

#### States
- Loading: button shows `"Preparing export..."`
- Large dataset: progress bar appears
- Done: button → `"✓ Download Ready"` (triggers file download)
- Failure: inline error + button resets
- Background job: modal dismissible, in-app notification on completion

---

### M13 — Group Settings

#### Fields (Admin/Owner only)
1. Group name
2. Group type dropdown
3. Group currency
4. Default split mode pills (Equal / Percentage / Shares)
5. "Manage per-member percentages →" → S07
6. Cover photo (current + change)
7. "Save Changes" button

---

## SECTION 4 — FEATURE → PAGE MAPPING

| Feature | Story | Page / Modal / Sheet |
|---|---|---|
| Sign Up / Login / Logout | 01 | P10, P11, P09 (logout) |
| Brute-force rate limiting | 01, 26 | P10 (FS02) |
| Forgot Password | 06 | P12, P13 |
| Google OAuth | 15 | P10, P11 |
| Apple Sign-In | 15 | P10, P11 (iOS/web) |
| Social login → add email/password | 15 | P09 (Security) |
| Account merging (same-email) | 15 | Background, toast on ghost join |
| Onboarding 3-step flow | 25 | P14 |
| Onboarding: invite link priority | 25, 31 | P10/P11 → P17 → P03 |
| Total balance display | 02 | P01 (hero card) |
| "You are owed" / "You owe" | 02 | P01 |
| Recent activity preview | 02, 07 | P01 |
| Balances by friend | 02, 09 | P01 |
| Add Expense (5 split modes) | 03, 20 | M01 |
| Multi-payer support | 20 | M01 |
| Real-time split preview | 03 | M01 |
| Duplicate click prevention | 03 | M01 (idempotency key) |
| Offline expense save | 13 | M01 → local queue |
| Recurring expense toggle | 17 | M01 |
| Edit recurring (occurrence/all) | 17 | M05 → M01 |
| Expense categories | 03 | M01 (icon chips) |
| Receipt image attachment | 28 | M01, P15 |
| Edit expense | 08 | M01 (pre-filled), P15 |
| Delete expense | 08 | M07, P15 |
| Expense detail + math | 03 | P15 |
| Comments on expense | 21 | P15 |
| Comment image attachments | 21 | P15 |
| Group creation | 04 | M03 |
| Group type (Trip/Home/etc.) | 04 | M03, P02 (card badge), P03 (header badge), M13 |
| Group cover photo | 04, 28 | M03, M13 |
| Group currency | 04, 16 | M03, M13 |
| Ghost/placeholder users | 04 | P03 (Members tab), M01 (split), M02 |
| Debt simplification toggle | 04 | P03 (Balances tab) |
| Debt simplification explainer | 04 | S06 |
| Default split per group | 22 | M13, S07, M01 (auto-selects) |
| Group settings | 22, 38 | M13 |
| Group-scoped search | 24 | S04 (in P03 Expenses tab) |
| Member roles (Owner/Admin/Member) | 38 | P03 (Members tab) |
| Transfer ownership | 38 | M06 |
| Remove member | 38 | P03 (Members tab) |
| Leave group | 04 | M08 |
| Empty group (1-member) | 04 | P03 (Expenses/Balances tabs) |
| Group invite link | 31 | P03 (Members tab) → P17 |
| Invite deep link chain (5 scenarios) | 31 | P17, P10, P11, FS01 (expired) |
| QR code for invite | 31 | P03 (Members tab) |
| Group preview before join | 31 | P17 |
| Invite + onboarding collision | 25, 31 | P10/P11 → P17 → P03 |
| Settle Up (full/partial) | 05 | M02 |
| Optimistic UI + rollback | 05 | M02, P01, P05 |
| Settlement currency choice | 16 | M02 |
| Deadlock protection | 05 | Backend (no UI change) |
| Friends list + balances | 09 | P04 |
| 1-on-1 ledger | 09 | P05 |
| Direct expense (no group) | 09 | M01 from P05 |
| Add friend | 09 | M04 |
| Ghost friend (unregistered) | 09 | M04 → ghost record |
| Remind button + cooldown | 37 | P05, P03 (Balances) |
| Auto-reminder schedule | 37 | P09 (Preferences) |
| Global activity feed | 07 | P06 |
| Feed filters | 07 | P06 |
| Soft-deleted in feed | 42 | P06 |
| Infinite scroll | 07 | P06 |
| Global search | 24 | P07 |
| Zero search results | 24 | P07 |
| Push notifications | 11 | P08, S01 (permission prompt) |
| In-app notification center | 11 | P08 |
| Notification deep links | 11 | P08 → various |
| Notification to deleted content | 11 | P08 (inline label) |
| Batched notifications | 11 | P08 (collapsible group), device push |
| Notification preferences | 39 | P08 |
| Profile edit | 10 | P09 (Profile) |
| Change password | 10 | P09 (Security) |
| Sessions list + revoke | 10, 26 | P09 (Security) + M11 |
| Delete account | 10 | M09, M10 |
| Multi-currency support | 16 | M01, M02, P01, P03 (Balances), P09 (Preferences) |
| Live currency preview | 16 | M01 |
| Exchange rate freshness | 16 | P03 (Balances tab) |
| Currency conversion breakdown | 16 | S05 |
| Dark mode / Light mode | 23 | P09 (Appearance) |
| Dark mode transition | 23 | All pages (250ms ease) |
| System theme auto-detect | 23 | App startup |
| Data export (CSV/JSON) | 19 | M12 |
| Offline sync + queue | 13 | All pages (FS03, FS04, S03) |
| Partial queue failure | 13 | FS04 banner + S03 |
| Conflict notification | 13 | P08 |
| Push permission timing | 11 | S01 (after first action) |
| Sentry error logging | 14 | Backend + global error boundary |
| Force update screen | 41 | FS01 |
| Soft update prompt | 41 | S02 |
| App version display | 41 | P09 (Data & Privacy) |
| Audit log | 35 | P16 (admin only) |
| Cookie consent (web) | 40 | W01 |
| Terms / Privacy Policy | 40 | P09 (Data & Privacy) |
| Accessibility (tap targets, labels) | 36 | All pages |
| Rate limiting UI | 01, 26 | P10 (FS02) |
| Security: CSRF/XSS/JWT | 26 | Backend |
| File upload (receipts, avatars) | 28 | M01, P09 (Profile), M03, M13 |
| Signed URLs | 28 | P15 (receipt display) |
| Soft delete + 90-day retention | 42 | P06 (feed), P03 (expenses) |
| Hard purge after retention | 42 | Backend (no UI) |

---

## SECTION 5 — USER FLOWS

---

### Flow 1 — Authentication

**New User:**
```
Launch App
  → Version check API
    → Pass: Signup screen (P11)
      → Fill form / Google / Apple
        → Success → auto-login
          → Onboarding (P14) [3 steps, skippable]
            → Dashboard (P01)
```

**Returning User:**
```
Launch App
  → Version check API
    → Pass: Auth check (JWT in HttpOnly cookie)
      → Valid JWT → Dashboard (P01)
      → Invalid/Expired JWT → Login (P10)
        → Successful login → Dashboard (P01)
```

**Via Invite Link (New User):**
```
Tap invite link
  → Web fallback page (app not installed) → App Store/Play Store
    → Install → deferred deep link fires
      → Login / Signup (P10/P11)
        → After auth → Group Preview (P17)
          → Tap "Join Group"
            → Group Detail (P03)
              → onboarding_completed = true
```

---

### Flow 2 — Add Expense

**Standard Path:**
```
P01 / P03 / P05: Tap "+ Add Expense"
  → M01 opens
    → Fill: Title, Amount, Date, Category
    → Select payer(s)
      → Single payer: continue
      → Multi-payer: enter amounts per payer
        → Running total must = expense total
    → Select split mode (default pre-selected from group settings)
    → View real-time split preview
    → Attach receipt (optional)
    → Toggle recurring (optional) → select frequency
    → Currency conversion preview shown if differs from group default
    → Tap "Save Expense"
      → Idempotency check → server call
        → Success → modal closes → expense appears in list (socket update for others)
        → Failure → inline error shown
        → Offline → saved to queue → toast: "Saved offline"
```

**Recurring Expense Edit:**
```
Tap "Edit" on recurring expense row
  → M05 appears FIRST:
    → "Edit this occurrence only" → M01 (detached, future unaffected)
    → "Edit this and all future occurrences" → M01 (updates template)
```

---

### Flow 3 — Settlement

**Standard Path:**
```
Tap "Settle Up" (P01 / P03 / P05 / P04)
  → M02 opens (pre-filled with payer, payee, full amount)
    → Optionally edit amount (partial payment)
    → Optionally change currency (multi-currency only)
    → Tap "Confirm Settlement"
      → Balance updates INSTANTLY (optimistic UI)
      → Server call in background
        → Success: silent
        → Failure within session:
          → Amount flashes amber (400ms) → reverts
          → Error toast (manual dismiss)
          → Button re-enables
        → Failure after navigation:
          → In-app notification with deep link to balance screen
```

---

### Flow 4 — Invite Link (All 5 Scenarios)

```
Scenario A (logged in, app installed):
Tap link → Group Preview (P17) → "Join Group" → Group Detail (P03)

Scenario B (logged out, app installed):
Tap link → Login (P10) → [auth] → Group Preview (P17) → "Join Group" → P03

Scenario C (not installed):
Tap link → Web fallback page (group name + download buttons)
  → Install app → deferred deep link fires → Signup (P11) → Group Preview (P17) → Join → P03

Scenario D (link expired/revoked):
Tap link → Error state (web or in-app): "This invite link has expired" + admin contact suggestion

Scenario E (already a member):
Tap link → Group Preview (P17): "You're already a member" + "Go to Group" button → P03
```

---

### Flow 5 — Offline / Sync

```
App detects network loss
  → Offline banner (FS03) appears system-wide
  → Write operations saved to local SQLite queue
    → Each queued item: action type, payload, timestamp, retry count
  → Expense confirmations show "Saved offline" toast

Network restored
  → Queue drains FIFO against API
    → All succeed: banner disappears silently
    → Partial failure (e.g., 2 of 5 fail):
      → FS04 banner appears: "N actions couldn't sync. [Review]"
        → "Review" → S03 (Sync Issues Sheet)
          → Each item: [Retry] or [Discard]
            → Retry: re-attempts single item
            → Discard: secondary confirmation → removed permanently
    → Conflict (last-write-wins):
      → Winning user: no notification
      → Losing user: in-app notification "Your edit was overwritten by [Name]"
        → Deep link to Expense Detail (P15) showing latest server state
```

---

### Flow 6 — Delete Account

```
Settings (P09) → Danger Zone → Tap "Delete Account"
  → System checks: active balance > $0?
    → YES → M09: shows specific debts + "View My Balances" CTA → blocked
    → NO → M10:
      → User types "DELETE"
      → "Delete My Account" enables
      → Tap → tokens wiped → redirect to Login (P10)
        → Toast: "Your account has been deleted"
```

---

### Flow 7 — Transfer Ownership + Leave Group

```
Group Detail (P03) → Members tab → Own row (as Owner)
  → "Transfer Ownership" → M06
    → Select new owner (radio, admins/members only)
    → "Transfer Ownership" button enables
    → Confirm → previous owner → Member → selected → Owner
    → Toast to all members
  → "Leave Group" → debt check:
    → Balance ≠ $0: M08 Step 1 (blocked)
    → Balance = $0, not owner: M08 Step 2 → confirm → Groups List (P02)
    → Is owner, no transfer: error → "Go to Members" to transfer first
```

---

## SECTION 6 — NAVIGATION STRUCTURE

### Sidebar Items
| Label | Icon | Route | Visibility |
|---|---|---|---|
| Dashboard | Grid | `/dashboard` | All |
| Groups | Users | `/groups` | All |
| Friends | UserCheck | `/friends` | All |
| Activity | Clock | `/activity` | All |
| Search | Magnifier | `/search` | All |
| Notifications | Bell (+ badge) | `/notifications` | All |
| Settings | Gear | `/settings` | All |
| Logout | Arrow-out (danger) | — | All |

### Sidebar Behavior
- Desktop: fixed left, collapsible (`240px` expanded / `64px` collapsed)
- Collapsed: icons only, tooltip on hover
- Mobile: hidden; hamburger in navbar opens overlay drawer
- Active route: `--color-primary-subtle` bg + left accent bar + `--color-primary` icon/label
- Collapse state: persisted in `SharedPreferences`/localStorage

### Back Navigation
- Sub-pages (P15, P16): Back button top-left → parent page
- Modals: close button / Cancel button / tap-outside (non-destructive only)
- FS01 (Force Update): no back, no close
- Auth screens: no sidebar, no back except explicit links

### Deep Link Routing Table
| Link Pattern | Auth State | Behavior |
|---|---|---|
| `/groups/:id/invite/:token` | Logged in | → P17 |
| `/groups/:id/invite/:token` | Logged out | → P10 → P17 |
| `/groups/:id/invite/:token` | Not installed | → Web fallback |
| `/expenses/:id` | Logged in | → P15 |
| `/settlements/:id` | Logged in | → M02 context |
| `/groups/:groupId/expenses/:expenseId` | Logged in | → P03 → P15 |

---

## SECTION 7 — SPECIAL SYSTEMS

### 7.1 Notifications System
- **Push:** FCM (Android/Web) + APNs (iOS)
- **Timing:** Permission (S01) triggered after first meaningful action — NOT on launch
- **Pre-prompt (S01):** Bottom sheet → "Enable notifications" triggers OS dialog; "Not now" → re-prompt in Settings after 7 days
- **Batching:** 50 actions → 1 push; push text summarises (actor + type + count); tapping opens P08
- **In-app center (P08):** All events individually; rapid-fire events collapsible by source group
- **Deep links:** All notification types route to the relevant screen; deleted content shows inline label
- **Denied state:** Settings Security shows instructions to re-enable via device Settings; in-app center still functional

### 7.2 Offline Queue System
- **Storage:** SQLite local DB (sqflite / Drift)
- **Queue schema:** action_type, payload, timestamp, retry_count
- **Trigger:** write operations attempted while offline
- **Drain:** FIFO on connectivity restoration
- **User indicator:** FS03 banner (offline) | FS04 banner (sync failure)
- **Failure handling (S03):** Per-item Retry / Discard with secondary confirmation on Discard
- **Conflict:** Last-write-wins; loser receives in-app notification with deep link

### 7.3 Rate Limiting UI
- **Trigger:** 10 failed login attempts within 1 minute (Story 01)
- **Effect:** Form fields disabled; button shows live countdown `"Try again in Xs"`
- **Reset:** Client-side timer; fields/button re-enable at 0s without page refresh
- **Google/Apple:** Unaffected by email login rate limit

### 7.4 Update System
- **Check:** App startup → `/api/version/check` API (Story 41)
- **Force update (FS01):** `force_update: true` → full-screen blocking page; no dismiss; "Update Now" → App Store/Play Store
- **Soft update (S02):** Minor version → dismissible bottom sheet; "What's new" from server; re-prompt: Day 3, then every launch from Day 7+
- **Version display:** P09 Data & Privacy section

### 7.5 Permission System
- **Push:** Requested via S01 at first meaningful action; re-prompting after OS denial is blocked (OS rule); settings fallback shown in P09
- **Admin UI:** Audit Log link (P16), Group Settings gear (M13), member removal, role management — all completely hidden from non-admins, never greyed out

### 7.6 Cookie Consent (Web — W01)
- **Trigger:** First web visit, before non-essential cookies set
- **Position:** Fixed bottom bar (full-width, non-blocking)
- **Options:** Accept All | Decline (essential only) | Manage (category toggles)
- **Persist:** First-party cookie, 30-day expiry; native app: not shown

---

## SECTION 8 — COLOR SYSTEM APPLICATION PER PAGE

| Page / Element | Green `#16A34A` | Red `#DC2626` | Indigo `#5B67CA` | Amber `#D97706` | Grey (neutral) |
|---|---|---|---|---|---|
| P01 Hero Balance | "You are owed" | "You owe" | Primary actions | — | Settled = $0 |
| P01 Friend rows | Net positive | Net negative | — | — | Settled |
| P03 Expense rows | Paid for you | You owe share | — | Rate stale | — |
| P03 Balances tab | Friend owes you | You owe friend | — | Rate stale | — |
| P03 Simplify toggle | ON state | — | — | — | OFF state |
| P04 Friend rows | Net positive | Net negative | — | — | Settled |
| P05 Ledger | Positive entries | Negative entries | — | — | — |
| P06 Activity rows | Received / settled | Added (you owe) | — | — | Deleted rows |
| P08 Notifications | Settlement received | — | Expense / invite | Reminder / warning | Deleted badge |
| M01 Multi-payer | Sum matches | Sum mismatch (amber) | Split mode pills | Sum mismatch | — |
| M02 Settle Up | — | — | Primary CTA | Balance rollback flash | — |
| P09 Toggles | ON track (all toggles) | Danger zone | Primary | — | OFF track |
| FS03 Offline banner | — | — | — | Amber bg | — |
| FS04 Sync failure | — | — | — | Amber bg | — |
| Badges (general) | Success/Settled | Danger/Owed | Type/Primary | Warning | Pending (ghost users) |

> **Absolute Rule:** Green and Red are reserved exclusively for financial meaning. Never used decoratively anywhere in the app.

---

## SECTION 9 — DEVELOPMENT ALIGNMENT NOTES

1. **Every modal is single-task.** No modal should contain a sub-modal. Use bottom sheets (S-series) for supplementary information.
2. **Every async block has a skeleton.** No section renders blank during a load. Skeleton matches exact dimensions of real content.
3. **Every destructive action has two steps.** Confirmation modal always shows context-specific copy (expense name, member count, etc.).
4. **Admin-only elements are absent for non-admins.** Not disabled, not greyed — simply not rendered.
5. **Optimistic updates must store the pre-update state** so rollback can occur without a server round-trip.
6. **All monetary values stored as integers (cents).** Display layer converts to decimal. `$12.50` = `1250` in DB.
7. **Idempotency keys** on all POST/PUT mutations — duplicates ignored by server.
8. **Deep links must preserve destination through auth.** After login/signup, the original deep link target is resolved.
9. **Skeleton widths vary per line** (100%, 80%, 60%) to appear natural — never all the same width.
10. **Dark mode transition** — `ThemeData` hot-swap, `250ms ease` crossfade, no page reload, modals transition too.
11. **Currency amounts:** Always `font-variant-numeric: tabular-nums`, right-aligned in all list/table contexts.
12. **Push notification permission** — Must use in-app pre-prompt (S01) before triggering OS dialog. Never on app launch.
13. **Soft-deleted items** — Excluded from all active queries. Shown in feeds as muted/labelled rows. Hard-purged after 90 days.
14. **Rate limit countdown** — Client-side timer; no server polling required; resets UI state at 0s.
15. **Force update screen** — Must intercept all navigation. No sidebar, no back, no dismiss. Implemented at router level as a redirect guard.

---

*This blueprint maps every feature to a specific location, every flow to explicit steps, and every system to a defined behavior. Nothing is ambiguous. Build directly from this document.*
