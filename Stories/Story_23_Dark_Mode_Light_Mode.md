# Story 23: Dark Mode / Light Mode Toggle - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Provide a system-respecting and manually toggleable dark/light theme. This is not cosmetic — dark mode reduces eye strain for evening app use and is a primary accessibility feature expected on any modern financial app.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. System Auto-Detect
1. **Trigger:** App opens for the first time.
2. **System State:** App reads OS preference via `PlatformDispatcher.platformBrightness`.
3. **Action:** Theme auto-applies (Dark if system is dark, Light if system is light). No user intervention required.

### B. Manual Override
1. **Trigger:** User taps Settings → "Appearance" → Toggles "Dark Mode ON".
2. **System State:** App writes preference to `SharedPreferences`.
3. **Action:** Flutter `ThemeData` swaps to dark tokens. Transition animates at `250ms ease`.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### Light Mode Token Set:
```dart
// Light ThemeData colors
Color colorBg      = Color(0xFFF9FAFB);
Color colorSurface = Color(0xFFFFFFFF);
Color colorText    = Color(0xFF111827);
Color colorBorder  = Color(0xFFE5E7EB);
```

### Dark Mode Token Set:
```dart
// Dark ThemeData colors
Color colorBg      = Color(0xFF0F172A);
Color colorSurface = Color(0xFF1E293B);
Color colorText    = Color(0xFFF1F5F9);
Color colorBorder  = Color(0xFF334155);
```

- **Transition Rule:** Use `AnimatedTheme` with a `duration: Duration(milliseconds: 250)` curve for smooth theme switching. NEVER animate layout properties.
- **`ThemeToggleButton`**: A sun ☀️ / moon 🌙 icon button in the top navigation bar.

---

## 🚀 5. Technical Architecture

- **Flutter:** `ThemeMode.system | ThemeMode.dark | ThemeMode.light` in `MaterialApp`. Persisted via `SharedPreferences`.
- **ThemeData:** Define `ThemeData.light()` and `ThemeData.dark()` with custom `ColorScheme` using the token sets above.
- **State Management:** A `ThemeNotifier` (using `ValueNotifier<ThemeMode>` or equivalent) reads the saved preference from `SharedPreferences` on startup and exposes `toggleTheme()` / `setThemeMode(ThemeMode)` methods.

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Dark mode launches automatically if the OS is in dark mode on first app open (via `PlatformDispatcher.platformBrightness`).
- [ ] Manual dark mode toggle persists after app is fully closed and reopened (stored in `SharedPreferences`).
- [ ] All text in dark mode passes 4.5:1 WCAG contrast ratio (verified with Colour Contrast Analyser).
- [ ] All images and charts are legible in both modes (no white-on-white or black-on-black scenarios).
