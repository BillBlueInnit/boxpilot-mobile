import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../core/import_link.dart';
import '../i18n/i18n.dart';
import 'adaptive.dart';
import 'pages/home_page.dart';
import 'pages/proxies_page.dart';
import 'pages/settings_page.dart';
import 'pages/subscriptions_page.dart';

/// Theme colours: (dark, light), the desktop's accent pairs.
const _accents = <String, (Color, Color)>{
  'blue': (Color(0xFF60CDFF), Color(0xFF005FB8)),
  'teal': (Color(0xFF4FD8CF), Color(0xFF00777B)),
  'green': (Color(0xFF6CCB5F), Color(0xFF0F7B0F)),
  'violet': (Color(0xFFB9A3FF), Color(0xFF6B48C8)),
  'pink': (Color(0xFFFF8FC8), Color(0xFFBF1F6A)),
  'orange': (Color(0xFFFFB066), Color(0xFFB94A00)),
};

/// BoxPilot's brand blue, for "System" when the device has no dynamic colours.
const _brand = Color(0xFF3B82F6);

class BoxPilotApp extends StatefulWidget {
  const BoxPilotApp({super.key});

  @override
  State<BoxPilotApp> createState() => _BoxPilotAppState();
}

class _BoxPilotAppState extends State<BoxPilotApp> {
  final app = AppState.instance;
  late final GoRouter _router = _buildRouter();
  StreamSubscription<Notice>? _notices;

  @override
  void initState() {
    super.initState();
    _notices = app.notices.listen((n) => showNotice(n.text, error: n.kind == NoticeKind.error));
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }

  ThemeData _material(Brightness brightness) {
    final accent = app.setting('accent', 'system');
    final wallpaper = app.systemAccent;
    ColorScheme scheme;
    if (accent == 'system' && wallpaper != null) {
      // Material You: the scheme grows from the wallpaper's accent colour.
      scheme = ColorScheme.fromSeed(seedColor: wallpaper, brightness: brightness);
    } else if (accent == 'graphite') {
      scheme = ColorScheme.fromSeed(
        seedColor: Colors.grey,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      );
    } else {
      final pair = _accents[accent];
      scheme = ColorScheme.fromSeed(seedColor: pair?.$2 ?? _brand, brightness: brightness);
    }
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
      ),
    );
  }

  CupertinoThemeData _cupertino(Brightness brightness) {
    final accent = app.setting('accent', 'system');
    final pair = _accents[accent];
    final Color primary = switch (accent) {
      'graphite' => CupertinoColors.label,
      _ when pair != null => CupertinoDynamicColor.withBrightness(color: pair.$2, darkColor: pair.$1),
      _ => CupertinoColors.systemBlue,
    };
    // Grouped background: the pages are inset grouped lists and cards.
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    );
  }

  ThemeMode get _themeMode => switch (app.setting('theme', 'system')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => AdaptiveApp.router(
        title: 'BoxPilot',
        themeMode: _themeMode,
        materialLightTheme: _material(Brightness.light),
        materialDarkTheme: _material(Brightness.dark),
        cupertinoLightTheme: _cupertino(Brightness.light),
        cupertinoDarkTheme: _cupertino(Brightness.dark),
        locale: currentLanguage.locale,
        supportedLocales: [for (final l in AppLanguage.values) l.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        scaffoldMessengerKey: scaffoldMessengerKey,
        routerConfig: _router,
      ),
    );
  }

  GoRouter _buildRouter() {
    GoRoute tab(String path, Widget page) => GoRoute(
      path: path,
      pageBuilder: (context, state) => NoTransitionPage(child: page),
    );
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _Shell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [tab('/home', const HomePage())]),
            StatefulShellBranch(routes: [tab('/proxies', const ProxiesPage())]),
            StatefulShellBranch(routes: [tab('/subscriptions', const SubscriptionsPage())]),
            StatefulShellBranch(routes: [tab('/settings', const SettingsPage())]),
          ],
        ),
      ],
    );
  }
}

/// The tab bar: Liquid Glass `UITabBar` on iOS 26, Material 3 `NavigationBar` on Android.
class _Shell extends StatefulWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  StreamSubscription<String>? _imports;

  StatefulNavigationShell get shell => widget.shell;

  static const tabs = [
    (
      'nav.home',
      AppIcon(Icons.home_outlined, CupertinoIcons.house, 'house'),
      AppIcon(Icons.home, CupertinoIcons.house_fill, 'house.fill'),
    ),
    (
      'nav.proxies',
      AppIcon(Icons.public_outlined, CupertinoIcons.globe, 'globe'),
      AppIcon(Icons.public, CupertinoIcons.globe, 'globe'),
    ),
    (
      'nav.subscriptions',
      AppIcon(Icons.layers_outlined, CupertinoIcons.square_stack_3d_up, 'square.stack.3d.up'),
      AppIcon(Icons.layers, CupertinoIcons.square_stack_3d_up_fill, 'square.stack.3d.up.fill'),
    ),
    (
      'nav.settings',
      AppIcon(Icons.settings_outlined, CupertinoIcons.gear, 'gearshape'),
      AppIcon(Icons.settings, CupertinoIcons.gear_solid, 'gearshape.fill'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final app = AppState.instance;
    _imports = app.imports.listen(_offerImport);
    final pending = app.takePendingImport();
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _offerImport(pending));
  }

  @override
  void dispose() {
    _imports?.cancel();
    super.dispose();
  }

  /// A provider's import link: show the prefilled editor so the user confirms it.
  void _offerImport(String raw) {
    final link = parseImportLink(raw);
    if (link == null) {
      AppState.instance.notify(NoticeKind.error, tr('editor.err_url'));
      return;
    }
    shell.goBranch(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) openSubscriptionEditor(ctx, url: link.url, name: link.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final native = PlatformInfo.isIOS26OrHigher();
    return AdaptiveScaffold(
      // The iOS 26 tab bar would otherwise shrink to a pill when a page is scrolled down.
      minimizeBehavior: TabBarMinimizeBehavior.never,
      body: shell,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          for (final (key, icon, selected) in tabs)
            AdaptiveNavigationDestination(
              label: tr(key),
              icon: native ? icon.sfSymbol : icon.platform,
              selectedIcon: native ? selected.sfSymbol : selected.platform,
            ),
        ],
      ),
    );
  }
}

/// Pushes a page in the current tab with the platform's transition.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  final route = isCupertino ? CupertinoPageRoute<T>(builder: (_) => page) : MaterialPageRoute<T>(builder: (_) => page);
  return Navigator.of(context).push(route);
}
