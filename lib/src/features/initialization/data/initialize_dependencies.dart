import 'dart:async';

import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:accessandrefreshtoken/src/common/constant/pubspec.yaml.g.dart';
import 'package:accessandrefreshtoken/src/common/controller/controller_observer.dart';
import 'package:accessandrefreshtoken/src/common/model/app_metadata.dart';
import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:accessandrefreshtoken/src/common/util/screen_util.dart';
import 'package:accessandrefreshtoken/src/features/authentication/controller/authentication_controller.dart';
import 'package:accessandrefreshtoken/src/features/authentication/data/authentication_repository.dart';
import 'package:accessandrefreshtoken/src/features/initialization/data/platform/platform_initialization.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:control/control.dart';
import 'package:dio/dio.dart';
import 'package:l/l.dart';
import 'package:platform_info/platform_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes the app and returns a [Dependencies] object
Future<Dependencies> $initializeDependencies({
  void Function(int progress, String message)? onProgress,
}) async {
  final dependencies = Dependencies();
  final totalSteps = _initializationSteps.length;
  var currentStep = 0;
  for (final step in _initializationSteps.entries) {
    try {
      currentStep++;
      final percent = (currentStep * 100 ~/ totalSteps).clamp(0, 100);
      onProgress?.call(percent, step.key);
      l.v6('Initialization | $currentStep/$totalSteps ($percent%) | "${step.key}"');
      await step.value(dependencies);
    } on Object catch (error, stackTrace) {
      l.e('Initialization failed at step "${step.key}": $error', stackTrace);
      Error.throwWithStackTrace('Initialization failed at step "${step.key}": $error', stackTrace);
    }
  }
  return dependencies;
}

typedef _InitializationStep = FutureOr<void> Function(Dependencies dependencies);

final Map<String, _InitializationStep> _initializationSteps = <String, _InitializationStep>{
  'Platform pre-initialization': (_) => $platformInitialization(),
  'Initialize sharedPreferences': (dependencies) async =>
      dependencies.sharedPreferences = await SharedPreferences.getInstance(),
  'Creating app metadata': (dependencies) => dependencies.metadata = AppMetadata(
    isWeb: platform.js,
    isRelease: platform.buildMode.release,
    appName: Pubspec.name,
    appVersion: Pubspec.version.representation,
    appVersionMajor: Pubspec.version.major,
    appVersionMinor: Pubspec.version.minor,
    appVersionPatch: Pubspec.version.patch,
    appBuildTimestamp: Pubspec.version.build.isNotEmpty
        ? (int.tryParse(Pubspec.version.build.firstOrNull ?? '-1') ?? -1)
        : -1,
    operatingSystem: platform.operatingSystem.name,
    processorsCount: platform.numberOfProcessors,
    appLaunchedTimestamp: DateTime.now(),
    locale: platform.locale,
    deviceVersion: platform.version,
    deviceScreenSize: ScreenUtil.screenSize().representation,
  ),
  'Observer state management': (_) => Controller.observer = const ControllerObserver(),
  'Initializing analytics': (_) {},
  'Log app open': (_) {},
  'Get remote config': (_) {},
  'Restore settings': (_) {},
  'Restore token storage': (dependencies) async {
    final tokenStorage = SharedPrefsTokenStorage(sharedPreferences: dependencies.sharedPreferences);
    await tokenStorage.restore(); // single disk read at startup
    dependencies.tokenStorage = tokenStorage;
  },
  'Initialize Dio': (dependencies) {
    // Create Dio first (bare), then attach interceptor that holds a reference to it.
    final dio = Dio(
      BaseOptions(
        baseUrl: Config.apiBaseUrl,
        connectTimeout: Config.apiConnectTimeout,
        receiveTimeout: Config.apiReceiveTimeout,
      ),
    );
    dio.interceptors.add(
      AuthenticationInterceptor(
        tokenStorage: dependencies.tokenStorage,
        dio: dio,
        // Lambda captures `dependencies` object — authenticationController is
        // read lazily at runtime (after full init), never during startup.
        onUnauthenticated: () => dependencies.authenticationController.logout(),
      ),
    );
    dependencies.dio = dio;
  },

  'Prepare authentication controller': (dependencies) {
    dependencies.authenticationController = AuthenticationController(
      repository: AuthenticationRepositoryImpl(
        dio: dependencies.dio,
        tokenStorage: dependencies.tokenStorage,
      ),
    );
  },
  'Restore session': (dependencies) => dependencies.authenticationController.restoreSession(),
};
