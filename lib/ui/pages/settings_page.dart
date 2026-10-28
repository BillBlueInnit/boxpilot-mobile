import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../i18n/i18n.dart';
import '../../src/rust/api/engine.dart' as api;
import '../adaptive.dart';
import '../app.dart';
import 'rules_page.dart';

const _sourceUrl = 'https://github.com/BillBlueInnit/boxpilot-mobile';

String? _port(String v) {
  final n = int.tryParse(v);
  return n == null || n < 1 || n > 65535 ? tr('err.port') : null;
}

String? _positive(String v) => (int.tryParse(v) ?? -1) < 0 ? tr('err.number') : null;

String? _httpUrl(String v) => RegExp(r'^https?://\S+$').hasMatch(v) ? null : tr('err.http_url');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final app = AppState.instance;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = '${p.version} (${p.buildNumber})');
    });
  }

  void _set(String key, Object value) => app.updateSettings({key: value});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final lanOn = app.setting('allow_lan', false);
        final mixedPort = app.setting('mixed_port', 7890);
        final strategy = app.setting('auto_strategy', 'quickest');
        final regions = {'': tr('auto.region_any')};
        for (final c in app.countryCounts()) {
          regions[c.code] = '${flagEmoji(c.code)} ${c.code} (${c.nodes})';
        }
        final region = app.setting('auto_region', '');
        if (!regions.containsKey(region)) regions[region] = region;
        return AppPage(
          title: tr('nav.settings'),
          slivers: [
            // ------------------------------------------------------------- general
            Section(
              header: tr('set.general'),
              children: [
                ChoiceTile<String>(
                  title: tr('set.language'),
                  icon: const AppIcon(Icons.translate, CupertinoIcons.globe),
                  iconColor: CupertinoColors.systemBlue,
                  value: app.setting('language', 'System'),
                  options: {'System': tr('lang.system'), for (final l in AppLanguage.values) l.code: l.nativeName},
                  onChanged: (v) => _set('language', v),
                ),
                SwitchTile(
                  title: tr('set.autoconnect'),
                  subtitle: tr('set.autoconnect_desc_mobile'),
                  icon: const AppIcon(Icons.play_circle_outline, CupertinoIcons.play_circle),
                  iconColor: CupertinoColors.systemGreen,
                  value: app.setting('auto_start_core', true),
                  onChanged: (v) => _set('auto_start_core', v),
                ),
              ],
            ),
            Section(
              header: tr('set.appearance'),
              footer: isCupertino ? null : tr('set.accent_desc_mobile'),
              children: [
                ChoiceTile<String>(
                  title: tr('set.theme'),
                  icon: const AppIcon(Icons.dark_mode_outlined, CupertinoIcons.moon),
                  iconColor: CupertinoColors.systemIndigo,
                  value: app.setting('theme', 'system'),
                  options: {'system': tr('theme.system'), 'light': tr('theme.light'), 'dark': tr('theme.dark')},
                  onChanged: (v) => _set('theme', v),
                ),
                ChoiceTile<String>(
                  title: tr('set.accent'),
                  icon: const AppIcon(Icons.palette_outlined, CupertinoIcons.paintbrush),
                  iconColor: CupertinoColors.systemPink,
                  value: app.setting('accent', 'system'),
                  options: {
                    'system': isCupertino ? tr('accent.system') : tr('set.accent_dynamic'),
                    for (final a in ['blue', 'teal', 'green', 'violet', 'pink', 'orange', 'graphite'])
                      a: tr('accent.$a'),
                  },
                  onChanged: (v) => _set('accent', v),
                ),
              ],
            ),
            // ----------------------------------------------------------- connection
            Section(
              header: tr('set.proxy'),
              children: [
                SwitchTile(
                  title: tr('set.proxy_udp'),
                  subtitle: tr('set.proxy_udp_desc'),
                  value: app.setting('proxy_udp', true),
                  onChanged: (v) => _set('proxy_udp', v),
                ),
                SwitchTile(
                  title: tr('set.block_quic'),
                  subtitle: tr('set.block_quic_desc'),
                  value: app.setting('block_quic', false),
                  onChanged: (v) => _set('block_quic', v),
                ),
                SwitchTile(
                  title: tr('quick.lan'),
                  subtitle: tr('quick.lan_desc_mobile', [mixedPort]),
                  value: lanOn,
                  onChanged: (v) => _set('allow_lan', v),
                ),
                if (lanOn)
                  TextTile(
                    title: tr('set.mixed_port'),
                    description: tr('set.mixed_port_desc'),
                    value: '$mixedPort',
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        _port(v) ?? (int.parse(v) == app.setting('clash_api_port', 9090) ? tr('err.port_api') : null),
                    onChanged: (v) => _set('mixed_port', int.parse(v)),
                  ),
              ],
            ),
            Section(
              header: tr('set.tun_mobile'),
              footer: tr('set.tun_mobile_desc'),
              children: [
                ChoiceTile<String>(
                  title: tr('set.stack'),
                  subtitle: tr('set.stack_desc'),
                  value: app.setting('tun_stack', 'mixed'),
                  options: const {'mixed': 'mixed', 'system': 'system', 'gvisor': 'gvisor'},
                  onChanged: (v) => _set('tun_stack', v),
                ),
                SwitchTile(
                  title: tr('set.strict'),
                  subtitle: tr('set.strict_desc'),
                  value: app.setting('tun_strict_route', true),
                  onChanged: (v) => _set('tun_strict_route', v),
                ),
                TextTile(
                  title: tr('set.mtu'),
                  value: '${app.setting('tun_mtu', 9000)}',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v);
                    return n == null || n < 1280 || n > 65535 ? tr('err.invalid') : null;
                  },
                  onChanged: (v) => _set('tun_mtu', int.parse(v)),
                ),
              ],
            ),
            Section(
              header: tr('set.dns'),
              children: [
                TextTile(
                  title: tr('set.dns_remote'),
                  description: tr('set.dns_remote_desc'),
                  value: app.setting('dns_remote', ''),
                  keyboardType: TextInputType.url,
                  validator: (v) => v.isEmpty ? tr('err.required') : null,
                  onChanged: (v) => _set('dns_remote', v),
                ),
                TextTile(
                  title: tr('set.dns_direct'),
                  description: tr('set.dns_direct_desc'),
                  value: app.setting('dns_direct', ''),
                  keyboardType: TextInputType.url,
                  validator: (v) => v.isEmpty ? tr('err.required') : null,
                  onChanged: (v) => _set('dns_direct', v),
                ),
                SwitchTile(
                  title: tr('set.fakeip'),
                  subtitle: tr('set.fakeip_desc'),
                  value: app.setting('fake_ip', false),
                  onChanged: (v) => _set('fake_ip', v),
                ),
                SwitchTile(
                  title: tr('set.ipv6'),
                  subtitle: tr('set.ipv6_desc'),
                  value: app.setting('ipv6', false),
                  onChanged: (v) => _set('ipv6', v),
                ),
              ],
            ),
            Section(
              header: tr('set.auto_group'),
              footer: tr('auto.${strategy}_hint'),
              children: [
                ChoiceTile<String>(
                  title: tr('set.auto_strategy'),
                  value: strategy,
                  options: {for (final s in autoStrategies) s: tr('auto.$s')},
                  onChanged: (v) => _set('auto_strategy', v),
                ),
                ChoiceTile<String>(
                  title: tr('set.auto_region'),
                  value: region,
                  options: regions,
                  onChanged: (v) => _set('auto_region', v),
                ),
                TextTile(
                  title: tr('set.test_url'),
                  value: app.setting('urltest_url', ''),
                  keyboardType: TextInputType.url,
                  validator: _httpUrl,
                  onChanged: (v) => _set('urltest_url', v),
                ),
                TextTile(
                  title: tr('set.test_interval'),
                  value: '${app.setting('urltest_interval_min', 10)}',
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v) ?? 0) < 1 ? tr('err.number') : null,
                  onChanged: (v) => _set('urltest_interval_min', int.parse(v)),
                ),
              ],
            ),
            Section(
              children: [
                NavTile(
                  title: tr('nav.rules'),
                  subtitle: isCupertino ? null : tr('home.rules_desc'),
                  icon: const AppIcon(Icons.alt_route, CupertinoIcons.arrow_branch),
                  iconColor: CupertinoColors.systemIndigo,
                  value: isCupertino ? tr('rules.count', [app.ruleProviders.length]) : null,
                  onTap: () => pushPage(context, const RulesPage()),
                ),
              ],
            ),
            Section(
              header: tr('set.subs'),
              children: [
                TextTile(
                  title: tr('set.ua'),
                  description: tr('set.ua_desc'),
                  value: app.setting('sub_user_agent', 'clash.meta'),
                  validator: (v) => v.isEmpty ? tr('err.required') : null,
                  onChanged: (v) => _set('sub_user_agent', v),
                ),
                TextTile(
                  title: tr('set.default_interval'),
                  description: tr('set.default_interval_desc'),
                  value: '${app.setting('sub_default_interval_min', 720) ~/ 60}',
                  keyboardType: TextInputType.number,
                  validator: _positive,
                  onChanged: (v) => _set('sub_default_interval_min', int.parse(v) * 60),
                ),
                TextTile(
                  title: tr('set.timeout'),
                  value: '${app.setting('sub_timeout_secs', 30)}',
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v) ?? 0) < 1 ? tr('err.number') : null,
                  onChanged: (v) => _set('sub_timeout_secs', int.parse(v)),
                ),
                SwitchTile(
                  title: tr('set.reload'),
                  subtitle: tr('set.reload_desc'),
                  value: app.setting('sub_reload_after_update', true),
                  onChanged: (v) => _set('sub_reload_after_update', v),
                ),
              ],
            ),
            // ------------------------------------------------------------- advanced
            Section(
              header: tr('set.advanced'),
              children: [
                ChoiceTile<String>(
                  title: tr('set.log_level'),
                  value: app.setting('log_level', 'info'),
                  options: const {'trace': 'trace', 'debug': 'debug', 'info': 'info', 'warn': 'warn', 'error': 'error'},
                  onChanged: (v) => _set('log_level', v),
                ),
                SwitchTile(
                  title: tr('set.record_logs'),
                  subtitle: tr('tip.record'),
                  value: app.setting('record_logs', true),
                  onChanged: (v) => _set('record_logs', v),
                ),
                TextTile(
                  title: tr('set.api_port'),
                  description: tr('set.api_port_desc'),
                  value: '${app.setting('clash_api_port', 9090)}',
                  keyboardType: TextInputType.number,
                  validator: (v) => _port(v) ?? (int.parse(v) == mixedPort ? tr('err.port_proxy') : null),
                  onChanged: (v) => _set('clash_api_port', int.parse(v)),
                ),
                TextTile(
                  title: tr('set.mirror'),
                  description: tr('set.mirror_desc'),
                  value: app.setting('github_mirror', ''),
                  placeholder: 'https://ghfast.top/',
                  keyboardType: TextInputType.url,
                  validator: (v) => v.isEmpty ? null : _httpUrl(v),
                  onChanged: (v) => _set('github_mirror', v),
                ),
                NavTile(
                  title: tr('set.export'),
                  subtitle: isCupertino ? null : tr('set.export_desc'),
                  chevron: false,
                  trailing: Icon(isCupertino ? CupertinoIcons.doc_on_doc : Icons.copy, size: 20),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: app.previewConfig()));
                    app.notify(NoticeKind.success, tr('set.config_copied'));
                  },
                ),
              ],
            ),
            Section(
              header: tr('set.data'),
              footer: tr('set.reset_desc_mobile'),
              children: [
                NavTile(title: tr('set.reset'), destructive: true, chevron: false, onTap: () => _reset(context)),
              ],
            ),
            // --------------------------------------------------------------- about
            Section(
              header: 'BoxPilot',
              footer: isCupertino ? null : tr('set.tile_hint'),
              children: [
                NavTile(title: tr('set.version'), value: _version, chevron: false),
                NavTile(
                  title: tr('set.core_embedded'),
                  value: app.coreVersion.isEmpty ? '—' : 'sing-box ${app.coreVersion}',
                  chevron: false,
                ),
                NavTile(
                  title: tr('set.source'),
                  subtitle: isCupertino ? null : 'github.com/BillBlueInnit/boxpilot-mobile',
                  onTap: () => launchUrl(Uri.parse(_sourceUrl), mode: LaunchMode.externalApplication),
                ),
                NavTile(
                  title: tr('set.licenses'),
                  subtitle: isCupertino ? null : tr('set.licenses_desc'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'BoxPilot',
                    applicationVersion: _version,
                    applicationLegalese: tr('set.licenses_desc'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _reset(BuildContext context) async {
    final parts = await openForm<api.ResetParts>(context, (_) => const _ResetForm());
    if (parts == null) return;
    await app.reset(parts);
    if (Platform.isAndroid) {
      // The engine is frozen after a reset; a fresh process starts clean.
      exit(0);
    }
    app.notify(NoticeKind.info, tr('reset.body_mobile'));
  }
}

class _ResetForm extends StatefulWidget {
  const _ResetForm();

  @override
  State<_ResetForm> createState() => _ResetFormState();
}

class _ResetFormState extends State<_ResetForm> {
  bool _settings = true, _subs = true, _rules = true, _caches = true;

  @override
  Widget build(BuildContext context) {
    final any = _settings || _subs || _rules || _caches;
    return FormPage(
      title: tr('reset.title'),
      saveLabel: tr('btn.reset'),
      onSave: !any
          ? null
          : () async {
              final ok = await confirm(
                context,
                title: tr('reset.title'),
                message: tr('reset.body_mobile'),
                confirmLabel: tr('btn.reset'),
                destructive: true,
              );
              if (ok && context.mounted) {
                Navigator.of(context)
                    .pop(api.ResetParts(settings: _settings, subscriptions: _subs, ruleSets: _rules, caches: _caches));
              }
            },
      children: [
        SectionBox(
          footer: tr('reset.body_mobile'),
          children: [
            SwitchTile(
              title: tr('reset.settings'),
              subtitle: tr('reset.settings_desc'),
              value: _settings,
              onChanged: (v) => setState(() => _settings = v),
            ),
            SwitchTile(
              title: tr('reset.subs'),
              subtitle: tr('reset.subs_desc'),
              value: _subs,
              onChanged: (v) => setState(() => _subs = v),
            ),
            SwitchTile(
              title: tr('reset.rules'),
              subtitle: tr('reset.rules_desc'),
              value: _rules,
              onChanged: (v) => setState(() => _rules = v),
            ),
            SwitchTile(
              title: tr('reset.caches'),
              subtitle: tr('reset.caches_desc'),
              value: _caches,
              onChanged: (v) => setState(() => _caches = v),
            ),
          ],
        ),
      ],
    );
  }
}
