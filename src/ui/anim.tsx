// Physically based, restrained motion matching the desktop app's anim.rs:
// critically damped spring layout transitions, smooth chevron rotation, gentle
// card entrances and subtle tactile feedback. Honours OS Reduce Motion.

import * as Haptics from 'expo-haptics';
import { type ReactNode, useEffect, useState } from 'react';
import {
  AccessibilityInfo,
  Animated,
  Easing,
  LayoutAnimation,
  Platform,
  type StyleProp,
  UIManager,
  type ViewStyle,
} from 'react-native';

import { Icon, type IconName } from './icons';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

let reduceMotion = false;
void AccessibilityInfo.isReduceMotionEnabled().then((v) => {
  reduceMotion = v;
});
AccessibilityInfo.addEventListener('reduceMotionChanged', (v) => {
  reduceMotion = v;
});

/** Critically-damped layout transition (~220 ms) for expand/collapse & list changes. */
export function configureLayoutMotion() {
  if (reduceMotion) return;
  LayoutAnimation.configureNext({
    duration: 220,
    create: { type: LayoutAnimation.Types.easeOut, property: LayoutAnimation.Properties.opacity },
    update: { type: LayoutAnimation.Types.spring, springDamping: 0.88 },
    delete: { type: LayoutAnimation.Types.easeOut, property: LayoutAnimation.Properties.opacity },
  });
}

/** Subtle selection tick (segment switch, proxy pick, profile switch). */
export function selectionHaptic() {
  void Haptics.selectionAsync().catch(() => {});
}

/** Light impact (toggle, add rule). */
export function lightHaptic() {
  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
}

/** Smoothly rotates a chevron/expand icon between 0° and `degrees` when `open` changes. */
export function AnimatedChevron({
  open,
  icon = 'chevron',
  degrees = 90,
  size = 14,
  color,
}: {
  open: boolean;
  icon?: IconName;
  degrees?: number;
  size?: number;
  color: string;
}) {
  const [anim] = useState(() => new Animated.Value(open ? 1 : 0));
  useEffect(() => {
    if (reduceMotion) {
      anim.setValue(open ? 1 : 0);
      return;
    }
    Animated.timing(anim, {
      toValue: open ? 1 : 0,
      duration: 200,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [open, anim]);

  const rotate = anim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', `${degrees}deg`],
  });

  return (
    <Animated.View style={{ transform: [{ rotate }] }}>
      <Icon name={icon} size={size} color={color} />
    </Animated.View>
  );
}

/** Gentle damped entrance (opacity + 8 pt lift) for results and surfaced cards. */
export function FadeInView({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  const [anim] = useState(() => new Animated.Value(reduceMotion ? 1 : 0));
  useEffect(() => {
    if (reduceMotion) return;
    Animated.timing(anim, {
      toValue: 1,
      duration: 220,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [anim]);

  return (
    <Animated.View
      style={[
        style,
        {
          opacity: anim,
          transform: [
            {
              translateY: anim.interpolate({
                inputRange: [0, 1],
                outputRange: [8, 0],
              }),
            },
          ],
        },
      ]}>
      {children}
    </Animated.View>
  );
}
