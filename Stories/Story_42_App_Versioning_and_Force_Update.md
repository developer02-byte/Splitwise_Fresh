# Story 41: App Versioning & Force Update - Detailed Execution Plan

## 1. Core Objective & Philosophy
Ensure users always run a compatible app version. When a breaking API change ships, old apps must update or they will crash with confusing errors. The version check system provides a clean, controlled way to force updates when necessary and gently nudge users when a new version is available. The web app auto-updates on deploy and does not need this mechanism.

---

## 2. Target Persona & Motivation
- **The Outdated User:** Has not updated the app in months. The API has changed, and their app is sending requests the server no longer understands. Without a force update mechanism, they see cryptic errors and think the app is broken.
- **The Slightly Behind User:** Running version 1.2.0 when 1.3.0 is out. Everything still works (no breaking changes), but there are bug fixes and improvements they should grab. A gentle nudge is appropriate.
- **The Developer/Release Manager:** Needs a clean way to bump the minimum supported version when shipping breaking changes, without deploying a client update to enforce it.

---

## 3. Comprehensive Step-by-Step User Journey

### A. App Startup — Version Check
1. **Trigger:** User opens the app (cold start or resume from background after >1 hour).
2. **System Action:** Before rendering the main UI, the app calls `GET /api/version` with the current app version in the `X-App-Version` header and the platform in the `X-Platform` header (`ios`, `android`).
3. **Server Response:** Returns the current version configuration.
4. **Client Comparison:** The app compares its own version against the server response using semantic version comparison.

### B. Force Update (Breaking Change)
1. **Condition:** `app_version < min_version` (e.g., app is 1.0.0, server requires minimum 1.2.0).
2. **UI:** Full-screen, non-dismissable modal overlays the entire app. No navigation is possible.
   - Title: "Update Required"
   - Body: The `force_update_message` from the server response, or a default: "A new version of the app is required to continue. Please update now."
   - Single button: "Update Now" — deep links to the appropriate app store.
3. **Behavior:** The user cannot close, dismiss, or navigate past this screen. The only escape is updating the app or force-quitting (which will show the same screen on relaunch).

### C. Soft Update (Non-Breaking Improvement)
1. **Condition:** `app_version >= min_version` but `app_version < latest_version` (e.g., app is 1.2.0, latest is 1.3.0).
2. **UI:** A dismissable `MaterialBanner` at the top of the dashboard: "A new version is available. [Update] [Later]".
3. **Behavior:**
   - Tapping "Update" deep links to the app store.
   - Tapping "Later" dismisses the banner. It will reappear on the next app cold start (not on every resume).
   - The banner does not reappear for 24 hours after being dismissed (timestamp stored in `SharedPreferences`).

### D. Up-to-Date
1. **Condition:** `app_version >= latest_version`.
2. **UI:** No banner, no modal. App proceeds normally.

### E. Offline Startup
1. **Condition:** The version check call fails due to no internet connectivity.
2. **UI:** The app proceeds normally. Version check is skipped. The app functions in offline mode (Story 13).
3. **Rationale:** Blocking the app when offline would make it unusable on flights, in subways, etc. The version check runs again when connectivity is restored.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Components Used:
- **`ForceUpdateScreen`**:
  - A `Scaffold` with no `AppBar`, no back button, no drawer.
  - Center-aligned `Column`: app logo at top, large title "Update Required" in `TextStyle(fontSize: 28, fontWeight: FontWeight.bold)`, body text with server-provided message, and a full-width "Update Now" `ElevatedButton`.
  - Background: white or brand color gradient. No skeleton loading, no shimmer — this is a dead-end screen.
  - `WillPopScope` (or `PopScope` in newer Flutter) wraps the screen to prevent back-button dismissal on Android.

- **`SoftUpdateBanner`**:
  - `MaterialBanner` widget with `backgroundColor: Colors.blue.shade50`.
  - Leading icon: `Icon(Icons.system_update, color: Colors.blue)`.
  - Content text: "A new version is available" in `TextStyle(fontSize: 14)`.
  - Actions: Two `TextButton` widgets — "Update" (primary color, bold) and "Later" (grey).
  - Dismissed via `ScaffoldMessenger` or a state flag.

- **`VersionCheckWrapper`**:
  - A widget that wraps the app's main `MaterialApp` router.
  - On initialization, performs the version check.
  - While checking, shows a splash screen (app logo + loading indicator).
  - Based on result, either renders the main app, overlays the force update screen, or proceeds with a banner flag.

### State Flow:
```
App Start
  → Show splash
  → Call GET /api/version
  → Parse response
  → Compare versions
  → Decision:
      ├─ force_update → Navigate to ForceUpdateScreen (no way out)
      ├─ soft_update → Set banner flag, proceed to main app
      ├─ up_to_date → Proceed to main app
      └─ network_error → Skip check, proceed to main app
```

---

## 5. Technical Architecture & Database

### Backend Endpoint (Node.js Fastify):

#### `GET /api/version`
- **Auth:** Public, no authentication required (the user may not be logged in if their token expired alongside an old app version).
- **Request Headers:**
  - `X-App-Version`: e.g., `1.2.0`
  - `X-Platform`: `ios` | `android` | `web`
- **Response Payload:**
```json
{
  "min_version": "1.2.0",
  "latest_version": "1.3.0",
  "force_update": true,
  "force_update_message": "Please update to continue using the app.",
  "update_url": {
    "ios": "https://apps.apple.com/app/id123456789",
    "android": "https://play.google.com/store/apps/details?id=com.yourapp.splitwise"
  }
}
```
- **Controller Logic:**
  - Read `MIN_SUPPORTED_VERSION` and `LATEST_VERSION` from config (DB or env).
  - Parse `X-App-Version` header using `semver` library.
  - Compare: if `app_version < MIN_SUPPORTED_VERSION`, set `force_update: true`.
  - Return appropriate response.

### Version Configuration:
```env
# .env
MIN_SUPPORTED_VERSION=1.0.0
LATEST_VERSION=1.3.0
FORCE_UPDATE_MESSAGE="Please update to continue using the app."
IOS_STORE_URL=https://apps.apple.com/app/id123456789
ANDROID_STORE_URL=https://play.google.com/store/apps/details?id=com.yourapp.splitwise
```

Alternatively, store in a `app_config` database table for dynamic updates without redeployment:
```sql
CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO app_config (key, value) VALUES
  ('min_supported_version', '1.0.0'),
  ('latest_version', '1.3.0'),
  ('force_update_message', 'Please update to continue using the app.'),
  ('ios_store_url', 'https://apps.apple.com/app/id123456789'),
  ('android_store_url', 'https://play.google.com/store/apps/details?id=com.yourapp.splitwise');
```

### Fastify Route Registration:
```typescript
import semver from 'semver';

fastify.get('/api/version', async (request, reply) => {
  const appVersion = request.headers['x-app-version'] as string;
  const platform = request.headers['x-platform'] as string;

  const minVersion = await getConfig('min_supported_version');
  const latestVersion = await getConfig('latest_version');
  const forceMessage = await getConfig('force_update_message');

  const forceUpdate = appVersion && semver.valid(appVersion)
    ? semver.lt(appVersion, minVersion)
    : false;

  return reply.send({
    min_version: minVersion,
    latest_version: latestVersion,
    force_update: forceUpdate,
    force_update_message: forceMessage,
    update_url: {
      ios: await getConfig('ios_store_url'),
      android: await getConfig('android_store_url'),
    },
  });
});
```

### Flutter Implementation:

#### Version Check Service:
```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

class VersionCheckService {
  final ApiClient apiClient;

  VersionCheckService(this.apiClient);

  Future<VersionCheckResult> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);

      final response = await apiClient.get(
        '/api/version',
        headers: {
          'X-App-Version': packageInfo.version,
          'X-Platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      final minVersion = Version.parse(response['min_version']);
      final latestVersion = Version.parse(response['latest_version']);

      if (currentVersion < minVersion) {
        return VersionCheckResult.forceUpdate(
          message: response['force_update_message'],
          updateUrl: response['update_url'][Platform.isIOS ? 'ios' : 'android'],
        );
      } else if (currentVersion < latestVersion) {
        return VersionCheckResult.softUpdate(
          updateUrl: response['update_url'][Platform.isIOS ? 'ios' : 'android'],
        );
      } else {
        return VersionCheckResult.upToDate();
      }
    } catch (e) {
      // Network error — skip version check, proceed offline
      return VersionCheckResult.skipped();
    }
  }
}
```

#### Deep Link to App Store:
```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openAppStore(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

### Semantic Versioning Policy:
- **MAJOR** bump (1.x.x → 2.0.0): Complete redesign or fundamental API overhaul. Always requires force update.
- **MINOR** bump (1.2.x → 1.3.0): New features, non-breaking API additions. Soft update.
- **PATCH** bump (1.2.0 → 1.2.1): Bug fixes, performance improvements. Soft update.
- **Rule:** Only bump `MIN_SUPPORTED_VERSION` when a MAJOR or breaking MINOR change makes old clients incompatible.

### Grace Period for Force Updates:
- When planning a force update, set `MIN_SUPPORTED_VERSION` to the new version but schedule the deployment 1 week after the new app version is available on the stores.
- This accounts for App Store review delays (1-3 days for iOS) and gives users time to update naturally.

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior (UX) | Technical Fallback (Dev) |
|---|---|---|
| **No internet on startup** | Version check silently fails. App proceeds to main content (or offline mode). | `try/catch` around the API call. On any error, return `VersionCheckResult.skipped()`. |
| **App store review delay** | Force update kicks in but the new version is not yet available on the store. User taps "Update Now" and sees the old version in the store. | Grace period: wait 1 week after store availability before bumping `MIN_SUPPORTED_VERSION`. Include a note in the force update message: "If the update is not yet available, please try again shortly." |
| **Invalid version string in header** | Server cannot parse the version. | Backend defaults to `force_update: false` if version parsing fails. Logs a warning for monitoring. |
| **Web app** | Web auto-updates on deploy. No version check needed. | `GET /api/version` still works for web but the client skips the check. `X-Platform: web` header allows the server to log web version usage. |
| **User clears app data** | `SharedPreferences` reset, soft update banner dismissal timestamp lost. Banner reappears. | Acceptable behavior. No negative impact. |
| **Rapid version bumps** | Multiple updates in a short period. User on 1.0.0, min is now 1.3.0. | Force update screen shows. User updates to latest (1.5.0). All intermediate versions are skipped. |
| **Background resume after long time** | App was backgrounded for days. Version may have changed. | Version check runs on cold start and on resume after >1 hour (configurable). |

---

## 7. Final QA Acceptance Criteria
- [ ] App calls `GET /api/version` on startup with correct `X-App-Version` and `X-Platform` headers.
- [ ] When `app_version < min_version`, a full-screen, non-dismissable "Update Required" modal appears.
- [ ] The force update screen's "Update Now" button opens the correct app store (iOS or Android).
- [ ] The force update screen cannot be dismissed via back button, swipe, or any gesture.
- [ ] When `app_version < latest_version` but `>= min_version`, a dismissable banner appears on the dashboard.
- [ ] Tapping "Later" on the soft update banner dismisses it and it does not reappear for 24 hours.
- [ ] When `app_version >= latest_version`, no banner or modal is shown.
- [ ] When the version check API call fails (no internet), the app proceeds normally without blocking.
- [ ] The `GET /api/version` endpoint is public and does not require authentication.
- [ ] Semantic version comparison handles all edge cases (e.g., 1.10.0 > 1.9.0, 2.0.0 > 1.99.99).
- [ ] Version configuration can be updated via database or environment variables without redeploying the app server.
- [ ] Web platform skips the version check entirely.
