---
name: flutter-frontend-design
description: >
  Create distinctive, production-grade Flutter interfaces with high design quality.
  Use this skill when the user asks to build Flutter screens, widgets, pages, or apps.
  Generates creative, polished Dart/Flutter code that avoids generic AI aesthetics.
  Also enforces Clean Architecture, Feature-first organization, and Riverpod state management.
---

You are an expert in Flutter, Dart, Riverpod, Freezed, Flutter Hooks, and Clean Architecture.
This skill guides creation of distinctive, production-grade Flutter UIs that avoid generic
"AI slop" aesthetics — while maintaining idiomatic Dart structure and architecture.

---

## Design Thinking (from Anthropic frontend-design SKILL)

Before writing any code, understand the context and commit to a BOLD aesthetic direction:

- **Purpose**: What problem does this screen/widget solve? Who uses it?
- **Tone**: Pick a clear direction — brutally minimal, luxury/refined, playful/toy-like,
  editorial, brutalist/raw, soft/pastel, industrial/utilitarian, retro-futuristic, etc.
- **Constraints**: Flutter version, target platform (iOS/Android/web), accessibility needs.
- **Differentiation**: What makes this screen UNFORGETTABLE? What's the one visual
  detail a user will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision.
Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

---

## Flutter Aesthetics Guidelines

Focus on these areas to avoid generic Flutter UI:

- **Typography**: Use `google_fonts` to pick characterful, unexpected fonts — avoid
  defaulting to Roboto. Pair a distinctive display font with a refined body font.
  Use `Theme.of(context).textTheme` tokens, not raw `TextStyle(fontSize: 18)`.

- **Color & Theme**: Commit to a cohesive aesthetic. Use `ColorScheme.fromSeed` with
  `useMaterial3: true`. Dominant colors with sharp accents outperform timid,
  evenly-distributed palettes. Define all colors as `Color` constants —
  never hardcode `Colors.blue` inline.

- **Motion**: Use animations for micro-interactions. Prefer `AnimatedSwitcher`,
  `AnimatedContainer`, `Hero` for high-impact transitions. One well-orchestrated
  page load with staggered `FadeTransition` + `SlideTransition` creates more delight
  than scattered micro-interactions.

- **Spatial Composition**: Generous negative space OR controlled density — never in between.
  Use `SliverAppBar` for dramatic scroll effects. Apply `BoxShadow` and `ClipRRect`
  intentionally, not by default.

- **Visual Details**: Create atmosphere — gradient meshes, subtle noise textures,
  decorative `CustomPainter` backgrounds, dramatic shadows. Match complexity to vision.

**NEVER**: Default Roboto everywhere, plain white scaffolds, generic card grids,
purple gradient on white, cookie-cutter Material widgets with zero customization.

---

## Dart/Flutter Code Principles

### Core Rules
- Write concise, technical Dart code with accurate examples
- Use functional and declarative programming patterns where appropriate
- Prefer composition over inheritance
- Use descriptive variable names with auxiliary verbs: `isLoading`, `hasError`, `canSubmit`
- Structure files: exported widget → subwidgets → helpers → static content → types
- Use `const` constructors for all immutable widgets — non-negotiable for performance
- Use trailing commas for better formatting and diffs
- Use arrow syntax for simple one-liner functions and getters
- Keep lines ≤ 80 characters; add commas before closing brackets for multi-param functions
- Use `log` (from `dart:developer`) instead of `print` for debugging
- Use `@JsonValue(int)` for enums stored in a database

### Naming Conventions
| Element | Convention | Example |
|---|---|---|
| Widgets/Classes | `PascalCase` | `UserProfileCard` |
| Files | `snake_case` | `user_profile_card.dart` |
| Variables/methods | `camelCase` | `isLoading`, `fetchUser()` |
| Private helpers | `_camelCase` | `_buildHeader()` |
| Constants | `kCamelCase` | `kDefaultPadding` |

### Widget Architecture
- Create **small, private widget classes** instead of `Widget _buildSomething()` methods
- Prefer `StatelessWidget` unless local state is truly needed
- Use `ConsumerWidget` (Riverpod) for state-dependent widgets
- Use `HookConsumerWidget` when combining Riverpod + Flutter Hooks
- Lift state only as high as necessary; co-locate with consumers

---

## Project Structure

```
lib/
├── main.dart
├── app.dart                        # MaterialApp / root widget
├── core/
│   ├── theme/
│   │   ├── app_theme.dart          # ThemeData, ColorScheme
│   │   ├── app_colors.dart         # Raw color palette constants
│   │   └── app_typography.dart     # TextTheme definitions
│   ├── constants/
│   │   └── dimensions.dart         # Spacing, radius, icon size
│   ├── extensions/
│   │   ├── context_ext.dart        # BuildContext helpers
│   │   └── async_value_ext.dart    # AsyncValue UI helpers
│   ├── errors/
│   │   ├── failures.dart           # Domain failure types
│   │   └── exceptions.dart
│   └── utils/
├── features/
│   └── [feature_name]/
│       ├── presentation/
│       │   ├── screens/            # Full-page widgets
│       │   ├── widgets/            # Feature-specific widgets
│       │   └── providers/          # Riverpod UI providers
│       ├── domain/
│       │   ├── entities/           # Pure Dart models
│       │   ├── repositories/       # Abstract interfaces
│       │   └── usecases/           # Business logic
│       └── data/
│           ├── models/             # JSON-serializable models
│           ├── datasources/        # Remote & local data sources
│           └── repositories/       # Concrete implementations
└── shared/
    └── widgets/                    # App-wide reusable components
        ├── buttons/
        ├── cards/
        ├── inputs/
        └── layout/
```

---

## Clean Architecture Rules

### Layers & Dependencies
- **Presentation** → **Domain** ← **Data**  (dependencies always point inward)
- Domain layer: entities, repository interfaces, use cases — pure Dart, zero Flutter imports
- Data layer: models (`@JsonSerializable`), data sources, concrete repository implementations
- Presentation layer: widgets, screens, Riverpod providers

### Feature-First Organization
- Organize by **feature**, not by technical layer
- Each feature is self-contained with its own Presentation/Domain/Data
- Core or shared functionality lives in `core/` or `shared/`
- Features should have minimal cross-dependencies

### Repository Pattern
```dart
// domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<Either<Failure, User>> getUser(String id);
  Future<Either<Failure, List<User>>> getUsers();
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });
  // ...
}
```

---

## State Management (Riverpod)

### Provider Rules
- Use `@riverpod` annotation for code-generated providers
- Prefer `AsyncNotifierProvider` and `NotifierProvider` over `StateProvider`
- **Avoid**: `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`
- Use `ref.invalidate()` for manually triggering provider refreshes
- Implement proper cancellation of async operations when widgets are disposed
- Use `AsyncValue` for all async state — never manage `isLoading`/`error` booleans manually

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<User> build(String userId) async {
    return ref.watch(userRepositoryProvider).getUser(userId);
  }

  Future<void> updateName(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).updateName(name),
    );
  }
}
```

### AsyncValue in UI
```dart
ref.watch(userProvider(userId)).when(
  data: (user) => UserCard(user: user),
  loading: () => const UserCardSkeleton(),
  error: (e, st) => ErrorWidget(message: e.toString()),
);
```

---

## Models & Serialization

- Use `Freezed` for immutable state classes and unions
- Use `@JsonSerializable(fieldRename: FieldRename.snake)` for API models
- Use `@JsonKey(includeFromJson: true, includeToJson: false)` for read-only fields
- Include `createdAt`, `updatedAt` in database-backed models
- Run after modifying annotated classes:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
    @JsonKey(includeFromJson: true, includeToJson: false)
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

---

## UI & Styling Patterns

### Theme Setup (Material 3)
```dart
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(), // Replace with your font choice
    cardTheme: const CardTheme(
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
  );
}
```

### Context Extension
```dart
extension ContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
```

### Dimension Constants
```dart
// core/constants/dimensions.dart
const kSpacingXS = 4.0;
const kSpacingS  = 8.0;
const kSpacingM  = 16.0;
const kSpacingL  = 24.0;
const kSpacingXL = 32.0;
const kRadiusS   = 8.0;
const kRadiusM   = 12.0;
const kRadiusL   = 20.0;
const kRadiusXL  = 28.0;
```

### Responsive Layout
```dart
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.mobile, this.tablet});

  final Widget mobile;
  final Widget? tablet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= 600 && tablet != null ? tablet! : mobile,
    );
  }
}
```

---

## Navigation

- Use `GoRouter` or `auto_route` for navigation and deep linking
- Never use `Navigator.push` with raw `MaterialPageRoute` in feature code
- Define all routes in a central `router.dart` file

---

## Performance Rules

- Use `const` widgets wherever possible — prevents unnecessary rebuilds
- Use `ListView.builder` / `SliverList` for lists, never `Column` with `.map()`
- Use `AssetImage` for static images; `cached_network_image` for remote images
- Use `MediaQuery.sizeOf(context)` instead of `MediaQuery.of(context).size`
  to avoid full widget rebuilds on padding changes
- Never put heavy computation inside `build()` methods

---

## Error Handling

- Display errors using `SelectableText.rich` with red color for visibility
  (not `SnackBar` which can be missed)
- Use `Either<Failure, T>` from `fpdart` or `dartz` in domain/data layers
- Implement `errorBuilder` whenever using `Image.network`
- Handle `RefreshIndicator` for pull-to-refresh on list screens

---

## TextField Best Practices

Always configure these on every `TextField` / `TextFormField`:
```dart
TextField(
  textCapitalization: TextCapitalization.sentences,
  keyboardType: TextInputType.emailAddress, // match field purpose
  textInputAction: TextInputAction.next,    // or .done on last field
)
```

---

## Anti-Patterns to Avoid

| ❌ Don't | ✅ Do instead |
|---|---|
| `Widget _buildHeader()` in State | Extract `class _Header extends StatelessWidget` |
| `print('debug')` | `log('debug', name: 'FeatureName')` |
| `MediaQuery.of(context).size` | `MediaQuery.sizeOf(context)` |
| `Colors.blue` inline | `context.colors.primary` |
| `TextStyle(fontSize: 18, fontWeight: FontWeight.bold)` | `context.textTheme.titleMedium` |
| Hardcoded `16.0` everywhere | `kSpacingM` |
| `Column` with `.map().toList()` for long lists | `ListView.builder` |
| Business logic inside `build()` | Move to use case / notifier |
| `StateProvider` for complex state | `AsyncNotifierProvider` |
| Raw `Navigator.push(MaterialPageRoute(...))` | `GoRouter` / `context.push()` |
| `Image.network(url)` without `errorBuilder` | Always add `errorBuilder` |

---

## Output Format

When delivering Flutter UI, always provide:
1. **File list** — every file created/modified with its full path
2. **Complete code** — no TODOs, no placeholder comments, no `// implement this`
3. **Usage snippet** — how to integrate the widget into an existing screen
4. **pubspec.yaml additions** — any new packages required
5. **build_runner note** — if Freezed/JSON serialization annotations were added

---

*Built from: Anthropic claude-code `frontend-design` SKILL.md (v1.0.0) +
cursor.directory Flutter + Riverpod + Clean Architecture rules.*
