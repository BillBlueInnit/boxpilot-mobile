import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import {
  type CustomRule,
  RULE_PROFILES,
  type RuleProfileId,
  type RuleProvider,
  engine,
} from '@/core/engine';
import { formatAgo, outboundLabel } from '@/core/format';
import { useT, useTick } from '@/core/hooks';
import {
  OWN_GROUP_VALUE,
  extraTargetGroups,
  profileMeta,
  providerSummary,
  providerTargetLabel,
  providerTitle,
  targetLabel,
  targetTint,
} from '@/core/rules-ui';
import { attempt, focusProxyGroup, notify, settingOf, updateSettings, useStore } from '@/core/store';
import { AnimatedChevron, configureLayoutMotion, selectionHaptic } from '@/ui/anim';
import { askChoice, askConfirm } from '@/ui/dialogs';
import { Icon } from '@/ui/icons';
import { ChoiceRow, GUTTER, Heading, Row, Screen, Section, SwitchRow, TextRow, Toggle } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

export default function Rules() {
  const t = useT();
  const palette = usePalette();
  const router = useRouter();
  const settings = useStore((s) => s.settings);
  const providers = useStore((s) => s.ruleProviders);
  const groups = useStore((s) => s.groups);
  const customGroups = useStore((s) => s.customRuleGroups);
  const [activeProfile, setActiveProfile] = useState<RuleProfileId | null>(null);
  const [parsedCustom, setParsedCustom] = useState<CustomRule[]>([]);
  const [advancedOpen, setAdvancedOpen] = useState(false);
  useTick(30);

  const refreshMeta = useCallback(() => {
    void engine.activeRuleProfile().then(setActiveProfile, () => setActiveProfile(null));
    void engine.customRulesParsed().then(setParsedCustom, () => setParsedCustom([]));
  }, []);

  useFocusEffect(
    useCallback(() => {
      refreshMeta();
    }, [refreshMeta]),
  );

  useEffect(() => {
    refreshMeta();
  }, [providers, settings, refreshMeta]);

  const template = (text: string) => (text === '' || text.includes('{name}') ? null : t('err.template'));
  const ids = providers.map((p) => p.id);
  const customEnabled = parsedCustom.filter((r) => r.enabled && r.error == null).length;
  const customErrors = parsedCustom.filter((r) => r.error != null).length;

  const jumpToProxyGroup = async (p: RuleProvider) => {
    const tag = (await engine.ruleGroupTagFor(p.id).catch(() => null)) ?? p.name;
    focusProxyGroup(tag);
    router.navigate('/(tabs)/proxies');
  };

  const applyProfile = async (profile: RuleProfileId) => {
    const { title } = profileMeta(profile);
    if (activeProfile === profile) return;
    selectionHaptic();
    const yes = await askConfirm({
      title: t('rules.profile_confirm_title', [title]),
      message: t('rules.profile_confirm_body'),
      confirmLabel: t('btn.apply'),
    });
    if (!yes) return;
    configureLayoutMotion();
    const ok = await attempt(engine.applyRuleProfile(profile).then(() => true));
    if (ok) {
      notify('success', t('rules.profile_applied', [title]));
      refreshMeta();
    }
  };

  /** Unified target picker: Proxy / Direct / Block / Own node group / other groups. */
  const pickTarget = async (p: RuleProvider) => {
    const extras = extraTargetGroups(groups, providers, customGroups).filter((g) => g !== p.name);
    const current = p.own_group && p.target !== 'reject' ? OWN_GROUP_VALUE : p.target;
    const options = [
      { value: 'proxy', label: t('target.proxy') },
      { value: 'direct', label: t('target.direct') },
      { value: 'reject', label: t('target.reject') },
      { value: OWN_GROUP_VALUE, label: t('rules.own_group_option') },
      ...extras.map((g) => ({ value: g, label: outboundLabel(g) })),
    ];
    if (!options.some((o) => o.value === current)) {
      options.push({ value: current, label: outboundLabel(current) });
    }
    const picked = await askChoice({
      title: providerTitle(p),
      message: t('rules.target_hint'),
      options,
      value: current,
    });
    if (picked === undefined || picked === current) return;
    selectionHaptic();
    if (picked === OWN_GROUP_VALUE) {
      const baseTarget = p.target === 'reject' ? 'proxy' : p.target;
      await attempt(engine.setRuleProviderTarget(p.id, baseTarget, true));
    } else {
      await attempt(engine.setRuleProviderTarget(p.id, picked, false));
    }
  };

  const menu = async (p: RuleProvider) => {
    const hasOwnGroup = p.own_group && p.target !== 'reject';
    const picked = await askChoice({
      title: providerTitle(p),
      message: [
        providerSummary(p),
        p.rule_count > 0 ? t('rules.count', [p.rule_count]) : null,
        p.last_update ? t('meta.updated', [formatAgo(p.last_update)]) : null,
      ]
        .filter(Boolean)
        .join(' · '),
      menu: true,
      options: [
        ...(hasOwnGroup ? [{ value: 'proxies', label: t('rules.goto_proxies') }] : []),
        { value: 'target', label: `${t('rules.target')}: ${providerTargetLabel(p)}` },
        { value: 'edit', label: t('btn.edit') },
        { value: 'update', label: t('tip.update_now') },
        { value: 'up', label: t('tip.move_up') },
        { value: 'down', label: t('tip.move_down') },
        { value: 'delete', label: t('btn.delete'), destructive: true },
      ],
    });
    if (picked === 'proxies') void jumpToProxyGroup(p);
    if (picked === 'target') void pickTarget(p);
    if (picked === 'edit') router.push({ pathname: '/edit-rule', params: { id: p.id } });
    if (picked === 'update') void engine.updateRuleProviders([p.id]);
    if (picked === 'up') {
      configureLayoutMotion();
      void engine.moveRuleProvider(p.id, -1);
    }
    if (picked === 'down') {
      configureLayoutMotion();
      void engine.moveRuleProvider(p.id, 1);
    }
    if (picked === 'delete') {
      const yes = await askConfirm({
        title: t('rules.delete_title'),
        message: t('rules.delete_body', [providerTitle(p)]),
        confirmLabel: t('btn.delete'),
        destructive: true,
      });
      if (yes) {
        configureLayoutMotion();
        void engine.removeRuleProviders([p.id]);
      }
    }
  };

  const finalDirect = settingOf(settings, 'final_direct', false);
  const cardRadius = isIOS ? 20 : 18;

  return (
    <Screen
      title={t('nav.rules')}
      actions={[
        {
          icon: 'search',
          label: t('btn.test_rules'),
          onPress: () => router.push('/rule-tester'),
        },
        {
          icon: 'add',
          label: t('btn.add'),
          menu: [
            { label: t('btn.service_library'), icon: 'apps', onPress: () => router.push('/service-library') },
            { label: t('btn.add_ruleset'), icon: 'rules', onPress: () => router.push('/edit-rule') },
            { label: t('btn.import_acl'), icon: 'download', onPress: () => router.push('/import-acl') },
          ],
        },
        ...(providers.length > 0
          ? [
              {
                icon: 'more' as const,
                label: t('btn.more'),
                menu: [
                  {
                    label: t('btn.update_all'),
                    icon: 'refresh' as const,
                    onPress: () => void engine.updateRuleProviders(ids),
                  },
                  {
                    label: t('btn.enable_all'),
                    icon: 'enable' as const,
                    onPress: () => void engine.setRuleProvidersEnabled(ids, true),
                  },
                  {
                    label: t('btn.disable_all'),
                    icon: 'disable' as const,
                    onPress: () => void engine.setRuleProvidersEnabled(ids, false),
                  },
                ],
              },
            ]
          : []),
      ]}>
      {/* Matching priority pipeline note */}
      <Text
        style={{
          fontSize: 13,
          lineHeight: 18,
          color: palette.secondary,
          marginHorizontal: GUTTER + 16,
          marginTop: isIOS ? 8 : 6,
        }}>
        {t('rules.pipeline_subtitle')}
      </Text>

      {/* Compact 2×2 One-click setups grid so ① Custom rules & ② Rule-sets fit right below */}
      <Heading>{t('rules.profiles_title')}</Heading>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginHorizontal: GUTTER }}>
        {RULE_PROFILES.map((profile) => {
          const { title, desc } = profileMeta(profile);
          const active = activeProfile === profile;
          return (
            <Pressable
              key={profile}
              testID={`profile-${profile}`}
              accessibilityRole="button"
              accessibilityState={{ selected: active }}
              onPress={() => void applyProfile(profile)}
              android_ripple={{ color: palette.fill }}
              style={({ pressed }) => ({
                width: '48.3%',
                flexGrow: 1,
                backgroundColor: palette.card,
                borderRadius: cardRadius,
                borderCurve: 'continuous',
                paddingHorizontal: 12,
                paddingVertical: 11,
                borderWidth: active ? 1.5 : 1,
                borderColor: active ? palette.accent : palette.separator,
                opacity: isIOS && pressed ? 0.78 : 1,
                overflow: 'hidden',
              })}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
                <Text
                  numberOfLines={1}
                  style={{
                    flex: 1,
                    fontSize: 14,
                    fontWeight: '600',
                    color: active ? palette.accent : palette.text,
                  }}>
                  {title}
                </Text>
                {active ? <Icon name="success" size={15} color={palette.accent} /> : null}
              </View>
              <Text
                numberOfLines={2}
                style={{ fontSize: 12, lineHeight: 16, color: palette.secondary, marginTop: 4 }}>
                {desc}
              </Text>
            </Pressable>
          );
        })}
      </View>
      <Text
        style={{
          fontSize: 12,
          lineHeight: 17,
          color: palette.secondary,
          marginHorizontal: GUTTER + 16,
          marginTop: 8,
        }}>
        {t('rules.profiles_hint')}
      </Text>

      {/* ① Custom rules (highest priority) */}
      <Section
        header={`① ${t('rules.step_custom')} · ${t('rules.step_custom_badge')}`}
        footer={t('rules.custom_file_mobile')}>
        <Row
          testID="custom-rules"
          title={t('rules.step_custom')}
          subtitle={
            customErrors > 0
              ? t('rules.errors_count_mobile', [customErrors])
              : parsedCustom.length === 0
                ? t('rules.custom_empty')
                : parsedCustom
                    .filter((r) => r.enabled && r.error == null)
                    .slice(0, 2)
                    .map((r) => `${r.value} → ${targetLabel(r.target)}`)
                    .join(' · ') || t('rules.count', [parsedCustom.length])
          }
          subtitleLines={1}
          value={customEnabled > 0 ? t('rules.count', [customEnabled]) : undefined}
          icon={{ name: 'edit', color: isIOS ? '#FF9500' : undefined }}
          chevron
          onPress={() => router.push('/custom-rules')}
        />
      </Section>

      {/* ② Routing rule-sets (matched in order) */}
      <Section header={`② ${t('rules.step_sets')} · ${t('rules.step_sets_badge')}`}>
        <Row
          testID="service-library"
          title={t('btn.service_library')}
          subtitle={t('rules.library_desc')}
          subtitleLines={1}
          icon={{ name: 'apps', color: isIOS ? '#5856D6' : undefined }}
          chevron
          onPress={() => router.push('/service-library')}
        />
        {providers.map((p) => {
          const hasOwnGroup = p.own_group && p.target !== 'reject';
          const tint = targetTint(palette, p.target, hasOwnGroup);
          const subtitle = p.last_error
            ? p.last_error
            : [providerSummary(p), p.rule_count > 0 ? t('rules.count', [p.rule_count]) : null]
                .filter(Boolean)
                .join(' · ');
          return (
            <Row
              key={p.id}
              title={providerTitle(p)}
              subtitle={subtitle}
              subtitleLines={p.last_error ? 2 : 1}
              disabled={!p.enabled}
              onPress={() => void menu(p)}
              trailing={
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <Pressable
                    accessibilityRole="button"
                    accessibilityLabel={`${t('rules.target')}: ${providerTargetLabel(p)}`}
                    hitSlop={6}
                    onPress={() => void pickTarget(p)}
                    style={{
                      paddingHorizontal: 10,
                      paddingVertical: 5,
                      borderRadius: 999,
                      backgroundColor: palette.fill,
                    }}>
                    <Text style={{ fontSize: 12, fontWeight: '600', color: p.enabled ? tint : palette.tertiary }}>
                      {providerTargetLabel(p)}
                    </Text>
                  </Pressable>
                  <Toggle
                    value={p.enabled}
                    onChange={(v) => {
                      selectionHaptic();
                      void engine.setRuleProvidersEnabled([p.id], v);
                    }}
                  />
                </View>
              }
            />
          );
        })}
      </Section>

      {/* ③ Default fallback */}
      <Section header={`③ ${t('rules.step_fallback')} · ${t('rules.step_fallback_badge')}`}>
        <SwitchRow
          testID="rule-bypass-cn"
          title={t('rules.bypass_cn')}
          subtitle={t('rules.bypass_cn_desc')}
          value={settingOf(settings, 'bypass_cn', true)}
          onChange={(v) => {
            selectionHaptic();
            updateSettings({ bypass_cn: v });
          }}
        />
        <SwitchRow
          testID="rule-block-ads"
          title={t('rules.block_ads')}
          subtitle={t('rules.block_ads_desc')}
          value={settingOf(settings, 'block_ads', false)}
          onChange={(v) => {
            selectionHaptic();
            updateSettings({ block_ads: v });
          }}
        />
        <ChoiceRow
          testID="rule-final-outbound"
          title={t('rules.final_outbound')}
          subtitle={t('rules.final_outbound_desc')}
          message={t('rules.final_outbound_desc')}
          value={finalDirect ? 'direct' : 'proxy'}
          options={[
            { value: 'proxy', label: t('target.proxy') },
            { value: 'direct', label: t('target.direct') },
          ]}
          onChange={(v) => {
            selectionHaptic();
            updateSettings({ final_direct: v === 'direct' });
          }}
        />
      </Section>

      {/* Collapsible Advanced */}
      <Section>
        <Row
          title={t('rules.advanced')}
          subtitle={t('rules.advanced_desc')}
          onPress={() => {
            configureLayoutMotion();
            setAdvancedOpen((v) => !v);
          }}
          trailing={<AnimatedChevron open={advancedOpen} icon="expand" degrees={180} size={16} color={palette.secondary} />}
        />
        {advancedOpen ? (
          <>
            <SwitchRow
              title={t('rules.via_proxy')}
              subtitle={t('rules.via_proxy_desc')}
              value={settingOf(settings, 'ruleset_via_proxy', true)}
              onChange={(v) => updateSettings({ ruleset_via_proxy: v })}
            />
            <TextRow
              title={t('rules.geosite_url')}
              description={t('rules.template_desc')}
              value={settingOf(settings, 'geosite_url', '')}
              keyboardType="url"
              validate={template}
              onChange={(v) => updateSettings({ geosite_url: v })}
            />
            <TextRow
              title={t('rules.geoip_url')}
              description={t('rules.template_desc')}
              value={settingOf(settings, 'geoip_url', '')}
              keyboardType="url"
              validate={template}
              onChange={(v) => updateSettings({ geoip_url: v })}
            />
          </>
        ) : null}
      </Section>
    </Screen>
  );
}
