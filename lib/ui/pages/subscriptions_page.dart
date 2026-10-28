import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../i18n/i18n.dart';
import '../adaptive.dart';
import '../app.dart';
import '../widgets.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final subs = app.subscriptions;
        final anyRemote = subs.any((s) => s.isRemote && s.enabled);
        return AppPage(
          title: tr('nav.subscriptions'),
          onRefresh: anyRemote ? () async => app.updateAllSubscriptions() : null,
          actions: [
            if (anyRemote)
              PageAction(
                icon: const AppIcon(Icons.sync, CupertinoIcons.arrow_2_circlepath, 'arrow.triangle.2.circlepath'),
                label: tr('btn.update_all'),
                onPressed: app.updateAllSubscriptions,
              ),
            if (isCupertino)
              PageAction(
                icon: const AppIcon(Icons.add, CupertinoIcons.add, 'plus'),
                label: tr('btn.add_subscription'),
                menu: [
                  PageMenuItem(
                    tr('btn.add_subscription'),
                    () => openSubscriptionEditor(context),
                    icon: const AppIcon(Icons.link, CupertinoIcons.link, 'link'),
                  ),
                  PageMenuItem(
                    tr('subs.from_clipboard'),
                    () => addFromClipboard(context),
                    icon: const AppIcon(Icons.content_paste, CupertinoIcons.doc_on_clipboard, 'doc.on.clipboard'),
                  ),
                ],
              )
            else
              PageAction(
                icon: const AppIcon(Icons.content_paste, CupertinoIcons.doc_on_clipboard, 'doc.on.clipboard'),
                label: tr('subs.from_clipboard'),
                onPressed: () => addFromClipboard(context),
              ),
          ],
          floatingActionButton: isCupertino
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => openSubscriptionEditor(context),
                  icon: const Icon(Icons.add),
                  label: Text(tr('btn.add')),
                ),
          slivers: [
            if (subs.isEmpty)
              EmptyState(
                icon: const AppIcon(Icons.layers_outlined, CupertinoIcons.square_stack_3d_up),
                title: tr('subs.empty_title'),
                message: tr('subs.empty_hint'),
                action: AdaptiveButton(
                  onPressed: () => addFromClipboard(context),
                  label: tr('subs.from_clipboard'),
                  style: isCupertino ? AdaptiveButtonStyle.glass : AdaptiveButtonStyle.tinted,
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isCupertino ? 20 : 32, 0, 20, 4),
                  child: Text(
                    tr('subs.subtitle', [subs.length, app.totalNodes]),
                    style: TextStyle(color: StatusColors.muted(context), fontSize: 13),
                  ),
                ),
              ),
              SliverGroupedList(
                itemCount: subs.length,
                itemBuilder: (context, i) =>
                    _SubscriptionRow(sub: subs[i], updating: app.updating.contains(subs[i].id)),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.sub, required this.updating});

  final Subscription sub;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final muted = StatusColors.muted(context);
    final error = sub.lastError;
    final meta = <String>[
      tr('meta.nodes', [sub.nodeCount]),
      if (!sub.isRemote) tr('subs.local'),
      if (updating)
        tr('subs.updating')
      else if (sub.lastUpdate != null)
        tr('meta.updated', [formatAgo(sub.lastUpdate!)])
      else
        tr('subs.never_updated'),
    ].join(' · ');
    final info = sub.info;
    final usage = info == null || info.total <= 0 ? null : (info.used / info.total).clamp(0.0, 1.0);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name.isEmpty ? tr('subs.untitled') : sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(fontSize: 13, color: muted)),
                if (error != null && !updating)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${tr('subs.update_failed')}: $error',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: StatusColors.bad(context)),
                    ),
                  ),
                if (usage != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: usage,
                      minHeight: 5,
                      color: usage > 0.9 ? StatusColors.bad(context) : StatusColors.accent(context),
                      backgroundColor: muted.withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_usageText(info!), style: TextStyle(fontSize: 12, color: muted)),
                ],
              ],
            ),
          ),
          if (updating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: isCupertino
                  ? const CupertinoActivityIndicator()
                  : const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          AdaptiveSwitch(value: sub.enabled, onChanged: (v) => app.setSubscriptionEnabled(sub.id, v)),
        ],
      ),
    );
    void open() => pushPage(context, SubscriptionDetailPage(id: sub.id));
    if (isCupertino) {
      return CupertinoButton(padding: EdgeInsets.zero, pressedOpacity: 0.6, onPressed: open, child: content);
    }
    return InkWell(onTap: open, child: content);
  }
}

String _usageText(SubInfo info) {
  final parts = [
    tr('usage.of', [formatBytes(info.used), formatBytes(info.total)]),
  ];
  if (info.expire > 0) {
    final at = DateTime.fromMillisecondsSinceEpoch(info.expire * 1000);
    final left = at.difference(DateTime.now());
    final date = '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
    parts.add(
      left.isNegative
          ? tr('usage.expired')
          : tr('usage.expires', [
              date,
              tr('usage.left', [formatDuration(left)]),
            ]),
    );
  }
  return parts.join(' · ');
}

/// Adds the clipboard: a URL becomes a remote subscription, anything else local content.
Future<void> addFromClipboard(BuildContext context) async {
  final app = AppState.instance;
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
  if (text.isEmpty) {
    app.notify(NoticeKind.warning, tr('subs.clipboard_empty'));
    return;
  }
  final remote = RegExp(r'^https?://\S+$').hasMatch(text);
  final sub = Subscription.blank(intervalMin: app.setting('sub_default_interval_min', 720));
  final ok = remote
      ? await app.addSubscription(sub.copyWith({'url': text}))
      : await app.addSubscription(sub.copyWith({'name': tr('subs.pasted'), 'auto_update': false}), content: text);
  if (ok && !remote) app.notify(NoticeKind.success, tr('subs.pasted'));
}

// ------------------------------------------------------------------ detail

class SubscriptionDetailPage extends StatelessWidget {
  const SubscriptionDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final sub = app.subscriptions.where((s) => s.id == id).firstOrNull;
        if (sub == null) {
          return AppPage(title: tr('nav.subscriptions'), largeTitle: false, slivers: const []);
        }
        final nodes = app.nodes(id);
        final updating = app.updating.contains(id);
        final index = app.subscriptions.indexOf(sub);
        return AppPage(
          title: sub.name.isEmpty ? tr('subs.untitled') : sub.name,
          largeTitle: false,
          actions: [
            PageAction(
              icon: const AppIcon(Icons.edit_outlined, CupertinoIcons.pencil, 'pencil'),
              label: tr('btn.edit'),
              onPressed: () => openSubscriptionEditor(context, existing: sub),
            ),
            PageAction(
              icon: const AppIcon(Icons.more_vert, CupertinoIcons.ellipsis_circle, 'ellipsis.circle'),
              label: tr('btn.more'),
              menu: [
                if (sub.isRemote)
                  PageMenuItem(tr('subs.copy_url'), () {
                    Clipboard.setData(ClipboardData(text: sub.url));
                    app.notify(NoticeKind.success, tr('subs.url_copied'));
                  }, icon: const AppIcon(Icons.link, CupertinoIcons.link, 'link')),
                if (index > 0)
                  PageMenuItem(
                    tr('tip.move_up'),
                    () => app.moveSubscription(id, -1),
                    icon: const AppIcon(Icons.arrow_upward, CupertinoIcons.arrow_up, 'arrow.up'),
                  ),
                if (index < app.subscriptions.length - 1)
                  PageMenuItem(
                    tr('tip.move_down'),
                    () => app.moveSubscription(id, 1),
                    icon: const AppIcon(Icons.arrow_downward, CupertinoIcons.arrow_down, 'arrow.down'),
                  ),
                PageMenuItem(
                  tr('btn.delete'),
                  () => _delete(context, sub),
                  icon: const AppIcon(Icons.delete_outline, CupertinoIcons.delete, 'trash'),
                  destructive: true,
                ),
              ],
            ),
          ],
          slivers: [
            Section(
              children: [
                SwitchTile(
                  title: tr('tip.enabled'),
                  value: sub.enabled,
                  onChanged: (v) => app.setSubscriptionEnabled(id, v),
                ),
                if (sub.isRemote)
                  NavTile(
                    title: updating ? tr('subs.updating') : tr('tip.update_now'),
                    subtitle: sub.lastUpdate == null
                        ? tr('subs.never_updated')
                        : tr('meta.updated', [formatAgo(sub.lastUpdate!)]),
                    icon: const AppIcon(Icons.sync, CupertinoIcons.arrow_2_circlepath),
                    iconColor: CupertinoColors.systemGreen,
                    chevron: false,
                    trailing: updating
                        ? (isCupertino
                              ? const CupertinoActivityIndicator()
                              : const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : null,
                    onTap: updating ? null : () => app.updateSubscription(id),
                  ),
                if (sub.info != null && sub.info!.total > 0)
                  NavTile(
                    title: tr('usage.used', [formatBytes(sub.info!.used)]),
                    subtitle: _usageText(sub.info!),
                    icon: const AppIcon(Icons.data_usage, CupertinoIcons.chart_pie),
                    iconColor: CupertinoColors.systemOrange,
                    chevron: false,
                  ),
                if (sub.lastError != null)
                  NavTile(
                    title: tr('subs.update_failed'),
                    subtitle: sub.lastError,
                    icon: const AppIcon(Icons.error_outline, CupertinoIcons.exclamationmark_triangle),
                    iconColor: CupertinoColors.systemRed,
                    chevron: false,
                  ),
              ],
            ),
            SliverGroupedList(
              header: Padding(
                padding: EdgeInsets.fromLTRB(isCupertino ? 36 : 32, 16, 24, 8),
                child: Text(
                  '${tr('subs.nodes_title')} · ${nodes.length}',
                  style: TextStyle(fontSize: 13, color: StatusColors.muted(context)),
                ),
              ),
              itemCount: nodes.length,
              itemBuilder: (context, i) {
                final n = nodes[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
                              ),
                            ),
                            Text(
                              '${n.protocol.toUpperCase()} · ${n.server}:${n.port}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: StatusColors.muted(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, Subscription sub) async {
    final ok = await confirm(
      context,
      title: tr('subs.delete_title'),
      message: tr('subs.delete_body', [sub.name.isEmpty ? tr('subs.untitled') : sub.name]),
      confirmLabel: tr('btn.delete'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    AppState.instance.removeSubscriptions([sub.id]);
    Navigator.of(context).pop();
  }
}

// ------------------------------------------------------------------ editor

Future<void> openSubscriptionEditor(BuildContext context, {Subscription? existing}) =>
    openForm<void>(context, (_) => _SubscriptionEditor(existing: existing));

class _SubscriptionEditor extends StatefulWidget {
  const _SubscriptionEditor({this.existing});

  final Subscription? existing;

  @override
  State<_SubscriptionEditor> createState() => _SubscriptionEditorState();
}

class _SubscriptionEditorState extends State<_SubscriptionEditor> {
  final app = AppState.instance;
  final _form = GlobalKey<FormState>();
  late final Subscription _sub =
      widget.existing ?? Subscription.blank(intervalMin: app.setting('sub_default_interval_min', 720));
  late bool _remote = widget.existing?.isRemote ?? true;
  late final _name = TextEditingController(text: _sub.name);
  late final _url = TextEditingController(text: _sub.url);
  final _content = TextEditingController();
  late final _interval = TextEditingController(text: '${_sub.intervalMin ~/ 60}');
  late final _ua = TextEditingController(text: _sub.userAgent);
  late final _include = TextEditingController(text: _sub.include);
  late final _exclude = TextEditingController(text: _sub.exclude);
  late bool _autoUpdate = _sub.autoUpdate;
  late bool _updateOnStart = _sub.updateOnStart;
  late String _via = _sub.updateVia;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  String? _validRegex(String v) {
    if (v.isEmpty) return null;
    try {
      RegExp(v);
      return null;
    } catch (_) {
      return tr('err.invalid');
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final hours = int.tryParse(_interval.text.trim()) ?? 0;
    final changes = <String, dynamic>{
      'name': _name.text.trim(),
      'url': _remote ? _url.text.trim() : '',
      'auto_update': _remote && _autoUpdate,
      'interval_min': hours * 60,
      'update_on_start': _remote && _updateOnStart,
      'update_via': _via,
      'user_agent': _ua.text.trim(),
      'include': _include.text.trim(),
      'exclude': _exclude.text.trim(),
    };
    final sub = _sub.copyWith(changes);
    final content = !_remote && _content.text.trim().isNotEmpty ? _content.text : null;
    final ok = _isNew
        ? await app.addSubscription(sub, content: content)
        : await app.saveSubscription(sub, content: content);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final defaultUa = app.setting('sub_user_agent', 'clash.meta');
    return FormPage(
      formKey: _form,
      title: _isNew ? tr('subs.add_title') : tr('editor.edit_title'),
      saveLabel: _isNew ? tr('btn.add') : tr('btn.save'),
      saving: _saving,
      onSave: _save,
      children: [
        if (_isNew)
          Padding(
            padding: EdgeInsets.fromLTRB(isCupertino ? 20 : 16, 16, isCupertino ? 20 : 16, 4),
            child: AdaptiveSegmentedControl(
              labels: [tr('editor.remote'), tr('editor.paste')],
              selectedIndex: _remote ? 0 : 1,
              onValueChanged: (i) => setState(() => _remote = i == 0),
            ),
          ),
        SectionBox(
          header: tr('subs.source'),
          footer: _remote ? tr('editor.url_hint') : null,
          children: [
            if (_remote)
              FormFieldRow(
                label: tr('editor.url'),
                controller: _url,
                placeholder: 'https://',
                keyboardType: TextInputType.url,
                autofocus: _isNew,
                validator: (v) => RegExp(r'^https?://\S+$').hasMatch(v) ? null : tr('editor.err_url'),
              )
            else
              FormFieldRow(
                label: tr('editor.content'),
                controller: _content,
                placeholder: tr('editor.content_ph'),
                maxLines: 10,
                validator: (v) => v.isEmpty && _isNew ? tr('editor.err_content') : null,
              ),
            FormFieldRow(label: tr('editor.name'), controller: _name, placeholder: tr('editor.name_ph')),
          ],
        ),
        if (_remote)
          SectionBox(
            header: tr('subs.updates'),
            footer: tr('editor.interval_hint'),
            children: [
              SwitchTile(
                title: tr('editor.auto_update'),
                subtitle: tr('editor.auto_update_desc'),
                value: _autoUpdate,
                onChanged: (v) => setState(() => _autoUpdate = v),
              ),
              FormFieldRow(
                label: tr('editor.interval'),
                controller: _interval,
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v) == null || int.parse(v) < 0 ? tr('editor.err_interval') : null,
              ),
              SwitchTile(
                title: tr('editor.update_start'),
                subtitle: tr('editor.update_start_desc'),
                value: _updateOnStart,
                onChanged: (v) => setState(() => _updateOnStart = v),
              ),
              ChoiceTile<String>(
                title: tr('editor.via'),
                subtitle: tr('editor.via_hint'),
                value: _via,
                options: {'auto': tr('via.auto'), 'direct': tr('via.direct'), 'proxy': tr('via.proxy')},
                onChanged: (v) => setState(() => _via = v),
              ),
              FormFieldRow(
                label: tr('editor.ua'),
                controller: _ua,
                placeholder: tr('editor.ua_ph', [defaultUa]),
                helper: tr('editor.ua_hint'),
              ),
            ],
          ),
        SectionBox(
          header: tr('subs.filters'),
          children: [
            FormFieldRow(
              label: tr('editor.include'),
              controller: _include,
              placeholder: '香港|HK|Hong Kong',
              validator: _validRegex,
            ),
            FormFieldRow(
              label: tr('editor.exclude'),
              controller: _exclude,
              placeholder: '过期|剩余|Expire',
              validator: _validRegex,
            ),
          ],
        ),
      ],
    );
  }
}
