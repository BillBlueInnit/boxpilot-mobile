import { Stack } from 'expo-router';
import { Platform } from 'react-native';

import { isIOS, usePalette } from './theme';

/** The navigation stack inside each tab: the native bar on iOS, Paper's on Android. */
export function TabStack() {
  const palette = usePalette();
  return <Stack screenOptions={stackOptions(palette.background)} />;
}

/**
 * iOS draws the native navigation bar (glass on iOS 26, with the system's
 * scroll edge effect). On Android each [Screen] draws a Material 3 top app bar.
 */
export function stackOptions(background: string) {
  return {
    headerShown: isIOS,
    headerBackButtonDisplayMode: 'minimal',
    headerShadowVisible: false,
    headerTransparent: isIOS,
    // Before iOS 26 a transparent bar needs its own material; iOS 26 draws glass.
    headerBlurEffect: isIOS && parseInt(String(Platform.Version), 10) < 26 ? 'systemChromeMaterial' : undefined,
    contentStyle: { backgroundColor: background },
  } as const;
}
