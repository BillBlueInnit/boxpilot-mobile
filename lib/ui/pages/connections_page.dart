import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../i18n/i18n.dart';
import '../../src/rust/api/engine.dart' as api;
import '../adaptive.dart';
import '../widgets.dart';

/// Live connections through the core, refreshed every second while open.
class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final app = AppState.instance;
  api.Connections? _snapshot;
  Timer? _timer;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final snap = app.running ? await app.connections() : null;
    if (mounted) setState(() => _snapshot = snap);
  }

  List<api.ConnectionInfo> get _items {
    final all = _snapshot?.items ?? const [];
    final f = _filter.toLowerCase();
    final list = f.isEmpty
        ? [...all]
        : all.where((c) => '${c.target} ${c.process} ${c.outbound} ${c.rule}'.toLowerCase().contains(f)).toList();
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final snap = _snapshot;
    return AppPage(
      title: tr('nav.connections'),
      largeTitle: !isCupertino,
      actions: [
        if (items.isNotEmpty)
          PageAction(
            icon: const AppIcon(Icons.clear_all, CupertinoIcons.xmark_circle, 'xmark.circle'),
            label: tr('btn.close_all'),
            onPressed: () async {
              await app.closeAllConnections();
              _refresh();
            },
          ),
      ],
      slivers: [
        if (!app.running)
          EmptyState(
            icon: const AppIcon(Icons.swap_vert, CupertinoIcons.arrow_up_arrow_down),
            title: tr('proxies.not_connected'),
            message: tr('conn.offline_hint'),
          )
        else ...[
          SliverToBoxAdapter(
            child: SearchField(placeholder: tr('conn.filter'), onChanged: (v) => setState(() => _filter = v)),
          ),
          if (snap != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isCupertino ? 20 : 32, 0, 20, 8),
                child: Text(
                  tr('conn.subtitle', [
                    snap.items.length,
                    formatBytes(snap.uploadTotal),
                    formatBytes(snap.downloadTotal),
                  ]),
                  style: TextStyle(fontSize: 13, color: StatusColors.muted(context)),
                ),
              ),
            ),
          if (items.isEmpty)
            EmptyState(
              icon: const AppIcon(Icons.check_circle_outline, CupertinoIcons.checkmark_circle),
              title: tr('conn.none'),
              message: tr('conn.none_hint'),
            )
          else
            SliverGroupedList(itemCount: items.length, itemBuilder: (context, i) => _row(context, items[i])),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, api.ConnectionInfo c) {
    final muted = StatusColors.muted(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
                  ),
                ),
                Text(
                  [c.network.toUpperCase(), if (c.process.isNotEmpty) c.process, c.outbound].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '↑ ${formatBytes(c.upload)}',
                style: TextStyle(fontSize: 12, color: muted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '↓ ${formatBytes(c.download)}',
                style: TextStyle(fontSize: 12, color: muted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ),
    );
    void open() => _details(context, c);
    if (isCupertino) {
      return CupertinoButton(padding: EdgeInsets.zero, pressedOpacity: 0.6, onPressed: open, child: content);
    }
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.close, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => app.closeConnection(c.id),
      child: InkWell(onTap: open, child: content),
    );
  }

  Future<void> _details(BuildContext context, api.ConnectionInfo c) async {
    final started = DateTime.tryParse(c.start)?.toLocal();
    final rows = <(String, String)>[
      (tr('col.host'), c.target),
      (tr('col.net'), c.network.toUpperCase()),
      if (c.process.isNotEmpty) (tr('col.process'), c.process),
      (tr('col.rule'), c.rule),
      (tr('conn.chain'), c.chains.reversed.join(' → ')),
      (tr('col.up'), formatBytes(c.upload)),
      (tr('col.down'), formatBytes(c.download)),
      if (started != null) (tr('conn.started'), formatAgo(started.millisecondsSinceEpoch ~/ 1000)),
    ];
    final close = await openForm<bool>(
      context,
      (context) => FormPage(
        title: tr('nav.connections'),
        saveLabel: tr('conn.close'),
        onSave: () => Navigator.of(context).pop(true),
        children: [
          SectionBox(
            children: [
              for (final (label, value) in rows)
                NavTile(
                  title: label,
                  subtitle: isCupertino ? null : value,
                  value: isCupertino ? value : null,
                  chevron: false,
                ),
            ],
          ),
        ],
      ),
    );
    if (close == true) {
      await app.closeConnection(c.id);
      _refresh();
    }
  }
}
