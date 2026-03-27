# Story 36: Accessibility (a11y) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Ensure the app is usable by people with visual, motor, and cognitive disabilities. Meet WCAG 2.1 AA compliance and pass app store accessibility guidelines. Accessibility is not a feature — it is a quality bar. Every screen, every interaction, every piece of information must be perceivable, operable, understandable, and robust for all users.

---

## 2. Target Persona & Motivation
- **The Visually Impaired User:** Uses TalkBack (Android) or VoiceOver (iOS) to navigate the app. Needs every screen element to be properly labeled and logically ordered.
- **The Low-Vision User:** Relies on large text settings (200% scale) and high-contrast mode. Needs the app to remain functional without text truncation or overlapping elements.
- **The Motor-Impaired User:** Uses switch access or voice control. Needs large touch targets and logical focus order without precision-dependent gestures.
- **The Color-Blind User:** Cannot distinguish red from green. Needs all status information conveyed through text and icons, not color alone.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Screen Reader Navigation Through Core Flow
1. **Dashboard:** VoiceOver announces: "Dashboard. Overall balance: You are owed forty-five dollars and twenty cents. 3 groups. Apartment 4B, you are owed thirty dollars. Tokyo Trip, you owe fifteen dollars."
2. **Navigate to Add Expense:** User swipes right to reach the FAB. VoiceOver: "Add expense button. Double tap to activate."
3. **Add Expense Form:** Each field is announced with its label, current value, and hint:
   - "Description, text field, empty. Enter expense description."
   - "Amount, text field, empty. Enter amount in dollars."
   - "Paid by, dropdown, Alice Johnson selected. Double tap to change."
   - "Split type, segmented control, Equal selected. Swipe up or down to change."
4. **Save:** "Save expense button. Double tap to save." After save: "Expense saved. Dinner, fifty-five dollars, split equally among 3 people."

### B. Large Text Navigation
1. **System setting:** User has device text scale set to 200%.
2. **Dashboard:** Balance cards expand vertically to accommodate larger text. No horizontal overflow.
3. **Expense list:** Each list item grows taller. Description and amount remain on separate lines if needed.
4. **Buttons:** Button text wraps or abbreviates gracefully. Touch targets remain at least 44x44px.

### C. Keyboard Navigation (Flutter Web)
1. **Tab order:** Tab moves through: App bar actions, navigation items, main content cards, FAB, bottom nav.
2. **Focus indicator:** A visible blue border (2px) appears around the focused element.
3. **Activation:** Enter or Space activates buttons, opens dropdowns, submits forms.
4. **Escape:** Closes modals, bottom sheets, and dropdown menus. Returns focus to the trigger element.
5. **Arrow keys:** Navigate within lists, segmented controls, and tab bars.

### D. Reduced Motion Mode
1. **System setting:** User has "Reduce motion" enabled on their device.
2. **App behavior:** Page transitions use instant cuts instead of slide/fade animations. Balance change animations are disabled. Loading spinners still animate (essential feedback). Pull-to-refresh uses a simple indicator instead of a bouncing animation.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### Semantics Implementation Per Widget

#### Balance Display
```dart
Semantics(
  label: _buildBalanceLabel(balance),
  // "You are owed forty-five dollars and twenty cents"
  // NOT "negative $45.20" or "-45.20"
  excludeSemantics: true,
  child: BalanceWidget(balance: balance),
)

String _buildBalanceLabel(Balance balance) {
  final amount = formatAmountForSpeech(balance.amount, balance.currency);
  if (balance.amount > 0) return 'You are owed $amount';
  if (balance.amount < 0) return 'You owe $amount';
  return 'You are settled up';
}
```

#### Expense List Item
```dart
Semantics(
  label: '${expense.description}, ${formatAmountForSpeech(expense.amount, expense.currency)}, '
         'paid by ${expense.paidBy.name}, ${formatRelativeDate(expense.createdAt)}',
  hint: 'Double tap to view details',
  child: ExpenseListTile(expense: expense),
)
```

#### Action Buttons
```dart
Semantics(
  button: true,
  label: 'Add expense',
  hint: 'Opens the add expense form',
  child: FloatingActionButton(
    onPressed: _openAddExpense,
    child: const Icon(Icons.add),
  ),
)
```

#### Lists with Item Count
```dart
Semantics(
  label: 'Expense list, ${expenses.length} items',
  child: ListView.builder(
    itemCount: expenses.length,
    itemBuilder: (context, index) => /* ... */,
  ),
)
```

### Touch Target Requirements
| Widget | Minimum Size | Implementation |
| --- | --- | --- |
| All buttons | 44x44px | `ConstrainedBox(constraints: BoxConstraints(minHeight: 44, minWidth: 44))` |
| List item tap areas | 44px height minimum | `ListTile` with `minVerticalPadding: 12` |
| Icon buttons | 44x44px | `IconButton` default 48px is compliant; never reduce below 44px |
| Checkbox / Toggle | 44x44px | `SizedBox(height: 44, width: 44, child: Checkbox(...))` |
| Adjacent targets gap | 8px minimum | Use `SizedBox(height: 8)` or padding between interactive elements |

### Color Contrast Compliance

#### Light Mode Palette (All pass WCAG AA 4.5:1)
| Element | Foreground | Background | Contrast Ratio |
| --- | --- | --- | --- |
| Primary text | `#1A1A1A` | `#FFFFFF` | 16.5:1 |
| Secondary text | `#555555` | `#FFFFFF` | 7.5:1 |
| "You owe" text | `#B71C1C` (dark red) | `#FFFFFF` | 5.9:1 |
| "You are owed" text | `#1B5E20` (dark green) | `#FFFFFF` | 6.3:1 |
| Button text | `#FFFFFF` | `#1565C0` (blue) | 6.1:1 |
| Disabled text | `#757575` | `#FFFFFF` | 4.6:1 |

#### Dark Mode Palette (All pass WCAG AA 4.5:1)
| Element | Foreground | Background | Contrast Ratio |
| --- | --- | --- | --- |
| Primary text | `#E0E0E0` | `#121212` | 13.5:1 |
| Secondary text | `#B0B0B0` | `#121212` | 8.2:1 |
| "You owe" text | `#EF9A9A` (light red) | `#121212` | 6.8:1 |
| "You are owed" text | `#A5D6A7` (light green) | `#121212` | 8.1:1 |
| Button text | `#FFFFFF` | `#1565C0` | 6.1:1 |

#### Color-Independence Rule
Every use of color to convey meaning must be paired with a secondary indicator:
| Meaning | Color | Secondary Indicator |
| --- | --- | --- |
| You owe money | Red | Downward arrow icon + "You owe" text |
| You are owed | Green | Upward arrow icon + "You are owed" text |
| Error state | Red | Error icon + descriptive error message |
| Success state | Green | Checkmark icon + "Saved" or "Settled" text |
| Pending state | Orange | Clock icon + "Pending" text |

### Dynamic Text Scaling

#### Testing at 200% Scale
```dart
// In test files, wrap with MediaQuery override
MediaQuery(
  data: MediaQueryData(textScaleFactor: 2.0),
  child: MaterialApp(home: DashboardScreen()),
)
```

#### Layout Rules for Scalable Text
- Use `Flexible` and `Expanded` widgets instead of fixed widths for text containers.
- Never use fixed `height` on containers that hold text. Use `minHeight` with `IntrinsicHeight` if needed.
- Prefer `Column` over `Row` for layouts that may need to reflow at large text sizes.
- Use `FittedBox` with `fit: BoxFit.scaleDown` for labels that must stay on one line (e.g., navigation bar labels).
- `TextOverflow.ellipsis` is the last resort — always provide a `Tooltip` or long-press to reveal full text.

### Keyboard Navigation (Web)

#### Focus Management
```dart
// Ensure focus returns to trigger after modal closes
void _openModal() {
  final trigger = FocusManager.instance.primaryFocus;
  showDialog(
    context: context,
    builder: (_) => ExpenseDialog(),
  ).then((_) {
    trigger?.requestFocus();
  });
}
```

#### Tab Order
Use `FocusTraversalGroup` and `FocusTraversalOrder` to ensure logical tab order:
```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(
    children: [
      FocusTraversalOrder(
        order: NumericFocusOrder(1),
        child: DescriptionField(),
      ),
      FocusTraversalOrder(
        order: NumericFocusOrder(2),
        child: AmountField(),
      ),
      FocusTraversalOrder(
        order: NumericFocusOrder(3),
        child: SaveButton(),
      ),
    ],
  ),
)
```

### Motion Sensitivity

```dart
// Check system preference
final reduceMotion = MediaQuery.of(context).disableAnimations;

// Use in animations
AnimatedContainer(
  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // ...
)

// Page transitions
MaterialPageRoute(
  builder: (_) => NextScreen(),
  // Disable transition animation when reduce motion is on
  fullscreenDialog: reduceMotion,
)
```

---

## 5. Technical Architecture

### Accessibility Testing Strategy

#### Automated Testing
- **Flutter Accessibility Inspector:** Run via DevTools on every screen during development.
- **`flutter test --accessibility`:** Runs accessibility checks as part of the test suite.
- **Semantic tree assertion tests:**
```dart
testWidgets('Dashboard announces balance correctly', (tester) async {
  await tester.pumpWidget(DashboardScreen());

  final semantics = tester.getSemantics(find.byType(BalanceWidget));
  expect(semantics.label, contains('You are owed'));
  expect(semantics.label, isNot(contains('-')));  // No raw negative signs
});

testWidgets('All buttons meet minimum touch target', (tester) async {
  await tester.pumpWidget(DashboardScreen());

  final buttons = find.byType(ElevatedButton);
  for (final button in buttons.evaluate()) {
    final size = tester.getSize(find.byWidget(button.widget));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  }
});
```

#### Manual Testing Checklist (Per Screen)
- [ ] Navigate entire screen using TalkBack/VoiceOver without visual reference.
- [ ] Every interactive element is reachable and activatable via screen reader.
- [ ] No "unlabeled button" or "image" announcements.
- [ ] Content order in screen reader matches visual layout.
- [ ] Test at 200% text scale — no clipping, overlap, or unusable layouts.
- [ ] Verify all color-dependent information has a non-color alternative.

### Accessibility Lint Rules
Add to `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint

linter:
  rules:
    # Ensure Semantics labels are present
    avoid_unnecessary_containers: true
    sized_box_for_whitespace: true
```

### Screen Reader Announcement Helpers
```dart
/// Announce a message to screen readers without changing focus
void announceToScreenReader(BuildContext context, String message) {
  SemanticsService.announce(message, TextDirection.ltr);
}

/// Format monetary amount for speech
/// Converts 5500 cents, "USD" → "fifty-five dollars"
String formatAmountForSpeech(int cents, String currency) {
  final dollars = cents ~/ 100;
  final remaining = cents % 100;
  final currencyName = getCurrencyName(currency); // "dollars", "euros", "pounds"

  if (remaining == 0) return '$dollars $currencyName';
  return '$dollars $currencyName and $remaining cents';
}
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **RTL language support** | Future consideration for Arabic/Hebrew users. | Deferred. When added: use `Directionality` widget, mirror all layouts, test with RTL screen readers. |
| **Screen magnification** | User zooms to 400% on a single area. | All layouts use relative sizing. No absolute-positioned overlapping elements. Scroll containers handle overflow. |
| **Switch access users** | User navigates via a physical switch (scanning mode). | All interactive elements are focusable. Focus order is linear and predictable. No time-dependent interactions. |
| **Voice control** | User says "tap Add expense" to activate the button. | All buttons have visible text labels matching their semantic labels, so voice control can target them. |
| **Custom font size in app settings** | User sets app-level font scale independent of system. | App respects the larger of system scale and app scale. `MediaQuery.textScaleFactor` is the single source of truth. |
| **Long user names in balance display** | "Alexander Constantinople III" at 200% text scale. | Names truncate with ellipsis after 2 lines. Full name available via long-press tooltip. Screen reader reads full name. |
| **Rapid screen reader navigation** | User swipes quickly through a long expense list. | Each list item is a single semantic node (not multiple). Swiping moves one expense at a time, not one widget at a time. |
| **Modal traps keyboard focus** | User opens a dialog; tab focus escapes to elements behind the dialog. | Use `FocusScope` with `autofocus: true` on the dialog. Focus is trapped within the dialog until dismissed. |
| **Empty state screens** | Dashboard with no groups or expenses. | Empty states have semantic labels: "No expenses yet. Tap Add expense to create your first expense." |
| **Loading states** | Spinner while data loads. | `Semantics(label: 'Loading expenses', child: CircularProgressIndicator())`. Screen reader announces "Loading expenses". After load: announce "15 expenses loaded". |

---

## 7. Final QA Criteria
- [ ] Every screen is fully navigable using VoiceOver (iOS) and TalkBack (Android) without visual reference.
- [ ] No "unlabeled button", "image", or generic announcements exist anywhere in the app.
- [ ] Balance amounts are read as "You owe fifty dollars" — never as "negative fifty" or "-50".
- [ ] All interactive elements meet the 44x44px minimum touch target size.
- [ ] All text passes WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text) in both light and dark modes.
- [ ] Color is never the sole indicator of meaning — all statuses have icon and/or text alternatives.
- [ ] App is fully usable at 200% system text scale with no text truncation, overlap, or broken layouts.
- [ ] Keyboard navigation (web) follows logical tab order with visible focus indicators on all interactive elements.
- [ ] Escape key closes all modals and returns focus to the trigger element.
- [ ] Reduced motion preference disables all non-essential animations.
- [ ] Loading spinners continue to animate even with reduced motion enabled.
- [ ] Automated accessibility tests pass in CI (`flutter test --accessibility`).
- [ ] Manual screen reader testing completed on at least 5 core screens (Dashboard, Add Expense, Expense Detail, Group Detail, Settings).
