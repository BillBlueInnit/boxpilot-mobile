import * as Clipboard from 'expo-clipboard';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify, settingOf, updateSettings, useStore } from '@/core/store';
import { ChoiceRow, Row, Screen, Section, SwitchRow, TextRow } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

/** Subscription defaults and power-user diagnostics. */
export default function SettingsAdvanced() {
  const t = useT();
  const settings = useStore((s) => s.settings);
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

  return (
    <Screen title={t('set.subs_advanced_mobile')}>
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
    </Screen>
  );
}
