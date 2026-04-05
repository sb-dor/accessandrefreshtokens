# AI Instructions

## AI Identity

You are an expert in Flutter and Dart development. Your goal is to build beautiful, performant, and maintainable applications following modern best practices. You have expert experience with application writing, testing, and running Flutter applications for various platforms, including desktop, web, and mobile platforms.

## Token Economy

Be concise and efficient in every response. Do not repeat information the user already knows, do not summarize what you just did, do not add filler text or preamble. Go straight to the point. Only output what is necessary: code changes, brief status updates, blockers, or decisions that need input. Shorter responses are better than longer ones when both convey the same information.

---

# Flutter Architecture Analysis

## Overview

This document analyzes the clean architecture implementation in this Flutter application, focusing on the example feature as an example. The application follows a well-structured clean architecture pattern with clear separation of concerns.

---

## Project Structure

### Project `lib` Folder Structure

The `lib` folder must follow this top-level structure:

```
lib/
├── main.dart
└── src/
    ├── common/       # shared utilities, widgets, database, constants, etc.
    └── feature/      # one sub-folder per feature
```

**Rules:**

- `lib/main.dart` must always exist as the app entry point.
- `lib/src/` must always exist. All source code lives inside `src/` — nothing else goes directly under `lib/` except `main.dart`.
- `lib/src/common/` must always exist for shared code (database, router, constants, models, utilities, common widgets).
- `lib/src/feature/` must always exist and contains one sub-folder per feature.
- **If these folders already exist, do not recreate or restructure them.** Only create what is genuinely missing.
- Never place feature code directly under `lib/src/` — every feature gets its own named folder inside `lib/src/feature/`.

### Feature Structure Analysis: Example

#### Directory Structure

```
example/
├── controller/
│   └── example_controller.dart
├── data/
│   └── example_repository.dart
├── models/
│   ├── example.dart
│   ├── example_other_1.dart
│   ├── example_other_2.dart
│   ├── example_other_3.dart
│   └── ...
└── widgets/
    ├── controllers/
    │   └── example_data_controller.dart
    ├── desktop/example_desktop_widget.dart
    ├── mobile/example_mobile_widget.dart
    ├── tablet/example_tablet_widget.dart
    └── example_config_widget.dart
```

#### Layer Integration

1. **UI Layer**: `example_config_widget.dart` initializes and manages feature controllers
2. **Presentation Layer**: `example_data_controller.dart` manages UI state
3. \*\*Business Logic Layer: `example_controller.dart` handles business logic and state
4. **Data Layer**: `example_repository.dart` handles data operations
5. **Model Layer**: `example.dart` represents domain entities

---

## Clean Architecture Layers

### 1. Data Layer (`data/`)

The data layer handles data operations and implements repositories that interact with external sources.

#### Example: `example_repository.dart`

```dart
// Interface definition
abstract interface class IExampleRepository {
  Future<List<Example>> example({...});
}

// Implementation
final class ExampleRepositoryImpl implements IExampleRepository {
  ExampleRepositoryImpl({required final ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Example>> example({...}) async {
    // API call implementation
    final response = await _apiClient.get(endpoint, queryParameters: queryParameters);
    // Data transformation logic
  }
}
```

**Key Patterns:**

- Abstract interfaces for testability
- Dependency injection through constructor
- API client abstraction
- Data transformation using converters

### Stream-Returning Methods in Repositories

Repository methods that return `Stream<T>` must always guarantee the stream is eventually closed. Never return a bare `StreamController.stream` without a close path — it leaks resources.

#### Pattern 1 — `onListen` / `onCancel` (lazy, resource-safe)

Code runs only when someone starts listening. Resources are released when the subscriber cancels.

```dart
Stream<R> fn() {
  final controller = StreamController<R>();
  controller
    ..onListen = () {
      // Start emitting values only when the stream is listened to.
      if (!controller.isClosed) controller.add(/* value of type R */);
    }
    ..onCancel = () {
      // Clean up resources when the stream is cancelled.
      if (!controller.isClosed) controller.close();
    };
  return controller.stream;
}
```

Add a mutex or boolean flag to guarantee `close()` is never called while `onListen` is still executing, and to break any loop inside `onListen` when cancellation occurs.

#### Pattern 2 — `async Future` wrapper (simpler, more readable)

The entire emission logic lives in an async closure. The `finally` block guarantees `close()` is always called.

```dart
Stream<R> fn() {
  final controller = StreamController<R>();
  Future<void>(() async {
    try {
      // Your emission logic here, e.g. a for(;;) loop.
      controller.add(r);
    } on Object catch (e, s) {
      controller.addError(e, s);
    } finally {
      controller.close();
    }
  }).ignore();
  return controller.stream;
}
```

The async body can also be placed entirely inside `onListen` instead of a standalone `Future`.

#### One-shot helpers

For simple cases prefer the built-in constructors over a manual controller:

```dart
Stream.value(r)               // single value then done
Stream.fromFuture(future)     // single async value then done
Stream.fromFutures([f1, f2])  // multiple async values then done
```

#### Rule

Every `Stream`-returning repository method must use one of the patterns above. A `StreamController` with no guaranteed `close()` path is always wrong.

---

### 2. Model Layer (`models/`)

Models represent business entities and are immutable.

#### Example: `example.dart` (optional)

```dart
@immutable
class Example {
  const Example({
    required this.id,
    this.exampleId,
    this.example,
    // ... other properties
  });

  // Properties
  final int id;
  final int? exampleId;
  // ... other fields

  // Copy with method for immutability
 Example copyWith({...}) {
    return Example(
      id: id ?? this.id,
      // ... other fields
    );
  }
}
```

**Key Patterns:**

- Immutable design with `@immutable` annotation
- `copyWith` method for functional updates

### Model CopyWith Pattern

For models that use the `copyWith` method, they must use the `ValueGetter` function from the foundation package for optional parameters. This ensures proper null-safety and functional updates:

```dart
Example copyWith({
  int? id,
  ValueGetter<double?>? parameter_1,
  ValueGetter<double?>? parameter_2,
  ValueGetter<double?>? invoicesQty,
  ValueGetter<double?>? returnsTotal,
  ValueGetter<double?>? returnsQty,
  ValueGetter<double?>? paymentsTotal,
  ValueGetter<double?>? paymentsQty,
  ValueGetter<double?>? grandTotal,
  // ... other parameters
}) {
  return Example(
    id: id ?? this.id,
    parameter_1: parameter_1 != null ? parameter_1() : this.parameter_1,
    parameter_2: parameter_2 != null ? parameter_2() : this.parameter_2,
    invoicesQty: invoicesQty != null ? invoicesQty() : this.invoicesQty,
    returnsTotal: returnsTotal != null ? returnsTotal() : this.returnsTotal,
    returnsQty: returnsQty != null ? returnsQty() : this.returnsQty,
    paymentsTotal: paymentsTotal != null ? paymentsTotal() : this.paymentsTotal,
    paymentsQty: paymentsQty != null ? paymentsQty() : this.paymentsQty,
    grandTotal: grandTotal != null ? grandTotal() : this.grandTotal,
    // ... assign other parameters
  );
}
```

---

### 3. Controller Layer (`controller/`)

Controllers manage state and business logic using reactive programming patterns.

#### Example: `example_controller.dart` (required)

```dart
@freezed
sealed class ExampleState with _$ExampleState {
  const factory ExampleState.initial() = Example$InitialState;

  const factory ExampleState.inProgress() = Example$InProgressState;

  const factory ExampleState.error() = Example$ErrorState;

  const factory ExampleState.completed({...}) =
      Example$CompletedState;
}

final class ExampleController extends StateController<ExampleState>
    with SequentialControllerHandler {
  ExampleController({
    required final IExampleRepository exampleRepository,
    super.initialState = const ExampleState.initial(),
  }) : _iExampleRepository = exampleRepository;

  final IExampleRepository _iExampleRepository;

  void load({...}) => handle(() async {
    setState(const ExampleState.inProgress());

    final example = await _iExampleRepository.example({...});

    setState(
      ExampleState.completed(),
    );
  }, error: (error, stackTrace) async => setState(const ExampleState.error()));
}
```

**Key Patterns:**

- Freezed for immutable state management
- Dependency injection through constructor
- Sequential handling to prevent race conditions
- State management with loading/error/completed states

### Single Responsibility Principle for Features and Controllers

Every feature folder and every controller must have **one clearly defined domain responsibility**. A responsibility is not a single function — it is a single domain concern.

#### What "one responsibility" means

A controller may have multiple methods as long as they all serve the same domain concern:

```dart
// ✅ Correct — AuthenticationController has one responsibility: managing auth state.
// signIn, signOut, checkToken all answer the same question: "is this user authenticated?"
class AuthenticationController {
  void signIn({required String username, required String password}) => ...
  void signOut() => ...
  void checkToken() => ...
}
```

This is fine. All three methods are facets of the same concern. Splitting them into three separate features would be over-engineering.

#### When to split into separate features

Split when two things have **genuinely independent UI state machines** or **no logical connection at the domain level**.

The quick replies functionality is split into three features because each has a distinct concern:

```
example_list/          → "Provide the reactive list of quick replies to the UI"
example_creation/   → "Manage the create/edit form lifecycle (inProgress, completed, error)"
example_deletion/   → "Manage the delete confirmation lifecycle (inProgress, completed, error)"
```

The creation form and the deletion dialog each need their own `inProgress` / `completed` / `error` state independently. If they shared one controller, a deletion in progress could overwrite the creation form's state — causing wrong UI feedback and broken `PopScope` behaviour. The list (watching a stream) has no state overlap with either mutation. These are separate concerns, so they are separate features.

#### The pattern for mutation features (creation, deletion)

Each mutation feature follows this exact structure:

```
feature_name/
├── data/feature_name_repository.dart      (interface + impl)
├── controller/feature_name_controller.dart (freezed states + handle())
└── widgets/
    ├── feature_name_config_widget.dart    (InheritedWidget scope + static factory)
    └── feature_name_dialog_widget.dart    (form/confirmation UI)
```

**Controller** uses `DroppableControllerHandler` for mutations so duplicate taps are dropped:

```dart
class ExampleCreationController extends StateController<ExampleCreationState>
    with DroppableControllerHandler {

  void save({required String title, required String content, int? workerId, Example? existing}) =>
      handle(() async {
        setState(const ExampleCreationState.inProgress());
        final result = await _repo.save(title: title, content: content, existing: existing);
        setState(ExampleCreationState.completed(result));
      }, error: (e, st) async => setState(const ExampleCreationState.error()));
}
```

Use `SequentialControllerHandler` for load/watch operations.

**Config widget** owns the controller lifecycle and exposes a static factory so callers need only one line:

```dart
class ExampleCreationConfigWidget extends StatefulWidget {
  static Future<void> showCreationDialog(BuildContext context, {Example? existing}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ExampleCreationConfigWidget(
        builder: (_) => ExampleCreationDialogWidget(existing: existing),
      ),
    );
  }
  // ...
}
```

**Dialog widget** uses `StateConsumer` to close itself on completion and `PopScope` to block dismissal mid-flight:

```dart
StateConsumer<ExampleCreationController, ExampleCreationState>(
  controller: _controller,
  listener: (context, controller, oldState, newState) {
    if (newState is ExampleCreation$CompletedState) Navigator.pop(context);
  },
  builder: (context, state, child) => PopScope(
    canPop: state is! ExampleCreation$InProgressState,
    child: AlertDialog(...),
  ),
);
```

**Calling site** only uses the static factory — no knowledge of internals:

```dart
ExampleCreationConfigWidget.showCreationDialog(context);
ExampleCreationConfigWidget.showCreationDialog(context, existing: example);
ExampleDeletionConfigWidget.showDeletionDialog(context, example);
```

#### Rules to always follow

- **Group by domain concern, not by function count.** A controller with three related methods is fine. A controller with two unrelated concerns must be split.
- **Create and update may share one feature** when they are conceptually the same action (both write the same record). The create-vs-update decision belongs in the repository, not the controller or widget.
- **Split when UI states are independent.** If two operations each need their own `inProgress` / `completed` / `error` displayed simultaneously or to different widgets, they need separate controllers and separate features.
- **Config widgets own controller lifecycle** — created in `initState`, disposed in `dispose`, never elsewhere.
- **Static factory methods on config widgets** keep all wiring internal and give callers a one-line API.
- **`DroppableControllerHandler`** for mutations. **`SequentialControllerHandler`** for load/watch.
- **`PopScope(canPop: state is! ...InProgressState)`** on every dialog with an async operation.

### Multiple Controllers per Feature

When a feature contains async operations with **different concurrency requirements**, split them into separate controllers — one per async concern. This is correct architecture, not over-engineering.

#### When to split controllers within one feature

Split when two groups of async operations:

- Need different concurrency handlers (`DroppableControllerHandler` vs `SequentialControllerHandler`), or
- Maintain genuinely independent state that must update simultaneously without one overwriting the other.

#### Example — call feature

```
call/controller/
├── call_controller.dart
├── call_media_controller.dart
└── call_members_controller.dart
```

Each controller handles one async concern. `CallMediaController` uses `Droppable` so rapid taps are dropped. `CallController` uses `Sequential` so join and leave are never interleaved. Sharing one controller would force a single concurrency strategy on all three — wrong for at least two of them.

#### Coordination rule

Controllers within the same feature must **never import or depend on each other**. Coordinate them in the **widget layer** via `addListener` or `StateConsumer`'s `listener` parameter. The widget reacts to one controller's state and calls methods on another.

```dart
// ✅ Widget layer coordinates — controllers stay decoupled
callController.addListener(() {
  if (callController.state is Call$IdleState) {
    callMembersController.reset();
    callMediaController.reset();
  }
});
```

---

### 4. Widgets Layer (`widgets/`)

The presentation layer handles UI rendering and user interaction.

#### Example: `example_config_widget.dart`

```dart
/// Inherited widgets that provides access to ExampleConfigWidgetState throughout the widgets tree.
class ExampleConfigInhWidget extends InheritedWidget {
  const ExampleConfigInhWidget({super.key, required this.state, required super.child});

  static ExampleConfigWidgetState of(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<ExampleConfigInhWidget>()
        ?.widget;
    assert(widget != null, 'ExampleConfigInhWidget was not found in element tree');
    return (widget as ExampleConfigInhWidget).state;
  }

  final ExampleConfigWidgetState state;

  @override
  bool updateShouldNotify(ExampleConfigInhWidget old) {
    return false;
  }
}

class ExampleConfigWidget extends StatefulWidget {
  const ExampleConfigWidget();
  // Implementation details

  @override
  State<ExampleConfigWidget> createState() => ExampleConfigWidgetState();
}

class ExampleConfigWidgetState extends State<ExampleConfigWidget> {
  // Controller initialization and lifecycle management
  late final ExampleController exampleController;

  @override
  void initState() {
    super.initState();
    final dependencies = DependenciesScope.of(context);
    _authenticationController = dependencies.authenticationController;
    _authenticationListener();
    _authenticationController.addListener(_authenticationListener);
  }

  @override
  void dispose() {
    _authenticationController.removeListener(_authenticationListener);
    exampleController.dispose();
    super.dispose();
  }

  void _authenticationListener() {
    // Initialize controller based on authentication state
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicatorWidget())
        : ExampleConfigInhWidget(
            state: this,
            child: context.screenSizeMaybeWhen(
              orElse: () => const ExampleDesktopWidget(),
              phone: () => const ExampleMobileWidget(),
            ),
          );
  }
}
```

**Key Patterns:**

- InheritedWidget for dependency propagation
- Proper lifecycle management with disposal
- Responsive UI based on screen size
- Authentication-aware initialization

#### Example: `example_data_controller.dart` (UI State Management)

```dart
class ExampleDataController with ChangeNotifier {
  ///
  ///
  /// not optional - it's just for an example
  String? _from;

  String? _to;

  String? get from => _from;

  String? get to => _to;

  final List<Example> _selectedExamples = [];

  List<Example> get selectedExamples => _selectedExamples;

  void addExample(final Example example) {
    _selectedExamples.add(example);
    notifyListeners()
  }
}
```

**Key Patterns:**

- Uses `ChangeNotifier` mixin for UI state management
- Different from `example_controller.dart` which manages asynchronous operations and application state
- `example_data_controller.dart` specifically manages UI-related state
- Provides getter methods for accessing state values
- Uses `notifyListeners()` to trigger UI updates when state changes
- Includes proper lifecycle management with disposal considerations
- Do not use other state solutions like these packages: Provider, Riverpod, Mobx, Getx, BloC for UI state management for widgets folder

### Accessing Dependencies Through Inherited Widgets

To access dependencies that were initialized inside the `ExampleConfigWidget`, use the `ExampleConfigInhWidget.of(context)` pattern. For example, if you have an `ExampleMobileWidget` that needs to access the `ExampleDataController` initialized in the `ExampleConfigWidget`:

```dart
class ExampleMobileWidget extends StatefulWidget {
  const ExampleMobileWidget({super.key});

  @override
  State<ExampleMobileWidget> createState() =>
      _ExampleMobileWidgetState();
}

class _ExampleMobileWidgetState
    extends State<ExampleMobileWidget> {
  late final _exampleInhWidget = ExampleConfigInhWidget.of(
    context,
  );

  late final _exampleDataController =
      _exampleInhWidget.exampleDataController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _exampleDataController,
      builder: (context, child) {
        // Build UI based on the controller's state
        return Container(
          // Your widget implementation
        );
      },
    );
  }
}
```

### Modern Dart Constructor Syntax

Use the modern Dart syntax for calling the parent constructor in the super parameter. Instead of the old approach of extending child constructors with explicit `super()` calls, you can now use the `super()` named parameter directly:

```dart
// Modern approach
const ExampleMobileWidget({super.key});

// Rather than the older approach which required more verbose syntax
```

### Using ListenableBuilder for ChangeNotifier

When listening to an `ExampleDataController` (which extends `ChangeNotifier`), use `ListenableBuilder` instead of `ValueListenableBuilder`. `ListenableBuilder` is designed for objects that extend `Listenable` (like `ChangeNotifier`), while `ValueListenableBuilder` is specifically for `ValueNotifier`:

```dart
// Correct approach for ChangeNotifier
ListenableBuilder(
  listenable: exampleDataController,
  builder: (context, child) {
    // Return your widget here
    return YourWidget();
  },
)

// Rather than ValueListenableBuilder which is for ValueNotifier
```

---

## Dependency Injection Patterns

### Global Dependency Injection

The application uses a global dependency injection system through `DependenciesScope`:

#### `Dependencies` Class

```dart
class Dependencies {
  late final AppMetadata metadata;
  late final SharedPreferences sharedPreferences;
  late final AppDatabase database;
  late final ApiClient apiClient;
  late final InternetConnectionController internetConnectionController;
  // ... other dependencies

  Widget inject({required Widget child, Key? key}) =>
      DependenciesScope(dependencies: this, key: key, child: child);
}
```

#### `DependenciesScope` Widget

```dart
class DependenciesScope extends InheritedWidget {
  const DependenciesScope({required this.dependencies, required super.child, super.key});

  final Dependencies dependencies;

  static Dependencies of(BuildContext context) =>
      maybeOf(context) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant DependenciesScope oldWidget) => false;
}
```

### Feature-Level Dependency Injection

Features use their own configuration widgets to initialize and provide controllers:

#### `example_config_widget.dart` (Dependency Initialization)

```dart
void _authenticationListener() {
  final authenticationState = _authenticationController.state;
  if (authenticationState is Authentication$AuthenticatedState && isLoading) {
    /// initializations for Authanticated state
  }
}
```

### Scope Management with Inherited Widgets

#### InheritedWidget Pattern

The application uses InheritedWidget for efficient state propagation:

```dart
// Custom InheritedWidget for feature-specific state
class ExampleConfigInhWidget extends InheritedWidget {
  const ExampleConfigInhWidget({super.key, required this.state, required super.child});

  static ExampleConfigWidgetState of(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<ExampleConfigInhWidget>()
        ?.widget;
    assert(widget != null, 'ExampleConfigInhWidget was not found in element tree');
    return (widget as ExampleConfigInhWidget).state;
  }

  final ExampleConfigWidgetState state;

  @override
  bool updateShouldNotify(ExampleConfigInhWidget old) {
    return false; // Prevent unnecessary rebuilds
 }
}
```

#### Global Scope with DependenciesScope

Global dependencies are provided through the DependenciesScope:

```dart
// In main app setup
dependencies.inject(child: MaterialApp(...))

// In widgets accessing dependencies
final deps = DependenciesScope.of(context);
```

### Interface Usage and DI Concepts

#### Interface-Based Design

The application extensively uses interfaces for loose coupling:

```dart
// Repository interfaces
abstract interface class IExampleRepository {...}
abstract interface class IProductsRepository {...}
abstract interface class IExampleBalanceRepository {...}

// Controller interfaces (when applicable)
```

#### Constructor-Based Dependency Injection

Dependencies are injected through constructors:

```dart
// Repository implementation receives API client
ExampleRepositoryImpl({required final ApiClient apiClient}) : _apiClient = apiClient;

// Controller receives repository interface
ExampleController({
  required final IExampleRepository exampleRepository,
  // ...
})

// Widget receives dependencies through scope
dependencies = DependenciesScope.of(context);
```

---

## Best Practices Observed

### 1. Separation of Concerns

- Each layer has a clear responsibility
- Models handle data representation
- Controllers manage business logic and state
- Repositories handle data operations
- Widgets handle presentation

#### Strict Layer Dependency Rule

Within a single feature, the dependency direction is strictly one-way:

```
widgets  →  controller  →  data (repository)
```

**Widgets must never access repositories directly.** All data operations go through the controller. The controller is the only layer that depends on the data layer. Widgets depend only on the controller layer.

**Wrong — widget accessing repository directly:**

```dart
// ❌ NEVER do this inside a widget or widget state
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    final deps = Dependencies.of(context);
    // Directly calling a repository from a widget — violates separation of concerns
    deps.someRepository.loadData();
  }
}
```

**Correct — widget depends only on controller:**

```dart
// ✅ Correct approach
class _MyWidgetState extends State<MyWidget> {
  late final _scope = MyConfigInhWidget.of(context);
  late final _controller = _scope.myController;

  @override
  void initState() {
    super.initState();
    _controller.load(); // controller handles all data access internally
  }
}
```

The controller encapsulates all repository calls. If a widget needs data (e.g. quick replies, workers, settings), that data must be fetched inside the controller and exposed via state or a getter — never fetched by the widget itself.

This rule applies everywhere: `StatefulWidget` states, `StatelessWidget` build methods, `InheritedWidget` config states, and data controllers (`ChangeNotifier`-based UI controllers). None of these should hold a reference to any `Repository` class.

### 2. Testability

- Interface-based design enables mocking
- Constructor injection enables easy testing
- Immutable models reduce side effects

### 3. Maintainability

- Consistent naming conventions
- Clear directory structure
- Proper separation of business logic from UI

### 4. Performance

- Efficient InheritedWidget usage
- Proper disposal of resources
- Lazy loading where appropriate

---

## Development Notes

### Generated Files

When working with this architecture, be aware of generated Dart files that should be ignored in version control and manual editing:

- Files ending with `.freezed.dart` (generated by the `freezed` package)
- Files ending with `.g.dart` (generated by various packages like `json_annotation`, `injectable`, etc.)
- Any other files with the `.g.dart` suffix
- Other generated files following the pattern `[filename].generated.dart`

These files should be added to your `.gitignore` file and should never be manually modified, as they are automatically regenerated by build runners.

### Build Runner Command

After creating a new feature or making changes that require code generation (such as adding new Freezed classes, JSON serialization annotations, or other annotated classes), run these following commands to generate the required files:

```bash
dart run build_runner build && dart format lib/
```

This command will generate all necessary files based on annotations in your code, such as Freezed classes, JSON serializers, and other generated code.

---

## Conclusion

This Flutter application demonstrates a well-implemented clean architecture with:

- Clear separation of concerns across data, domain, and presentation layers
- Comprehensive dependency injection using both global and feature-level approaches
- Effective use of InheritedWidget for state management and dependency propagation
- Consistent patterns across all features
- Proper lifecycle management and resource disposal

The example feature serves as an excellent example of how the architecture principles are applied consistently throughout the application, maintaining scalability and maintainability while following Flutter best practices.
