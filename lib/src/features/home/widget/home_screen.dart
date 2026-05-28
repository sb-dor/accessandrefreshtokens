import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:accessandrefreshtoken/src/features/authentication/widget/authentication_scope.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:flutter/material.dart';

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

  Future<void> getPizzas() async {
    if (_loading) return;
    _loading = true;
    setState(() {});
    final httpClient = Dependencies.of(context).httpClient;
    final response = await httpClient.get(Uri.parse('${Config.apiBaseUrl}/pizzas/'));
    print('pizzas: ${response.body}');
    _loading = false;
    setState(() {});
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
