# Playwright E2E Testing Plan — SplitEase

## Prompt (Copy-paste this into a new Claude Code session)

```
I need you to set up and run comprehensive Playwright E2E tests for my SplitEase project.
The testing order is designed to surface bugs fast — visual/silent issues first, then functional tests.

## Context
- Project root: d:\Projects\Splitwise
- App is a Splitwise clone: Flutter Web frontend + Node.js Fastify backend + PostgreSQL + Redis
- All services run via Docker Compose
- Read the README.md first for full architecture, endpoints, and test accounts

## What I need

### 1. Setup (in a separate `e2e/` folder at project root)
- Initialize a new Playwright project in `e2e/` (NOT inside frontend/ or backend/)
- Use TypeScript
- Configure baseURL: http://localhost:8080
- Install browsers (chromium is enough)
- Install `@axe-core/playwright` for accessibility
- Create a shared auth helper that can log in and return tokens
- Create test fixtures for authenticated vs unauthenticated contexts
- Create a monitors helper (console errors, network failures, JS exceptions)

### 2. Test every layer — step by step, fix issues as you find them

Run each test file after writing it. If a test fails because of a real bug in the app (not a test bug), FIX the app code, rebuild the Docker container, and re-run. Document every fix.

---

#### Phase 1: Infrastructure Health
Verify the foundation before testing anything else.

- All 4 Docker containers are running and healthy
- PostgreSQL accepts connections
- Redis accepts connections
- API responds on :3000
- NGINX proxies correctly on :8080
- Frontend loads (HTTP 200, has Flutter content)

---

#### Phase 2: Visual Verification & Screenshots
See the app before testing logic. Find rendering bugs, blank screens, broken layouts immediately.

**Screenshot capture:**
- Take a full-page screenshot of every distinct route/state
- Save all screenshots to `e2e/screenshots/` with descriptive names
- After capturing, READ each screenshot image file and visually verify:
  - Does the page render correctly? (no blank screens, no missing content)
  - Are all expected UI elements present? (buttons, forms, labels, nav)
  - Is the layout correct? (no overlapping, no cutoff, no broken styling)
  - Does it look like a real production app? (not a broken/half-rendered page)
- If anything looks wrong, report what's broken with the screenshot path

**Pages to screenshot and verify:**
1. `/login` — Login form (default state)
2. `/login` — Signup mode (toggled)
3. `/login` — Form validation errors shown
4. `/login` — Loading state during submission
5. `/onboarding` — Page 1 (Add your friends)
6. `/onboarding` — Page 2 (Create a group)
7. `/onboarding` — Page 3 (Settle up seamlessly)
8. `/dashboard` — Main dashboard (authenticated)
9. `/groups` — Groups list page
10. `/friends` — Friends list page
11. `/activity` — Activity feed page

**Responsive checks (screenshot at each breakpoint):**
- Desktop: 1920x1080
- Tablet: 768x1024
- Mobile: 375x812

That's 11 pages x 3 viewports = 33 screenshots. Read and verify every one.

---

#### Phase 3: Console & Network Error Monitoring
Catch silent errors that users won't see but break the app.

For every page in the app, navigate to it and capture:

**Console error collector:**
```typescript
// Attach to EVERY page
const consoleErrors: string[] = [];
const jsExceptions: string[] = [];

page.on('console', msg => {
  if (msg.type() === 'error') consoleErrors.push(msg.text());
});
page.on('pageerror', error => {
  jsExceptions.push(error.message);
});
```

**Network failure collector:**
```typescript
const failedRequests: { url: string; status: number; method: string }[] = [];

page.on('response', response => {
  if (response.status() >= 400) {
    failedRequests.push({
      url: response.url(),
      status: response.status(),
      method: response.request().method(),
    });
  }
});

page.on('requestfailed', request => {
  failedRequests.push({
    url: request.url(),
    status: 0,
    method: request.method(),
  });
});
```

**What to check on each page:**
- Assert `consoleErrors` is empty (or only contains expected warnings)
- Assert `jsExceptions` is empty — any uncaught JS exception is a bug
- Assert `failedRequests` has no unexpected 4xx/5xx responses
- If any API call returns 500, investigate the backend error
- If any request fails entirely (status 0), check CORS/proxy config

**Network performance checks:**
- No API call should take longer than 5 seconds
- No page should have more than 50 network requests on initial load
- All API responses should have correct Content-Type headers

**Create a helper for this — use in ALL remaining UI tests:**
```typescript
// helpers/monitors.ts
export function attachMonitors(page: Page) {
  // Returns { getConsoleErrors, getJsExceptions, getFailedRequests, assertClean }
  // assertClean() throws if any errors were captured
}
```

---

#### Phase 4: Accessibility (a11y)
Find structural issues before testing behavior.

- Install `@axe-core/playwright`
- Run axe-core accessibility scan on each page
- Check: color contrast, missing alt text, missing ARIA labels, keyboard navigation
- Report violations grouped by severity (critical, serious, moderate, minor)
- Fix critical and serious violations in the app code

---

#### Phase 5: Auth API (direct HTTP, no browser)
Now test the core security layer that everything else depends on.

- POST /api/auth/signup — creates user, returns JWT
- POST /api/auth/signup — duplicate email returns 400
- POST /api/auth/signup — missing fields returns 400
- POST /api/auth/login — correct credentials return JWT + cookies
- POST /api/auth/login — wrong password returns 401
- POST /api/auth/login — nonexistent email returns 401
- GET /api/user/me — valid JWT returns user with onboardingCompleted
- GET /api/user/me — no token returns 401
- GET /api/user/me — forged "user_ID_1" token returns 401
- GET /api/user/me — expired JWT returns 401
- POST /api/auth/refresh — rotates tokens (new access + refresh)
- POST /api/auth/logout — clears cookies + deletes session
- Rate limiting — 6th login attempt within 1 minute returns 429

---

#### Phase 6: UI User Journeys
Test the real flows users take, with monitors attached.

- Login page loads with form fields
- Signup flow: fill form → submit → redirects to /onboarding
- Onboarding: 3 pages → "Get Started" → redirects to /dashboard
- Login flow: fill form → submit → redirects to /dashboard (existing user)
- Auth guard: visiting /dashboard without login redirects to /login
- Logout: clears session, redirects to /login
- Dashboard loads and shows user data
- Navigation: bottom nav bar switches between dashboard/groups/friends/activity

IMPORTANT: Attach the monitors helper to every test. Assert `assertClean()` at the end of each test.

---

#### Phase 7: User API
- GET /api/user/me — returns full profile
- PUT /api/user/me — updates name
- PUT /api/user/me — updates defaultCurrency
- PUT /api/user/me — updates onboardingCompleted
- GET /api/user/balances — returns balance structure
- GET /api/user/profile — alternate profile endpoint
- PATCH /api/user/profile — alternate update endpoint

---

#### Phase 8: Group API
- POST /api/groups — create a group
- GET /api/groups — list groups
- GET /api/groups/:id — get group detail
- PUT /api/groups/:id — update group
- DELETE /api/groups/:id — delete group

---

#### Phase 9: Expense API
- POST /api/expenses — create expense with splits
- GET /api/expenses — list expenses
- GET /api/expenses/:id — get expense detail
- PUT /api/expenses/:id — update expense
- DELETE /api/expenses/:id — delete expense

---

#### Phase 10: Friends API
- POST /api/user/friends — add friend
- GET /api/user/friends — list friends
- DELETE /api/user/friends/:id — remove friend

---

#### Phase 11: Settlements API
- POST /api/settlements — create settlement
- GET /api/settlements — list settlements

---

#### Phase 12: Invites API
- POST /api/invites — create group invite
- GET /api/invites — list invites
- POST /api/invites/:id/accept — accept invite

---

#### Phase 13: Activity & Currency APIs
- GET /api/user/activities — list activities
- GET /api/currencies/rates — returns exchange rates

---

#### Phase 14: Performance Baseline
After everything works, measure how fast.

- Measure page load times for each route (navigationStart to load event)
- Measure Time to First Contentful Paint (FCP) on /login and /dashboard
- Assert no page takes >5s to fully load
- Assert no individual API call takes >2s
- Log total transfer size per page

---

#### Phase 15: Cross-cutting
Edge cases and integration points.

- CORS: API rejects requests from disallowed origins
- WebSocket: Socket.io connects and authenticates via cookie

---

### 3. Test organization
```
e2e/
├── playwright.config.ts
├── package.json
├── tsconfig.json
├── helpers/
│   ├── auth.ts          # Login helper, token management
│   ├── api.ts           # API request helpers
│   ├── fixtures.ts      # Test fixtures (authenticated context)
│   └── monitors.ts      # Console/network error collectors
├── screenshots/          # Auto-captured by Phase 2
│   ├── login-default-desktop.png
│   ├── login-default-tablet.png
│   ├── login-default-mobile.png
│   ├── login-signup-desktop.png
│   ├── onboarding-page1-desktop.png
│   ├── dashboard-desktop.png
│   ├── dashboard-tablet.png
│   ├── dashboard-mobile.png
│   └── ...
├── tests/
│   ├── 01-infrastructure.spec.ts
│   ├── 02-visual-screenshots.spec.ts
│   ├── 03-console-network-errors.spec.ts
│   ├── 04-accessibility.spec.ts
│   ├── 05-auth-api.spec.ts
│   ├── 06-ui-auth.spec.ts
│   ├── 06-ui-onboarding.spec.ts
│   ├── 06-ui-dashboard.spec.ts
│   ├── 06-ui-navigation.spec.ts
│   ├── 07-user-api.spec.ts
│   ├── 08-groups-api.spec.ts
│   ├── 09-expenses-api.spec.ts
│   ├── 10-friends-api.spec.ts
│   ├── 11-settlements-api.spec.ts
│   ├── 12-invites-api.spec.ts
│   ├── 13-activity-currency-api.spec.ts
│   ├── 14-performance.spec.ts
│   └── 15-cross-cutting.spec.ts
└── test-results/         # Playwright auto-generated on failure
```

### 4. Workflow for each test file
1. Write the test file
2. Run it: `npx playwright test tests/<file>.spec.ts`
3. If test fails due to APP BUG:
   - Identify the root cause in the app code
   - Fix the backend/frontend code
   - Rebuild: `docker compose up -d --build api` (or nginx for frontend)
   - Re-run the test
   - Document the fix
4. If test fails due to TEST BUG: fix the test
5. Move to next file only when current file is fully green
6. After all phases: run full suite `npx playwright test` and confirm 100% pass

### 5. Important notes
- Docker must be running before tests start
- Seed the DB before running: `cd backend && npx prisma db seed`
- Each test file should clean up after itself (delete created test users, etc.)
- Use unique emails per test to avoid conflicts (e.g., `test-{timestamp}@example.com`)
- For UI tests, use Playwright's built-in waiting (locator.waitFor) — Flutter web takes a moment to hydrate
- The frontend is Flutter Web (CanvasKit) — use `data-testid` or text selectors, not CSS class selectors
- API tests should use Playwright's `request` context (no browser needed)
- ALWAYS attach the monitors helper in UI tests and assert clean at test end

### 6. Final deliverable
After all tests pass, give me:
- Total test count and pass rate
- List of all app bugs found and fixed (with file paths and what you changed)
- Screenshot review summary (any visual issues found)
- Console/network error report (any errors captured)
- Accessibility violations report
- Performance baseline numbers
- Any remaining issues or recommendations

### 7. Bug fix workflow
When you find a bug during testing:
1. Document what test exposed it
2. Read the relevant source file
3. Fix the root cause (not a workaround)
4. If backend change: `docker compose up -d --build api` then re-run test
5. If frontend change: `docker compose up -d --build nginx` then re-run test
6. Confirm the test passes
7. Check that no previously-passing tests broke (run full suite)
8. Add the fix to the deliverable summary
```

---

## Pre-requisites Checklist

Before running the prompt above, ensure:

- [ ] Docker Desktop is running
- [ ] `docker compose up -d --build` completed successfully
- [ ] All 4 containers healthy (`docker compose ps`)
- [ ] Database seeded (`cd backend && npx prisma db seed`)
- [ ] http://localhost:8080 loads in browser
- [ ] Node.js installed locally (for running Playwright)

## Phase Order Rationale

```
Phase 1: Infrastructure     → Can anything run at all?
Phase 2: Screenshots         → What does the user SEE? (find visual bugs)
Phase 3: Console/Network     → What's silently broken? (find hidden errors)
Phase 4: Accessibility       → Is the structure correct? (find structural issues)
Phase 5: Auth API            → Is security working? (core dependency for everything)
Phase 6: UI Journeys         → Do real user flows work? (with error monitoring)
Phase 7-13: CRUD APIs        → Does each endpoint work correctly?
Phase 14: Performance        → How fast is it? (after everything works)
Phase 15: Cross-cutting      → Edge cases and integration points
```

The idea: surface the most impactful bugs first. A blank screen or a console
full of errors is more important to find than a missing API validation.

## Expected Timeline

| Phase | Tests | Estimate |
|-------|-------|----------|
| Setup | - | 5 min |
| Phase 1: Infrastructure | ~6 | 5 min |
| Phase 2: Visual Screenshots | ~33 (11 pages x 3 viewports) | 15 min |
| Phase 3: Console/Network | ~11 (per page) | 10 min |
| Phase 4: Accessibility | ~11 (per page) | 10 min |
| Phase 5: Auth API | ~13 | 15 min |
| Phase 6: UI Journeys | ~8 | 20 min |
| Phase 7-13: CRUD APIs | ~27 | 25 min |
| Phase 14: Performance | ~6 | 10 min |
| Phase 15: Cross-cutting | ~3 | 5 min |
| Bug fixes | varies | varies |
| **Total** | **~118+** | **~2-3 hours** |
