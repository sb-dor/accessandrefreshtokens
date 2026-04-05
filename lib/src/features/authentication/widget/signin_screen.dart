import 'package:flutter/material.dart';
import 'package:accessandrefreshtoken/src/common/widget/scaffold_padding.dart';
import 'package:accessandrefreshtoken/src/features/authentication/controller/authentication_controller.dart';
import 'package:accessandrefreshtoken/src/features/authentication/widget/authentication_scope.dart';

/// {@template signin_screen}
/// Login / Register screen.
/// {@endtemplate}
class SignInScreen extends StatefulWidget {
  /// {@macro signin_screen}
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final emailOk = _emailController.text.trim().contains('@');
    final passOk = _passwordController.text.length >= 6;
    final nameOk = _isLogin || _nameController.text.trim().length >= 2;
    return emailOk && passOk && nameOk;
  }

  void _submit() {
    final controller = AuthenticationScope.controllerOf(context);
    if (_isLogin) {
      controller.login(email: _emailController.text.trim(), password: _passwordController.text);
    } else {
      controller.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: AuthenticationScope.controllerOf(context),
      builder: (context, _) {
        final state = AuthenticationScope.controllerOf(context).state;
        final isLoading = state is Authentication$InProgressState;
        final errorMessage = state.error;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Padding(
                    padding: ScaffoldPadding.of(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.chat_bubble_rounded, size: 72, color: Colors.teal),
                        const SizedBox(height: 20),
                        Text(
                          'WsChat',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Login')),
                            ButtonSegment(value: false, label: Text('Register')),
                          ],
                          selected: {_isLogin},
                          onSelectionChanged: isLoading
                              ? null
                              : (s) => setState(() => _isLogin = s.first),
                        ),
                        const SizedBox(height: 24),
                        if (!_isLogin) ...[
                          TextField(
                            key: const Key('nameField'),
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            enabled: !isLoading,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          key: const Key('emailField'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          enabled: !isLoading,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('passwordField'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !isLoading,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _isValid ? _submit() : null,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('submitButton'),
                          onPressed: (!isLoading && _isValid) ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isLogin ? 'Login' : 'Create Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
