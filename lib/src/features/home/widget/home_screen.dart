import 'package:accessandrefreshtoken/src/common/router/routes.dart';
import 'package:accessandrefreshtoken/src/features/authentication/controller/authentication_controller.dart';
import 'package:accessandrefreshtoken/src/features/authentication/widget/authentication_scope.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:octopus/octopus.dart';

/// {@template home_screen}
/// HomeScreen — main authenticated screen.
/// {@endtemplate}
class HomeScreen extends StatefulWidget {
  /// {@macro home_screen}
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  late final AuthenticationController _authenticationController;

  @override
  void initState() {
    super.initState();
    _authenticationController = Dependencies.of(context).authenticationController;
    _authenticationController.addListener(_authenticationListener);
  }

  @override
  void dispose() {
    _authenticationController.removeListener(_authenticationListener);
    super.dispose();
  }

  void _authenticationListener() {
    if (_authenticationController.state.isIdle) {
      context.octopus.setState(
        (stack) => stack
          ..clear()
          ..add(Routes.signin.node()),
      );
    }
  }

  Future<void> getPizzas() async {
    try {
      if (_loading) return;
      _loading = true;
      setState(() {});
      final httpClient = Dependencies.of(context).apiClient;
      final response = await httpClient.get('/pizzas/');
      print('pizzas: ${response.body}');
    } catch (_) {
    } finally {
      _loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthenticationScope.userOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Dependencies.of(context).authenticationController.logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, ${user?.name ?? 'Guest'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(height: 10),
              FilledButton(onPressed: getPizzas, child: const Text('Test GET pizzas')),
            ],
          ),
        ),
      ),
    );
  }
}
