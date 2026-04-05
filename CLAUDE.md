# CLAUDE.md

Flutter app: access/refresh token auth + WebSocket (Laravel Reverb/Pusher).

## Structure

```
lib/src/
├── common/       # shared utils, router, localization, constants
└── features/     # authentication, initialization, home, account, settings, developer
```

Each feature: `controller/` `data/` `model/` `widget/` — **singular folder names**.

## Patterns

**Layers:** `widget → controller → data` — widgets never touch repositories directly.

**State:** handwritten sealed classes (`@freezed` is NOT used/commented out).

```dart
@immutable sealed class ExampleState {
  const factory ExampleState.idle() = Example$IdleState;
  const factory ExampleState.inProgress() = Example$InProgressState;
  const factory ExampleState.error(String? error) = Example$ErrorState;
  const factory ExampleState.completed(T result) = Example$CompletedState;
}
```

**Controller:** `StateController<TState>` + `DroppableControllerHandler` (mutations) or `SequentialControllerHandler` (load/watch).

```dart
class ExampleController extends StateController<ExampleState> with DroppableControllerHandler {
  ExampleController({required IExampleRepository repository}) : _repo = repository;
  void load() => handle(() async {
    setState(const ExampleState.inProgress());
    setState(ExampleState.completed(await _repo.fetch()));
  }, error: (e, st) async => setState(ExampleState.error(e.toString())));
}
```

**Repository:** interface + impl + fake.

```dart
abstract interface class IExampleRepository { Future<T> fetch(); }
class ExampleRepositoryImpl implements IExampleRepository { ... }
class ExampleFakeRepositoryImpl implements IExampleRepository { ... }
```

**Model:** `@immutable`, `copyWith` uses `ValueGetter<T?>` for nullable fields, manual `==`/`hashCode`.

```dart
SomeModel copyWith({int? id, ValueGetter<String?>? name}) => SomeModel(
  id: id ?? this.id, name: name != null ? name() : this.name);
```

**Scope widget:** `StatefulWidget` + private `_InheritedFeatureScope`. State listens via `addListener` → `setState`. Access: `ExampleScope.controllerOf(context)` / `stateOf(context, listen: true)`. `updateShouldNotify` uses `!identical(oldWidget.state, state)`.

**DI:** `Dependencies.of(context)` — service locator initialized at startup, all controllers as `late final` fields.

## Naming

`Feature$VariantState` · `IFeatureRepository` · `FeatureRepositoryImpl` · `FeatureFakeRepositoryImpl` · `FeatureScope` · `_InheritedFeatureScope` · `FeatureController`

## Key packages

`control` (PlugFox/control, git) · `octopus` (router) · `dio` · `dart_pusher_channels` · `shared_preferences` · `l` (logger)
**Not used:** provider, riverpod, bloc, get, mobx, freezed.

## Auth flow

Startup → `restoreSession()` reads token from SharedPreferences → `GET /api/auth/me` → `Authentication$AuthenticatedState`. Token auto-injected via Dio interceptor. Logout: best-effort `POST /api/auth/logout`, always clears token locally.

## Code gen

```bash
dart run build_runner build && dart format lib/
```

Never edit `*.g.dart` / `*.generated.dart` manually.
