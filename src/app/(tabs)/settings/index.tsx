import * as Application from 'expo-application';
import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Linking } from 'react-native';

import { type RuleProfileId, engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { profileMeta } from '@/core/rules-ui';
import { settingOf, updateSettings, useStore } from '@/core/store';
import { LANGUAGES } from '@/i18n';
import { ChoiceRow, Row, Screen, Section, SwitchRow } from '@/ui/kit';
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
  const providers = useStore((s) => s.ruleProviders);
  const [activeProfile, setActiveProfile] = useState<RuleProfileId | null>(null);
  const get = <T,>(key: string, fallback: T) => settingOf(settings, key, fallback);
  const set = (key: string, value: unknown) => updateSettings({ [key]: value });

  const refreshProfile = useCallback(() => {
    void engine.activeRuleProfile().then(setActiveProfile, () => setActiveProfile(null));
  }, []);

  useFocusEffect(
    useCallback(() => {
      refreshProfile();
    }, [refreshProfile]),
  );
  useEffect(() => {
    refreshProfile();
  }, [providers, settings, refreshProfile]);

  const mixedPort = get('mixed_port', 7890);
  const tunStack = get('tun_stack', 'mixed');
  const ruleValue = activeProfile
    ? profileMeta(activeProfile).title
    : providers.length > 0
      ? t('rules.count', [providers.length])
      : undefined;

  const version = [Application.nativeApplicationVersion, Application.nativeBuildVersion]
    .filter(Boolean)
    .join(' (')
    .replace(/(\(.*)$/, '$1)');

  return (
    <Screen title={t('nav.settings')} root>
      <Section header={t('set.general')} footer={isIOS ? undefined : t('set.accent_desc_mobile')}>
        <ChoiceRow
          testID="setting-language"
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
          testID="setting-theme"
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

      <Section header={t('set.routing_network_mobile')}>
        <Row
          title={t('nav.rules')}
          subtitle={isIOS ? undefined : t('home.rules_desc')}
          value={ruleValue}
          icon={{ name: 'rules', color: tint('#5856D6') }}
          chevron
          onPress={() => router.push('/rules')}
        />
        {perApp ? (
          <Row
            title={t('perapp.title')}
            subtitle={t('perapp.summary')}
            icon={{ name: 'apps', color: tint('#FF9500') }}
            chevron
            onPress={() => router.push('/per-app')}
          />
        ) : null}
        <Row
          testID="setting-network"
          title={t('set.network_dns_mobile')}
          subtitle={isIOS ? undefined : `${mixedPort} · ${tunStack}`}
          value={isIOS ? `${mixedPort} · ${tunStack}` : undefined}
          icon={{ name: 'proxies', color: tint('#007AFF') }}
          chevron
          onPress={() => router.push('/settings-network')}
        />
        <Row
          testID="setting-advanced"
          title={t('set.subs_advanced_mobile')}
          subtitle={isIOS ? undefined : t('set.subs_advanced_desc_mobile')}
          icon={{ name: 'tune', color: tint('#8E8E93') }}
          chevron
          onPress={() => router.push('/settings-advanced')}
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
