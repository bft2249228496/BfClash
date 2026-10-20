import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/theme.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:bfclash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class TestApp extends StatelessWidget {
  final Widget child;
  final bool includeNavigatorKey;
  final bool setTheme;
  final bool wrapInProviderScope;
  final List<Override> overrides;
  final Widget Function(Widget child) homeBuilder;
  final Locale? locale;
  final ThemeData? theme;

  /// Text scale used for [CommonTheme] and [Measure]. Defaults to 1 to keep
  /// historical visual tests unchanged; pass the scenario's scale to emulate
  /// the real app (see [ThemeManagerView.build]).
  final double textScaleFactor;

  const TestApp({
    super.key,
    required this.child,
    this.includeNavigatorKey = true,
    this.setTheme = true,
    this.wrapInProviderScope = false,
    this.overrides = const [],
    this.homeBuilder = _identity,
    this.locale,
    this.theme,
    this.textScaleFactor = 1,
  });

  static Widget _identity(Widget child) => child;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      navigatorKey: includeNavigatorKey ? globalState.navigatorKey : null,
      locale: locale,
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, textScaleFactor);
        if (setTheme) {
          globalState.theme = CommonTheme.of(context, textScaleFactor);
        }
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(
          child: IconTheme(data: Theme.of(context).iconTheme, child: child!),
        );
      },
      home: homeBuilder(child),
    );
    return overrides.isNotEmpty || wrapInProviderScope
        ? ProviderScope(overrides: overrides, child: app)
        : app;
  }
}
