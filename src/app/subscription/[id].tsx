import * as Clipboard from 'expo-clipboard';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';

import { LOCAL_NODES_ID, type NodeInfo, engine } from '@/core/engine';
import { formatAgo, formatInterval, usageText } from '@/core/format';
import { useT } from '@/core/hooks';
import { attempt, notify, useStore } from '@/core/store';
import { askChoice, askConfirm } from '@/ui/dialogs';
import { type MenuItem, Row, Screen, Section, SwitchRow, useClose } from '@/ui/kit';

/** One subscription: its switch, details and nodes. "Local nodes" shows here too. */
export default function SubscriptionDetail() {
  const t = useT();
  const router = useRouter();
  const close = useClose();
  const { id } = useLocalSearchParams<{ id: string }>();
  const isLocalNodes = id === LOCAL_NODES_ID;
  const sub = useStore((s) => (isLocalNodes ? s.local : s.subscriptions.find((x) => x.id === id)));
  const updating = useStore((s) => s.updating.includes(id));
  const [nodes, setNodes] = useState<NodeInfo[]>([]);
  const stamp = `${sub?.last_update}/${sub?.node_count}`;

  useEffect(() => {
    void engine.nodes(id).then(setNodes, () => setNodes([]));
  }, [id, stamp]);

  // Deleted (here or by the last local node going): nothing left to show.
  const gone = !sub;
  const left = useRef(false);
  useEffect(() => {
    if (gone && !left.current) {
      left.current = true;
      close();
    }
  });
  if (!sub) return null;

  const name = isLocalNodes ? t('local.title') : sub.name || t('subs.untitled');
  const remote = sub.url !== '';

  const copyLinks = async () => {
    const shared = await attempt(engine.shareSubscription(id));
    if (!shared) return;
    const count = shared.text === '' ? 0 : shared.text.split('\n').length;
    if (count === 0) {
      notify('error', t('share.none'));
      return;
    }
    await Clipboard.setStringAsync(shared.text);
    const skipped = shared.skipped.length > 0 ? t('share.skipped', [shared.skipped.length]) : '';
    notify('success', t('share.copied_n', [count]) + skipped);
  };

  const remove = async () => {
    const yes = await askConfirm({
      title: t('subs.delete_title'),
      message: t('subs.delete_body', [name]),
      confirmLabel: t('btn.delete'),
      destructive: true,
    });
    if (yes) void engine.removeSubscriptions([id]);
  };

  const nodeMenu = async (node: NodeInfo, index: number) => {
    const picked = await askChoice({
      title: node.name,
      menu: true,
      options: [
        { value: 'share', label: t('tip.share') },
        ...(isLocalNodes ? [{ value: 'delete', label: t('btn.delete'), destructive: true }] : []),
      ],
    });
    if (picked === 'share') {
      const link = await attempt(engine.shareNode(id, index));
      if (link) {
        await Clipboard.setStringAsync(link);
        notify('success', t('share.copied'));
      }
    }
    if (picked === 'delete') {
      const yes = await askConfirm({
        title: t('local.delete_title'),
        message: t('local.delete_body', [node.name]),
        confirmLabel: t('btn.delete'),
        destructive: true,
      });
      if (yes) await attempt(engine.removeLocalNode(index));
    }
  };

  const more: MenuItem[] = [
    ...(remote
      ? [
          { label: t('tip.update_now'), icon: 'refresh' as const, onPress: () => void engine.updateSubscriptions([id]) },
          {
            label: t('subs.copy_url'),
            icon: 'link' as const,
            onPress: () => {
              void Clipboard.setStringAsync(sub.url);
              notify('success', t('subs.url_copied'));
            },
          },
        ]
      : []),
    { label: t('tip.copy_links'), icon: 'share', onPress: () => void copyLinks() },
    ...(isLocalNodes
      ? []
      : [
          { label: t('tip.move_up'), icon: 'up' as const, onPress: () => void engine.moveSubscription(id, -1) },
          { label: t('tip.move_down'), icon: 'down' as const, onPress: () => void engine.moveSubscription(id, 1) },
        ]),
    { label: t('btn.delete'), icon: 'delete', destructive: true, onPress: () => void remove() },
  ];

  const usage = usageText(sub);
  const schedule = !remote
    ? null
    : !sub.auto_update
      ? t('meta.auto_off')
      : [t('meta.every', [formatInterval(sub.interval_min)]), sub.update_on_start ? t('meta.on_startup') : null]
          .filter(Boolean)
          .join(' · ');

  return (
    <Screen
      title={name}
      actions={[
        ...(isLocalNodes
          ? [{ icon: 'add' as const, label: t('btn.add_node'), onPress: () => router.push('/add-node') }]
          : [
              {
                icon: 'edit' as const,
                label: t('btn.edit'),
                onPress: () => router.push({ pathname: '/edit-subscription', params: { id } }),
              },
            ]),
        { icon: 'more', label: t('btn.more'), menu: more },
      ]}>
      <Section
        footer={
          [usage, sub.last_error ? `${t('subs.update_failed')}: ${sub.last_error}` : null].filter(Boolean).join('\n') ||
          undefined
        }>
        <SwitchRow
          title={t('tip.enabled')}
          value={sub.enabled}
          onChange={(v) => void engine.setSubscriptionsEnabled([id], v)}
        />
        {remote ? (
          <Row
            title={t('tip.update_now')}
            value={
              updating
                ? t('subs.updating')
                : sub.last_update
                  ? t('meta.updated', [formatAgo(sub.last_update)])
                  : t('subs.never_updated')
            }
            onPress={() => void engine.updateSubscriptions([id])}
          />
        ) : null}
        {schedule ? <Row title={t('subs.updates')} value={schedule} /> : null}
      </Section>
      <Section
        header={`${t('subs.nodes_title')} · ${nodes.length}`}
        footer={isLocalNodes ? t('local.subtitle') : undefined}>
        {nodes.map((node, i) => (
          <Row
            key={`${i}/${node.name}`}
            title={node.name}
            subtitle={`${node.protocol.toUpperCase()} · ${node.server}:${node.port}`}
            subtitleLines={1}
            onPress={() => void nodeMenu(node, i)}
          />
        ))}
      </Section>
    </Screen>
  );
}
