import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart' show autoStrategies;
import '../../i18n/i18n.dart';
import '../../src/rust/api/engine.dart' as api;
import '../adaptive.dart';
import '../widgets.dart';
import 'home_page.dart' show outboundLabel;

enum _Sort { order, latency, name }

class ProxiesPage extends StatefulWidget {
  const ProxiesPage({super.key});

  @override
  State<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends State<ProxiesPage> {
  final app = AppState.instance;
  final _expanded = <String>{'Proxy'};
  String _filter = '';
  _Sort _sort = _Sort.order;

  List<api.Member> _visible(api.Group g) {
    final f = _filter.toLowerCase();
    final members = g.members.where((m) => f.isEmpty || m.name.toLowerCase().contains(f)).toList();
    int latency(api.Member m) {
      final d = m.realDelay ?? m.delay;
      return d == null ? 1 << 30 : (d < 0 ? 1 << 29 : d);
    }

    switch (_sort) {
      case _Sort.latency:
        members.sort((a, b) => latency(a).compareTo(latency(b)));
      case _Sort.name:
        members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.order:
        break;
    }
    return members;
  }

  /// Nodes (not groups) currently shown, for the bulk tests.
  List<String> get _shownNodes => {
    for (final g in app.groups)
      if (_expanded.contains(g.name))
        for (final m in _visible(g))
          if (!m.isGroup && m.name != 'direct') m.name,
  }.toList();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final groups = app.groups;
        return AppPage(
          title: tr('nav.proxies'),
          actions: app.running
              ? [
                  PageAction(
                    icon: const AppIcon(Icons.speed, CupertinoIcons.speedometer, 'speedometer'),
                    label: tr('btn.test_latency'),
                    menu: [
                      PageMenuItem(
                        tr('btn.test_latency'),
                        () => app.testLatency(_shownNodes),
                        icon: const AppIcon(Icons.bolt, CupertinoIcons.bolt, 'bolt'),
                      ),
                      PageMenuItem(
                        tr('btn.real_latency'),
                        () => app.testRealLatency(_shownNodes),
                        icon: const AppIcon(
                          Icons.network_check,
                          CupertinoIcons.antenna_radiowaves_left_right,
                          'antenna.radiowaves.left.and.right',
                        ),
                      ),
                      PageMenuItem(
                        tr('btn.speed_test'),
                        () => app.speedTest(_shownNodes),
                        icon: const AppIcon(Icons.download, CupertinoIcons.cloud_download, 'arrow.down.circle'),
                      ),
                    ],
                  ),
                  PageAction(
                    icon: const AppIcon(Icons.sort, CupertinoIcons.arrow_up_arrow_down, 'arrow.up.arrow.down'),
                    label: tr('proxies.sort'),
                    menu: [
                      PageMenuItem(tr('sort.default'), () => setState(() => _sort = _Sort.order)),
                      PageMenuItem(tr('sort.latency'), () => setState(() => _sort = _Sort.latency)),
                      PageMenuItem(tr('sort.name'), () => setState(() => _sort = _Sort.name)),
                    ],
                  ),
                ]
              : const [],
          slivers: [
            if (!app.running)
              EmptyState(
                icon: const AppIcon(Icons.public_off_outlined, CupertinoIcons.globe),
                title: tr('proxies.not_connected'),
                message: tr('proxies.not_connected_hint'),
                action: _connectButton(context),
              )
            else if (groups.isEmpty)
              EmptyState(
                icon: const AppIcon(Icons.hourglass_empty, CupertinoIcons.hourglass),
                title: tr('proxies.loading'),
              )
            else ...[
              SliverToBoxAdapter(
                child: SearchField(placeholder: tr('proxies.filter'), onChanged: (v) => setState(() => _filter = v)),
              ),
              for (final g in groups) _group(context, g),
            ],
          ],
        );
      },
    );
  }

  Widget _connectButton(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton.filled(onPressed: app.connect, child: Text(tr('btn.connect')));
    }
    return FilledButton.icon(
      onPressed: app.connect,
      icon: const Icon(Icons.power_settings_new),
      label: Text(tr('btn.connect')),
    );
  }

  Widget _group(BuildContext context, api.Group g) {
    final expanded = _expanded.contains(g.name) || _filter.isNotEmpty;
    final members = expanded ? _visible(g) : const <api.Member>[];
    final kind = g.selectable ? tr('proxies.selector') : tr('proxies.urltest');
    final now = g.now.isEmpty ? '' : outboundLabel(g.now);
    final muted = StatusColors.muted(context);
    final header = InkWell(
      onTap: () => setState(() => expanded ? _expanded.remove(g.name) : _expanded.add(g.name)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isCupertino ? 36 : 32, 14, isCupertino ? 28 : 24, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outboundLabel(g.name),
                    style: isCupertino
                        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    [kind, if (now.isNotEmpty) now].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
            Text('${g.members.length}', style: TextStyle(color: muted)),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(isCupertino ? CupertinoIcons.chevron_right : Icons.chevron_right, size: 18, color: muted),
            ),
          ],
        ),
      ),
    );
    return SliverGroupedList(
      header: g.name == 'Auto'
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, _autoControls(context)])
          : header,
      itemCount: members.length,
      itemBuilder: (context, i) => _member(context, g, members[i]),
    );
  }

  /// How the Auto group picks its node and which region it keeps to, as on the
  /// desktop's Proxies page.
  Widget _autoControls(BuildContext context) {
    final strategy = app.setting('auto_strategy', 'quickest');
    final region = app.setting('auto_region', '');
    final regions = <String, String>{
      '': tr('auto.region_any'),
      for (final c in app.countryCounts()) c.code: '${flagEmoji(c.code)} ${c.code}  (${c.nodes})',
    };
    if (!regions.containsKey(region)) regions[region] = region;
    return Padding(
      padding: EdgeInsets.fromLTRB(isCupertino ? 36 : 32, 0, isCupertino ? 28 : 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MenuChip(
                icon: isCupertino ? CupertinoIcons.slider_horizontal_3 : Icons.tune,
                value: strategy,
                options: {for (final s in autoStrategies) s: tr('auto.$s')},
                onSelected: (v) => app.updateSettings({'auto_strategy': v}),
              ),
              _MenuChip(
                icon: isCupertino ? CupertinoIcons.globe : Icons.public,
                value: region,
                options: regions,
                onSelected: (v) => app.updateSettings({'auto_region': v}),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('auto.${strategy}_hint'), style: TextStyle(fontSize: 12, color: StatusColors.muted(context))),
        ],
      ),
    );
  }

  Widget _member(BuildContext context, api.Group g, api.Member m) {
    final selected = g.now == m.name;
    final muted = StatusColors.muted(context);
    final accent = StatusColors.accent(context);
    final details = [
      if (m.isGroup) tr('proxies.group') else m.protocol.toUpperCase(),
      if (m.speed != null) formatSpeed(m.speed!),
      if (m.speedTesting) '…',
    ].join(' · ');
    final leading = SizedBox(
      width: 24,
      child: selected
          ? Icon(isCupertino ? CupertinoIcons.check_mark : Icons.check_circle, color: accent, size: 20)
          : null,
    );
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NodeName(
                  name: outboundLabel(m.name),
                  country: m.country,
                  origin: m.countryOrigin,
                  ip: m.countryIp,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
                  ),
                ),
                if (details.isNotEmpty) Text(details, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          if (m.name != 'direct' && !m.isGroup)
            LatencyBadge(
              delay: m.realDelay ?? m.delay,
              testing: m.testing || m.speedTesting,
              onTap: () => app.testLatency([m.name]),
            ),
        ],
      ),
    );
    final onTap = g.selectable && !selected ? () => app.select(g.name, m.name) : null;
    if (isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        pressedOpacity: onTap == null ? 1 : 0.5,
        onPressed: onTap,
        child: content,
      );
    }
    return InkWell(
      onTap: onTap,
      onLongPress: m.isGroup || m.name == 'direct' ? null : () => app.speedTest([m.name]),
      child: content,
    );
  }
}

/// A compact pull-down: native `UIMenu` on iOS 26, a Material menu on Android.
class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.icon, required this.value, required this.options, required this.onSelected});

  final IconData icon;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = options[value] ?? value;
    final Widget chip;
    if (isCupertino) {
      final tint = CupertinoTheme.of(context).primaryColor;
      chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: tint, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_down, size: 11, color: tint),
          ],
        ),
      );
    } else {
      final scheme = Theme.of(context).colorScheme;
      chip = Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8, right: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Icon(Icons.arrow_drop_down, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      );
    }
    final keys = options.keys.toList();
    return AdaptivePopupMenuButton.widget<String>(
      items: [for (final k in keys) AdaptivePopupMenuItem<String>(label: options[k]!, value: k, selected: k == value)],
      onSelected: (i, item) {
        final picked = item.value;
        if (picked != null && picked != value) onSelected(picked);
      },
      child: chip,
    );
  }
}
