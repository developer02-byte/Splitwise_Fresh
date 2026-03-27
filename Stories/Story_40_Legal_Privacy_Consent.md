# Story 40: Legal / Privacy / Consent - Detailed Execution Plan

## 1. Core Objective & Philosophy
Meet app store requirements and data protection regulations. Without this, Apple and Google will reject the app. Beyond compliance, this is about building user trust — users share financial data with us, and they deserve clarity on how that data is collected, used, stored, and deleted. The goal is to be compliant with GDPR, CCPA, and COPPA while keeping the experience frictionless.

---

## 2. Target Persona & Motivation
- **The Privacy-Conscious User:** Reads the privacy policy before signing up. Wants to know exactly what data is collected and whether it is shared with third parties. Will not use the app if the policy is vague or missing.
- **The App Store Reviewer:** Apple/Google reviewer checking that the app has a valid privacy policy URL, terms of service, and accurate data safety declarations. Will reject the app if these are missing or inconsistent.
- **The EU User:** Protected by GDPR. Has the right to export their data, request deletion, and withdraw consent for analytics. Expects a cookie banner on the web version.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Signup Flow — Terms Acceptance
1. **Trigger:** User reaches the signup screen (Story 01).
2. **UI Element:** Below the "Create Account" button, a checkbox with tappable text: "I agree to the [Terms of Service] and [Privacy Policy]". Links open an in-app browser (`url_launcher`) to the hosted pages.
3. **Validation:** The "Create Account" button is disabled until the checkbox is checked. If the user tries to submit without checking, a red helper text appears: "You must accept the Terms of Service and Privacy Policy to continue."
4. **Backend:** On successful registration, the server stores `accepted_terms_at` as the current UTC timestamp and `accepted_terms_version` as the current terms version string (e.g., `"2026-03-01"`).
5. **System State:** The user record now has a legal acceptance audit trail.

### B. Terms Update — Re-Acceptance Flow
1. **Trigger:** The terms of service or privacy policy are updated. The server's `CURRENT_TERMS_VERSION` env variable is bumped.
2. **System Check:** On app startup (after login), the client calls `GET /api/user/profile` which includes `accepted_terms_version`. If it is older than `CURRENT_TERMS_VERSION`, the app presents a blocking modal.
3. **UI Element:** Full-screen modal: "We've updated our Terms of Service and Privacy Policy. Please review and accept to continue." Two tappable links to the updated documents. A single "I Accept" button.
4. **Backend:** `PUT /api/user/accept-terms` updates `accepted_terms_at` and `accepted_terms_version`. The blocking modal dismisses.
5. **Edge Case:** If the user dismisses the app without accepting, the modal reappears on next launch. They cannot use the app until they accept.

### C. Privacy Policy & Terms of Service Pages
1. **Hosting:** Static pages served at `https://yourdomain.com/privacy` and `https://yourdomain.com/terms`.
2. **Accessibility:** Linked from: app settings screen, signup screen, app store listing (iOS and Android), footer of any marketing/landing page.
3. **Content — Privacy Policy covers:**
   - What personal data is collected (name, email, profile photo, expense data, device info)
   - How data is used (expense splitting, notifications, analytics)
   - How data is stored (PostgreSQL on Hetzner, encrypted at rest and in transit)
   - Data retention periods (active data indefinitely, soft-deleted data 90 days, audit logs 2 years)
   - Third-party services and their data access (see section below)
   - User rights (access, export, deletion, correction)
   - Contact information for data protection inquiries
4. **Content — Terms of Service covers:**
   - Acceptable use policy
   - Account responsibilities
   - Intellectual property
   - Limitation of liability (the app is not a bank, not a payment processor)
   - Dispute resolution
   - Termination of account

### D. Cookie Consent (Web Only)
1. **Trigger:** First visit to the web app or marketing site.
2. **UI Element:** Bottom banner: "We use cookies for essential functionality and optional analytics. [Accept All] [Customize] [Reject Non-Essential]".
3. **Customize Option:** Toggle switches for: Essential (always on, disabled toggle), Analytics (default off), Performance (default off).
4. **Storage:** Consent preference stored in `localStorage` as a JSON object with a version and timestamp.
5. **Enforcement:** Analytics scripts (if any) only load after consent is granted. Essential cookies (session, CSRF) load regardless.
6. **Mobile App:** No cookie banner needed. Mobile does not use cookies. Analytics consent is handled via app settings toggle.

### E. Data Subject Rights
1. **Right to Access / Export (GDPR Art. 15):** Covered by Story 19 (Data Export). User can export all their data as JSON from the settings screen.
2. **Right to Deletion (GDPR Art. 17):** Covered by Story 10 (Delete Account). Soft delete immediately, anonymize after 30 days, hard purge after 90 days. Audit log entries are anonymized (user_id replaced with "deleted_user") but not removed.
3. **Right to Rectification (GDPR Art. 16):** Users can edit their profile (name, email) at any time via settings.
4. **Right to Data Portability (GDPR Art. 20):** JSON export satisfies this requirement.
5. **Right to Withdraw Consent:** Analytics tracking can be disabled in app settings at any time.

### F. App Store Compliance
1. **Apple App Store:**
   - Privacy nutrition label filled out in App Store Connect (data types: name, email, photos, financial data, usage data).
   - App Tracking Transparency (ATT) prompt only if third-party tracking is used. For v1, no third-party advertising tracking is planned — ATT is not required.
   - Privacy policy URL provided in App Store Connect.
2. **Google Play Store:**
   - Data Safety section completed in Play Console (data collected, data shared, security practices).
   - Privacy policy URL provided in Play Console.
   - Data deletion mechanism documented (in-app account deletion flow).

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`TermsCheckbox`**:
  - Widget: `Row` containing `Checkbox` and `RichText` with tappable `TextSpan` links.
  - Links styled with `TextDecoration.underline` and brand primary color.
  - Tapping "Terms of Service" opens `https://yourdomain.com/terms` via `url_launcher`.
  - Tapping "Privacy Policy" opens `https://yourdomain.com/privacy` via `url_launcher`.
  - Error state: red border on checkbox, helper text "Required" below.

- **`TermsUpdateModal`**:
  - Full-screen `Dialog` with `barrierDismissible: false`.
  - Title: "Updated Terms" in `TextStyle(fontSize: 22, fontWeight: FontWeight.bold)`.
  - Body: Explanatory text with tappable links to updated documents.
  - Single "I Accept" button, full-width, brand primary color.
  - No close button, no back navigation. The user must accept.

- **`CookieConsentBanner` (Web only)**:
  - Fixed-position bottom banner, `background: Colors.grey.shade900`, text `Colors.white`.
  - Three buttons: "Accept All" (primary), "Customize" (outlined), "Reject Non-Essential" (text).
  - Customize expands to show toggle switches for each cookie category.
  - Banner animates away with `SlideTransition` after user makes a choice.

- **`PrivacySettingsSection`** (in app settings):
  - Toggle: "Analytics & Usage Data" — defaults to ON, user can turn OFF.
  - Link: "View Privacy Policy" — opens web page.
  - Link: "View Terms of Service" — opens web page.
  - Link: "Export My Data" — navigates to data export (Story 19).
  - Link: "Delete My Account" — navigates to account deletion (Story 10).

---

## 5. Technical Architecture & Database

### Database Schema Changes (PostgreSQL via Prisma):
```sql
-- Add terms acceptance tracking to users table
ALTER TABLE users ADD COLUMN accepted_terms_at TIMESTAMPTZ NULL;
ALTER TABLE users ADD COLUMN accepted_terms_version TEXT NULL;
```

### Prisma Schema Update:
```prisma
model User {
  id                   Int       @id @default(autoincrement())
  email                String    @unique
  name                 String
  // ... existing fields
  acceptedTermsAt      DateTime? @map("accepted_terms_at")
  acceptedTermsVersion String?   @map("accepted_terms_version")

  @@map("users")
}
```

### Backend Endpoints (Node.js Fastify):

#### 1. `POST /api/auth/register` (Modified)
- **Additional Validation:** Request body must include `accepted_terms: true`. If missing or false, return `400: "You must accept the Terms of Service and Privacy Policy"`.
- **Additional Storage:** On successful registration, set `accepted_terms_at = NOW()` and `accepted_terms_version = process.env.CURRENT_TERMS_VERSION`.

#### 2. `PUT /api/user/accept-terms`
- **Purpose:** Record user's acceptance of updated terms.
- **Auth:** Requires authenticated user.
- **Controller Logic:**
  - Update `accepted_terms_at = NOW()` and `accepted_terms_version = process.env.CURRENT_TERMS_VERSION`.
- **Response:** `200 OK` with updated user profile.

#### 3. `GET /api/user/profile` (Modified)
- **Additional Response Field:** Include `accepted_terms_version` in the profile response so the client can compare against the current version.
- **Additional Response Field:** Include `current_terms_version` from server config so the client knows if re-acceptance is needed.

#### 4. `GET /api/legal/privacy` and `GET /api/legal/terms`
- **Purpose:** Serve privacy policy and terms of service as HTML or redirect to hosted URLs.
- **Auth:** Public, no authentication required.
- **Response:** `302 Redirect` to `https://yourdomain.com/privacy` or `https://yourdomain.com/terms`.

### Third-Party Service Disclosures (for Privacy Policy):
| Service | Data Shared | Purpose |
|---------|-------------|---------|
| Firebase Cloud Messaging | Device token, user ID | Push notifications |
| Firebase Crashlytics | Device info, crash logs | Crash reporting and stability |
| Resend / SendGrid | Email address, name | Transactional emails (verification, password reset, notifications) |
| Exchange Rate API | None (read-only) | Currency conversion rates |
| Hetzner Cloud | All app data (hosted) | Infrastructure provider |
| Cloudflare | IP address, request metadata | CDN, DDoS protection, DNS |

### Environment Configuration:
```env
CURRENT_TERMS_VERSION=2026-03-01
PRIVACY_POLICY_URL=https://yourdomain.com/privacy
TERMS_OF_SERVICE_URL=https://yourdomain.com/terms
```

### Flutter Implementation:
```dart
// Terms version check on app startup
Future<void> checkTermsAcceptance(UserProfile profile) async {
  final serverTermsVersion = profile.currentTermsVersion;
  final userTermsVersion = profile.acceptedTermsVersion;

  if (userTermsVersion == null || userTermsVersion != serverTermsVersion) {
    // Show blocking modal requiring re-acceptance
    await showTermsUpdateDialog();
  }
}
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
|---|---|---|
| **User under 13 signs up (COPPA)** | Terms of Service state minimum age is 13. No age gate in v1, but ToS provides legal cover. If discovered, account is terminated. | Future consideration: add date-of-birth field and block under-13 registration. |
| **EU user vs US user** | Same privacy policy covers both. GDPR rights (export, deletion) available to all users regardless of location. | No geo-fencing of privacy features. All users get the same rights. |
| **Terms updated, user never re-accepts** | Blocking modal on every app launch. User cannot use the app. | `accepted_terms_version` check in profile response triggers modal. No API calls blocked (to avoid breaking background sync), but UI is gated. |
| **Data deletion request from user with active debts** | Account deletion flow (Story 10) requires settling all debts first, or the debts are reassigned/written off per policy. | Backend checks for non-zero balances before allowing account deletion. |
| **Cookie consent withdrawn after initial acceptance** | Analytics stop immediately. Existing analytics data is retained (not retroactively deleted). | `localStorage` consent object updated. Analytics scripts check consent on every page load. |
| **Social login user (no signup checkbox)** | Social login flow (Story 15) presents terms acceptance as part of the first-time profile setup. | Backend still requires `accepted_terms_at` to be set. Social login handler includes terms acceptance step. |

---

## 7. Final QA Acceptance Criteria
- [ ] Signup screen displays "I agree to the Terms of Service and Privacy Policy" with tappable links.
- [ ] Account cannot be created without checking the terms acceptance checkbox.
- [ ] `accepted_terms_at` and `accepted_terms_version` are stored on the user record upon registration.
- [ ] Privacy policy page is accessible at `https://yourdomain.com/privacy` and loads correctly.
- [ ] Terms of service page is accessible at `https://yourdomain.com/terms` and loads correctly.
- [ ] When terms version is updated, existing users see a blocking modal on next app launch requiring re-acceptance.
- [ ] Users cannot dismiss the terms update modal without accepting.
- [ ] App settings screen includes links to privacy policy, terms, data export, and account deletion.
- [ ] Web version displays a cookie consent banner on first visit.
- [ ] Analytics scripts do not load until cookie consent is granted (web only).
- [ ] Apple App Store privacy nutrition label is accurately filled out.
- [ ] Google Play Data Safety section is accurately completed.
- [ ] Privacy policy lists all third-party services and the data shared with each.
- [ ] All privacy and terms URLs are provided in app store listings.
