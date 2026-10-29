import 'dart:async';
import 'dart:typed_data';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/core_host.dart';
import '../../i18n/i18n.dart';
import '../adaptive.dart';
import '../widgets.dart';

/// Android's per-app proxy: all apps, only the selected ones, or all but the
/// selected ones. Saved by the platform and applied when the core (re)starts.
class PerAppPage extends StatefulWidget {
  const PerAppPage({super.key});

  @override
  State<PerAppPage> createState() => _PerAppPageState();
}

class _PerAppPageState extends State<PerAppPage> {
  final host = CoreHost.instance;
  PerAppMode _mode = PerAppMode.all;
  Set<String> _selected = {};
  List<InstalledApp>? _apps;
  String _filter = '';
  Timer? _apply;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Apply a pending change right away when leaving the page.
    if (_apply?.isActive ?? false) {
      _apply!.cancel();
      AppState.instance.reloadCore();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final (mode, selected) = await host.perApp();
    final apps = await host.apps();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _selected = selected;
      _apps = apps;
    });
  }

  /// Saves at once; the running core reloads after a pause, so ticking several apps costs one reload.
  void _changed() {
    host.setPerApp(_mode, _selected);
    _apply?.cancel();
    _apply = Timer(const Duration(seconds: 2), AppState.instance.reloadCore);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final f = _filter.toLowerCase();
    final shown = apps == null
        ? const <InstalledApp>[]
        : [
            for (final a in apps)
              if (f.isEmpty || a.label.toLowerCase().contains(f) || a.package.contains(f)) a,
          ];
    // Selected apps first, so the choice is easy to review.
    shown.sort((a, b) {
      final sa = _selected.contains(a.package), sb = _selected.contains(b.package);
      return sa == sb ? 0 : (sa ? -1 : 1);
    });
    final description = switch (_mode) {
      PerAppMode.all => tr('perapp.desc_all'),
      PerAppMode.include => tr('perapp.desc_include'),
      PerAppMode.exclude => tr('perapp.desc_exclude'),
    };
    return AppPage(
      title: tr('perapp.title'),
      largeTitle: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: AdaptiveSegmentedControl(
              labels: [tr('perapp.mode_all'), tr('perapp.mode_include'), tr('perapp.mode_exclude')],
              selectedIndex: _mode.index,
              onValueChanged: (i) {
                setState(() => _mode = PerAppMode.values[i]);
                _changed();
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
            child: Text(
              '$description ${tr('perapp.applies')}',
              style: TextStyle(fontSize: 13, color: StatusColors.muted(context)),
            ),
          ),
        ),
        if (_mode != PerAppMode.all) ...[
          SliverToBoxAdapter(
            child: SearchField(placeholder: tr('perapp.search'), onChanged: (v) => setState(() => _filter = v)),
          ),
          if (apps == null)
            EmptyState(icon: const AppIcon(Icons.apps, Icons.apps), title: tr('perapp.loading'))
          else
            SliverGroupedList(
              header: Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 24, 8),
                child: Text(
                  tr('perapp.selected', [_selected.length]),
                  style: TextStyle(fontSize: 13, color: StatusColors.muted(context)),
                ),
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final app = shown[i];
                final checked = _selected.contains(app.package);
                return CheckboxListTile(
                  value: checked,
                  onChanged: (v) {
                    setState(() => v == true ? _selected.add(app.package) : _selected.remove(app.package));
                    _changed();
                  },
                  secondary: _AppIcon(package: app.package),
                  title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(app.package, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
        ],
      ],
    );
  }
}

/// App icons load lazily and stay cached for the session.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.package});

  final String package;

  static final _cache = <String, Future<Uint8List?>>{};

  @override
  Widget build(BuildContext context) {
    final future = _cache.putIfAbsent(package, () => CoreHost.instance.appIcon(package));
    return SizedBox.square(
      dimension: 40,
      child: FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) return const Icon(Icons.android);
          return Image.memory(bytes, gaplessPlayback: true, filterQuality: FilterQuality.medium);
        },
      ),
    );
  }
}
