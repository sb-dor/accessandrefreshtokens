import 'package:accessandrefreshtoken/src/common/router/authentication_guard.dart';
import 'package:accessandrefreshtoken/src/common/router/routes.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:flutter/widgets.dart' show State, StatefulWidget, ValueNotifier;
import 'package:octopus/octopus.dart';

mixin RouterStateMixin<T extends StatefulWidget> on State<T> {
  late final Octopus router;
  late final ValueNotifier<List<({Object error, StackTrace stackTrace})>> errorsObserver;

  @override
  void initState() {
    final dependencies = Dependencies.of(context);
    // Observe all errors.
    errorsObserver = ValueNotifier<List<({Object error, StackTrace stackTrace})>>(
      <({Object error, StackTrace stackTrace})>[],
    );

    // Create router.
    router = Octopus(
      routes: Routes.values,
      defaultRoute: Routes.home,
      guards: <IOctopusGuard>[
        // Check authentication.
        AuthenticationGuard(
          // Get current user from authentication controller.
          getUser: () async => dependencies.authenticationController.state.user,
          // Available routes for non authenticated user.
          routes: <String>{Routes.signin.name},
          // Default route for non authenticated user.
          signInNavigation: OctopusState.single(Routes.signin.node()),
          // Default route for authenticated user.
          homeNavigation: OctopusState.single(Routes.home.node()),
          // Check authentication on every authentication controller state change.
          // if you use bloc just navigate to the specific screen manually after states changes to Authenticated
          refresh: dependencies.authenticationController,
        ),
        // Home route should be always on top.
      ],
      onError: (error, stackTrace) =>
          errorsObserver.value = <({Object error, StackTrace stackTrace})>[
            (error: error, stackTrace: stackTrace),
            ...errorsObserver.value,
          ],
      /* observers: <NavigatorObserver>[
        HeroController(),
      ], */
    );
    super.initState();
  }
}
