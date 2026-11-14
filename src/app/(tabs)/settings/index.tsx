import * as Application from 'expo-application';
import * as Clipboard from 'expo-clipboard';
import { useRouter } from 'expo-router';
import { Linking } from 'react-native';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify, settingOf, updateSettings, useStore } from '@/core/store';
import { LANGUAGES } from '@/i18n';
import { ChoiceRow, Row, Screen, Section, SwitchRow, TextRow } from '@/ui/kit';
import { ACCENT_NAMES, isIOS } from '@/ui/theme';

const SOURCE_URL = 'https://github.com/BillBlueInnit/boxpilot-mobile';

/** iOS Settings-style icon colours; Android rows use the theme's. */
const tint = (ios: string) => (isIOS ? ios : undefined);

export default function SettingsPage() {
  const t = useT();
  const router = useRouter();
  const settings = useStore((s) => s.settings);
  const coreVersion = useStore((s) => s.coreVersion);
  const perApp = useStore((s) => s.host?.perApp ?? false);
  const ruleSets = useStore((s) => s.ruleProviders.length);
  const get = <T,>(key: string, fallback: T) => settingOf(settings, key, fallback);
  const set = (key: string, value: unknown) => updateSettings({ [key]: value });

  const mixedPort = get('mixed_port', 7890);
  const apiPort = get('clash_api_port', 9090);

  const port = (other: number, clash: string) => (text: string) => {
    const n = Number(text);
    if (!/^\d+$/.test(text) || n < 1 || n > 65535) return t('err.port');
    return n === other ? t(clash) : null;
  };
  const number = (min: number) => (text: string) => (/^\d+$/.test(text) && Number(text) >= min ? null : t('err.number'));
  const httpUrl = (text: string) => (text === '' || /^https?:\/\/\S+$/.test(text) ? null : t('err.http_url'));
  const required = (text: string) => (text === '' ? t('err.required') : null);

  const version = [Application.nativeApplicationVersion, Application.nativeBuildVersion]
    .filter(Boolean)
    .join(' (')
    .replace(/(\(.*)$/, '$1)');

  return (
    <Screen title={t('nav.settings')} root>
      <Section header={t('set.general')} footer={isIOS ? undefined : t('set.accent_desc_mobile')}>
        <ChoiceRow
          title={t('set.language')}
          icon={{ name: 'language', color: tint('#007AFF') }}
          value={get('language', 'System')}
          options={[
            { value: 'System', label: t('lang.system') },
            ...LANGUAGES.map((l) => ({ value: l.code as string, label: l.name })),
          ]}
          onChange={(v) => set('language', v)}
        />
        <ChoiceRow
          title={t('set.theme')}
          icon={{ name: 'theme', color: tint('#5856D6') }}
          value={get('theme', 'system')}
          options={[
            { value: 'system', label: t('theme.system') },
            { value: 'light', label: t('theme.light') },
            { value: 'dark', label: t('theme.dark') },
          ]}
          onChange={(v) => set('theme', v)}
        />
        <ChoiceRow
          title={t('set.accent')}
          icon={{ name: 'palette', color: tint('#FF2D55') }}
          value={get('accent', 'system')}
          options={[
            // iOS has no system accent colour for apps: "system" is the default blue there.
            { value: 'system', label: isIOS ? t('accent.ios_default') : t('set.accent_dynamic') },
            ...ACCENT_NAMES.map((a) => ({ value: a, label: t(`accent.${a}`) })),
          ]}
          onChange={(v) => set('accent', v)}
        />
        <SwitchRow
          title={t('set.autoconnect')}
          subtitle={t('set.autoconnect_desc_mobile')}
          icon={{ name: 'autoconnect', color: tint('#34C759') }}
          value={get('auto_start_core', true)}
          onChange={(v) => set('auto_start_core', v)}
        />
      </Section>

      <Section header={t('set.proxy')}>
        <TextRow
          title={t('set.mixed_port')}
          description={t('set.mixed_port_desc')}
          value={String(mixedPort)}
          keyboardType="number-pad"
          validate={port(apiPort, 'err.port_api')}
          onChange={(v) => set('mixed_port', Number(v))}
        />
        <SwitchRow
          title={t('quick.lan')}
          subtitle={t('quick.lan_desc_mobile', [mixedPort])}
          value={get('allow_lan', false)}
          onChange={(v) => set('allow_lan', v)}
        />
        <SwitchRow
          title={t('set.proxy_udp')}
          subtitle={t('set.proxy_udp_desc')}
          value={get('proxy_udp', true)}
          onChange={(v) => set('proxy_udp', v)}
        />
        <SwitchRow
          title={t('set.block_quic')}
          subtitle={t('set.block_quic_desc')}
          value={get('block_quic', false)}
          onChange={(v) => set('block_quic', v)}
        />
      </Section>

      {/* The phone app is TUN mode: the system VPN is the virtual adapter. */}
      <Section header={t('set.tun_mobile')} footer={t('set.tun_mobile_desc')}>
        {perApp ? (
          <Row
            title={t('perapp.title')}
            subtitle={t('perapp.summary')}
            icon={{ name: 'apps', color: tint('#FF9500') }}
            chevron
            onPress={() => router.push('/per-app')}
          />
        ) : null}
        <ChoiceRow
          title={t('set.stack')}
          message={t('set.stack_desc')}
          value={get('tun_stack', 'mixed')}
          options={['mixed', 'system', 'gvisor'].map((s) => ({ value: s, label: s }))}
          onChange={(v) => set('tun_stack', v)}
        />
        <TextRow
          title={t('set.mtu')}
          value={String(get('tun_mtu', 9000))}
          keyboardType="number-pad"
          validate={number(576)}
          onChange={(v) => set('tun_mtu', Number(v))}
        />
      </Section>

      <Section header={t('set.dns')}>
        <TextRow
          title={t('set.dns_remote')}
          description={t('set.dns_remote_desc')}
          value={get('dns_remote', '')}
          validate={required}
          onChange={(v) => set('dns_remote', v)}
        />
        <TextRow
          title={t('set.dns_direct')}
          description={t('set.dns_direct_desc')}
          value={get('dns_direct', '')}
          validate={required}
          onChange={(v) => set('dns_direct', v)}
        />
        <SwitchRow
          title={t('set.fakeip')}
          subtitle={t('set.fakeip_desc_mobile')}
          value={get('fake_ip', false)}
          onChange={(v) => set('fake_ip', v)}
        />
        <SwitchRow
          title={t('set.ipv6')}
          subtitle={t('set.ipv6_desc')}
          value={get('ipv6', false)}
          onChange={(v) => set('ipv6', v)}
        />
      </Section>

      <Section>
        <Row
          title={t('nav.rules')}
          subtitle={isIOS ? undefined : t('home.rules_desc')}
          value={ruleSets > 0 ? t('rules.count', [ruleSets]) : undefined}
          icon={{ name: 'rules', color: tint('#5856D6') }}
          chevron
          onPress={() => router.push('/rules')}
        />
      </Section>

      <Section header={t('set.subs')}>
        <TextRow
          title={t('set.ua')}
          description={t('set.ua_desc')}
          value={get('sub_user_agent', 'clash.meta')}
          validate={required}
          onChange={(v) => set('sub_user_agent', v)}
        />
        <TextRow
          title={t('set.default_interval')}
          description={t('set.default_interval_desc')}
          value={String(Math.floor(get('sub_default_interval_min', 720) / 60))}
          keyboardType="number-pad"
          validate={number(0)}
          onChange={(v) => set('sub_default_interval_min', Number(v) * 60)}
        />
        <TextRow
          title={t('set.timeout')}
          value={String(get('sub_timeout_secs', 30))}
          keyboardType="number-pad"
          validate={number(1)}
          onChange={(v) => set('sub_timeout_secs', Number(v))}
        />
        <SwitchRow
          title={t('set.reload')}
          subtitle={t('set.reload_desc')}
          value={get('sub_reload_after_update', true)}
          onChange={(v) => set('sub_reload_after_update', v)}
        />
      </Section>

      <Section header={t('set.advanced')}>
        <ChoiceRow
          title={t('set.log_level')}
          value={get('log_level', 'info')}
          options={['trace', 'debug', 'info', 'warn', 'error'].map((l) => ({ value: l, label: l }))}
          onChange={(v) => set('log_level', v)}
        />
        <SwitchRow
          title={t('set.record_logs')}
          subtitle={t('tip.record')}
          value={get('record_logs', true)}
          onChange={(v) => set('record_logs', v)}
        />
        <TextRow
          title={t('set.api_port')}
          description={t('set.api_port_desc')}
          value={String(apiPort)}
          keyboardType="number-pad"
          validate={port(mixedPort, 'err.port_proxy')}
          onChange={(v) => set('clash_api_port', Number(v))}
        />
        <TextRow
          title={t('set.test_url')}
          value={get('urltest_url', '')}
          keyboardType="url"
          validate={(v) => required(v) ?? httpUrl(v)}
          onChange={(v) => set('urltest_url', v)}
        />
        <SwitchRow
          title={t('set.auto_test')}
          subtitle={t('set.auto_test_desc')}
          value={get('auto_test_nodes', true)}
          onChange={(v) => set('auto_test_nodes', v)}
        />
        <TextRow
          title={t('set.test_interval')}
          value={String(get('urltest_interval_min', 10))}
          keyboardType="number-pad"
          validate={number(1)}
          onChange={(v) => set('urltest_interval_min', Number(v))}
        />
        <TextRow
          title={t('set.mirror')}
          description={t('set.mirror_desc')}
          value={get('github_mirror', '')}
          placeholder="—"
          keyboardType="url"
          validate={httpUrl}
          onChange={(v) => set('github_mirror', v)}
        />
        <Row
          title={t('set.export')}
          subtitle={isIOS ? undefined : t('set.export_desc')}
          chevron
          onPress={async () => {
            const config = await attempt(engine.previewConfig());
            if (config) {
              await Clipboard.setStringAsync(config);
              notify('success', t('set.config_copied'));
            }
          }}
        />
      </Section>

      <Section header={t('set.data')} footer={t('set.reset_desc_mobile')}>
        <Row testID="reset" title={t('set.reset')} destructive onPress={() => router.push('/reset')} />
      </Section>

      <Section header="BoxPilot" footer={isIOS ? undefined : t('set.tile_hint')}>
        <Row title={t('set.version')} value={version || '—'} />
        <Row title={t('set.core_embedded')} value={coreVersion === '' ? '—' : `sing-box ${coreVersion}`} />
        <Row
          title={t('set.source')}
          subtitle={isIOS ? undefined : 'github.com/BillBlueInnit/boxpilot-mobile'}
          chevron
          onPress={() => void Linking.openURL(SOURCE_URL)}
        />
        <Row
          title={t('set.licenses')}
          subtitle={isIOS ? undefined : t('set.licenses_desc')}
          chevron
          onPress={() => router.push('/licenses')}
        />
      </Section>
    </Screen>
  );
}
