import 'package:accessandrefreshtoken/src/common/router/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:octopus/octopus.dart';

/// {@template home_screen}
/// HomeScreen — redirects to lobby.
/// {@endtemplate}
class HomeScreen extends StatelessWidget {
  /// {@macro home_screen}
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Octopus.of(context).setState(
        (state) => state
          ..removeWhere((n) => n.name == Routes.home.name)
          ..add(Routes.home.node()),
      );
    });
    return const SizedBox.shrink();
  }
}
