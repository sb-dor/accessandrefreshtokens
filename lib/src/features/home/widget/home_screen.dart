import 'package:accessandrefreshtoken/src/features/authentication/widget/authentication_scope.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:dio/dio.dart';
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
  String? _result;

  Future<void> _testAuthenticatedRequest() async {
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      // The AuthenticationInterceptor automatically attaches the Bearer token.
      // If the access token is expired it will refresh it transparently before
      // this call resolves.
      final dio = Dependencies.of(context).dio;
      final response = await dio.get<Map<String, Object?>>('/api/auth/me');
      final data = response.data!;
      setState(() {
        _result = 'Success ✓\n\n'
            'id: ${data['id']}\n'
            'name: ${data['name']}\n'
            'email: ${data['email']}';
      });
    } on DioException catch (e) {
      setState(() {
        _result = 'Error ${e.response?.statusCode ?? '?'}\n${e.message}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthenticationScope.userOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
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
              FilledButton(
                onPressed: _loading ? null : _testAuthenticatedRequest,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test GET /api/auth/me'),
              ),
              if (_result != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _result!.startsWith('Error')
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _result!.startsWith('Error')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  child: Text(
                    _result!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
