// ignore_for_file: avoid_classes_with_only_static_members

/// Config for app.
abstract final class Config {
  // --- ENVIRONMENT --- //

  /// Environment flavor.
  /// e.g. development, staging, production
  static final EnvironmentFlavor environment = EnvironmentFlavor.from(
    const String.fromEnvironment('ENVIRONMENT', defaultValue: 'development'),
  );

  static const bool alpha = bool.fromEnvironment('ALPHA', defaultValue: false);

  static const bool beta = bool.fromEnvironment('BETA', defaultValue: false);

  // --- API --- //

  /// Base url for api.
  /// e.g. http://localhost:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // --- WEBSOCKET (Reverb) --- //

  /// Reverb / Pusher app key (matches REVERB_APP_KEY in backend .env).
  static const String wsKey = String.fromEnvironment('WS_KEY', defaultValue: '');

  /// Reverb WebSocket host.
  static const String wsHost = String.fromEnvironment('WS_HOST', defaultValue: 'localhost');

  /// Reverb WebSocket port.
  static const int wsPort = int.fromEnvironment('WS_PORT', defaultValue: 8080);

  /// Use TLS for WebSocket (false in dev, true in prod).
  static const bool wsTls = bool.fromEnvironment('WS_TLS', defaultValue: false);

  /// Timeout in milliseconds for opening url.
  /// [Dio] will throw the [DioException] with [DioExceptionType.connectTimeout] type when time out.
  /// e.g. 15000
  static const Duration apiConnectTimeout = Duration(
    milliseconds: int.fromEnvironment('API_CONNECT_TIMEOUT', defaultValue: 15000),
  );

  /// Timeout in milliseconds for receiving datasources from url.
  /// [Dio] will throw the [DioException] with [DioExceptionType.receiveTimeout] type when time out.
  /// e.g. 10000
  static const Duration apiReceiveTimeout = Duration(
    milliseconds: int.fromEnvironment('API_RECEIVE_TIMEOUT', defaultValue: 10000),
  );

  /// Cache lifetime.
  /// Refetch datasources from url when cache is expired.
  /// e.g. 1 hour
  static const Duration cacheLifetime = Duration(hours: 1);

  // --- DATABASE --- //

  /// Database file name by default.
  /// e.g. sqlite means "sqlite.db" for native platforms and "sqlite" for web platform.
  static const String databaseName = String.fromEnvironment(
    'DATABASE_NAME',
    defaultValue: 'sqlite',
  );

  /// Whether to use in-memory database.
  static const bool inMemoryDatabase = bool.fromEnvironment(
    'IN_MEMORY_DATABASE',
    defaultValue: false,
  );

  // --- AUTHENTICATION --- //

  /// Minimum length of password.
  /// e.g. 8
  static const int passwordMinLength = int.fromEnvironment('PASSWORD_MIN_LENGTH', defaultValue: 6);

  /// Maximum length of password.
  /// e.g. 32
  static const int passwordMaxLength = int.fromEnvironment('PASSWORD_MAX_LENGTH', defaultValue: 32);

  // --- LAYOUT --- //

  /// Maximum screen layout width for screen with list view.
  static const int maxScreenLayoutWidth = int.fromEnvironment(
    'MAX_LAYOUT_WIDTH',
    defaultValue: 768,
  );
}

/// Environment flavor.
/// e.g. development, staging, production
enum EnvironmentFlavor {
  /// Development
  development('development'),
  production('production');

  /// Create environment flavor.
  const EnvironmentFlavor(this.value);

  /// Create environment flavor from string.
  factory EnvironmentFlavor.from(String? value) => switch (value?.trim().toLowerCase()) {
    'development' || 'debug' || 'develop' || 'dev' => development,
    'production' || 'release' || 'prod' || 'prd' => production,
    _ => const bool.fromEnvironment('dart.vm.product') ? production : development,
  };

  /// development, staging, production
  final String value;

  /// Whether the environment is development.
  bool get isDevelopment => this == development;

  /// Whether the environment is production.
  bool get isProduction => this == production;
}
