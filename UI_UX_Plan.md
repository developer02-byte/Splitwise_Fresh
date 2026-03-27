# UI/UX Feature-Aligned Plan — Resolved Edition
> All 36 identified edge cases resolved (Round 1 + Round 2).
> Version: 3.0 | March 26, 2026

---

## RESOLUTIONS INDEX

| # | Issue | Status |
|---|---|---|
| 1 | Multi-currency balance display | ✅ Resolved |
| 2 | Multi-payer sum validation | ✅ Resolved |
| 3 | Recurring expense edit modal | ✅ Resolved |
| 4 | Ghost user visual treatment | ✅ Resolved |
| 5 | Simplify Debts explainer | ✅ Resolved |
| 6 | Optimistic UI rollback UX | ✅ Resolved |
| 7 | Delete confirmation copy | ✅ Resolved |
| 8 | Invite deep link chain | ✅ Resolved |
| 9 | Export progress state | ✅ Resolved |
| 10 | Force update screen | ✅ Resolved |
| 11 | Leave Group flow | ✅ Resolved |
| 12 | Settlement currency selector | ✅ Resolved |
| 13 | Soft-deleted items in Activity Feed | ✅ Resolved |
| 14 | Zero search results state | ✅ Resolved |
| 15 | Notification to deleted content | ✅ Resolved |
| 16 | Social user adding email/password | ✅ Resolved |
| 17 | Post-skip onboarding empty dashboard | ✅ Resolved |
| 18 | Concurrent editing conflict notification | ✅ Resolved |

---

## PART A — CRITICAL FLAW RESOLUTIONS

---

### ✅ Fix #1 — Multi-Currency Balance Display (Story 16)

**Rule:** All balance figures displayed anywhere in the app are always shown in the **user's home currency** (set in Profile → Default Currency). Conversion uses the exchange rate snapshot frozen at the time of each expense entry.

**Dashboard Hero Card:**
- Total balance figure is displayed in home currency with the currency code visible: `USD 142.50`
- If conversions were applied, a sub-label appears below the hero figure: `"Converted from 2 currencies"` — tapping this opens a breakdown sheet showing each original currency and the rate used.

**Exchange Rate Freshness Indicator:**
- Shown in Group Detail → Balances tab (only if the group has multi-currency expenses)
- Format: `"Rates last updated 3 hours ago"` — in muted text, `text-micro` size, below the balance summary
- If rates are stale (> 6 hours), label shows: `"Rates may be outdated"` in warning amber

**Live Conversion Preview While Typing (Add Expense):**
- Below the amount field, if the expense currency differs from the group's default: `"≈ USD 43.20 at today's rate"`
- This text updates in real-time as the user types (300ms debounce)
- Formatted in `text-body-sm`, muted color — clearly secondary to the actual amount

---

### ✅ Fix #2 — Multi-Payer Sum Validation (Add Expense Modal)

**Problem:** When multiple payers split the cost of a single bill, their amounts must sum to the total.

**UI Behavior:**
- In the "Paid by" multi-payer section, each selected payer gets an amount input field
- A running total appears below all payer rows: `"Total paid: $95.00 of $100.00"` — in warning amber if not matching
- When the sum equals the total: `"Total paid: $100.00 ✓"` — in success green
- The "Save Expense" button is **disabled** until the sum matches exactly
- If user taps Save while mismatched: inline error above the button — `"Payer amounts must add up to the total expense amount ($100.00)"`

**Interaction with Split Modes:**
- The split (who owes what) is calculated independently from who paid. A multi-payer expense still supports all 5 split modes.
- The split preview table clearly labels "Paid" vs "Owes" as two separate columns for each member when in multi-payer mode.

---

### ✅ Fix #3 — Recurring Expense Edit Modal (Story 17)

**Trigger:** User taps "Edit" on any expense row that has a recurring badge.

**Choice Modal (appears before the edit form opens):**

```
┌────────────────────────────────────────┐
│  Edit recurring expense                │
│                                        │
│  "Monthly Rent" repeats every month.   │
│  What would you like to change?        │
│                                        │
│  [Edit this occurrence only]           │
│  [Edit this and all future occurrences]│
│  [Cancel]                              │
└────────────────────────────────────────┘
```

- "Edit this occurrence only" → opens standard edit form; saves a detached copy, future recurrences unaffected
- "Edit this and all future occurrences" → opens edit form; updates the parent recurring template; past occurrences are frozen
- This modal uses the standard modal design (16px border-radius, backdrop blur, focus-trapped)

**Delete Recurring Expense:**
Same two-option choice modal: "Delete this occurrence only" or "Delete this and all future occurrences".

---

### ✅ Fix #4 — Ghost User Visual Treatment (Story 04)

**Definition:** A ghost user is a person added to a group by name/email who has not yet created an account.

**Visual Differentiation:**
- Avatar: dashed circular border (`2px dashed --color-border`), initials in `--color-text-muted`, background `--color-surface-raised`
- Name displayed as entered (e.g., "Sarah M."), with a sub-label: `"Invited — not joined yet"` in muted text
- Role badge: `"Pending"` — neutral/grey badge variant

**In Expense Splits:**
- Ghost users appear in split previews and balance tables exactly like real users
- Their share is tracked and recorded normally — the balance is attributed to their placeholder record

**Settling Ghost User Debt:**
- The "Settle Up" option with a ghost user shows a notice: `"Sarah hasn't joined yet. You can record this payment manually once they join."`
- Settling is still allowed — the group admin can mark it as settled on behalf of the ghost user

**When Ghost User Joins:**
- Their placeholder account is merged with their real account automatically (same-email merge, Story 15)
- No balance is lost; history is fully transferred
- Toast notification to group members: `"Sarah M. joined the group"`

---

## PART B — HIGH PRIORITY RESOLUTIONS

---

### ✅ Fix #5 — Simplify Debts Explainer (Story 04)

**Location:** Group Detail → Balances tab, beside the toggle.

**Design:**
```
[Simplify group debts]  [Toggle: ON]
Minimizes the total number of payments using smart
debt calculation. Instead of everyone paying everyone,
we find the shortest path to settle all debts.
ⓘ  How does this work?
```

- The `ⓘ` icon opens a small info popover (not a full modal) that shows a simplified before/after example:
  - **Before:** A owes B $20, B owes C $20 → 2 payments
  - **After:** A owes C $20 → 1 payment
- Popover closes on tap-outside or pressing Esc
- The explainer text below the toggle is always visible (not hidden behind the icon) — the icon only opens the deeper example

---

### ✅ Fix #6 — Optimistic UI Rollback (Story 05)

**Success Path (normal):**
1. User taps "Confirm Settlement"
2. Balance updates **instantly** in the UI (optimistic)
3. Server confirms silently in background
4. No additional feedback needed — the balance is correct

**Failure Path (server error):**
1. Balance updates optimistically
2. API call fails
3. Balance **snaps back** to original value — accompanied by a subtle flash animation: the balance figure briefly highlights in amber (`--color-warning`) for 400ms, then returns to its normal color. This signals to the user that the number changed back.
4. Error toast appears (manual dismiss): `"Settlement failed — your balance was not changed. Please try again."`
5. The "Settle Up" button re-enables

**Navigation-away failure scenario:**
- If the user navigated away before failure was detected: the error is delivered as an **in-app notification** with deep link back to the relevant balance: `"Your settlement with Bob failed. Tap to review."`
- On returning to the balance screen, data is refreshed from server — no stale optimistic state persists

---

### ✅ Fix #7 — Delete Expense Confirmation Copy (Story 08)

**Confirmation modal copy (exact):**

```
┌────────────────────────────────────────────────┐
│  Delete "Dinner at Nobu"?                      │
│                                                │
│  This will permanently remove this expense    │
│  and update the balances of all 4 members.    │
│  Any comments and receipt images attached     │
│  to this expense will also be deleted.        │
│                                                │
│  This action cannot be undone.                │
│                                                │
│               [Cancel]  [Delete Expense 🗑]  │
└────────────────────────────────────────────────┘
```

- The expense title is shown in the heading so the user knows exactly what they're deleting
- Member count is dynamically filled
- "Delete Expense" button is danger-red, right-aligned
- After deletion: user is returned to the group's expense list with a toast: `"Expense deleted. Balances updated."`
- The deleted expense no longer appears in any list — immediately removed from UI (socket-driven for other connected clients)

---

### ✅ Fix #8 — Invite Deep Link Chain (Story 31)

**Scenario A — Existing user, app installed, logged in:**
- Tapping the invite link opens the app directly to a **Group Preview Screen**
- Shows: group name, cover photo, member count, creator name
- Single CTA: `"Join Group"` primary button
- On confirm → user is added, navigated directly into Group Detail

**Scenario B — Existing user, app installed, logged out:**
- Deep link opens Login screen
- After login → redirect to Group Preview Screen (link preserved through auth)

**Scenario C — New user, app NOT installed:**
- Link opens a web fallback page (hosted on the Fastify backend domain)
- Shows group preview (name, creator) + App Store / Play Store download buttons
- After installing → deep link re-fires on first launch via deferred deep link (App Links / Universal Links)

**Scenario D — Link expired or revoked:**
- Web fallback or in-app: full-page error state with icon + `"This invite link has expired or is no longer valid."` + `"Ask the group admin for a new invite link"` sub-text

**Scenario E — User already in the group:**
- Group Preview Screen shows `"You're already a member of this group"` + `"Go to Group"` button

---

### ✅ Fix #9 — Export Progress State (Story 19)

**Trigger:** Settings → Data & Privacy → "Export My Data" → modal opens:

```
┌─────────────────────────────┐
│  Export your data           │
│                             │
│  Format:  [CSV]  [JSON]    │
│                             │
│  Date range:  [All time ▾] │
│                             │
│   [Cancel]   [Start Export] │
└─────────────────────────────┘
```

**After "Start Export" is tapped:**
1. Button becomes a loading spinner: `"Preparing export..."`
2. For large datasets (streamed response, Story 19): a progress bar appears below the button showing approximate completion
3. On completion: button text changes to `"✓ Download Ready"` — tapping it triggers the file download
4. If the export fails: inline error in the modal: `"Export failed. Please try again."` and the button resets

**For very large exports (background processing):**
- Modal can be dismissed: `"We'll notify you when your export is ready"`
- In-app notification delivered when download is ready with a direct download link

---

### ✅ Fix #10 — Force Update Screen (Story 41)

**Trigger:** App startup → version check API → server returns `force_update: true`

**Design:** Full-screen blocking page (NOT a modal — cannot be dismissed by tapping outside)

```
┌──────────────────────────────────────┐
│                                      │
│         [App Icon]                   │
│                                      │
│   Update Required                    │
│                                      │
│   A new version of the app is        │
│   required to continue. Please       │
│   update to the latest version.      │
│                                      │
│   Version required: 2.1.0            │
│   Your version: 1.9.2                │
│                                      │
│        [Update Now →]                │
│                                      │
└──────────────────────────────────────┘
```

- "Update Now" button deep-links to the correct App Store / Play Store listing
- No close button, no back navigation, no sidebar — completely non-bypassable
- If soft update (not force): same design but with a `"Remind me later"` ghost button below the primary

---

## PART C — MEDIUM PRIORITY RESOLUTIONS

---

### ✅ Fix #11 — Leave Group Flow (Story 04)

**Access:** Group Detail → Members tab → tap your own entry → "Leave Group" option (not shown for others)

**Step 1 — Check for active debt:**
- If the user has outstanding balance ≠ $0 → blocked:
```
You can't leave this group while you have an
outstanding balance of $45.00 with other members.
Settle all debts first, then leave the group.
```
Button: "View Balances" (routes to Balances tab) | "OK"

**Step 2 — Confirm (if balance = $0):**
```
Leave "Rome Trip"?

You'll lose access to this group's expenses and
history. Other members will be notified.

[Cancel]  [Leave Group]
```
- After leaving: user is navigated back to Groups List with a toast: `"You left Rome Trip"`
- Group owner cannot leave — they must transfer ownership first (Story 38): error message: `"Transfer group ownership before leaving"`

---

### ✅ Fix #12 — Settlement Currency Selector (Story 16)

**Location:** Settle Up modal — new field added below the amount field (only visible if the group or friendship involves multiple currencies).

```
Amount:  [ $45.00        ]
Currency: [ USD ▾        ]
           USD — US Dollar
           EUR — Euro
           GBP — British Pound
```

- Dropdown defaults to the group's default currency
- Selecting a different currency: the amount field label updates to show the equivalent: `"≈ USD 49.30 at today's rate"`
- The agreed settlement currency is stored on the settlement record (Story 16)
- If 1-on-1 (no group context): defaults to the user's home currency, selector available

---

### ✅ Fix #13 — Soft-Deleted Items in Activity Feed (Story 42)

**Rule:** Soft-deleted expenses are excluded from all active views by default.

**In Activity Feed:**
- Deleted expense events are shown with a `[Deleted]` label replacing the expense title
- Row appearance: muted opacity (0.6), strikethrough on title, `"[Expense deleted]"` text
- Tapping the row shows an in-place message: `"This expense was deleted and is no longer available"` — no navigation occurs
- Settlement rows for a deleted expense: remain visible (the payment history is preserved)

**Retention Window (Story 42 — 90 days):**
- Deleted items visible in feed for 90 days, then permanently removed from all views after hard purge

---

### ✅ Fix #14 — Zero Search Results State (Story 24)

**Trigger:** User searches and no results match across any category.

**UI:**

```
🔍

No results for "xyzabc"

Try:
• Checking for typos
• Searching by group name or member email
• Using fewer or different keywords
```

- Icon: search icon, `--color-text-muted`, 40px
- Heading: `text-h4`, `--color-text-secondary`
- Suggestion bullets: `text-body-sm`, muted
- Partial results: if some categories have results and others don't — only empty categories show `"No [groups/friends/expenses] found"` within their collapsed section header

---

### ✅ Fix #15 — Notification to Deleted Content (Story 11)

**Scenario:** User taps a notification that references an expense or settlement that has since been deleted.

**Behavior:**
- The notification row in the Notifications Center remains visible (history is preserved)
- The notification row shows a `"Deleted"` badge (neutral grey) in place of the action type badge
- Tapping such a row does NOT navigate — instead shows an inline sub-text below the notification: `"This expense was deleted by [Name] on [Date]"`
- No error toast, no navigation — the information is displayed inline so the user is not confused

**For group invite notifications (where group was deleted):**
- Row shows: `"This group no longer exists"`
- Badge: `"Expired"`, neutral grey

---

### ✅ Fix #16 — Social Login User Adding Email/Password (Story 15)

**Location:** Settings → Security section

**For Google/Apple login users, the Security section shows:**

```
Account type:  [via Google]

Want to add email sign-in?
Set a password to also sign in with your email
address ([email]) directly.

[Set a Password]
```

- "Set a Password" opens a modal with: New Password field + Confirm Password field
- On success: toast `"Email sign-in enabled. You can now log in with your email or Google."` 
- The Security section then shows the "Change Password" option (same as email users)
- The "via Google" badge remains to indicate the original provider

---

### ✅ Fix #17 — Post-Skip Onboarding Empty Dashboard (Story 25)

**Scenario:** User skips all 3 onboarding steps → lands on Dashboard with zero data.

**Empty Dashboard Design:**
- Balance Hero Card still renders, but shows `$0.00` with neutral text (no green or red)
- Sub-figures: "You are owed $0.00" | "You owe $0.00"
- Below the Quick Actions row, a single **Getting Started card** replaces all empty sections:

```
┌────────────────────────────────────────────────────┐
│  👋  You're all set up!                            │
│                                                    │
│  Here's how to get started:                        │
│                                                    │
│  ① Add a friend    →  [Add Friend]                │
│  ② Create a group  →  [Create Group]              │
│  ③ Add an expense  →  [Add Expense]               │
│                                                    │
│  These steps can be done in any order.             │
└────────────────────────────────────────────────────┘
```

- This card disappears permanently once the user has at least 1 friend OR 1 group
- The card is not dismissible (it's helpful, not intrusive)
- Each inline button in the card triggers the corresponding modal directly

---

### ✅ Fix #18 — Concurrent Editing Conflict Notification (Story 13)

**Scenario:** Two users edit the same expense simultaneously. Last-write-wins, and the losing edit is discarded.

**For the user whose edit was overwritten:**

**In-app notification (in Notifications Center):**
```
⚠️  Your edit was overwritten

You edited "Dinner at Nobu" at the same time as
Alice. Alice's version was saved. Your changes
were not applied.

[View Current Version →]    [Dismiss]
```

- Delivered as an in-app notification within seconds of the conflict detection
- Also triggers a push notification on mobile/web
- "View Current Version" deep-links to the Expense Detail screen
- The user can then re-apply their changes manually if needed

**For the user whose edit "won" (was saved):**
- No notification — their save succeeded normally

**In the Expense Detail screen (after conflict):**
- No persistent indicator — the screen always shows the current server state
- If user had the old version cached offline: on sync, their cache is overwritten and a toast appears: `"This expense was updated by Alice. Showing the latest version."`

---

## PART D — CONSISTENCY RULES (UPDATED)

1. Green = you are owed. Red = you owe. These colors are never used decoratively.
2. All currency amounts are right-aligned with tabular numerals.
3. All amounts in the app are in the user's home currency unless viewing a multi-currency breakdown.
4. Ghost users are always visually distinct — dashed avatar, "Pending" badge, muted sub-label.
5. No blank screens — every section has a skeleton, empty state with CTA, or error state.
6. No 3-dot menus visible by default — only on hover (desktop) or long-press (mobile).
7. Modals are single-task — one purpose per modal, no nested modals.
8. Destructive actions always require explicit confirmation with context-specific copy.
9. Optimistic UI updates are always accompanied by a rollback plan if the server fails.
10. Deep links must gracefully handle all 5 scenarios: logged in, logged out, not installed, expired, already member.
11. Soft-deleted content is shown as muted/labelled in feeds — never causes navigation errors.
12. Every badge uses a semantic color — no plain grey backgrounds.
13. Spacing is always a multiple of 4px. Standard padding: 24px desktop, 16px mobile.
14. All notification taps that reference deleted content show inline explanation — no broken navigations.
15. Force update screen is fully blocking — no dismiss, no skip, no back.

---

---

## PART E — ROUND 2 RESOLUTIONS (18 NEW FIXES)

---

### ✅ Fix #19 — Transfer Ownership Flow (Story 38)

**Access:** Group Detail → Members tab → tap the group Owner's row (only visible to the Owner themselves) → "Transfer Ownership" option.

**Transfer Ownership Modal:**
```
┌───────────────────────────────────────────┐
│  Transfer group ownership                 │
│                                           │
│  Select a member to become the new owner. │
│  You will become a regular Member.        │
│                                           │
│  ○ Alice Sharma  [Admin]                 │
│  ○ Bob Tran      [Member]                │
│  ○ Sara Kim      [Member]                │
│                                           │
│  [Cancel]   [Transfer Ownership]         │
└───────────────────────────────────────────┘
```
- Only current admins and members appear (not ghost/pending users)
- "Transfer Ownership" button is disabled until a member is selected
- On confirm: previous owner's role → Member; selected member's role → Owner
- Toast to everyone: `"[Name] is now the group owner"`
- Previous owner's row in Members tab loses the Owner badge immediately

**Owner trying to leave without transferring:**
- Error modal: `"You must transfer group ownership before leaving. Tap 'Transfer Ownership' in the Members tab."`
- CTA: "Go to Members" button that routes directly to Members tab

---

### ✅ Fix #20 — Account Deletion Blocked State (Story 10)

**How the block is surfaced:**

The "Delete Account" danger button is always **visible and enabled**. Pressing it opens a 2-step flow:

**Step 1 — Check debts (before showing confirmation):**
If the user has any active debt > $0, the modal shows a block screen instead of the form:
```
┌───────────────────────────────────────────┐
│  You can't delete your account yet        │
│                                           │
│  You have outstanding balances:           │
│  • You owe Bob $45.00 (Rome Trip)         │
│  • Alice owes you $12.50 (Apartment)      │
│                                           │
│  Settle all debts before deleting your   │
│  account. Once settled, you can return   │
│  here to complete deletion.              │
│                                           │
│  [View My Balances]         [Close]      │
└───────────────────────────────────────────┘
```
- Debts are listed specifically (max 3 shown, "+ N more" if >3)
- "View My Balances" routes to Dashboard balance section

**Step 2 — Confirmation (if no debts):**
```
┌───────────────────────────────────────────┐
│  Permanently delete account?              │
│                                           │
│  This will erase all your data           │
│  including expenses, groups, and history. │
│  This cannot be undone.                  │
│                                           │
│  Type DELETE to confirm:                 │
│  [ _________________________ ]           │
│                                           │
│  [Cancel]   [Delete My Account]          │
└───────────────────────────────────────────┘
```
- "Delete My Account" button is disabled until the user types "DELETE" exactly
- After deletion: tokens wiped, redirected to Login with toast: `"Your account has been deleted"`

---

### ✅ Fix #21 — Default Split Setting Configuration UI (Story 22)

**Access:** Group Detail → top-right gear/settings icon → "Group Settings" sheet.

**Group Settings Sheet layout:**
```
Group Settings — Rome Trip

Group name:   [ Rome Trip        ]
Group type:   [ Trip ▾           ]
Currency:     [ EUR ▾            ]

── Default Split ──────────────────────
Default split for new expenses:

  [Equal] [Percentage] [Shares]

[Manage per-member percentages →]

── Cover Photo ────────────────────────
[Current photo]  [Change photo]

                    [Save Changes]
```

- Only Admins and Owner see this gear icon (Story 38)
- "Manage per-member percentages" → opens a sub-sheet where each member has a percentage input; must sum to 100% (same live-validation as multi-payer)
- Default split pre-selects the matching mode pill in every new Add Expense modal opened within this group
- Per-expense override is always available in Add Expense — the default is just a starting selection

---

### ✅ Fix #22 — Onboarding + Invite Link Collision (Story 25, 31)

**Scenario:** First-time user installs app via a group invite link.

**Resolution — Invite takes priority over Onboarding:**

1. App installs and deferred deep link fires
2. User sees Login / Signup screen (not onboarding)
3. After auth: Group Preview Screen is shown (not onboarding)
4. User joins the group → navigated to Group Detail
5. `onboarding_completed` flag is set to `true` at this point — the group join counts as completing onboarding
6. Standard getting-started prompt on Dashboard is suppressed since user is already in a group

**Scenario: Mid-onboarding invite link received:**
- If user is in the 3-step onboarding and taps an external invite link, onboarding is paused
- App routes to Group Preview → user joins → returns to Dashboard (onboarding is marked complete)
- The paused onboarding is not resumed — it's considered done

---

### ✅ Fix #23 — Rate Limit Countdown UI (Story 01, 26)

**Trigger:** 10 failed login attempts within 1 minute.

**UI Behavior:**
- Both email and password fields become disabled (greyed out, `cursor: not-allowed`)
- The "Sign In" button becomes disabled and its label is replaced with a live countdown: `"Try again in 47s"`
- Countdown ticks down every second using a client-side timer
- At `0s`: fields re-enable, button resets to "Sign In", no page refresh required
- The error message above the form reads: `"Too many failed attempts. Please wait before trying again."`
- Google/Apple sign-in buttons remain active during the lockout (they are not affected)

---

### ✅ Fix #24 — Audit Log Page (Story 35)

**Access:** Group Detail → Members tab → admin-only "Audit Log" link at the very bottom of the members list (hidden from non-admins entirely — not greyed out, just absent).

**Audit Log Screen layout:**
- Back button + title: "Audit Log — Rome Trip"
- Filter bar: "All actions" dropdown | Date range picker
- Table rows (newest first):

| Time | Actor | Action | Detail |
|---|---|---|---|
| Mar 25, 14:32 | Alice | Edited expense | "Dinner" $60→$75 |
| Mar 25, 13:10 | Bob | Deleted expense | "Coffee" $12.50 |
| Mar 25, 11:00 | You | Added member | Sara Kim |

- Tapping a row expands it inline to show the before/after snapshot (Story 35)
- Expanded view: two columns "Before" / "After" showing field-level diff
- No edit/undo capability from this screen — read-only
- Empty state: "No recorded actions yet in this group"

---

### ✅ Fix #25 — Remind Button Cooldown State (Story 37)

**Normal state (cooldown not active):**
- Button label: `"Remind"` — ghost style
- Tap → sends reminder push/email → cooldown starts

**Cooldown active (within 3-day window):**
- Button is disabled, label changes to: `"Reminded"` with a checkmark icon
- Hovering (desktop) or long-pressing (mobile) shows a tooltip: `"You reminded Bob 1 day ago. You can remind again in 2 days."`
- Button color: `--color-text-muted` (not danger red — it's not an error state, just unavailable)

**After cooldown expires:**
- Button resets to normal "Remind" state automatically on next screen load
- Cooldown is per-contact (reminding Bob doesn't affect Alice's Remind button)

---

### ✅ Fix #26 — Group-Scoped Search (Story 24)

**Access:** Group Detail → Expenses tab → magnifier icon in the tab action bar (right of "+ Add Expense" button).

**Behavior:**
- Tapping the icon expands an inline search field within the Expenses tab (does not navigate away)
- Placeholder: `"Search expenses in Rome Trip..."`
- Results filter the expense list in real-time (300ms debounce, client-side for loaded items, server-side for older paginated items)
- Matches on: expense title, payer name, amount, category
- Clearing the search (✕ button) restores the full list
- Search state is not persisted — closing and reopening the tab resets it

---

### ✅ Fix #27 — Push Notification Permission Timing (Story 11)

**Rule:** Never request push permission on first app launch — this is the #1 cause of permission denial.

**Trigger point:** After the user completes their **first meaningful action** — specifically, after they add their first expense or join/create their first group.

**In-app pre-prompt (shown before OS dialog):**
```
┌──────────────────────────────────────────┐
│  🔔  Stay in the loop                   │
│                                          │
│  Get notified when someone adds an      │
│  expense or settles up with you.        │
│                                          │
│  [Not now]    [Enable notifications]    │
└──────────────────────────────────────────┘
```
- This appears as a bottom sheet (not a modal) — less intimidating
- "Enable notifications" → triggers the OS permission dialog
- "Not now" → dismisses. App shows a soft reminder in Settings 7 days later

**If permission denied:**
- No repeated OS prompts (OS blocks this after denial)
- Settings → Notifications section shows: `"Notifications are blocked. To enable, go to your device Settings → [App Name] → Notifications."`
- An in-app notification center still works for all in-app alerts — only push is affected

---

### ✅ Fix #28 — Session Revoke Confirmation (Story 10)

**Sessions list row:**
```
iPhone 14 Pro — iOS 18        Mar 24, 2026
Current session                          [–]

MacBook Pro — Chrome          Mar 22, 2026
                                    [Revoke]
```

- Current session is labelled "Current session" — its Revoke button is **hidden** (you cannot revoke yourself)
- Other sessions show a "Revoke" ghost button (danger color on hover)

**On tapping "Revoke":**
```
┌──────────────────────────────────────┐
│  Sign out of this device?            │
│                                      │
│  MacBook Pro — Chrome                │
│  Last active: March 22, 2026        │
│                                      │
│  [Cancel]    [Sign Out Device]      │
└──────────────────────────────────────┘
```
- On confirm: that session is revoked, row disappears from list, toast: `"Device signed out"`
- The revoked device gets silently logged out on next API call (JWT becomes invalid)

---

### ✅ Fix #29 — Cookie Consent Banner for Web (Story 40)

**Trigger:** First visit to the web version — shown before any non-essential cookies are set.

**Position:** Fixed bottom bar (full width, not a modal — doesn't block content).

```
┌─────────────────────────────────────────────────────────────────────┐
│  🍪  We use cookies to improve your experience and analyze usage.  │
│  Read our Privacy Policy.                                           │
│                            [Manage]  [Decline]  [Accept All]       │
└─────────────────────────────────────────────────────────────────────┘
```

- "Accept All" → sets all cookies, banner dismissed permanently
- "Decline" → only essential cookies set (auth, session), banner dismissed
- "Manage" → expands to show category toggles: Essential (always on, disabled) | Analytics | Marketing
- Consent choice persisted in a first-party cookie (30-day expiry, re-shown after expiry)
- Banner does not appear on iOS/Android native app — web only

---

### ✅ Fix #30 — Soft Update Re-prompt Behavior (Story 41)

**Trigger:** App launch → version check → `force_update: false`, new version available.

**First time shown:** Bottom sheet (not full-screen — dismissible).
```
┌───────────────────────────────────────┐
│  Update available — v2.2.0           │
│                                      │
│  What's new:                         │
│  • Multi-currency settlement         │
│  • Improved offline sync             │
│                                      │
│  [Remind me later]   [Update Now]   │
└───────────────────────────────────────┘
```

**Re-prompt schedule after "Remind me later":**
- Day 1: not shown again that day
- Day 3: shown again on app launch
- Day 7+: shown on every launch until the user updates or a new version supersedes it

**"What's new" section:** Server-provided string from version check API response — not hardcoded.

---

### ✅ Fix #31 — Batched Notification Display (Story 11)

**Push notification (device lock screen / notification shade) — batched:**
```
[App Icon]  Rome Trip  •  5 new updates
            Alice added 3 expenses, Bob settled up
```
- The push text summarises: actor + action type + count
- Tapping the batched push → opens the **Notifications Center** (not a specific expense)
- Badge on app icon: shows total unread count (not batched — 5 separate notifications = badge shows 5)

**In the Notifications Center after a batch:**
- All individual events are shown separately in the list (50 items = 50 rows)
- A collapsible group header may optionally group rapid-fire events from the same source: `"Rome Trip — 12 updates in the last hour"` — tapping expands to show all 12 rows inline

---

### ✅ Fix #32 — Empty Group Edge Case (Story 04)

**Scenario:** Group exists but only has 1 member (the creator — no one else added yet).

**Expenses tab:**
- "+ Add Expense" button is hidden
- Full-width prompt card replaces the expense list:
```
┌──────────────────────────────────────────┐
│  Add members to start splitting          │
│                                          │
│  You need at least one other member     │
│  before you can add a shared expense.   │
│                                          │
│          [Invite Members →]             │
└──────────────────────────────────────────┘
```
- "Invite Members" routes directly to Members tab with the invite field focused

**Balances tab:**
- Shows only the creator's row with $0.00 balance
- Sub-text: "Invite members to see group balances here"

**Members tab:**
- Normal — shows the single member (creator with Owner role) + invite field

---

### ✅ Fix #33 — Partial Offline Queue Failure (Story 13)

**Scenario:** App reconnects and drains offline queue — 3 of 5 actions succeed, 2 fail.

**Visual indicator:** A persistent banner appears at the top of the screen (below Navbar):
```
⚠️  2 actions couldn't sync.  [Review]  [✕]
```
- Amber background, warning icon, dismiss (✕) button
- "Review" → opens a Sync Issues sheet

**Sync Issues Sheet:**
```
Sync Issues

These actions failed to sync and need attention:

✗  "Dinner" expense — conflict detected
   [Retry]  [Discard]

✗  Settlement with Bob — server error
   [Retry]  [Discard]
```
- Each failed item shows the action type and reason (conflict / server error / validation)
- "Retry" → re-attempts that single item
- "Discard" → removes the queued item permanently (with a secondary confirmation: "Are you sure? This action will be lost.")
- Successfully retried items disappear from the list
- Banner disappears when the list is empty

---

### ✅ Fix #34 — Dark Mode Transition Behavior (Story 23)

**Toggle behavior (in Settings):**
- Theme switches instantly on toggle — no page reload required
- Transition: all colors cross-fade at `250ms ease` as defined in Story 23
- No flash or flicker — implemented via CSS custom property swaps (Flutter `ThemeData` hot-swap)
- If a modal is open when toggled: the modal also transitions smoothly within the same animation cycle

**System auto-detect on first launch:**
- On first launch (before user visits Settings), the app reads the OS dark/light preference via `MediaQuery.platformBrightness`
- The appropriate theme is applied immediately — no white flash on startup
- If OS preference changes while app is open, the app responds in real-time only if the user has not set a manual preference
- If user has manually set Light/Dark in Settings, OS changes are ignored

---

### ✅ Fix #35 — Group Type in Group Detail Header (Story 04)

**Group Detail Header layout (updated):**
```
┌─────────────────────────────────────────────┐
│  [Cover photo — 200px tall, gradient overlay]│
│                                             │
│  Rome Trip              [Trip]  ⚙ Settings │
│  8 members  •  Last activity 2 hours ago   │
└─────────────────────────────────────────────┘
```
- Group type badge (`[Trip]`, `[Home]`, `[Couple]`, `[Other]`) appears inline next to the group name
- Badge style: `--color-primary-subtle` background, `--color-primary` text (consistent with badge rules)
- Tapping the badge does nothing — it is informational only
- Group type can be changed via Group Settings (gear icon → Group Settings sheet defined in Fix #21)

---

### ✅ Fix #36 — Auto-Reminder Configuration UI (Story 37)

**Access:** Settings → Preferences section → "Reminders" sub-section.

**Layout within Preferences:**
```
── Reminders ─────────────────────────────────

Auto-remind friends with outstanding debts
Automatically send reminders on a schedule.

Frequency:  [Off ▾]
             Off
             Every 3 days
             Weekly
             Every 2 weeks

Applies to all outstanding balances across
all groups and direct friendships.
```

- Dropdown defaults to "Off"
- Selecting a frequency activates the auto-scheduler (BullMQ job per user, Story 37)
- When active, a note appears below: `"Next reminders will be sent on Apr 2, 2026"`
- The 3-day manual cooldown (Fix #25) still applies — auto-reminders respect the same cooldown per contact
- Auto-reminders only fire for balances older than 24 hours (no reminders on same-day expenses)

---

## PART D — CONSISTENCY RULES (v3.0)

1. Green = you are owed. Red = you owe. These colors are never used decoratively.
2. All currency amounts are right-aligned with tabular numerals.
3. All amounts are in the user's home currency unless viewing a multi-currency breakdown.
4. Ghost users are always visually distinct — dashed avatar, "Pending" badge, muted sub-label.
5. No blank screens — every section has a skeleton, empty state with CTA, or error state.
6. No 3-dot menus visible by default — only on hover (desktop) or long-press (mobile).
7. Modals are single-task — one purpose per modal, no nested modals.
8. Destructive actions always require explicit confirmation with context-specific copy.
9. Optimistic UI updates always have a rollback plan and a visible flash if reverted.
10. Deep links handle all 5 scenarios: logged in, logged out, not installed, expired, already a member.
11. Soft-deleted content is muted/labelled in feeds — never causes broken navigation.
12. Every badge uses a semantic color — no plain grey backgrounds.
13. Spacing is always a multiple of 4px. Standard padding: 24px desktop, 16px mobile.
14. All notification taps to deleted content show inline explanation — no navigation errors.
15. Force update screen is fully blocking — no dismiss, no skip, no back.
16. Invite links always take priority over onboarding flow for first-time users.
17. Push notification permission is never requested on first launch — only after first meaningful action.
18. Admin-only UI elements are completely hidden from non-admins — never just greyed out.
19. Auto-reminders and manual reminders share the same per-contact cooldown.
20. Rate limiting locks the form visually with a live countdown — never a silent failure.

---

*Version 3.0 — All 36 edge cases resolved across 2 audit rounds. This document is the authoritative UI/UX specification.*

