import * as Clipboard from 'expo-clipboard';
import { useRouter } from 'expo-router';
import { Pressable, Text, View } from 'react-native';

import { type Subscription, engine } from '@/core/engine';
import { formatAgo, parseImportLink, usageText } from '@/core/format';
import { useT, useTick } from '@/core/hooks';
import { notify, useStore } from '@/core/store';
import { Icon } from '@/ui/icons';
import { Button, EmptyState, GUTTER, Screen, Spinner, Toggle } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

export default function Subscriptions() {
  const t = useT();
  const router = useRouter();
  const subscriptions = useStore((s) => s.subscriptions);
  const local = useStore((s) => s.local);
  const updating = useStore((s) => s.updating);
  const anyUpdating = updating.length > 0;
  useTick(30);

  const fromClipboard = async () => {
    const text = (await Clipboard.getStringAsync()).trim();
    if (text === '') {
      notify('info', t('subs.clipboard_empty'));
      return;
    }
    const link = parseImportLink(text);
    if (link) router.push({ pathname: '/edit-subscription', params: { url: link.url, name: link.name ?? '' } });
    else if (/^https?:\/\/\S+$/i.test(text)) router.push({ pathname: '/edit-subscription', params: { url: text } });
    // Anything else is treated as node links (or a pasted subscription body).
    else router.push({ pathname: '/add-node', params: { text } });
  };

  return (
    <Screen
      title={t('nav.subscriptions')}
      root
      onRefresh={subscriptions.some((s) => s.url !== '') ? () => void engine.updateAllSubscriptions() : undefined}
      refreshing={anyUpdating}
      actions={[
        {
          icon: 'add',
          label: t('btn.add'),
          menu: [
            {
              label: t('btn.add_subscription'),
              icon: 'subscriptions',
              onPress: () => router.push('/edit-subscription'),
            },
            { label: t('btn.add_node'), icon: 'node', onPress: () => router.push('/add-node') },
            { label: t('subs.from_clipboard'), icon: 'paste', onPress: () => void fromClipboard() },
          ],
        },
      ]}>
      {subscriptions.length === 0 && !local ? (
        <EmptyState
          icon="subscriptions"
          title={t('subs.empty_title')}
          message={t('subs.empty_hint')}
          action={
            <Button testID="add-subscription" label={t('btn.add_subscription')} onPress={() => router.push('/edit-subscription')} />
          }
        />
      ) : (
        <View style={{ paddingTop: isIOS ? 8 : 4 }}>
          {subscriptions.map((sub) => (
            <SubscriptionCard key={sub.id} sub={sub} updating={updating.includes(sub.id)} />
          ))}
          {local ? <SubscriptionCard sub={local} updating={false} /> : null}
        </View>
      )}
    </Screen>
  );
}

function SubscriptionCard({ sub, updating }: { sub: Subscription; updating: boolean }) {
  const t = useT();
  const palette = usePalette();
  const router = useRouter();
  const isLocalNodes = sub.id === 'local-nodes';
  const name = isLocalNodes ? t('local.title') : sub.name || t('subs.untitled');
  const meta = [
    t('meta.nodes', [sub.node_count]),
    isLocalNodes
      ? null
      : sub.url === ''
        ? t('subs.local')
        : sub.last_update
          ? t('meta.updated', [formatAgo(sub.last_update)])
          : t('subs.never_updated'),
  ]
    .filter(Boolean)
    .join(' · ');
  const usage = usageText(sub);
  return (
    <Pressable
      testID={`subscription-${name}`}
      onPress={() => router.push({ pathname: '/subscription/[id]', params: { id: sub.id } })}
      android_ripple={{ color: palette.fill }}
      style={({ pressed }) => ({
        marginHorizontal: GUTTER,
        marginTop: 12,
        padding: 16,
        borderRadius: isIOS ? 26 : 24,
        borderCurve: 'continuous',
        backgroundColor: palette.card,
        opacity: isIOS && pressed ? 0.7 : 1,
        overflow: 'hidden',
      })}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1 }}>
          <Text numberOfLines={1} style={{ fontSize: 17, fontWeight: '600', color: sub.enabled ? palette.text : palette.tertiary }}>
            {name}
          </Text>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 4 }}>
            {updating ? <Spinner size={12} /> : null}
            <Text numberOfLines={1} style={{ flexShrink: 1, fontSize: 13, color: palette.secondary }}>
              {updating ? t('subs.updating') : isLocalNodes ? `${meta} · ${t('local.subtitle')}` : meta}
            </Text>
          </View>
        </View>
        <Toggle value={sub.enabled} onChange={(v) => void engine.setSubscriptionsEnabled([sub.id], v)} />
        {isIOS ? <Icon name="chevron" size={14} color={palette.tertiary} style={{ marginLeft: 10 }} /> : null}
      </View>
      {usage ? <Text style={{ fontSize: 13, color: palette.secondary, marginTop: 8 }}>{usage}</Text> : null}
      {sub.last_error ? (
        <Text numberOfLines={3} style={{ fontSize: 13, color: palette.bad, marginTop: 8 }}>
          {`${t('subs.update_failed')}: ${sub.last_error}`}
        </Text>
      ) : null}
    </Pressable>
  );
}
