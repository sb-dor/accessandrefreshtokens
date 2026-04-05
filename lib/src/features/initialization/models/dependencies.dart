import 'package:accessandrefreshtoken/src/common/model/app_metadata.dart';
import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:accessandrefreshtoken/src/features/authentication/controller/authentication_controller.dart';
import 'package:accessandrefreshtoken/src/features/initialization/widget/dependencies_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template dependencies}
/// Application dependencies.
/// {@endtemplate}
class Dependencies {
  /// {@macro dependencies}
  Dependencies();

  /// The state from the closest instance of this class.
  ///
  /// {@macro dependencies}
  factory Dependencies.of(BuildContext context) => DependenciesScope.of(context);

  /// Injest dependencies to the widget tree.
  Widget inject({required Widget child, Key? key}) =>
      DependenciesScope(dependencies: this, key: key, child: child);

  late final SharedPreferences sharedPreferences;

  /// Token storage — in-memory cache backed by SharedPreferences
  late final ITokenStorage tokenStorage;

  /// App metadata
  late final AppMetadata metadata;

  /// Shared Dio HTTP client (base URL + auth interceptor)
  late final Dio dio;

  /// Authentication controller
  late final AuthenticationController authenticationController;

  @override
  String toString() => 'Dependencies{}';
}

/// Fake Dependencies
@visibleForTesting
class FakeDependencies extends Dependencies {
  FakeDependencies();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // ... implement fake dependencies
    throw UnimplementedError();
  }
}
