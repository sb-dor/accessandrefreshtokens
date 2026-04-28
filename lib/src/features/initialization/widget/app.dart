import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:accessandrefreshtoken/src/common/localization/localization.dart';
import 'package:accessandrefreshtoken/src/common/router/router_state_mixin.dart';
import 'package:accessandrefreshtoken/src/common/util/performance_overlay_tool.dart';
import 'package:accessandrefreshtoken/src/common/widget/window_scope.dart';
import 'package:accessandrefreshtoken/src/features/authentication/widget/authentication_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:octopus/octopus.dart';

/// {@template app}
/// App widget.
/// {@endtemplate}
class App extends StatefulWidget {
  /// {@macro app}
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with RouterStateMixin {
  final Key builderKey = GlobalKey(); // Disable recreate widget tree

  String _buildBannerMessage() {
    if (Config.environment.isProduction) {
      if (Config.alpha) return 'ALPHA';
      if (Config.beta) return 'BETA';
      return '';
    }

    if (Config.environment.isDevelopment) return 'DEBUG';

    return '';
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'WebSockets',
    debugShowCheckedModeBanner: false,

    // Router
    routerConfig: router.config,

    // Localizations
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      Localization.delegate,
    ],
    supportedLocales: Localization.supportedLocales,
    // locale: const Locale("en"),
    /* locale: SettingsScope.localOf(context), */

    // Theme
    // theme: SettingsScope.themeOf(context),
    theme: ThemeData.dark(),

    // Scopes
    builder: (context, child) => MediaQuery(
      key: builderKey,
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: WindowScope(
        title: Localization.of(context).title,
        child: OctopusTools(
          enable: !kReleaseMode,
          octopus: router,
          child: PerformanceOverlayTool(
            enabled: false,
            child: Banner(
              location: BannerLocation.topEnd,
              message: _buildBannerMessage(),
              child: AuthenticationScope(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    ),
  );
}
