import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../i18n/i18n.dart';
import '../adaptive.dart';
import '../widgets.dart';
import 'home_page.dart' show outboundLabel;

/// The subconverter config the desktop offers as a preset.
const _aclPreset = 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Full.ini';

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final providers = app.ruleProviders;
        String? template(String v) => v.contains('{name}') ? null : tr('err.template');
        return AppPage(
          title: tr('nav.rules'),
          largeTitle: !isCupertino,
          actions: [
            PageAction(
              icon: const AppIcon(Icons.add, CupertinoIcons.add, 'plus'),
              label: tr('btn.add_ruleset'),
              menu: [
                PageMenuItem(
                  tr('btn.add_ruleset'),
                  () => openRuleEditor(context),
                  icon: const AppIcon(Icons.link, CupertinoIcons.link, 'link'),
                ),
                PageMenuItem(
                  tr('btn.import_acl'),
                  () => _importAcl(context),
                  icon: const AppIcon(Icons.download, CupertinoIcons.cloud_download, 'square.and.arrow.down'),
                ),
              ],
            ),
            if (providers.isNotEmpty)
              PageAction(
                icon: const AppIcon(Icons.sync, CupertinoIcons.arrow_2_circlepath, 'arrow.triangle.2.circlepath'),
                label: tr('btn.update_all'),
                onPressed: () => app.updateRuleProviders([for (final p in providers) p.id]),
              ),
          ],
          slivers: [
            Section(
              header: tr('rules.builtin'),
              children: [
                SwitchTile(
                  title: tr('rules.bypass_cn'),
                  subtitle: tr('rules.bypass_cn_desc'),
                  value: app.setting('bypass_cn', true),
                  onChanged: (v) => app.updateSettings({'bypass_cn': v}),
                ),
                SwitchTile(
                  title: tr('rules.block_ads'),
                  subtitle: tr('rules.block_ads_desc'),
                  value: app.setting('block_ads', false),
                  onChanged: (v) => app.updateSettings({'block_ads': v}),
                ),
                SwitchTile(
                  title: tr('rules.via_proxy'),
                  subtitle: tr('rules.via_proxy_desc'),
                  value: app.setting('ruleset_via_proxy', true),
                  onChanged: (v) => app.updateSettings({'ruleset_via_proxy': v}),
                ),
                TextTile(
                  title: tr('rules.geosite_url'),
                  description: tr('rules.template_desc'),
                  value: app.setting('geosite_url', ''),
                  keyboardType: TextInputType.url,
                  validator: template,
                  onChanged: (v) => app.updateSettings({'geosite_url': v}),
                ),
                TextTile(
                  title: tr('rules.geoip_url'),
                  description: tr('rules.template_desc'),
                  value: app.setting('geoip_url', ''),
                  keyboardType: TextInputType.url,
                  validator: template,
                  onChanged: (v) => app.updateSettings({'geoip_url': v}),
                ),
              ],
            ),
            if (providers.isEmpty)
              Section(
                header: tr('rules.sets'),
                footer: tr('rules.empty_hint'),
                children: [
                  NavTile(
                    title: tr('btn.add_ruleset'),
                    icon: const AppIcon(Icons.add, CupertinoIcons.add),
                    iconColor: CupertinoColors.systemBlue,
                    onTap: () => openRuleEditor(context),
                  ),
                  NavTile(
                    title: tr('btn.import_acl'),
                    icon: const AppIcon(Icons.download, CupertinoIcons.cloud_download),
                    iconColor: CupertinoColors.systemIndigo,
                    onTap: () => _importAcl(context),
                  ),
                ],
              )
            else
              SliverGroupedList(
                header: Padding(
                  padding: EdgeInsets.fromLTRB(isCupertino ? 36 : 32, 16, 24, 8),
                  child: Text(tr('rules.sets'), style: TextStyle(fontSize: 13, color: StatusColors.muted(context))),
                ),
                itemCount: providers.length,
                itemBuilder: (context, i) => _RuleRow(provider: providers[i]),
              ),
            Section(
              header: tr('rules.custom'),
              footer: tr('rules.custom_help'),
              children: [
                TextTile(
                  title: tr('rules.custom'),
                  value: app.setting('custom_rules', ''),
                  display: _customSummary(app.setting('custom_rules', '')),
                  placeholder: 'DOMAIN-SUFFIX,example.com,DIRECT',
                  multiline: true,
                  onChanged: (v) => app.updateSettings({'custom_rules': v}),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _customSummary(String rules) {
    final n = rules.split('\n').where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#')).length;
    return tr('rules.count', [n]);
  }

  Future<void> _importAcl(BuildContext context) async {
    final source = await promptText(
      context,
      title: tr('acl.title'),
      message: tr('acl.desc'),
      initial: _aclPreset,
      keyboardType: TextInputType.url,
      confirmLabel: tr('btn.import'),
      validator: (v) => v.isEmpty ? tr('err.required') : null,
    );
    if (source == null) return;
    final n = await AppState.instance.importAcl(source);
    if (n != null) AppState.instance.notify(NoticeKind.success, tr('acl.imported', [n]));
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.provider});

  final RuleProvider provider;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final p = provider;
    final muted = StatusColors.muted(context);
    final meta = [
      _targetLabel(p.target),
      tr('rules.count', [p.ruleCount]),
      p.lastUpdate == null ? tr('subs.never_updated') : tr('meta.updated', [formatAgo(p.lastUpdate!)]),
    ].join(' · ');
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name.isEmpty ? p.source : p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCupertino ? CupertinoColors.label.resolveFrom(context) : null,
                  ),
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                if (p.lastError != null)
                  Text(
                    p.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: StatusColors.bad(context)),
                  ),
              ],
            ),
          ),
          isCupertino
              ? CupertinoSwitch(value: p.enabled, onChanged: (v) => app.setRuleProviderEnabled(p.id, v))
              : Switch(value: p.enabled, onChanged: (v) => app.setRuleProviderEnabled(p.id, v)),
        ],
      ),
    );
    void open() => openRuleEditor(context, existing: p);
    if (isCupertino) {
      return CupertinoButton(padding: EdgeInsets.zero, pressedOpacity: 0.6, onPressed: open, child: content);
    }
    return InkWell(onTap: open, child: content);
  }
}

String _targetLabel(String target) => switch (target) {
  'proxy' => tr('target.proxy'),
  'direct' => tr('target.direct'),
  'reject' => tr('target.reject'),
  _ => outboundLabel(target),
};

Future<void> openRuleEditor(BuildContext context, {RuleProvider? existing}) =>
    openForm<void>(context, (_) => _RuleEditor(existing: existing));

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.existing});

  final RuleProvider? existing;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final app = AppState.instance;
  final _form = GlobalKey<FormState>();
  late final RuleProvider _p = widget.existing ?? RuleProvider.blank();
  late final _name = TextEditingController(text: _p.name);
  late final _source = TextEditingController(text: _p.source);
  late final _interval = TextEditingController(text: '${_p.intervalHours}');
  late String _format = _p.format;
  late String _target = _p.target;

  bool get _isNew => widget.existing == null;

  /// A rule-set file is copied into the data folder; the engine reads it from there
  /// and converts it again whenever it is updated, as for a local file on desktop.
  Future<void> _chooseFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return;
    final dir = Directory('${app.dataDir}${Platform.pathSeparator}imported');
    await dir.create(recursive: true);
    final safe = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = File('${dir.path}${Platform.pathSeparator}$safe');
    await target.writeAsBytes(await file.readAsBytes(), flush: true);
    setState(() {
      _source.text = target.path;
      if (_name.text.trim().isEmpty) _name.text = file.name.replaceFirst(RegExp(r'[.][^.]+$'), '');
    });
  }

  String? _validSource(String v) {
    if (RegExp(r'^https?://\S+$').hasMatch(v)) return null;
    if (v.isNotEmpty && File(v).existsSync()) return null;
    return tr('rules.err_source');
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    app.saveRuleProvider(
      _p.copyWith({
        'name': _name.text.trim(),
        'source': _source.text.trim(),
        'format': _format,
        'target': _target,
        'interval_hours': int.tryParse(_interval.text.trim()) ?? 24,
      }),
    );
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: tr('rules.delete_title'),
      message: tr('rules.delete_body', [_p.name.isEmpty ? _p.source : _p.name]),
      confirmLabel: tr('btn.delete'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    app.removeRuleProviders([_p.id]);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groups = {for (final g in app.groups) g.name: outboundLabel(g.name)}..remove('Proxy');
    final targets = {
      'proxy': tr('target.proxy'),
      'direct': tr('target.direct'),
      'reject': tr('target.reject'),
      ...groups,
      if (!{'proxy', 'direct', 'reject', ...groups.keys}.contains(_target)) _target: outboundLabel(_target),
    };
    final index = app.ruleProviders.indexWhere((p) => p.id == _p.id);
    return FormPage(
      formKey: _form,
      title: _isNew ? tr('rules.add_title') : tr('rules.edit_title'),
      saveLabel: _isNew ? tr('btn.add') : tr('btn.save'),
      onSave: _save,
      children: [
        SectionBox(
          footer: tr('rules.source_hint'),
          children: [
            FormFieldRow(
              label: tr('rules.source'),
              controller: _source,
              placeholder: 'https://',
              keyboardType: TextInputType.url,
              autofocus: _isNew,
              validator: _validSource,
            ),
            NavTile(
              title: tr('subs.choose_file'),
              icon: const AppIcon(Icons.folder_open, CupertinoIcons.folder),
              iconColor: CupertinoColors.systemBlue,
              chevron: false,
              onTap: _chooseFile,
            ),
            FormFieldRow(label: tr('editor.name'), controller: _name, placeholder: tr('editor.name_ph')),
          ],
        ),
        SectionBox(
          footer: tr('rules.target_hint'),
          children: [
            ChoiceTile<String>(
              title: tr('rules.target'),
              value: _target,
              options: targets,
              onChanged: (v) => setState(() => _target = v),
            ),
            ChoiceTile<String>(
              title: tr('rules.format'),
              value: _format,
              options: {
                for (final e in ruleFormats.entries) e.key: e.value.isEmpty ? tr('rules.format_auto') : e.value,
              },
              onChanged: (v) => setState(() => _format = v),
            ),
            FormFieldRow(
              label: tr('editor.interval'),
              controller: _interval,
              keyboardType: TextInputType.number,
              helper: tr('editor.interval_hint'),
              validator: (v) => int.tryParse(v) == null || int.parse(v) < 0 ? tr('editor.err_interval') : null,
            ),
          ],
        ),
        if (!_isNew)
          SectionBox(
            children: [
              NavTile(
                title: tr('tip.update_now'),
                icon: const AppIcon(Icons.sync, CupertinoIcons.arrow_2_circlepath),
                iconColor: CupertinoColors.systemGreen,
                chevron: false,
                onTap: () => app.updateRuleProviders([_p.id]),
              ),
              if (index > 0)
                NavTile(
                  title: tr('tip.move_up'),
                  icon: const AppIcon(Icons.arrow_upward, CupertinoIcons.arrow_up),
                  iconColor: CupertinoColors.systemGrey,
                  chevron: false,
                  onTap: () => app.moveRuleProvider(_p.id, -1),
                ),
              if (index >= 0 && index < app.ruleProviders.length - 1)
                NavTile(
                  title: tr('tip.move_down'),
                  icon: const AppIcon(Icons.arrow_downward, CupertinoIcons.arrow_down),
                  iconColor: CupertinoColors.systemGrey,
                  chevron: false,
                  onTap: () => app.moveRuleProvider(_p.id, 1),
                ),
              NavTile(
                title: tr('btn.delete'),
                icon: const AppIcon(Icons.delete_outline, CupertinoIcons.delete),
                iconColor: CupertinoColors.systemRed,
                destructive: true,
                chevron: false,
                onTap: _delete,
              ),
            ],
          ),
      ],
    );
  }
}
