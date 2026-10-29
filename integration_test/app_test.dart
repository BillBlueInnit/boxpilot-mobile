// A guided tour of the real app for CI: it seeds a subscription, walks every
// page in light and dark, and on Android connects the VPN through a test node
// and checks traffic gets through. Each screenshot is a handshake with
// `scripts/ci_ui_test.sh`: the test leaves a request file in its temp folder and
// waits until the script has taken the screenshot and removed it. The script also
// grants VPN permission on Android once the app is installed.
//
//   --dart-define=BOXPILOT_TEST_NODE=ss://… (a working node; Android only)

import 'dart:async';
import 'dart:io';

import 'package:boxpilot/core/app_state.dart';
import 'package:boxpilot/core/models.dart';
import 'package:boxpilot/main.dart' as app;
import 'package:boxpilot/ui/adaptive.dart';
import 'package:boxpilot/ui/pages/subscriptions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

const testNode = String.fromEnvironment('BOXPILOT_TEST_NODE');

/// Lets real time pass while frames keep rendering.
Future<void> wait(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
  }
}

/// Asks the CI script for a screenshot of the current screen and waits for it.
Future<void> shot(WidgetTester t, String name) async {
  await wait(t, const Duration(milliseconds: 1200));
  // Where the script looks: `run-as … cache/` on Android, the app's tmp on iOS.
  final dir = Directory(
    Platform.isAndroid
        ? '/data/data/io.github.billblueinnit.boxpilot/cache/boxpilot-shots'
        : '${Directory.systemTemp.path}/boxpilot-shots',
  );
  await dir.create(recursive: true);
  final request = File('${dir.path}/$name');
  await request.writeAsString(name, flush: true);
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (request.existsSync() && DateTime.now().isBefore(end)) {
    await wait(t, const Duration(milliseconds: 250));
  }
  if (request.existsSync()) request.deleteSync();
}

Future<void> go(WidgetTester t, String path) async {
  GoRouter.of(rootNavigatorKey.currentContext!).go(path);
  await wait(t, const Duration(milliseconds: 800));
}

/// Scrolls the visible page to its end (or back to the top). Through its
/// position, not a fling: a drag that starts on a native iOS control goes to
/// that control instead.
Future<void> scrollToEnd(WidgetTester t, {bool top = false}) async {
  final page = find
      .byType(Scrollable)
      .hitTestable()
      .evaluate()
      .map((e) => (e as StatefulElement).state as ScrollableState)
      .firstWhere((s) => s.position.axis == Axis.vertical);
  for (var i = 0; i < 3; i++) {
    final position = page.position;
    final target = top ? position.minScrollExtent : position.maxScrollExtent;
    unawaited(position.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOut));
    await wait(t, const Duration(milliseconds: 800));
  }
}

Future<bool> waitFor(WidgetTester t, bool Function() done, Duration timeout) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (done()) return true;
    await wait(t, const Duration(milliseconds: 500));
  }
  return done();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('tour', timeout: const Timeout(Duration(minutes: 10)), (t) async {
    await app.main();
    await wait(t, const Duration(seconds: 3));
    final state = AppState.instance;
    state.updateSettings({'language': 'en', 'theme': 'light', 'auto_start_core': false});
    await shot(t, '01_home_empty');

    // A subscription to look at: the CI test node, or a placeholder on iOS.
    final node = testNode.isNotEmpty
        ? testNode
        : 'ss://MjAyMi1ibGFrZTMtYWVzLTEyOC1nY206YWFhYWFhYWFhYWFhYWFhYWFhYWFhQT09@203.0.113.7:8388#Tokyo%20JP%2001';
    final ok = await state.addSubscription(
      Subscription.blank(intervalMin: 720).copyWith({'name': 'CI Test', 'auto_update': false}),
      content: '$node\n${node.replaceFirst('#', '#2-')}',
    );
    expect(ok, isTrue);
    await wait(t, const Duration(seconds: 1));
    await shot(t, '02_home_ready');
    await scrollToEnd(t);
    await shot(t, '03_home_scrolled');

    await go(t, '/subscriptions');
    await shot(t, '04_subscriptions');
    await t.tap(find.text('CI Test').first);
    await wait(t, const Duration(seconds: 1));
    await shot(t, '05_subscription_detail');
    Navigator.of(rootNavigatorKey.currentContext!).maybePop();
    await wait(t, const Duration(seconds: 1));
    openSubscriptionEditor(rootNavigatorKey.currentContext!);
    await wait(t, const Duration(seconds: 1));
    await shot(t, '06_add_subscription');
    Navigator.of(rootNavigatorKey.currentContext!).maybePop();
    await wait(t, const Duration(seconds: 1));

    await go(t, '/proxies');
    await shot(t, '07_proxies_offline');

    await go(t, '/settings');
    await shot(t, '08_settings');
    await scrollToEnd(t);
    await shot(t, '09_settings_end');

    state.updateSettings({'theme': 'dark'});
    await go(t, '/home');
    await shot(t, '10_home_dark');
    await go(t, '/settings');
    await scrollToEnd(t, top: true);
    await shot(t, '11_settings_dark');
    state.updateSettings({'theme': 'light'});

    if (Platform.isAndroid && testNode.isNotEmpty) {
      await go(t, '/home');
      await state.connect();
      final connected = await waitFor(t, () => state.running, const Duration(seconds: 60));
      await shot(t, '12_home_connected');
      expect(connected, isTrue, reason: 'the VPN did not connect: ${state.failure}');
      expect(await waitFor(t, () => state.groups.isNotEmpty, const Duration(seconds: 20)), isTrue);

      await go(t, '/proxies');
      final names = [
        for (final g in state.groups)
          for (final m in g.members)
            if (!m.isGroup) m.name,
      ];
      state.testLatency(names.toSet().toList());
      final tested = await waitFor(
        t,
        () => state.groups.expand((g) => g.members).any((m) => (m.delay ?? 0) > 0),
        const Duration(seconds: 30),
      );
      await shot(t, '13_proxies_connected');
      expect(tested, isTrue, reason: 'no node answered a latency test through the VPN');

      await t.tap(find.textContaining('Auto').first);
      await wait(t, const Duration(seconds: 1));
      await shot(t, '14_proxies_auto_group');

      await wait(t, const Duration(seconds: 3));
      await go(t, '/home');
      await shot(t, '15_home_traffic');
      expect(state.logs().isNotEmpty, isTrue, reason: 'the core wrote no log lines');

      state.disconnect();
      expect(await waitFor(t, () => !state.running && !state.busy, const Duration(seconds: 20)), isTrue);
      await shot(t, '16_home_disconnected');
    }
  });
}
