import * as Clipboard from 'expo-clipboard';
import { useEffect, useMemo, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';

import { AUTO_STRATEGIES, type AutoStrategy, type Group, type Member, engine } from '@/core/engine';
import { flagEmoji, formatSpeed, outboundLabel } from '@/core/format';
import { useT } from '@/core/hooks';
import { attempt, connect, isRunning, notify, settingOf, updateSettings, useStore } from '@/core/store';
import { askChoice } from '@/ui/dialogs';
import { Icon } from '@/ui/icons';
import { Button, Chip, EmptyState, GUTTER, Screen } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';
import { CountryBadge, LatencyBadge } from '@/ui/widgets';

type Sort = 'order' | 'latency' | 'name';

type Item =
  | { kind: 'header'; group: Group; expanded: boolean }
  | { kind: 'controls'; group: Group }
  | { kind: 'member'; group: Group; member: Member; first: boolean; last: boolean };

/** Latency for sorting: tested nodes first, failed ones before untested. */
function latencyRank(m: Member): number {
  const d = m.real_delay ?? m.delay;
  return d == null ? 2 ** 30 : d < 0 ? 2 ** 29 : d;
}

function visibleMembers(g: Group, filter: string, sort: Sort): Member[] {
  const f = filter.toLowerCase();
  const members = g.members.filter((m) => f === '' || m.name.toLowerCase().includes(f));
  if (sort === 'latency') members.sort((a, b) => latencyRank(a) - latencyRank(b));
  if (sort === 'name') members.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  return members;
}

/** Whether the engine picks this group's node (Auto, or a rule-set group with a mode). */
const picksItself = (g: Group) => g.name === 'Auto' || g.rule_group != null;

export default function Proxies() {
  const t = useT();
  const running = useStore((s) => isRunning(s.status));
  const groups = useStore((s) => s.groups);
  const [expanded, setExpanded] = useState<string[]>(['Proxy']);
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState<Sort>('order');

  const items = useMemo(() => {
    const out: Item[] = [];
    for (const group of groups) {
      const open = expanded.includes(group.name) || filter !== '';
      out.push({ kind: 'header', group, expanded: open });
      if (picksItself(group)) out.push({ kind: 'controls', group });
      if (open) {
        const members = visibleMembers(group, filter, sort);
        members.forEach((member, i) =>
          out.push({ kind: 'member', group, member, first: i === 0, last: i === members.length - 1 }),
        );
      }
    }
    return out;
  }, [groups, expanded, filter, sort]);

  /** Nodes (not groups) currently shown, for the bulk tests. */
  const shownNodes = () => {
    const names = new Set<string>();
    for (const item of items) {
      if (item.kind === 'member' && !item.member.is_group && item.member.name !== 'direct') names.add(item.member.name);
    }
    return [...names];
  };

  const toggle = (name: string) =>
    setExpanded((list) => (list.includes(name) ? list.filter((n) => n !== name) : [...list, name]));

  if (!running || groups.length === 0) {
    return (
      <Screen title={t('nav.proxies')} root>
        {running ? (
          <EmptyState icon="hourglass" title={t('proxies.loading')} />
        ) : (
          <EmptyState
            icon="offline"
            title={t('proxies.not_connected')}
            message={t('proxies.not_connected_hint')}
            action={<Button label={t('btn.connect')} onPress={() => void connect()} />}
          />
        )}
      </Screen>
    );
  }

  return (
    <Screen
      title={t('nav.proxies')}
      root
      scroll={false}
      search={{ placeholder: t('proxies.filter'), onChange: setFilter }}
      actions={[
        {
          icon: 'speed',
          label: t('btn.test_latency'),
          menu: [
            { label: t('btn.test_latency'), icon: 'bolt', onPress: () => void engine.testDelays(shownNodes()) },
            {
              label: t('btn.real_latency'),
              icon: 'realLatency',
              onPress: () => void engine.testRealLatency(shownNodes()),
            },
            { label: t('btn.speed_test'), icon: 'download', onPress: () => void engine.speedTest(shownNodes()) },
          ],
        },
        {
          icon: 'sort',
          label: t('proxies.sort'),
          menu: [
            { label: t('sort.default'), checked: sort === 'order', onPress: () => setSort('order') },
            { label: t('sort.latency'), checked: sort === 'latency', onPress: () => setSort('latency') },
            { label: t('sort.name'), checked: sort === 'name', onPress: () => setSort('name') },
          ],
        },
      ]}>
      <FlatList
        data={items}
        contentInsetAdjustmentBehavior="automatic"
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="on-drag"
        keyExtractor={(item) =>
          item.kind === 'member' ? `${item.group.name}/${item.member.name}` : `${item.kind}/${item.group.name}`
        }
        contentContainerStyle={{ paddingBottom: 32 }}
        renderItem={({ item }) =>
          item.kind === 'header' ? (
            <GroupHeader group={item.group} expanded={item.expanded} onPress={() => toggle(item.group.name)} />
          ) : item.kind === 'controls' ? (
            <PickControls group={item.group} />
          ) : (
            <MemberRow group={item.group} member={item.member} first={item.first} last={item.last} />
          )
        }
      />
    </Screen>
  );
}

function GroupHeader({ group, expanded, onPress }: { group: Group; expanded: boolean; onPress: () => void }) {
  const t = useT();
  const palette = usePalette();
  const pick = group.rule_group?.pick;
  const kind = group.rule_group
    ? pick
      ? t(`auto.${pick}`)
      : t('auto.manual')
    : group.selectable
      ? t('proxies.selector')
      : t('proxies.urltest');
  const now = group.now === '' ? '' : outboundLabel(group.now);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ expanded }}
      onPress={onPress}
      android_ripple={{ color: palette.fill }}
      style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: GUTTER + 16, paddingTop: 16, paddingBottom: 8 }}>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 17, fontWeight: '600', color: palette.text }}>{outboundLabel(group.name)}</Text>
        <Text numberOfLines={1} style={{ fontSize: 13, color: palette.secondary, marginTop: 2 }}>
          {[kind, now].filter(Boolean).join(' · ')}
        </Text>
      </View>
      <Text style={{ fontSize: 15, color: palette.secondary, marginRight: 6 }}>{group.members.length}</Text>
      <View style={{ transform: [{ rotate: expanded ? '90deg' : '0deg' }] }}>
        <Icon name="chevron" size={14} color={palette.secondary} />
      </View>
    </Pressable>
  );
}

/** How a group picks its node and which region it keeps to, as on the desktop's Proxies page. */
function PickControls({ group }: { group: Group }) {
  const t = useT();
  const palette = usePalette();
  const settings = useStore((s) => s.settings);
  const groups = useStore((s) => s.groups);
  const [countries, setCountries] = useState<{ code: string; nodes: number }[]>([]);
  useEffect(() => {
    void engine.countryCounts().then(setCountries, () => {});
  }, [groups]);

  const rule = group.rule_group;
  const strategy: AutoStrategy | null = rule ? rule.pick : settingOf(settings, 'auto_strategy', 'quickest') as AutoStrategy;
  const region = rule ? rule.region : settingOf(settings, 'auto_region', '');
  const setPick = (pick: AutoStrategy | null, where: string) => {
    if (rule) void attempt(engine.setRuleGroupPick(rule.id, pick, where));
    else if (pick) updateSettings({ auto_strategy: pick, auto_region: where });
  };

  const regionLabel = region === '' ? t('auto.region_any') : `${flagEmoji(region)} ${region}`;
  const pickStrategy = async () => {
    const options: { value: AutoStrategy | 'manual'; label: string }[] = [
      // A rule-set's group can also be left to the user.
      ...(rule ? [{ value: 'manual' as const, label: t('auto.manual') }] : []),
      ...AUTO_STRATEGIES.map((s) => ({ value: s, label: t(`auto.${s}`) })),
    ];
    const picked = await askChoice<AutoStrategy | 'manual'>({
      title: outboundLabel(group.name),
      options,
      value: strategy ?? 'manual',
    });
    if (picked !== undefined) setPick(picked === 'manual' ? null : picked, region);
  };
  const pickRegion = async () => {
    const options = [
      { value: '', label: t('auto.region_any') },
      ...countries.map((c) => ({ value: c.code, label: `${flagEmoji(c.code)} ${c.code}  (${c.nodes})` })),
    ];
    if (region !== '' && !countries.some((c) => c.code === region)) options.push({ value: region, label: region });
    const picked = await askChoice({ title: t('auto.region_any'), options, value: region });
    if (picked !== undefined) setPick(strategy, picked);
  };

  let hint = strategy ? t(`auto.${strategy}_hint`) : t('auto.manual_hint_mobile');
  // iOS suspends the app in the background, and with it the engine's picking.
  if (isIOS && strategy) hint += ` ${t('auto.ios_managed')}`;
  return (
    <View style={{ paddingHorizontal: GUTTER + 16, paddingBottom: 10 }}>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        <Chip icon="tune" label={strategy ? t(`auto.${strategy}`) : t('auto.manual')} onPress={pickStrategy} />
        {strategy ? <Chip icon="region" label={regionLabel} onPress={pickRegion} /> : null}
      </View>
      <Text style={{ fontSize: 12, lineHeight: 17, color: palette.secondary, marginTop: 8 }}>{hint}</Text>
    </View>
  );
}

function MemberRow({ group, member, first, last }: { group: Group; member: Member; first: boolean; last: boolean }) {
  const t = useT();
  const palette = usePalette();
  const selected = group.now === member.name;
  const isNode = !member.is_group && member.name !== 'direct';
  const details = [
    member.is_group ? t('proxies.group') : member.protocol.toUpperCase(),
    member.speed != null ? formatSpeed(member.speed) : null,
    member.speed_testing ? '…' : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const radius = isIOS ? 26 : 24;

  const menu = async () => {
    // Where the country comes from: the name, the server's address, or a measured exit.
    const origin =
      member.country_origin === 'exit'
        ? t('geo.from_exit', [member.country_ip])
        : member.country_origin === 'ip'
          ? t('geo.from_ip', [member.country_ip])
          : member.country_origin === 'name'
            ? t('geo.from_name')
            : undefined;
    const picked = await askChoice({
      title: outboundLabel(member.name),
      message: origin,
      menu: true,
      options: [
        { value: 'latency', label: t('btn.test_latency') },
        { value: 'real', label: t('btn.real_latency') },
        { value: 'speed', label: t('btn.speed_test') },
        { value: 'share', label: t('tip.share') },
      ],
    });
    if (picked === 'latency') void engine.testDelays([member.name]);
    if (picked === 'real') void engine.testRealLatency([member.name]);
    if (picked === 'speed') void engine.speedTest([member.name]);
    if (picked === 'share') {
      const link = await attempt(engine.shareLinkFor(member.name));
      if (link) {
        await Clipboard.setStringAsync(link);
        notify('success', t('share.copied'));
      }
    }
  };

  return (
    <View
      style={{
        marginHorizontal: GUTTER,
        marginBottom: last ? 4 : 0,
        backgroundColor: palette.card,
        borderTopLeftRadius: first ? radius : 0,
        borderTopRightRadius: first ? radius : 0,
        borderBottomLeftRadius: last ? radius : 0,
        borderBottomRightRadius: last ? radius : 0,
        borderCurve: 'continuous',
        overflow: 'hidden',
      }}>
      {!first ? (
        <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: palette.separator, marginLeft: 48 }} />
      ) : null}
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ selected }}
        disabled={!group.selectable && !isNode}
        onPress={group.selectable && !selected ? () => void engine.selectProxy(group.name, member.name) : undefined}
        onLongPress={isNode ? menu : undefined}
        android_ripple={{ color: palette.fill }}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          paddingLeft: 12,
          paddingRight: 12,
          paddingVertical: 10,
          minHeight: 56,
          backgroundColor: isIOS && pressed ? palette.fill : undefined,
        })}>
        <View style={{ width: 24, alignItems: 'center', marginRight: 12 }}>
          {selected ? <Icon name={isIOS ? 'check' : 'success'} size={isIOS ? 18 : 22} color={palette.accent} /> : null}
        </View>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            {member.country ? <CountryBadge code={member.country} /> : null}
            <Text
              numberOfLines={1}
              style={{ flexShrink: 1, fontSize: 16, fontWeight: selected ? '600' : '400', color: palette.text }}>
              {outboundLabel(member.name)}
            </Text>
          </View>
          {details ? <Text style={{ fontSize: 12, color: palette.secondary, marginTop: 3 }}>{details}</Text> : null}
        </View>
        {isNode ? (
          <LatencyBadge
            delay={member.real_delay ?? member.delay}
            testing={member.testing || member.speed_testing}
            onPress={() => void engine.testDelays([member.name])}
          />
        ) : null}
      </Pressable>
    </View>
  );
}
