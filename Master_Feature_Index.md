# Master Feature Index & Reevaluation Checklist

This document serves as the high-level index for every scenario, workflow, and button currently architected for the application. Use this file to reevaluate the scope, approve features, or propose changes before we write any code.

---

## 1. Authentication & Onboarding
* **Location:** `Stories/Story_01_Onboarding_and_Authentication.md`
* **Features Included:**
  - [ ] **Sign Up Flow** (Name, Email, Password, JWT generation)
  - [ ] **Login Flow** (Authentication, secure session creation)
  - [ ] **Security Measures** (Brute-force/bot prevention, Regex email masking)

## 2. Dashboard & Balances
* **Location:** `Stories/Story_02_Dashboard_and_Balances.md`
* **Features Included:**
  - [ ] **Hero Balance Display** (Total Balance, You Owe, You are Owed)
  - [ ] **Instant Data Loading** (Skeleton loaders, optimistic rendering <200ms)
  - [ ] **Empty State UI** (Friendly onboarding illustration when no debts exist)

## 3. Core Add Expense Flow
* **Location:** `Stories/Story_03_Add_Expense_Core_Flow.md`
* **Features Included:**
  - [ ] **Add Expense Modal** (Amount, Description, Select Payer)
  - [ ] **Split Math Engine** (Equal Split, Exact Amounts, Percentages)
  - [ ] **Fractional Penny Defense** (Preventing 0.01 cent drift in database ledgers)
  - [ ] **Offline Save Protection** (Preserving data locally if user drops service in an elevator)

## 4. Groups & Internal Ledgers
* **Location:** `Stories/Story_04_Groups_and_Ledger.md`
* **Features Included:**
  - [ ] **Group Creation** (Naming trips/apartments, adding members)
  - [ ] **Ghost Users** (Adding friends by name/email who haven't installed the app yet)
  - [ ] **Debt Simplifier Algorithm** (Reducing circular debts: A owes B $10, B owes C $10 -> A owes C $10)
  - [ ] **Leave Group Flow** (Member leaves group, balances settled or transferred)
  - [ ] **Delete Group Flow** (Admin deletes group, cascade handling)
  - [ ] **Debt Simplification Toggle** (Per-group setting to enable/disable debt simplification)

## 5. Settlements & Payments
* **Location:** `Stories/Story_05_Settlements_and_Payments.md`
* **Features Included:**
  - [ ] **Settle Up Invocation** (Selecting a friend to log a payback)
  - [ ] **Partial Payments** (Paying $45 toward a $100 debt accurately)
  - [ ] **Deadlock Protection** (Preventing database crashes if two friends click "Settle Up" at the exact same millisecond)
  - [ ] **Settle All with One Person** (Settle all balances across multiple groups with a single person in one action)

## 6. Password Recovery
* **Location:** `Stories/Story_06_Forgot_Password_and_Recovery.md`
* **Features Included:**
  - [ ] **Request Reset Link** (Email anti-scraping protections)
  - [ ] **Set New Password** (Token validation, password strength requirements)

## 7. Global Activity Feed
* **Location:** `Stories/Story_07_Global_Activity_Feed_and_Filters.md`
* **Features Included:**
  - [ ] **Unified Feed** (Infinite scrolling of historical expenses + settlements)
  - [ ] **Filters** (Slice feed by "Date", specific "Groups", or "Friends")
  - [ ] **Deep Linking** (Tapping an item to view exact math breakdowns)

## 8. Edit & Delete Administration
* **Location:** `Stories/Story_08_Edit_and_Delete_Expense.md`
* **Features Included:**
  - [ ] **Edit Expense Form** (Validating authorization, recalculating live balances on typo fixes)
  - [ ] **Delete Cascade** (Hard-deleting an expense and instantly removing it from everyone's balances via database transactions)

## 9. Friends & Direct 1-on-1 Ledgers
* **Location:** `Stories/Story_09_Friends_and_Individual_Ledgers.md`
* **Features Included:**
  - [ ] **Direct Balances** (Viewing what you owe Bob, ignoring group context)
  - [ ] **Add Friend** (Outside a group, just a direct relationship)
  - [ ] **1-on-1 Ledger History** (Feed specifically filtered for interactions involving just You and Bob)

## 10. User Profile & Settings
* **Location:** `Stories/Story_10_Profile_and_Settings.md`
* **Features Included:**
  - [ ] **Edit Identity** (Update Name, Avatar, Default Currency)
  - [ ] **Account Logout** (Secure frontend token wiping)
  - [ ] **Delete Account** (Strict destructive UI validation, backend checks preventing deletion if active debt exists)
  - [ ] **Timezone Setting** (User-configurable timezone for accurate date display)

## 11. Notifications System
* **Location:** `Stories/Story_11_Notifications_System.md`
* **Features Included:**
  - [ ] **Real-Time Push Alerts** (FCM/APNS integration for new expenses/settlements)
  - [ ] **In-App Notification Center** (Chronological feed of missed alerts)
  - [ ] **Action Deep-Linking** (Tapping alert routes directly to expense details)
  - [ ] **Notification Preferences** (Granular per-type toggles for push, email, in-app)
  - [ ] **Email Notification Digests** (Daily/weekly summary emails of activity)

## 12. Analytics & Insights [DEFERRED v1.5]
* **Location:** `Stories/Story_12_Analytics_and_Insights.md`
* **Features Included:**
  - [ ] **Group Spending Breakdown** (Donut chart splitting expenses into Categories like Food/Travel)
  - [ ] **Personal Debt Trajectory** (Time-range graphs showing spending habits)
  - [ ] **Expense Categorization** (Forcing structured tags on new expenses)

## 13. Offline Sync & Resilience
* **Location:** `Stories/Story_13_Offline_Sync_and_Resilience.md`
* **Features Included:**
  - [ ] **Auto-Retry Queue** (Storing actions locally when LTE drops, firing them upon reconnection)
  - [ ] **Multi-Device Conflict Resolution** (Gracefully handling two tabs editing the same debt)
  - [ ] **Idempotent Data Integrity** (Preventing 409 errors on bad-network retries)

## 14. Observability & Monitoring
* **Location:** `Stories/Story_14_Observability_and_Monitoring.md`
* **Features Included:**
  - [ ] **Frontend Error Auditing** (Sentry capturing crashes and PII-redacted context)
  - [ ] **Backend Latency APM** (Logging endpoint duration to catch DB deadlocks)
  - [ ] **Graceful Error Boundaries** (UI fallbacks preventing the App from "White Screening")

## 15. Social Login (Google & Apple)
* **Location:** `Stories/Story_15_Social_Login.md`
* **Features Included:**
  - [ ] **Google OAuth Flow** (id_token verification, upsert user record)
  - [ ] **Apple Sign-In** (iOS only, relay email handling)
  - [ ] **Account Merging** (same email via different providers linked, not duplicated)

## 16. Multi-Currency Support
* **Location:** `Stories/Story_16_Multi_Currency_Support.md`
* **Features Included:**
  - [ ] **Home Currency Setting** (per user, all balances converted to it)
  - [ ] **Live Conversion Preview** (shows approximate equivalent as you type in foreign currency)
  - [ ] **Exchange Rate Snapshot** (rate frozen at time of expense entry, not settlement)
  - [ ] **Group Default Currency** (Per-group currency setting applied to new expenses)
  - [ ] **Settlement Currency Choice** (Choose which currency to settle in)

## 17. Recurring Expenses
* **Location:** `Stories/Story_17_Recurring_Expenses.md`
* **Features Included:**
  - [ ] **Recurrence Toggle** on Add Expense (Weekly / Monthly / Custom)
  - [ ] **Backend CRON Auto-Generation** (auto-creates ledger entry at midnight on schedule)
  - [ ] **Edit One vs Edit All** occurrences independently

## 18. Receipt Scanning (OCR) [DEFERRED v1.5]
* **Location:** `Stories/Story_18_Receipt_Scanning_OCR.md`
* **Features Included:**
  - [ ] **Camera Capture** -> auto-fill Amount field via Google ML Kit OCR
  - [ ] **Confidence Scoring** (falls back gracefully if scan is unclear)
  - [ ] **Receipt Attachment** (image stored permanently on the expense record)

## 19. Data Export (CSV / JSON)
* **Location:** `Stories/Story_19_Data_Export.md`
* **Features Included:**
  - [ ] **CSV Export** (date range, group scope, opens in Excel/Sheets cleanly)
  - [ ] **JSON Export** (GDPR-compliant full data dump)

## 20. Advanced Split Types
* **Location:** `Stories/Story_20_Advanced_Split_Types.md`
* **Features Included:**
  - [ ] **Split by Shares** (Bob drank 3 beers, Alice 1 -> weighted split)
  - [ ] **Split by Adjustment** (equal + manual delta per person)
  - [ ] **Multiple Payers** (Alice paid $60, Bob paid $40 on same bill)

## 21. Expense Comments & Attachments
* **Location:** `Stories/Story_21_Expense_Comments_and_Attachments.md`
* **Features Included:**
  - [ ] **Comment Thread** on every expense (full chronological chat)
  - [ ] **Receipt Image Attachment** via comment
  - [ ] **Push Notification on new comment** to all group members on that expense

## 22. Default Split Settings per Group
* **Location:** `Stories/Story_22_Default_Split_Settings.md`
* **Features Included:**
  - [ ] **Pre-configure split** (e.g. 60/40 rent) once per group
  - [ ] **Auto-applies** to every new expense in that group (overridable per-expense)

## 23. Dark Mode / Light Mode
* **Location:** `Stories/Story_23_Dark_Mode_Light_Mode.md`
* **Features Included:**
  - [ ] **System auto-detect** (matches OS dark/light preference on launch)
  - [ ] **Manual toggle** persisted in localStorage / SharedPreferences

## 24. Search Functionality
* **Location:** `Stories/Story_24_Search_Functionality.md`
* **Features Included:**
  - [ ] **Global search** across expenses, groups, and friends
  - [ ] **Context-scoped search** within a specific group
  - [ ] **SQL injection protection** via prepared statements

## 25. Onboarding Flow (First-Time UX)
* **Location:** `Stories/Story_25_Onboarding_Flow.md`
* **Features Included:**
  - [ ] **3-step guided slides** (Add Friend -> Create Group -> Add Expense)
  - [ ] **Skip button** at every step
  - [ ] **One-time only** -- never shown again after completion or skip

## 26. Security Hardening
* **Location:** `Stories/Story_26_Security_Hardening.md`
* **Features Included:**
  - [ ] **SQL Injection** prevention (PDO prepared statements only)
  - [ ] **XSS** prevention (output escaping + CSP headers)
  - [ ] **CSRF** token validation on all mutating requests
  - [ ] **JWT** in HttpOnly cookies (never localStorage)
  - [ ] **File upload MIME validation** (receipts only)

## 27. Deployment Plan
* **Location:** `Stories/Story_27_Deployment_Plan.md`
* **Features Included:**
  - [ ] **Step-by-step server setup** and `.env` configuration
  - [ ] **Migration strategy** (additive-only SQL files, tracked in migrations log)
  - [ ] **Rollback plan** (database backups before every deploy)
  - [ ] **Smoke test checklist** post-deployment

## 28. File Storage & Image Infrastructure
* **Location:** `Stories/Story_28_File_Storage_and_Image_Infrastructure.md`
* **Features Included:**
  - [ ] **Cloud Storage Strategy** (S3-compatible or local with CDN)
  - [ ] **Image Compression Pipeline** (WebP conversion for optimized delivery)
  - [ ] **Avatar Uploads** (User profile picture upload and crop)
  - [ ] **Receipt Images** (Attach receipt photos to expenses)
  - [ ] **Group Cover Photos** (Custom group header images)
  - [ ] **Signed URL Access** (Private file access via time-limited signed URLs)

## 29. Email System
* **Location:** `Stories/Story_29_Email_System.md`
* **Features Included:**
  - [ ] **Transactional Email Provider** (Resend/SendGrid/SMTP integration)
  - [ ] **Password Reset Emails** (Secure token-based reset flow)
  - [ ] **Invitation Emails** (Group and friend invite delivery)
  - [ ] **Notification Email Digests** (Daily/weekly activity summaries)
  - [ ] **Email Templates and Branding** (Consistent branded email design)

## 30. Real-time Architecture (WebSocket/Socket.io)
* **Location:** `Stories/Story_30_Realtime_Architecture.md`
* **Features Included:**
  - [ ] **Socket.io Connection Management** (Authentication and lifecycle handling)
  - [ ] **Room Strategy** (Per-group and per-user rooms for targeted broadcasts)
  - [ ] **Live Balance Updates** (Real-time balance refresh when expenses are added/edited)
  - [ ] **Expense Notifications** (Instant push when someone adds an expense in your group)
  - [ ] **Reconnection and Fallback** (Auto-reconnect with fallback to HTTP polling)

## 31. Group Invitations & Deep Linking
* **Location:** `Stories/Story_31_Group_Invitations_and_Deep_Linking.md`
* **Features Included:**
  - [ ] **Invite Link Generation** (Unique token-based shareable links)
  - [ ] **Deep Link Handling** (Universal links for iOS + App Links for Android)
  - [ ] **Invite Flow** (Tap link -> app opens -> one-tap signup -> land in group)
  - [ ] **QR Code Generation** (For in-person group invites)
  - [ ] **Invitation Expiry and Management** (Time-limited invites, revocation)

## 32. Testing Strategy (Full TDD)
* **Location:** `Stories/Story_32_Testing_Strategy.md`
* **Features Included:**
  - [ ] **Unit Tests** (Split math, currency conversion, debt simplification)
  - [ ] **Integration Tests** (API endpoints, database operations)
  - [ ] **Widget Tests** (Flutter component rendering and interaction)
  - [ ] **E2E Tests** (Full user flows across frontend and backend)
  - [ ] **Test Database Strategy** (Fixtures, factories, isolated test DB)

## 33. CI/CD Pipeline
* **Location:** `Stories/Story_33_CICD_Pipeline.md`
* **Features Included:**
  - [ ] **Self-hosted Runner** (Local development -> Hetzner production)
  - [ ] **Auto-test on Push** (Run full test suite on every push)
  - [ ] **Flutter Build Pipeline** (Web, iOS, Android builds)
  - [ ] **Deployment Automation** (Automated deploy to Hetzner)
  - [ ] **Environment Management** (Dev, staging, prod configuration)

## 34. Database Migration & Seeding
* **Location:** `Stories/Story_34_Database_Migration_and_Seeding.md`
* **Features Included:**
  - [ ] **Prisma Migration Strategy** (Versioned schema migrations)
  - [ ] **Seed Data for Development** (Realistic test data generation)
  - [ ] **Rollback Procedures** (Safe migration reversal)
  - [ ] **Migration Testing in CI** (Validate migrations before deploy)

## 35. Audit Trail & Change Log
* **Location:** `Stories/Story_35_Audit_Trail_and_Change_Log.md`
* **Features Included:**
  - [ ] **Financial Operation Logging** (WHO changed WHAT and WHEN for all money operations)
  - [ ] **Expense Edit History** (Before/after snapshots on every edit)
  - [ ] **Settlement Modifications Tracked** (Full history of settlement changes)
  - [ ] **Admin-viewable Audit Log** (Per-group audit log for group admins)

## 36. Accessibility (a11y)
* **Location:** `Stories/Story_36_Accessibility.md`
* **Features Included:**
  - [ ] **Screen Reader Support** (Semantic labels on all interactive elements)
  - [ ] **Minimum Tap Targets** (44x44px minimum for all tappable areas)
  - [ ] **Color Contrast Compliance** (WCAG 4.5:1 ratio minimum)
  - [ ] **Keyboard Navigation** (Full keyboard support for web)
  - [ ] **Dynamic Text Scaling** (Support system font size preferences)

## 37. Reminders & Nudges
* **Location:** `Stories/Story_37_Reminders_and_Nudges.md`
* **Features Included:**
  - [ ] **Remind Friend to Pay** (One-tap "Remind" button on outstanding debts)
  - [ ] **Configurable Reminder Frequency** (User controls to prevent spam)
  - [ ] **Push + Email Reminder Delivery** (Multi-channel reminder sending)
  - [ ] **Auto-reminder Option** (Weekly automatic reminders for outstanding debts)
  - [ ] **Reminder Cooldown** (Max 1 reminder per 3 days per person)

## 38. Group Permissions & Roles
* **Location:** `Stories/Story_38_Group_Permissions_and_Roles.md`
* **Features Included:**
  - [ ] **Group Creator = Admin** (Automatic admin assignment on group creation)
  - [ ] **Admin Capabilities** (Remove members, delete group, edit group settings)
  - [ ] **Member Capabilities** (Add expenses, settle up, comment)
  - [ ] **Transfer Admin Role** (Hand off admin to another member)
  - [ ] **Expense Deletion Protection** (Non-admins cannot delete others' expenses)

## 40. Legal / Privacy / Consent
* **Location:** `Stories/Story_40_Legal_Privacy_Consent.md`
* **Features Included:**
  - [ ] **Privacy Policy Screen** (Required for App Store and Play Store submission)
  - [ ] **Terms of Service Acceptance** (Mandatory agreement on signup)
  - [ ] **Data Collection Consent** (Transparent data usage disclosure)
  - [ ] **Cookie/Tracking Consent** (Web-specific consent banner)
  - [ ] **GDPR Right to Deletion** (Ties to Story 10 delete account flow)

## 41. App Versioning & Force Update
* **Location:** `Stories/Story_41_App_Versioning_and_Force_Update.md`
* **Features Included:**
  - [ ] **Version Check on Startup** (App queries server for latest version info)
  - [ ] **Soft Update Prompt** (New version available, user can skip)
  - [ ] **Force Update for Breaking Changes** (Blocks app until updated for breaking API changes)
  - [ ] **Minimum Supported Version Endpoint** (Server-side version policy API)

## 42. Soft Delete & Data Retention
* **Location:** `Stories/Story_42_Soft_Delete_and_Data_Retention.md`
* **Features Included:**
  - [ ] **Soft Delete** (deleted_at timestamp for expenses, settlements, groups)
  - [ ] **Hidden from UI** (Deleted items retained in DB but not shown)
  - [ ] **Data Retention Policy** (Keep deleted data for 90 days)
  - [ ] **Hard Purge CRON** (Automated permanent deletion after retention period)
  - [ ] **Restore Capability** (Recover accidentally deleted items within retention window)

---

## Deferred Stories (v1.5)

The following stories are planned but deferred to version 1.5:

- **Story 12: Analytics & Insights** -- Group spending breakdowns, debt trajectory graphs, expense categorization
- **Story 18: Receipt Scanning (OCR)** -- Camera capture, ML Kit OCR, confidence scoring
- **Story 43: Contact Sync / Friend Discovery** [DEFERRED v1.5] -- Find friends from phone contacts, suggest connections
- **Story 44: Home Screen Widget** [DEFERRED v1.5] -- Native iOS/Android widget showing balances at a glance
- **Story 45: Expense Categories Management** [DEFERRED v1.5] -- Custom category creation, default categories, category-based filtering

---

**Review Instructions:**
1. This index now covers **42 complete Stories** (plus 3 deferred v1.5 stories) with zero known gaps.
2. Any new feature request will generate a new Story appended here.
3. Check off items `[ ]` as they are implemented to track progress.
4. Stories marked **[DEFERRED v1.5]** are excluded from the v1.0 build scope.
