// Pieces specific to BoxPilot: the connect button, latency and country badges,
// the traffic chart and the notice host.

import * as Haptics from 'expo-haptics';
import { useEffect, useState } from 'react';
import { Animated, Pressable, Text, View } from 'react-native';
import { Snackbar } from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { flagEmoji } from '../core/format';
import { type Notice, useStore } from '../core/store';
import { tr } from '../i18n';
import { Icon } from './icons';
import { Spinner } from './kit';
import { isIOS, latencyColor, usePalette } from './theme';

/** The big round button on the dashboard. */
export function ConnectButton({ running, busy, onPress }: { running: boolean; busy: boolean; onPress: () => void }) {
  const palette = usePalette();
  const scale = useState(() => new Animated.Value(1))[0];
  const press = (to: number) =>
    Animated.spring(scale, { toValue: to, useNativeDriver: true, speed: 30, bounciness: 6 }).start();
  return (
    <Pressable
      testID="connect"
      accessibilityRole="button"
      accessibilityLabel={running ? tr('btn.disconnect') : tr('btn.connect')}
      accessibilityState={{ busy, selected: running }}
      onPressIn={() => press(0.94)}
      onPressOut={() => press(1)}
      onPress={() => {
        void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
        onPress();
      }}>
      <Animated.View
        style={{
          width: 132,
          height: 132,
          borderRadius: 66,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: running ? palette.accent : palette.card,
          transform: [{ scale }],
          shadowColor: running ? palette.accent : '#000000',
          shadowOpacity: running ? 0.35 : 0.08,
          shadowRadius: 18,
          shadowOffset: { width: 0, height: 8 },
          elevation: running ? 6 : 1,
        }}>
        {busy ? (
          <Spinner size={36} />
        ) : (
          <Icon name="power" size={52} color={running ? palette.onAccent : palette.text} />
        )}
      </Animated.View>
    </Pressable>
  );
}

/** `128 ms`, `timeout` or a spinner, coloured by quality. Tap to test. */
export function LatencyBadge({
  delay,
  testing,
  onPress,
}: {
  delay: number | null;
  testing?: boolean;
  onPress?: () => void;
}) {
  const palette = usePalette();
  let child;
  if (testing) {
    child = <Spinner size={14} />;
  } else if (delay == null) {
    child = <Icon name="bolt" size={16} color={palette.tertiary} />;
  } else {
    child = (
      <Text style={{ fontSize: 13, fontWeight: '600', fontVariant: ['tabular-nums'], color: latencyColor(palette, delay) }}>
        {delay < 0 ? tr('latency.timeout') : `${delay} ms`}
      </Text>
    );
  }
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={tr('btn.test_latency')}
      disabled={testing || !onPress}
      hitSlop={8}
      onPress={onPress}
      style={{ paddingHorizontal: 4, paddingVertical: 6, minWidth: 40, alignItems: 'flex-end' }}>
      {child}
    </Pressable>
  );
}

/** A country as flag and code (the code alone is ambiguous, the flag alone unreadable). */
export function CountryBadge({ code }: { code: string }) {
  const palette = usePalette();
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 3,
        paddingHorizontal: 5,
        height: 20,
        borderRadius: 5,
        backgroundColor: palette.fill,
      }}>
      <Text style={{ fontSize: 12 }}>{flagEmoji(code)}</Text>
      <Text style={{ fontSize: 11, fontWeight: '700', color: palette.secondary }}>{code.toUpperCase()}</Text>
    </View>
  );
}

/** Up and down speed over the last minute, as two rows of bars. */
export function TrafficChart({ height = 84 }: { height?: number }) {
  const palette = usePalette();
  const up = useStore((s) => s.up);
  const down = useStore((s) => s.down);
  const peak = Math.max(1, ...up, ...down);
  const downColor = isIOS ? (palette.dark ? '#40C8E0' : '#30B0C7') : palette.secondary;
  return (
    <View style={{ height, flexDirection: 'row', alignItems: 'flex-end', gap: 1 }}>
      {down.map((d, i) => {
        const u = up[i];
        return (
          <View key={i} style={{ flex: 1, height: '100%', justifyContent: 'flex-end' }}>
            <View
              style={{
                height: Math.max(1, (Math.max(d, u) / peak) * (height - 2)),
                borderRadius: 1.5,
                backgroundColor: d >= u ? downColor : palette.accent,
                opacity: 0.9,
                justifyContent: 'flex-end',
              }}>
              <View
                style={{
                  height: `${Math.max(d, u) === 0 ? 0 : (Math.min(d, u) / Math.max(d, u)) * 100}%`,
                  borderRadius: 1.5,
                  backgroundColor: d >= u ? palette.accent : downColor,
                }}
              />
            </View>
          </View>
        );
      })}
    </View>
  );
}

/** The colours [TrafficChart] uses, for its legend. */
export function useTrafficColors() {
  const palette = usePalette();
  return { up: palette.accent, down: isIOS ? (palette.dark ? '#40C8E0' : '#30B0C7') : palette.secondary };
}

/** Short messages from the engine: a snackbar on Android, a banner on iOS. */
export function NoticeHost() {
  const notice = useStore((s) => s.notice);
  return isIOS ? <Banner notice={notice} /> : <AndroidNotice notice={notice} />;
}

function AndroidNotice({ notice }: { notice: Notice | null }) {
  // The newest notice shows until it is dismissed (by its timer or the user).
  const [dismissed, setDismissed] = useState(0);
  const shown = notice && notice.id !== dismissed ? notice : null;
  const dismiss = () => setDismissed(notice?.id ?? 0);
  return (
    <Snackbar
      visible={shown != null}
      duration={shown?.kind === 'error' ? 5000 : 2800}
      onDismiss={dismiss}
      icon="close"
      onIconPress={shown?.kind === 'error' ? dismiss : undefined}
      wrapperStyle={{ bottom: 88 }}>
      {shown?.text ?? ''}
    </Snackbar>
  );
}

function Banner({ notice }: { notice: Notice | null }) {
  const palette = usePalette();
  const insets = useSafeAreaInsets();
  const [hidden, setHidden] = useState(0);
  const shown = notice && notice.id !== hidden ? notice : null;
  const progress = useState(() => new Animated.Value(0))[0];

  useEffect(() => {
    if (!notice) return;
    progress.setValue(0);
    Animated.spring(progress, { toValue: 1, useNativeDriver: true, speed: 16, bounciness: 7 }).start();
    const timer = setTimeout(
      () => {
        Animated.timing(progress, { toValue: 0, duration: 220, useNativeDriver: true }).start(({ finished }) => {
          if (finished) setHidden(notice.id);
        });
      },
      notice.kind === 'error' ? 4200 : 2600,
    );
    return () => clearTimeout(timer);
  }, [notice, progress]);

  if (!shown) return null;
  const error = shown.kind === 'error' || shown.kind === 'warning';
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        top: insets.top + 6,
        left: 24,
        right: 24,
        alignItems: 'center',
        opacity: progress,
        transform: [{ translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [-24, 0] }) }],
      }}>
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 8,
          paddingHorizontal: 18,
          paddingVertical: 12,
          borderRadius: 28,
          borderCurve: 'continuous',
          backgroundColor: palette.dark ? '#2C2C2E' : '#FFFFFF',
          shadowColor: '#000000',
          shadowOpacity: 0.18,
          shadowRadius: 16,
          shadowOffset: { width: 0, height: 6 },
        }}>
        <Icon name={error ? 'error' : 'success'} size={20} color={error ? palette.bad : palette.good} />
        <Text style={{ flexShrink: 1, fontSize: 15, fontWeight: '500', color: palette.text }}>{shown.text}</Text>
      </View>
    </Animated.View>
  );
}
