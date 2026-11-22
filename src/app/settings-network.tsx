import { useT } from '@/core/hooks';
import { settingOf, updateSettings, useStore } from '@/core/store';
import { ChoiceRow, Screen, Section, SwitchRow, TextRow } from '@/ui/kit';

/** Proxy, TUN and DNS settings — kept out of top-level Settings so daily options stay calm. */
export default function SettingsNetwork() {
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
  const required = (text: string) => (text === '' ? t('err.required') : null);

  return (
    <Screen title={t('set.network_dns_mobile')}>
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
    </Screen>
  );
}
