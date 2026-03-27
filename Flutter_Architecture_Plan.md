# Flutter Architecture & Development Plan
> **Role:** Senior Frontend & Mobile Engineer
> **Focus:** Scalable, Component-Driven, Performant Flutter Architecture
> **Platform Coverage:** Web + iOS + Android (single codebase, sole frontend)
> **Backend:** Node.js Fastify + PostgreSQL
> **SKILL.md Alignment:** Strictly follows Clean Architecture, Feature-First organization, Riverpod Codegen, and Freezed.

---

> **Note:** Flutter is the ONLY frontend for this project. There is no separate React webapp or any other web client. Flutter serves all three platforms — Web, iOS, and Android — from a single codebase. All UI, routing, state management, and offline logic described here apply universally across platforms.

---

## 1. Feature-First Clean Architecture

To ensure clarity, scalability, and maintainability, the application strictly follows a **Feature-First Clean Architecture** as mandated by `SKILL.md`.

Dependencies always point inward: **Presentation → Domain ← Data**.

### Folder Structure
```text
lib/
├── main.dart
├── app.dart                        # MaterialApp / root widget / GoRouter config
├── core/                           # Core utilities, constants, themes
│   ├── theme/
│   │   ├── app_theme.dart          # ThemeData (Material 3 + ColorScheme.fromSeed)
│   │   ├── app_colors.dart         # Raw color palette constants
│   │   └── app_typography.dart     # TextTheme definitions (Google Fonts)
│   ├── constants/
│   │   └── dimensions.dart         # Spacing, radius, icon size constants
│   ├── extensions/
│   │   ├── context_ext.dart        # BuildContext helpers (colors, textTheme)
│   │   └── async_value_ext.dart    # AsyncValue UI helpers
│   ├── network/                    # Dio client, socket.io client
│   └── errors/                     # Failure types and global error handling
├── features/
│   └── [feature_name]/             # e.g., auth, groups, expenses, settlements
│       ├── presentation/
│       │   ├── screens/            # Full-page widgets
│       │   ├── widgets/            # Feature-specific components
│       │   └── providers/          # @riverpod UI providers
│       ├── domain/
│       │   ├── entities/           # Pure Dart models (Freezed)
│       │   ├── repositories/       # Abstract interfaces
│       │   └── usecases/           # Business logic
│       └── data/
│           ├── models/             # API models (@JsonSerializable)
│           ├── datasources/        # Remote & local data sources
│           └── repositories/       # Concrete implementation of domain interfaces
└── shared/
    └── widgets/                    # App-wide reusable components
        ├── buttons/
        ├── inputs/
        └── layout/
```

---

## 2. State Management (Riverpod Codegen)

We exclusively use **Riverpod with Code Generation** (`@riverpod`). 

**Rules:**
- Use `AsyncNotifierProvider` and `NotifierProvider`.
- **FORBIDDEN:** `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`.
- Use `AsyncValue` for async state — never manage `isLoading`/`error` booleans manually.
- Use `ref.invalidate()` for manual refreshes.
- Provide state directly to components via `ConsumerWidget` or `HookConsumerWidget`.

**Example:**
```dart
@riverpod
class GroupNotifier extends _$GroupNotifier {
  @override
  Future<Group> build(String groupId) async {
    return ref.watch(groupRepositoryProvider).getGroup(groupId);
  }

  Future<void> updateGroup(Group group) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).updateGroup(group),
    );
  }
}
```

---

## 3. Models & Serialization (Freezed)

All entities and state models must use **Freezed** for immutability and unions. 
All data layer models interacting with the API must use `@JsonSerializable(fieldRename: FieldRename.snake)`.

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 4. UI, Styling & Aesthetics

### Theme (Material 3)
We use `ColorScheme.fromSeed` to enforce a cohesive aesthetic, avoiding hardcoded colors inline.
- **Typography:** `google_fonts` picking characterful fonts (e.g., `Inter` or `Outfit`).
- **Extensions:** Use `context.colors.primary` and `context.textTheme.titleMedium` via context extensions.

### Component Rules
- Small, private widget classes rather than `Widget _buildSomething()` methods.
- Use `const` constructors for all immutable widgets.
- No raw dimensions. Use predefined constants (`kSpacingM`, `kRadiusL`).
- Use `SelectableText.rich` with a distinct color for errors, over `SnackBar`s.

---

## 5. API Integration & Offline Strategy

### Data Sources
1. **Remote Data Source (Dio):** Handles REST API communication.
2. **Local Data Source (SQLite / Drift):** Handles offline queue and caching.
3. **Real-time (Socket.io):** Listens to live events, pushing updates into Riverpod `StreamProvider`s.

### Offline Queue
Write operations while offline write to the Local Data Source. A connectivity listener drains the queue (FIFO) via the Remote Data Source when the network is restored.

---

## 6. Core Packages

| Package | Purpose |
|---|---|
| `flutter_riverpod` + `riverpod_annotation` | State management (codegen) |
| `freezed` + `json_serializable` | Immutable models and JSON mapping |
| `go_router` | Declarative routing + deep links |
| `dio` | HTTP client for Fastify API |
| `socket_io_client` | Real-time communication with Fastify |
| `fpdart` | Functional programming (`Either<Failure, T>`) |
| `sqflite` (or `drift`) | SQLite local database |
| `google_fonts` | Typography |
| `connectivity_plus` | Network state detection |
| `build_runner` | Code generation |

---

## 7. Performance & Anti-Patterns

### ✅ DO:
- Use `const` widgets wherever possible.
- Use `ListView.builder` for lists.
- Use `MediaQuery.sizeOf(context)` instead of `MediaQuery.of(context).size`.
- Use descriptive variable names with auxiliary verbs (`isLoading`, `hasError`).
- Organize by Feature.

### ❌ DO NOT:
- Default to Roboto or generic Material aesthetics.
- Use `StateProvider` or manual `setState` for complex logic.
- Hardcode padding or colors inline (e.g., `16.0` or `Colors.blue`).
- Inject logic into `build()` methods.
- Put raw `Navigator.push()` inside features. Use `go_router`.

---

*This architecture plan is strictly aligned with the anthropic flutter frontend-design SKILL.md guidelines to produce production-grade, highly-maintainable, distinctive Flutter applications.*
