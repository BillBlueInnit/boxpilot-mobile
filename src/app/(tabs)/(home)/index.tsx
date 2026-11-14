import { useRouter } from 'expo-router';
import { Text, View } from 'react-native';

import { type Group, type Member, engine } from '@/core/engine';
import { formatBytes, formatDuration, formatSpeed, outboundLabel } from '@/core/format';
import { useT, useTick } from '@/core/hooks';
import { enabledNodes, isBusy, isRunning, setMode, settingOf, toggle, useStore } from '@/core/store';
import { Icon } from '@/ui/icons';
import { Button, Card, GUTTER, Heading, Row, Screen, Section, Segmented } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';
import { ConnectButton, CountryBadge, LatencyBadge, TrafficChart, useTrafficColors } from '@/ui/widgets';

const MODES = ['Rule', 'Global', 'Direct'];

/** The node traffic leaves through now, and the groups on the way to it. */
function currentRoute(groups: Group[]): { node: Member | null; path: string[] } {
  const path: string[] = [];
  let now = groups.find((g) => g.name === 'Proxy')?.now ?? '';
  while (path.length < 5) {
    const next = groups.find((g) => g.name === now && g.now !== '');
    if (!next) break;
    path.push(outboundLabel(next.name));
    now = next.now;
  }
  for (const g of groups) {
    const node = g.members.find((m) => m.name === now);
    if (node) return { node, path };
  }
  return { node: null, path };
}

export default function Home() {
  const t = useT();
  const router = useRouter();
  const status = useStore((s) => s.status);
  const hasSubscriptions = useStore((s) => s.subscriptions.length > 0 || s.local != null);
  const running = isRunning(status);
  return (
    <Screen
      title="BoxPilot"
      root
      actions={
        running ? [{ icon: 'refresh', label: t('tip.restart_core'), onPress: () => void engine.restart() }] : []
      }>
      <Hero />
      <VpnProblem />
      {hasSubscriptions ? (
        <>
          <ModeCard />
          <NowUsing />
          <Traffic />
        </>
      ) : (
        <GettingStarted />
      )}
      <Section header={t('home.tools')}>
        <Row
          title={t('nav.connections')}
          subtitle={isIOS ? undefined : t('home.connections_desc')}
          icon={{ name: 'connections', color: isIOS ? '#007AFF' : undefined }}
          chevron
          onPress={() => router.push('/connections')}
        />
        <Row
          title={t('nav.rules')}
          subtitle={isIOS ? undefined : t('home.rules_desc')}
          icon={{ name: 'rules', color: isIOS ? '#5856D6' : undefined }}
          chevron
          onPress={() => router.push('/rules')}
        />
        <Row
          title={t('nav.logs')}
          subtitle={isIOS ? undefined : t('home.logs_desc')}
          icon={{ name: 'logs', color: isIOS ? '#8E8E93' : undefined }}
          chevron
          onPress={() => router.push('/logs')}
        />
      </Section>
    </Screen>
  );
}

function Hero() {
  const t = useT();
  const palette = usePalette();
  const router = useRouter();
  const status = useStore((s) => s.status);
  const since = useStore((s) => s.connectedSince);
  const nodes = useStore(enabledNodes);
  const mode = useStore((s) => settingOf(s.settings, 'mode', 'Rule'));
  const running = isRunning(status);
  // Keeps the "connected for" time current.
  const now = useTick(30, running);

  const [title, color] =
    status.state === 'running'
      ? [t('status.connected'), palette.good]
      : status.state === 'starting'
        ? [t('status.connecting'), palette.fair]
        : status.state === 'stopping'
          ? [t('status.disconnecting'), palette.fair]
          : status.state === 'failed'
            ? [t('status.failed'), palette.bad]
            : [t('status.disconnected'), palette.secondary];

  let detail: string;
  if (status.state === 'failed') detail = status.error;
  else if (running)
    detail = since == null ? t('home.protected') : t('home.uptime', [formatDuration(Math.max(0, now - since) / 1000)]);
  else if (nodes > 0) detail = t('dash.ready', [nodes, t(`mode.${mode.toLowerCase()}`)]);
  else detail = t('dash.no_nodes');

  return (
    <View style={{ alignItems: 'center', paddingHorizontal: 24, paddingTop: 12, paddingBottom: 8 }}>
      <ConnectButton
        running={running}
        busy={isBusy(status)}
        // Nothing to connect to yet: go and add a subscription.
        onPress={nodes === 0 && !running ? () => router.push('/edit-subscription') : toggle}
      />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 20 }}>
        <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: color }} />
        <Text testID="status" style={{ fontSize: 22, fontWeight: '700', color: palette.text }}>
          {title}
        </Text>
      </View>
      <Text
        numberOfLines={3}
        style={{
          fontSize: 14,
          lineHeight: 19,
          textAlign: 'center',
          marginTop: 6,
          color: status.state === 'failed' ? palette.bad : palette.secondary,
        }}>
        {detail}
      </Text>
    </View>
  );
}

/**
 * iOS: this copy of the app can never get VPN permission (it was signed
 * without the capability, or its extension was removed). iOS shows no prompt
 * in that case, so the reason is stated here, before the user taps Connect.
 */
function VpnProblem() {
  const t = useT();
  const palette = usePalette();
  const problem = useStore((s) => s.host?.vpnProblem);
  if (!problem) return null;
  return (
    <Card style={{ marginHorizontal: GUTTER, marginTop: 16, padding: 20 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Icon name="error" size={20} color={palette.fair} />
        <Text style={{ flex: 1, fontSize: 17, fontWeight: '600', color: palette.text }}>{t('vpn.unavailable')}</Text>
      </View>
      <Text selectable style={{ fontSize: 14, lineHeight: 20, color: palette.secondary, marginTop: 8 }}>
        {t(`vpn.${problem}`)}
      </Text>
    </Card>
  );
}

function GettingStarted() {
  const t = useT();
  const palette = usePalette();
  const router = useRouter();
  return (
    <Card style={{ marginHorizontal: GUTTER, marginTop: 16, padding: 20 }}>
      <Text style={{ fontSize: 17, fontWeight: '600', color: palette.text }}>{t('subs.empty_title')}</Text>
      <Text style={{ fontSize: 14, lineHeight: 20, color: palette.secondary, marginTop: 6, marginBottom: 16 }}>
        {t('subs.empty_hint')}
      </Text>
      <Button testID="add-first" label={t('btn.add_subscription')} onPress={() => router.push('/edit-subscription')} />
    </Card>
  );
}

function ModeCard() {
  const t = useT();
  const palette = usePalette();
  const mode = useStore((s) => settingOf(s.settings, 'mode', 'Rule'));
  return (
    <>
      <Heading>{t('quick.mode')}</Heading>
      <View style={{ marginHorizontal: GUTTER }}>
        <Segmented
          labels={MODES.map((m) => t(`mode.${m.toLowerCase()}`))}
          index={Math.max(0, MODES.indexOf(mode))}
          onChange={(i) => setMode(MODES[i])}
        />
        <Text style={{ fontSize: 13, lineHeight: 18, color: palette.secondary, marginHorizontal: 16, marginTop: 8 }}>
          {t('quick.mode_desc')}
        </Text>
      </View>
    </>
  );
}

function NowUsing() {
  const t = useT();
  const palette = usePalette();
  const running = useStore((s) => isRunning(s.status));
  const groups = useStore((s) => s.groups);
  const { node, path } = currentRoute(groups);
  return (
    <>
      <Heading>{t('dash.now_using')}</Heading>
      <Card style={{ marginHorizontal: GUTTER }}>
        {!running || !node ? (
          <Text style={{ fontSize: 16, color: palette.secondary }}>{t('status.disconnected')}</Text>
        ) : (
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <View style={{ flex: 1 }}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                {node.country ? <CountryBadge code={node.country} /> : null}
                <Text numberOfLines={1} style={{ flexShrink: 1, fontSize: 17, fontWeight: '600', color: palette.text }}>
                  {outboundLabel(node.name)}
                </Text>
              </View>
              <Text numberOfLines={1} style={{ fontSize: 13, color: palette.secondary, marginTop: 4 }}>
                {[...path, node.protocol.toUpperCase()].join(' · ')}
              </Text>
            </View>
            <LatencyBadge
              delay={node.real_delay ?? node.delay}
              testing={node.testing}
              onPress={() => void engine.testDelays([node.name])}
            />
          </View>
        )}
      </Card>
    </>
  );
}

function Traffic() {
  const t = useT();
  const palette = usePalette();
  const colors = useTrafficColors();
  const up = useStore((s) => s.up[s.up.length - 1]);
  const down = useStore((s) => s.down[s.down.length - 1]);
  const sessionUp = useStore((s) => s.sessionUp);
  const sessionDown = useStore((s) => s.sessionDown);
  const stat = (label: string, value: number, icon: 'up' | 'down', color: string) => (
    <View style={{ flex: 1 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
        <Icon name={icon} size={14} color={color} />
        <Text style={{ fontSize: 13, color: palette.secondary }}>{label}</Text>
      </View>
      <Text style={{ fontSize: 20, fontWeight: '600', fontVariant: ['tabular-nums'], color: palette.text, marginTop: 2 }}>
        {formatSpeed(value)}
      </Text>
    </View>
  );
  return (
    <>
      <Heading>{t('chart.traffic')}</Heading>
      <Card style={{ marginHorizontal: GUTTER }}>
        <View style={{ flexDirection: 'row', marginBottom: 14 }}>
          {stat(t('stat.upload'), up, 'up', colors.up)}
          {stat(t('stat.download'), down, 'down', colors.down)}
        </View>
        <TrafficChart />
        <Text style={{ fontSize: 13, color: palette.secondary, marginTop: 10, fontVariant: ['tabular-nums'] }}>
          {`${t('stat.session')}  ↑ ${formatBytes(sessionUp)}  ↓ ${formatBytes(sessionDown)}`}
        </Text>
      </Card>
    </>
  );
}
