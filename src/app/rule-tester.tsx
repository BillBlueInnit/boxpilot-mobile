import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Text, View } from 'react-native';

import { type RuleMatchLayer, type RuleMatchResult, engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { targetLabel, targetTint } from '@/core/rules-ui';
import { focusProxyGroup, useStore } from '@/core/store';
import { FadeInView, selectionHaptic } from '@/ui/anim';
import { Card, Chip, Field, GUTTER, Row, Screen, Section, useClose } from '@/ui/kit';
import { usePalette } from '@/ui/theme';

const SAMPLES = ['chatgpt.com', 'youtube.com', 'bilibili.com', '192.168.1.1'];

function layerLabel(t: (key: string, args?: (string | number)[]) => string, layer: RuleMatchLayer): string {
  switch (layer.kind) {
    case 'private_ip':
      return t('rules.match_private');
    case 'custom_rule':
      return t('rules.match_custom', [layer.line_index + 1]);
    case 'custom_group':
      return t('rules.match_custom_group_mobile', [layer.name]);
    case 'rule_set':
      return t('rules.match_ruleset', [layer.name]);
    case 'built_in':
      return t('rules.match_builtin');
    case 'fallback':
      return t('rules.match_fallback');
  }
}

/** Simulates the routing pipeline for a domain, URL, IP or app name. */
export default function RuleTester() {
  const t = useT();
  const palette = usePalette();
  const router = useRouter();
  const close = useClose();
  const providers = useStore((s) => s.ruleProviders);
  const customGroups = useStore((s) => s.customRuleGroups);
  const [query, setQuery] = useState('');
  const [result, setResult] = useState<RuleMatchResult | null>(null);

  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed === '') return;
    let alive = true;
    const timer = setTimeout(() => {
      void engine.testRuleMatch(trimmed).then(
        (res) => {
          if (alive) setResult(res);
        },
        () => {
          if (alive) setResult(null);
        },
      );
    }, 140);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [query]);

  const ruleSetId = result?.layer.kind === 'rule_set' ? result.layer.id : null;
  const customGroupId = result?.layer.kind === 'custom_group' ? result.layer.id : null;
  const matchedProvider = ruleSetId
    ? providers.find((p) => p.id === ruleSetId && p.own_group && p.target !== 'reject')
    : undefined;
  const matchedCustomGroup = customGroupId
    ? customGroups.find((g) => g.id === customGroupId && g.own_group && g.target !== 'reject')
    : undefined;

  const openGroup = async () => {
    let tag: string | null = null;
    if (matchedProvider) {
      tag = (await engine.ruleGroupTagFor(matchedProvider.id).catch(() => null)) ?? matchedProvider.name;
    } else if (matchedCustomGroup) {
      tag = (await engine.customRuleGroupTagFor(matchedCustomGroup.id).catch(() => null)) ?? matchedCustomGroup.name;
    }
    if (!tag) return;
    focusProxyGroup(tag);
    close();
    router.navigate('/(tabs)/proxies');
  };

  return (
    <Screen title={t('btn.test_rules')} modal dismissLabel={t('btn.close')}>
      <Section footer={t('rules.pipeline_subtitle')}>
        <Field
          testID="rule-tester-input"
          label={t('btn.test_rules')}
          value={query}
          onChange={(v) => {
            setQuery(v);
            if (v.trim() === '') setResult(null);
          }}
          placeholder={t('rules.tester_placeholder_mobile')}
          autoFocus
        />
      </Section>

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginHorizontal: GUTTER, marginTop: 14 }}>
        {SAMPLES.map((sample) => (
          <Chip
            key={sample}
            icon="search"
            label={sample}
            onPress={() => {
              selectionHaptic();
              setQuery(sample);
            }}
          />
        ))}
      </View>

      {result ? (
        <FadeInView key={`${result.query}:${result.rule}`}>
          <Card style={{ marginHorizontal: GUTTER, marginTop: 18 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
              <Text style={{ fontSize: 13, fontWeight: '600', color: palette.accent, flexShrink: 1 }}>
                {layerLabel(t, result.layer)}
              </Text>
              <View
                style={{
                  paddingHorizontal: 10,
                  paddingVertical: 4,
                  borderRadius: 999,
                  backgroundColor: palette.fill,
                }}>
                <Text style={{ fontSize: 13, fontWeight: '600', color: targetTint(palette, result.target) }}>
                  {targetLabel(result.target)}
                </Text>
              </View>
            </View>
            <Text
              selectable
              style={{
                fontSize: 15,
                fontWeight: '500',
                color: palette.text,
                marginTop: 10,
              }}>
              {result.rule}
            </Text>
            {result.approximate ? (
              <Text style={{ fontSize: 12, color: palette.secondary, marginTop: 6 }}>{t('rules.match_approx')}</Text>
            ) : null}
          </Card>
        </FadeInView>
      ) : null}

      {matchedProvider || matchedCustomGroup ? (
        <Section>
          <Row
            title={t('rules.goto_proxies')}
            value={matchedProvider?.name ?? matchedCustomGroup?.name}
            chevron
            onPress={() => void openGroup()}
          />
        </Section>
      ) : null}
    </Screen>
  );
}
