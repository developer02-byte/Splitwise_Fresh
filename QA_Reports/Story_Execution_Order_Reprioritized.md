# 📋 SplitEase — Reprioritized Story Execution Order

> Based on QA Audit findings (2026-03-28). Stories reordered by **build dependency** and **criticality**.  
> Every story that was a critical blocker is promoted to earlier in the sequence.  
> Original story numbers preserved in brackets for traceability.

---

## 🏗️ PHASE 1 — Foundation & Infrastructure
> Must be done first. Nothing else works without these.

| New # | Original # | Story Title | Why First |
|---|---|---|---|
| **01** | S26 | Security Hardening — Real JWT Middleware | Every protected route is currently bypassed. Zero auth = zero trust. |
| **02** | S27 | Deployment Plan — Docker + Environment Setup | Dev environment must be stable before features are built. |
| **03** | S34 | Database Migration & Seeding | Schema must be correct and seeded before any route can work. |
| **04** | S29 | Email System | Required by Forgot Password (S06) and Notifications (S11). |
| **05** | S28 | File Storage & Image Infrastructure (S3/Cloudinary) | Required for avatars, receipts, attachments. |

---

## 🔐 PHASE 2 — Authentication & Onboarding
> Users must be able to sign up, log in, recover access, and complete onboarding before seeing anything.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **06** | S01 | Onboarding & Authentication (Email/Password) | Core login/signup — fix SharedPreferences → flutter_secure_storage, fix validators, fix UI. |
| **07** | S25 | Onboarding Flow (Multi-step wizard) | Runs immediately after signup. Must not trap users in loop. |
| **08** | S06 | Forgot Password & Account Recovery | Account recovery must exist before launch. |
| **09** | S15 | Social Login (Google & Apple Sign-In) | Reduces signup friction; depends on S06 + S29 email system. |
| **10** | S40 | Legal / Privacy Consent (ToS + Privacy Policy) | Consent checkbox during signup; legal routes in router. |

---

## 💰 PHASE 3 — Core Financial Features (MVP)
> The reason the app exists. Must all work end-to-end before anything else.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **11** | S02 | Dashboard & Balances | Central hub. Fix stub CTAs, fix balance data contract (÷100 bug), add real cards. |
| **12** | S03 | Add Expense — Core Flow | Fix hardcoded participants, add payer selector, group selector, idempotency key. |
| **13** | S20 | Advanced Split Types (Equal / Exact / %) | Must be built alongside S03 — the split toggle is part of the core add-expense form. |
| **14** | S04 | Groups & Ledger | Create Group flow, GroupDetailScreen, Ledger view, Simplify Debts toggle. |
| **15** | S38 | Group Permissions & Roles | Role enforcement (admin/member/owner) must be added as groups are built. |
| **16** | S31 | Group Invitations & Deep Linking | Invite share sheet + deep link router entry; depends on S04. |
| **17** | S05 | Settlements & Payments | Settle Up modal, Settle All, overpayment validation, optimistic UI. |
| **18** | S09 | Friends & Individual Ledgers | FriendDetailScreen, 1-on-1 ledger, balance fix, Settle Up per friend. |

---

## 🔄 PHASE 4 — Real-Time & Sync
> Makes the app feel live and trustworthy across devices.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **19** | S30 | Realtime Architecture (Socket.io) | Emit events from all routes; build Flutter Socket.io client. Deps: S12–S18. |
| **20** | S13 | Offline Sync & Resilience | Wire SQLiteQueueHelper, add OfflineBanner, auto-sync on reconnect, delta endpoint. |
| **21** | S42 | Soft Delete & Data Retention | user deleted_at + 30-day grace; settlement soft delete. |
| **22** | S35 | Audit Trail & Change Log | Fix auditLog guard bug; capture before/after JSONB on edits. |

---

## 🧭 PHASE 5 — Navigation & User Flows
> Secondary screens that depend on Phase 3 being complete.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **23** | S07 | Global Activity Feed & Filters | Wire /activity route; cursor pagination; date-range filters; tap → detail. |
| **24** | S08 | Edit & Delete Expense | Pre-filled edit sheet; PATCH endpoint called; optimistic list removal. |
| **25** | S10 | Profile & Settings | Fix all stub tiles; Change Password; Dark Mode toggle; timezone picker; /profile route. |
| **26** | S23 | Dark Mode / Light Mode | Theme Riverpod provider; persist preference; wire Switch. |
| **27** | S22 | Default Split Settings | Per-user default split type in settings; stored and applied to new expenses. |

---

## 🔔 PHASE 6 — Notifications
> Requires Phase 2 (email) + Phase 4 (real-time) to be complete.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **28** | S11 | Notifications System | Register FCM token; Bell icon + NotificationListScreen; dispatch on expense/settlement. |
| **29** | S39 | Notification Preferences & Controls | Per-type, per-channel preference matrix; mute groups. |
| **30** | S37 | Reminders & Nudges | Scheduled reminder job; nudge users with outstanding debts. Dep: S29 (email). |

---

## 🌍 PHASE 7 — Advanced Features
> Power-user features added after the MVP is solid.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **31** | S16 | Multi-Currency Support | CurrencyPicker; live conversion; exchange rate CRON; settlement in foreign currency. |
| **32** | S21 | Expense Comments & Attachments | ExpenseDetailScreen comments; file upload; dep: S28 (file storage). |
| **33** | S24 | Search Functionality | Global search bar; /api/search endpoint; fuzzy match. |
| **34** | S17 | Recurring Expenses | Recurring toggle; CRON auto-creation; management UI. |
| **35** | S12 | Analytics & Insights [DEFERRED v1.5] | Charts; group insights; materialized views; dep: S03 category selector. |
| **36** | S18 | Receipt Scanning / OCR | Camera integration; OCR service; auto-fill expense fields. Dep: S28. |
| **37** | S19 | Data Export (CSV/PDF) | Export button; generation endpoint; PDF library. |

---

## ⚙️ PHASE 8 — Quality, Operations & Compliance
> Non-functional but production-critical. Built in parallel or after MVP.

| New # | Original # | Story Title | Why Here |
|---|---|---|---|
| **38** | S32 | Testing Strategy | Unit, integration, widget, E2E tests across frontend & backend. |
| **39** | S33 | CI/CD Pipeline | GitHub Actions: build, test, deploy on every PR/push. |
| **40** | S14 | Observability & Monitoring | Sentry, structured logs, APM, alert rules. |
| **41** | S36 | Accessibility | Semantics widgets, screen reader testing, high-contrast mode. |
| **42** | S41 | App Versioning & Force Update | Version check on startup; force-update dialog; /api/app/version endpoint. |

---

## 📊 Summary by Phase

| Phase | Stories | Theme |
|---|---|---|
| Phase 1 | New 01–05 | Foundation & Infrastructure |
| Phase 2 | New 06–10 | Auth & Onboarding |
| Phase 3 | New 11–18 | Core Financial MVP |
| Phase 4 | New 19–22 | Real-Time & Sync |
| Phase 5 | New 23–27 | Navigation & User Flows |
| Phase 6 | New 28–30 | Notifications |
| Phase 7 | New 31–37 | Advanced Features |
| Phase 8 | New 38–42 | Quality & Operations |

---

## 🔗 Critical Dependency Chain

```
S26 (JWT Auth)
  └─► S01 (Login/Signup)
        └─► S25 (Onboarding)
        └─► S06 (Forgot Password)  ◄── S29 (Email System)
        └─► S15 (Social Login)
              └─► S02 (Dashboard)
                    └─► S03 (Add Expense) + S20 (Split Types)
                          └─► S04 (Groups) + S38 (Roles)
                                └─► S31 (Invites)
                                └─► S17 (Settlements)
                                └─► S09 (Friends)
                                      └─► S30 (Realtime)
                                            └─► S13 (Offline Sync)
                                                  └─► S11 (Notifications) ◄── S28 (File Storage)
```

---

> **Note:** Original story content and spec are unchanged — only the execution order and numbering are updated here. Rename physical files accordingly when implementing.
