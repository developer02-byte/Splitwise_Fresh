# Story 25: Onboarding Flow (First-Time User Experience) - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
A brand-new user who just signed up has NO context, NO friends, and NO expenses. If we drop them on a blank dashboard with zero guidance, they will churn. The Onboarding Flow is a guided, skippable walkthrough that transforms confusion into immediate productive action in under 60 seconds.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. First-Login Detection
1. **Trigger:** User signs up for the first time. Backend API returns `{ onboarding_completed: false }` in the login response.
2. **System State:** App checks the `onboarding_completed` flag from the server response. If `false`, `go_router` redirects to `/onboarding` instead of `/dashboard`.

### B. Step-by-Step Guided Slides
1. **Slide 1 - Welcome:** "Welcome to SplitApp! 👋 Let's get you set up in 3 quick steps." Progress dots: `● ○ ○`.
2. **Slide 2 - Add Your First Friend:** Pre-built friend-add form mid-onboarding. Enter email. Tap "Add Friend". Progress dots: `● ● ○`.
3. **Slide 3 - Create a Group:** Pre-built group setup form. Enter group name. Tap "Create Group". Progress dots `● ● ●`.
4. **Completion:** "You're all set! 🎉 Add your first expense." → `go_router` navigates to Dashboard with the Add Expense FAB visually pulsing with a spotlight animation.

### C. Skip Button
1. **Design:** A subtle "Skip" `TextButton` always visible in the top-right corner of each slide.
2. **Action:** Tapping Skip calls `POST /api/user/onboarding-complete` to mark the server-side `onboarding_completed` flag as `true`, then `go_router` navigates directly to the Dashboard. This flow never shows again.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`OnboardingScreen`**: Full-screen layout using a `PageView` widget for swipeable slides. Top 50% is an illustration/animation. Bottom 50%: Title, Subtitle, Action input or button, Skip link, Progress dots.
- **`ProgressDots`**: `8px × 8px` circles using `Container` with `BoxDecoration(shape: BoxShape.circle)`. Active dot: Brand color, width `24px` (pill shape via `borderRadius`). Inactive: `Color(0xFFD1D5DB)`.
- **`SpotlightPulse`**: After onboarding completes, a radial glow animation (using `AnimationController` + `ScaleTransition`) pulses around the FAB for 3 seconds to draw the user's eye.

---

## 🚀 5. Technical Architecture & Database

```sql
ALTER TABLE users ADD COLUMN onboarding_completed BOOLEAN DEFAULT FALSE;
```

- **`POST /api/user/onboarding-complete`** (Fastify handler): Marks `onboarding_completed = true` via Prisma when user finishes or skips.
- App checks `onboarding_completed` from the user profile API on every Dashboard load. If `false`, `go_router` redirects to onboarding. If `true`, never shows again.

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] First-time users are automatically routed to onboarding after signup (via `go_router` redirect).
- [ ] Returning users NEVER see the onboarding screen again after completing or skipping (server-side `onboarding_completed` flag).
- [ ] Skipping mid-onboarding lands the user on a fully functional Dashboard.
- [ ] Completing onboarding triggers the spotlight pulse animation on the FAB.
