import { useRouter } from 'expo-router';

import { type RuleProvider, engine } from '@/core/engine';
import { formatAgo, outboundLabel } from '@/core/format';
import { useT, useTick } from '@/core/hooks';
import { settingOf, updateSettings, useStore } from '@/core/store';
import { tr } from '@/i18n';
import { askChoice, askConfirm } from '@/ui/dialogs';
import { EmptyState, Row, Screen, Section, SwitchRow, TextRow, Toggle } from '@/ui/kit';

/** Where a rule-set's matches go, as the list shows it. */
function targetLabel(p: RuleProvider): string {
  if (p.own_group && p.target !== 'reject') return tr('rules.target_custom');
  if (p.target === 'proxy' || p.target === 'direct' || p.target === 'reject') return tr(`target.${p.target}`);
  return outboundLabel(p.target);
}

export default function Rules() {
  const t = useT();
  const router = useRouter();
  const settings = useStore((s) => s.settings);
  const providers = useStore((s) => s.ruleProviders);
  useTick(30);

  const template = (text: string) => (text === '' || text.includes('{name}') ? null : t('err.template'));
  const ids = providers.map((p) => p.id);
  const customRules = settingOf(settings, 'custom_rules', '');
  const customCount = customRules.split('\n').filter((l) => l.trim() !== '' && !l.trim().startsWith('#')).length;

  const menu = async (p: RuleProvider) => {
    const picked = await askChoice({
      title: p.name,
      menu: true,
      options: [
        { value: 'edit', label: t('btn.edit') },
        { value: 'update', label: t('tip.update_now') },
        { value: 'up', label: t('tip.move_up') },
        { value: 'down', label: t('tip.move_down') },
        { value: 'delete', label: t('btn.delete'), destructive: true },
      ],
    });
    if (picked === 'edit') router.push({ pathname: '/edit-rule', params: { id: p.id } });
    if (picked === 'update') void engine.updateRuleProviders([p.id]);
    if (picked === 'up') void engine.moveRuleProvider(p.id, -1);
    if (picked === 'down') void engine.moveRuleProvider(p.id, 1);
    if (picked === 'delete') {
      const yes = await askConfirm({
        title: t('rules.delete_title'),
        message: t('rules.delete_body', [p.name]),
        confirmLabel: t('btn.delete'),
        destructive: true,
      });
      if (yes) void engine.removeRuleProviders([p.id]);
    }
  };

  return (
    <Screen
      title={t('nav.rules')}
      actions={[
        {
          icon: 'add',
          label: t('btn.add'),
          menu: [
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
      <Section header={t('rules.builtin')}>
        <SwitchRow
          title={t('rules.bypass_cn')}
          subtitle={t('rules.bypass_cn_desc')}
          value={settingOf(settings, 'bypass_cn', true)}
          onChange={(v) => updateSettings({ bypass_cn: v })}
        />
        <SwitchRow
          title={t('rules.block_ads')}
          subtitle={t('rules.block_ads_desc')}
          value={settingOf(settings, 'block_ads', false)}
          onChange={(v) => updateSettings({ block_ads: v })}
        />
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
      </Section>

      <Section header={t('rules.custom')} footer={t('rules.custom_file_mobile')}>
        <Row
          testID="custom-rules"
          title={t('rules.custom')}
          value={customCount > 0 ? t('rules.count', [customCount]) : undefined}
          chevron
          onPress={() => router.push('/custom-rules')}
        />
      </Section>

      {providers.length > 0 ? (
        <Section header={t('rules.sets')}>
          {providers.map((p) => (
            <Row
              key={p.id}
              title={p.name}
              subtitle={
                p.last_error
                  ? p.last_error
                  : [
                      targetLabel(p),
                      t('rules.count', [p.rule_count]),
                      p.last_update ? t('meta.updated', [formatAgo(p.last_update)]) : t('subs.never_updated'),
                    ].join(' · ')
              }
              subtitleLines={2}
              onPress={() => void menu(p)}
              trailing={<Toggle value={p.enabled} onChange={(v) => void engine.setRuleProvidersEnabled([p.id], v)} />}
            />
          ))}
        </Section>
      ) : (
        <EmptyState icon="rules" title={t('rules.empty_title')} message={t('rules.empty_hint')} />
      )}
    </Screen>
  );
}
