import 'package:accessandrefreshtoken/src/features/authentication/controller/authentication_controller.dart';
import 'package:accessandrefreshtoken/src/features/authentication/data/authentication_repository.dart';
import 'package:accessandrefreshtoken/src/features/initialization/models/dependencies.dart';
import 'package:accessandrefreshtoken/src/features/initialization/widget/app.dart';
import 'package:accessandrefreshtoken/src/features/initialization/widget/dependencies_scope.dart';
import 'package:accessandrefreshtoken/src/features/settings/widget/settings_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus/octopus.dart';

void main() => group('Widget', () {
  testWidgets('Dependencies_are_injected', (tester) async {
    await tester.pumpWidget(FakeDependencies().inject(child: Container()));
    expect(find.byType(Container), findsOneWidget);
    expect(find.byType(DependenciesScope), findsOneWidget);
    final context = tester.element(find.byType(Container));
    expect(
      Dependencies.of(context),
      allOf(isNotNull, isA<Dependencies>(), isA<FakeDependencies>()),
    );
  });

  testWidgets('App', skip: true, (tester) async {
    final dependencies = FakeDependencies()
      ..authenticationController = AuthenticationController(
        repository: AuthenticationFakeRepositoryImpl(),
      );
    await tester.pumpWidget(
      dependencies.inject(
        child: const SettingsScope(child: NoAnimationScope(noAnimation: true, child: App())),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DependenciesScope), findsOneWidget);
  });
});
