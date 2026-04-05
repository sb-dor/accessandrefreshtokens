/// A mixin that provides safe, ordered resource cleanup via a closure chain.
///
/// Dart has no built-in `defer` (Go), `RAII` (C++), or `using` (C#).
/// This mixin builds the equivalent: each [defer] call wraps the previous
/// cleanup into a linked chain — so resources are always released in
/// reverse registration order (LIFO), and a failure in one cleanup
/// never prevents the rest from running.
///
/// Usage:
/// ```dart
/// class MyController with Disposable {
///   Future<void> init() async {
///     // Step 1 — open DB and immediately register its cleanup.
///     // If anything fails after this point, db.close() is guaranteed to run.
///     final db = await Database.open();
///     defer(() => db.close());
///
///     // Step 2 — connect WebSocket and register its cleanup.
///     // disposeResources() will run ws.close() first, then db.close().
///     final ws = await WebSocket.connect(url);
///     defer(() => ws.close());
///
///     // Step 3 — bail out early if the widget is already gone.
///     // disposeResources() unwinds only what was initialized so far:
///     //   ws.close() → db.close()
///     // Steps that never ran have nothing to clean up.
///     if (!mounted) {
///       await disposeResources();
///       return;
///     }
///
///     // Step 4 — happy path: everything is up, register the rest.
///     // Full cleanup order: ws.close() → db.close()
///     _isInitialized = true;
///   }
///
///   @override
///   void dispose() {
///     // Called by Flutter when the widget is removed from the tree.
///     // unawaited() is intentional — Flutter's dispose() is synchronous,
///     // so we fire the async chain and let it finish in the background.
///     unawaited(disposeResources());
///     super.dispose();
///   }
/// }
/// ```
mixin Disposable {
  // Sentinel no-op that terminates the cleanup chain.
  static Future<void> _noOp() async {}

  // Guards against double-dispose.
  bool _disposed = false;

  // Head of the cleanup chain. Each defer() wraps this with a new closure.
  Future<void> Function() _dispose = _noOp;

  /// Registers [fn] as the next cleanup step.
  ///
  /// Cleanups are executed in LIFO order — the last deferred runs first.
  /// Safe to call at any point during initialization; silently ignored
  /// if [disposeResources] has already been called.
  void defer(Future<void> Function() fn) {
    if (_disposed) return;

    final prev = _dispose;

    // Wrap fn() around the existing chain.
    // try/finally guarantees prev() runs even if fn() throws.
    _dispose = () async {
      try {
        await fn();
      } finally {
        await prev(); // walk down the chain
      }
    };
  }

  /// Runs all registered cleanups in reverse order, then marks this
  /// instance as disposed.
  ///
  /// Idempotent — safe to call multiple times; only the first call
  /// has any effect. The chain is cleared before execution to prevent
  /// re-entry if an async cleanup triggers a second dispose() call.
  Future<void> disposeResources() async {
    if (_disposed) return;
    _disposed = true;

    // Atomically swap out the chain before invoking it,
    // so a second concurrent call finds _noOp instead of a live chain.
    final disposeFn = _dispose;
    _dispose = _noOp;

    await disposeFn();
  }
}
