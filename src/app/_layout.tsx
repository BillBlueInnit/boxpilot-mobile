import { DarkTheme, DefaultTheme, Stack, ThemeProvider as NavigationTheme } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { SymbolView } from 'expo-symbols';
import { useEffect, useMemo } from 'react';
import { Appearance, Text, View, useColorScheme } from 'react-native';
import { PaperProvider } from 'react-native-paper';

import Native from '../../modules/boxpilot-core';
import { startApp, useSetting, useStore } from '@/core/store';
import { DialogHost } from '@/ui/dialogs';
import { androidSymbol } from '@/ui/icons';
import { stackOptions } from '@/ui/tab-stack';
import { ThemeProvider, buildTheme, isIOS } from '@/ui/theme';
import { NoticeHost } from '@/ui/widgets';

void SplashScreen.preventAutoHideAsync();

/** A page opened by a link (an import link's editor) sits on top of the tabs. */
export const unstable_settings = { anchor: '(tabs)' };

/** Forms slide up as sheets; everything else is pushed. */
const FORMS = ['edit-subscription', 'add-node', 'edit-rule', 'import-acl', 'custom-rules', 'rule-text', 'reset'];

export default function Root() {
  const scheme = useColorScheme();
  const ready = useStore((s) => s.ready);
  const fatal = useStore((s) => s.fatal);
  const language = useStore((s) => s.language);
  const themeSetting = useSetting('theme', 'system');
  const accent = useSetting('accent', 'system');

  useEffect(() => {
    void startApp();
  }, []);

  // The whole app, native bars and controls included, follows the app's theme.
  useEffect(() => {
    Appearance.setColorScheme(themeSetting === 'light' || themeSetting === 'dark' ? themeSetting : 'unspecified');
  }, [themeSetting]);

  useEffect(() => {
    if (ready) void SplashScreen.hideAsync();
  }, [ready]);

  const wallpaper = useMemo(() => (isIOS ? null : Native.palette()), []);
  const dark = scheme === 'dark';
  // A new object when the language changes, so every themed component redraws its text.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const theme = useMemo(() => buildTheme(dark, accent, wallpaper), [dark, accent, wallpaper, language]);
  const { palette } = theme;

  const navigation = useMemo(() => {
    const base = dark ? DarkTheme : DefaultTheme;
    return {
      ...base,
      colors: {
        ...base.colors,
        primary: palette.accent,
        background: palette.background,
        card: palette.background,
        text: palette.text,
        border: palette.separator,
        notification: palette.bad,
      },
    };
  }, [dark, palette]);

  return (
    <PaperProvider
      theme={theme.paper}
      settings={{
        icon: ({ name, color, size }) => (
          <SymbolView name={{ android: androidSymbol(String(name)) }} size={size} tintColor={color} />
        ),
      }}>
      <ThemeProvider value={theme}>
        <NavigationTheme value={navigation}>
          <StatusBar style={dark ? 'light' : 'dark'} />
          {fatal ? (
            <View style={{ flex: 1, backgroundColor: palette.background, justifyContent: 'center', padding: 32 }}>
              <Text style={{ fontSize: 20, fontWeight: '600', color: palette.text }}>BoxPilot</Text>
              <Text selectable style={{ fontSize: 15, color: palette.secondary, marginTop: 8 }}>
                {fatal}
              </Text>
            </View>
          ) : ready ? (
            <Stack screenOptions={stackOptions(palette.background)}>
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
              {FORMS.map((name) => (
                <Stack.Screen key={name} name={name} options={{ presentation: 'modal', headerTransparent: false }} />
              ))}
            </Stack>
          ) : (
            <View style={{ flex: 1, backgroundColor: palette.background }} />
          )}
          <NoticeHost />
          <DialogHost />
        </NavigationTheme>
      </ThemeProvider>
    </PaperProvider>
  );
}
