import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../i18n/i18n.dart';
import '../../src/rust/api/engine.dart' as api;
import '../adaptive.dart';
import '../widgets.dart';

/// Core and app log lines, newest at the bottom, following new ones.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final app = AppState.instance;
  final _scroll = ScrollController();
  final List<api.LogEntry> _lines = [];
  String _filter = '';

  /// 0 all, else the minimum level (2 info, 3 warn, 4 error).
  int _minLevel = 0;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _lines.addAll(app.logs());
    app.logRevision.addListener(_onLogs);
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atEnd = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 48;
      if (atEnd != _follow) setState(() => _follow = atEnd);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
  }

  @override
  void dispose() {
    app.logRevision.removeListener(_onLogs);
    _scroll.dispose();
    super.dispose();
  }

  void _onLogs() {
    final fresh = app.logs(skip: _lines.length);
    setState(() {
      // The buffer is trimmed or cleared from time to time; then start over.
      if (fresh.isEmpty && app.logs().length < _lines.length) {
        _lines
          ..clear()
          ..addAll(app.logs());
      } else {
        _lines.addAll(fresh);
        if (_lines.length > 2000) _lines.removeRange(0, _lines.length - 2000);
      }
    });
    if (_follow) WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
  }

  void _toEnd() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  List<api.LogEntry> get _shown {
    final f = _filter.toLowerCase();
    return _lines.where((l) => l.level >= _minLevel && (f.isEmpty || l.message.toLowerCase().contains(f))).toList();
  }

  String _levelName(int level) => const ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'][level.clamp(0, 4)];

  Color _levelColor(BuildContext context, int level) => switch (level) {
    >= 4 => StatusColors.bad(context),
    3 => StatusColors.fair(context),
    2 => StatusColors.accent(context),
    _ => StatusColors.muted(context),
  };

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    const levels = [0, 2, 3, 4];
    final mono = TextStyle(
      fontFamily: isCupertino ? 'Menlo' : 'monospace',
      fontSize: 12,
      height: 1.35,
      color: isCupertino ? CupertinoColors.label.resolveFrom(context) : Theme.of(context).colorScheme.onSurface,
    );
    return AppPage(
      title: tr('nav.logs'),
      largeTitle: !isCupertino,
      controller: _scroll,
      actions: [
        PageAction(
          icon: const AppIcon(Icons.copy_all_outlined, CupertinoIcons.doc_on_doc, 'doc.on.doc'),
          label: tr('btn.copy'),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: shown.map((l) => '${formatClock(l.time)} ${_levelName(l.level)} ${l.message}').join('\n'),
              ),
            );
            app.notify(NoticeKind.success, tr('logs.copied'));
          },
        ),
        PageAction(
          icon: const AppIcon(Icons.delete_sweep_outlined, CupertinoIcons.trash, 'trash'),
          label: tr('tip.clear'),
          onPressed: () {
            app.clearLogs();
            setState(_lines.clear);
          },
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: SearchField(placeholder: tr('logs.search'), onChanged: (v) => setState(() => _filter = v)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(isCupertino ? 20 : 16, 0, isCupertino ? 20 : 16, 8),
            child: AdaptiveSegmentedControl(
              labels: [tr('logs.all'), 'Info', 'Warn', 'Error'],
              selectedIndex: levels.indexOf(_minLevel),
              onValueChanged: (i) => setState(() => _minLevel = levels[i]),
            ),
          ),
        ),
        if (!app.setting('record_logs', true))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(tr('logs.stopped'), style: TextStyle(color: StatusColors.fair(context), fontSize: 13)),
            ),
          ),
        if (shown.isEmpty)
          EmptyState(
            icon: const AppIcon(Icons.article_outlined, CupertinoIcons.doc_text),
            title: tr('logs.empty'),
            message: tr('logs.empty_hint'),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isCupertino ? 20 : 16),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final l = shown[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: SelectableText.rich(
                    TextSpan(
                      style: mono,
                      children: [
                        TextSpan(
                          text: '${formatClock(l.time)} ',
                          style: TextStyle(color: StatusColors.muted(context)),
                        ),
                        TextSpan(
                          text: '${_levelName(l.level).padRight(5)} ',
                          style: TextStyle(color: _levelColor(context, l.level), fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: l.message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
