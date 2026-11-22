import * as Clipboard from 'expo-clipboard';
import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';

import { type ConnectionInfo, type Connections, engine } from '@/core/engine';
import { formatBytes, formatSpeed, outboundLabel } from '@/core/format';
import { useT } from '@/core/hooks';
import { extraTargetGroups } from '@/core/rules-ui';
import { attempt, isRunning, notify, useStore } from '@/core/store';
import { askChoice } from '@/ui/dialogs';
import { EmptyState, GUTTER, Screen } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

type Row = ConnectionInfo & { up: number; down: number };

/** Live connections through the core. Tap one to add a rule for it or close it. */
export default function ConnectionsPage() {
  const t = useT();
  const router = useRouter();
  const palette = usePalette();
  const running = useStore((s) => isRunning(s.status));
  const groups = useStore((s) => s.groups);
  const providers = useStore((s) => s.ruleProviders);
  const customGroups = useStore((s) => s.customRuleGroups);
  const [snapshot, setSnapshot] = useState<Connections | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [filter, setFilter] = useState('');
  const last = useRef(new Map<string, { upload: number; download: number }>());

  useFocusEffect(
    useCallback(() => {
      if (!running) {
        setSnapshot(null);
        setRows([]);
        return;
      }
      let alive = true;
      const poll = async () => {
        const snap = await engine.connections().catch(() => null);
        if (!alive || !snap) return;
        // Speeds are the bytes since the last poll, one second ago.
        const next = new Map<string, { upload: number; download: number }>();
        const list = snap.items.map((c) => {
          const before = last.current.get(c.id);
          next.set(c.id, { upload: c.upload, download: c.download });
          return { ...c, up: before ? c.upload - before.upload : 0, down: before ? c.download - before.download : 0 };
        });
        last.current = next;
        list.sort((a, b) => b.start.localeCompare(a.start));
        setSnapshot(snap);
        setRows(list);
      };
      void poll();
      const timer = setInterval(poll, 1000);
      return () => {
        alive = false;
        clearInterval(timer);
      };
    }, [running]),
  );

  const f = filter.toLowerCase();
  const shown =
    f === ''
      ? rows
      : rows.filter((c) => [c.target, c.process, c.rule, c.outbound].some((v) => v.toLowerCase().includes(f)));

  /** The desktop's right-click menu: a rule for this host, its site, the app or the address. */
  const menu = async (c: ConnectionInfo) => {
    const extraGroups = extraTargetGroups(groups, providers, customGroups);
    const picked = await askChoice({
      title: c.target,
      message: [c.rule, c.chains.map(outboundLabel).reverse().join(' → ')].filter(Boolean).join('\n'),
      menu: true,
      options: [
        { value: 'direct', label: t('conn.always_direct') },
        { value: 'proxy', label: t('conn.always_proxy') },
        { value: 'reject', label: t('conn.always_block') },
        ...(extraGroups.length > 0 ? [{ value: 'group', label: t('conn.route_to_group') }] : []),
        { value: 'rules', label: t('rules.open_rules_mobile') },
        { value: 'copy', label: t('conn.copy_address') },
        { value: 'close', label: t('conn.close'), destructive: true },
      ],
    });
    if (picked === undefined) return;
    if (picked === 'rules') {
      router.push('/rules');
      return;
    }
    if (picked === 'copy') {
      await Clipboard.setStringAsync(c.target);
      notify('success', t('conn.copied'));
      return;
    }
    if (picked === 'close') {
      await attempt(engine.closeConnection(c.id));
      return;
    }
    let target = picked;
    if (picked === 'group') {
      const groupPicked = await askChoice({
        title: t('conn.route_to_group'),
        options: extraGroups.map((g) => ({ value: g, label: outboundLabel(g) })),
      });
      if (!groupPicked) return;
      target = groupPicked;
    }
    const matches: { label: string; rule: string }[] = [];
    if (c.host !== '') {
      const base = await engine.baseDomain(c.host).catch(() => null);
      if (base) matches.push({ label: t('conn.match_site', [base]), rule: `DOMAIN-SUFFIX,${base}` });
      matches.push({ label: t('conn.match_host', [c.host]), rule: `DOMAIN,${c.host}` });
    } else if (c.destination_ip !== '') {
      const bits = c.destination_ip.includes(':') ? 128 : 32;
      matches.push({ label: t('conn.match_ip', [c.destination_ip]), rule: `IP-CIDR,${c.destination_ip}/${bits}` });
    }
    if (c.process !== '') matches.push({ label: t('conn.match_process', [c.process]), rule: `PROCESS-NAME,${c.process}` });
    if (matches.length === 0) return;
    const match =
      matches.length === 1
        ? matches[0].rule
        : await askChoice({
            title: t('conn.add_rule'),
            menu: true,
            options: matches.map((m) => ({ value: m.rule, label: m.label })),
          });
    if (!match) return;
    const rule = `${match},${target}`;
    // The core reloads to apply a rule, so open connections drop.
    const added = await attempt(engine.addCustomRule(rule));
    if (added !== undefined) notify(added ? 'success' : 'info', added ? t('conn.rule_added', [rule]) : t('conn.rule_exists'));
  };

  return (
    <Screen
      title={t('nav.connections')}
      scroll={false}
      search={running ? { placeholder: t('conn.filter'), onChange: setFilter } : undefined}
      actions={
        rows.length > 0
          ? [{ icon: 'close', label: t('btn.close_all'), onPress: () => void attempt(engine.closeAllConnections()) }]
          : []
      }>
      <FlatList
        data={shown}
        keyExtractor={(c) => c.id}
        contentInsetAdjustmentBehavior="automatic"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ paddingBottom: 32 }}
        ListHeaderComponent={
          snapshot && rows.length > 0 ? (
            <Text style={{ fontSize: 13, color: palette.secondary, marginHorizontal: GUTTER + 16, marginVertical: 8 }}>
              {t('conn.subtitle', [rows.length, formatBytes(snapshot.upload_total), formatBytes(snapshot.download_total)])}
            </Text>
          ) : undefined
        }
        ListEmptyComponent={
          running ? (
            <EmptyState icon="connections" title={t('conn.none')} message={t('conn.none_hint')} />
          ) : (
            <EmptyState icon="offline" title={t('proxies.not_connected')} message={t('conn.offline_hint')} />
          )
        }
        renderItem={({ item, index }) => (
          <ConnectionRow
            connection={item}
            first={index === 0}
            last={index === shown.length - 1}
            onPress={() => void menu(item)}
          />
        )}
      />
    </Screen>
  );
}

function ConnectionRow({
  connection: c,
  first,
  last,
  onPress,
}: {
  connection: Row;
  first: boolean;
  last: boolean;
  onPress: () => void;
}) {
  const palette = usePalette();
  const radius = isIOS ? 26 : 24;
  return (
    <View
      style={{
        marginHorizontal: GUTTER,
        backgroundColor: palette.card,
        borderTopLeftRadius: first ? radius : 0,
        borderTopRightRadius: first ? radius : 0,
        borderBottomLeftRadius: last ? radius : 0,
        borderBottomRightRadius: last ? radius : 0,
        borderCurve: 'continuous',
        overflow: 'hidden',
      }}>
      {!first ? (
        <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: palette.separator, marginLeft: 16 }} />
      ) : null}
      <Pressable
        onPress={onPress}
        android_ripple={{ color: palette.fill }}
        style={({ pressed }) => ({
          paddingHorizontal: 16,
          paddingVertical: 10,
          backgroundColor: isIOS && pressed ? palette.fill : undefined,
        })}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Text numberOfLines={1} style={{ flex: 1, fontSize: 15, fontWeight: '500', color: palette.text }}>
            {c.target}
          </Text>
          <Text style={{ fontSize: 11, fontWeight: '600', color: palette.secondary }}>{c.network.toUpperCase()}</Text>
        </View>
        <Text numberOfLines={1} style={{ fontSize: 12, color: palette.secondary, marginTop: 3 }}>
          {[outboundLabel(c.outbound), c.rule, c.process].filter(Boolean).join(' · ')}
        </Text>
        <Text style={{ fontSize: 12, color: palette.secondary, marginTop: 2, fontVariant: ['tabular-nums'] }}>
          {`↑ ${formatSpeed(c.up)}  ↓ ${formatSpeed(c.down)}  ·  ${formatBytes(c.upload + c.download)}`}
        </Text>
      </Pressable>
    </View>
  );
}
