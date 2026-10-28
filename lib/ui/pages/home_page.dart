import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../i18n/i18n.dart';
import '../../src/rust/api/engine.dart' as api;
import '../adaptive.dart';
import '../app.dart';
import '../widgets.dart';
import 'connections_page.dart';
import 'logs_page.dart';
import 'rules_page.dart';
import 'subscriptions_page.dart';

/// The group names the config generator uses (`config::TAG_*`), in the UI's words.
String outboundLabel(String name) => switch (name) {
  'Proxy' => tr('group.proxy'),
  'Auto' => tr('group.auto'),
  'direct' => tr('group.direct'),
  _ => name,
};

/// The node traffic leaves through, followed from Proxy through any groups.
({api.Member? node, List<String> path}) currentRoute(List<api.Group> groups) {
  final path = <String>[];
  var now = groups.where((g) => g.name == 'Proxy').firstOrNull?.now ?? '';
  while (path.length < 5) {
    final g = groups.where((g) => g.name == now && g.now.isNotEmpty).firstOrNull;
    if (g == null) break;
    path.add(outboundLabel(g.name));
    now = g.now;
  }
  final node = groups.expand((g) => g.members).where((m) => m.name == now).firstOrNull;
  return (node: node, path: path);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final app = AppState.instance;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the "connected for" time current.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && app.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => AppPage(
        title: 'BoxPilot',
        actions: [
          if (app.running)
            PageAction(
              icon: const AppIcon(Icons.refresh, CupertinoIcons.arrow_clockwise, 'arrow.clockwise'),
              label: tr('tip.restart_core'),
              onPressed: api.restart,
            ),
        ],
        slivers: [
          SliverToBoxAdapter(child: _hero(context)),
          if (app.subscriptions.isEmpty) SliverToBoxAdapter(child: _gettingStarted(context)),
          if (app.subscriptions.isNotEmpty) ...[
            _padded(_modeCard(context)),
            _padded(_nowUsing(context)),
            _padded(_trafficCard(context)),
          ],
          Section(
            header: tr('home.tools'),
            children: [
              NavTile(
                title: tr('nav.connections'),
                subtitle: isCupertino ? null : tr('home.connections_desc'),
                icon: const AppIcon(Icons.swap_vert, CupertinoIcons.arrow_up_arrow_down),
                iconColor: CupertinoColors.systemBlue,
                onTap: () => pushPage(context, const ConnectionsPage()),
              ),
              NavTile(
                title: tr('nav.rules'),
                subtitle: isCupertino ? null : tr('home.rules_desc'),
                icon: const AppIcon(Icons.alt_route, CupertinoIcons.arrow_branch),
                iconColor: CupertinoColors.systemIndigo,
                onTap: () => pushPage(context, const RulesPage()),
              ),
              NavTile(
                title: tr('nav.logs'),
                subtitle: isCupertino ? null : tr('home.logs_desc'),
                icon: const AppIcon(Icons.article_outlined, CupertinoIcons.doc_text),
                iconColor: CupertinoColors.systemGrey,
                onTap: () => pushPage(context, const LogsPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _padded(Widget child) => SliverPadding(
    padding: EdgeInsets.fromLTRB(isCupertino ? 20 : 16, 6, isCupertino ? 20 : 16, 6),
    sliver: SliverToBoxAdapter(child: child),
  );

  Widget _hero(BuildContext context) {
    final muted = StatusColors.muted(context);
    final failure = app.failure;
    final (title, color) = switch (app.status) {
      api.CoreState_Running() => (tr('status.connected'), StatusColors.good(context)),
      api.CoreState_Starting() => (tr('status.connecting'), StatusColors.fair(context)),
      api.CoreState_Stopping() => (tr('status.disconnecting'), StatusColors.fair(context)),
      api.CoreState_Failed() => (tr('status.failed'), StatusColors.bad(context)),
      _ => (tr('status.disconnected'), muted),
    };
    String detail;
    if (failure != null) {
      detail = failure;
    } else if (app.running) {
      final since = app.connectedSince;
      detail = since == null
          ? tr('home.protected')
          : tr('home.uptime', [formatDuration(DateTime.now().difference(since))]);
    } else if (app.totalNodes > 0) {
      detail = tr('dash.ready', [app.totalNodes, tr('mode.${app.mode.toLowerCase()}')]);
    } else {
      detail = tr('dash.no_nodes');
    }
    final titleStyle = isCupertino
        ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.headlineSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        children: [
          ConnectButton(
            running: app.running,
            busy: app.busy,
            onPressed: app.totalNodes == 0 && !app.running ? _addFirst : app.toggle,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title, style: titleStyle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: failure != null ? StatusColors.bad(context) : muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _addFirst() {
    context.go('/subscriptions');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) openSubscriptionEditor(ctx);
    });
  }

  Widget _gettingStarted(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCupertino ? 20 : 16, vertical: 6),
      child: InfoCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('subs.empty_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(tr('subs.empty_hint'), style: TextStyle(color: StatusColors.muted(context))),
            const SizedBox(height: 16),
            AdaptiveButton(
              onPressed: _addFirst,
              label: tr('btn.add_subscription'),
              style: isCupertino ? AdaptiveButtonStyle.prominentGlass : AdaptiveButtonStyle.filled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(BuildContext context) {
    const modes = ['Rule', 'Global', 'Direct'];
    final index = modes.indexOf(app.mode).clamp(0, 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, tr('quick.mode')),
        SizedBox(
          width: double.infinity,
          child: AdaptiveSegmentedControl(
            labels: [for (final m in modes) tr('mode.${m.toLowerCase()}')],
            selectedIndex: index,
            onValueChanged: (i) => app.setMode(modes[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(tr('quick.mode_desc'), style: TextStyle(fontSize: 13, color: StatusColors.muted(context))),
        ),
      ],
    );
  }

  Widget _cardTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: isCupertino
          ? TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context))
          : Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  Widget _nowUsing(BuildContext context) {
    final route = currentRoute(app.groups);
    final node = route.node;
    final muted = StatusColors.muted(context);
    Widget body;
    if (!app.running || node == null) {
      body = Text(tr('status.disconnected'), style: TextStyle(color: muted));
    } else {
      final protocol = node.protocol.toUpperCase();
      final routeText = [
        route.path.join(' → '),
        if (protocol.isNotEmpty) protocol,
      ].where((s) => s.isNotEmpty).join(' · ');
      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NodeName(
                  name: outboundLabel(node.name),
                  country: node.country,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                if (routeText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      routeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
              ],
            ),
          ),
          if (node.name != 'direct')
            LatencyBadge(
              delay: node.realDelay ?? node.delay,
              testing: node.testing,
              onTap: () => app.testRealLatency([node.name]),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, tr('dash.now_using')),
        InfoCard(onTap: () => context.go('/proxies'), child: body),
      ],
    );
  }

  Widget _trafficCard(BuildContext context) {
    final t = app.traffic;
    final upColor = StatusColors.accent(context);
    final downColor = isCupertino
        ? CupertinoColors.systemTeal.resolveFrom(context)
        : Theme.of(context).colorScheme.tertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardTitle(context, tr('chart.traffic')),
        InfoCard(
          child: ListenableBuilder(
            listenable: t,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Stat(
                        label: tr('stat.upload'),
                        value: formatSpeed(t.currentUp),
                        color: upColor,
                        icon: isCupertino ? CupertinoIcons.arrow_up : Icons.arrow_upward,
                      ),
                    ),
                    Expanded(
                      child: Stat(
                        label: tr('stat.download'),
                        value: formatSpeed(t.currentDown),
                        color: downColor,
                        icon: isCupertino ? CupertinoIcons.arrow_down : Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TrafficChart(history: t),
                const SizedBox(height: 8),
                Text(
                  '${tr('stat.session')}  ↑ ${formatBytes(t.sessionUp)}  ↓ ${formatBytes(t.sessionDown)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: StatusColors.muted(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
