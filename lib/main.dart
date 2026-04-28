import 'dart:async';

import 'package:accessandrefreshtoken/src/common/util/app_zone.dart';
import 'package:accessandrefreshtoken/src/common/util/error_util/error_util.dart';
import 'package:accessandrefreshtoken/src/common/widget/app_error.dart' deferred as app_error;
import 'package:accessandrefreshtoken/src/features/initialization/data/initialization.dart'
    deferred as initialization;
import 'package:accessandrefreshtoken/src/features/initialization/widget/app.dart';
import 'package:accessandrefreshtoken/src/features/settings/widget/settings_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:octopus/octopus.dart';
import 'package:platform_info/platform_info.dart';

void main() => appZone(() async {
  // Splash screen
  final initializationProgress = ValueNotifier<({int progress, String message})>((
    progress: 0,
    message: '',
  ));

  /// Calling runApp again will detach the previous root widget from the view and attach the given
  /// widget in its place. The new widget tree is compared against the previous widget tree and any
  /// differences are applied to the underlying render tree, similar to what happens when a StatefulWidget
  /// rebuilds after calling State.setState.
  // runApp(InitializationSplashScreen(progress: initializationProgress));

  /// to lazily load library:
  /// checkout: https://dart.dev/language/libraries#lazily-loading-a-library
  await initialization.loadLibrary();
  initialization
      .$initializeApp(
        onProgress: (progress, message) =>
            initializationProgress.value = (progress: progress, message: message),
        onSuccess: (dependencies) async => runApp(
          dependencies.inject(
            child: SettingsScope(
              child: NoAnimationScope(
                noAnimation: platform.js || platform.desktop,
                child: const App(),
              ),
            ),
          ),
        ),
        onError: (error, stackTrace) async {
          /// to lazily load library:
          /// checkout: https://dart.dev/language/libraries#lazily-loading-a-library
          await app_error.loadLibrary();
          runApp(app_error.AppError(error: error));
          ErrorUtil.logError(error, stackTrace).ignore();
        },
      )
      .ignore();
});
