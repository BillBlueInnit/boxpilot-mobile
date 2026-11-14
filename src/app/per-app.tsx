import { useEffect, useRef, useState } from 'react';
import { FlatList, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { Checkbox } from 'react-native-paper';

import Native, { type PerAppMode } from '../../modules/boxpilot-core';
import { useT } from '@/core/hooks';
import { reloadCore } from '@/core/store';
import { EmptyState, GUTTER, Screen, Segmented } from '@/ui/kit';
import { usePalette } from '@/ui/theme';

type InstalledApp = { package: string; label: string };

const MODES: PerAppMode[] = ['all', 'include', 'exclude'];

/** App icons load lazily and stay cached for the session. */
const icons = new Map<string, Promise<string | null>>();

function AppIcon({ pkg }: { pkg: string }) {
  const [uri, setUri] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    let pending = icons.get(pkg);
    if (!pending) {
      pending = Native.appIcon(pkg).catch(() => null);
      icons.set(pkg, pending);
    }
    void pending.then((v) => alive && setUri(v));
    return () => {
      alive = false;
    };
  }, [pkg]);
  return uri ? <Image source={{ uri }} style={{ width: 40, height: 40 }} /> : <View style={{ width: 40, height: 40 }} />;
}

/** Per-app proxy (Android): which apps the VPN carries. */
export default function PerApp() {
  const t = useT();
  const palette = usePalette();
  const [saved] = useState(() => Native.perApp());
  const [mode, setMode] = useState<PerAppMode>(saved.mode);
  const [selected, setSelected] = useState<string[]>(saved.packages);
  const [apps, setApps] = useState<InstalledApp[] | null>(null);
  const [filter, setFilter] = useState('');
  const apply = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    void Native.apps().then(setApps, () => setApps([]));
    return () => {
      // Apply a pending change right away when leaving the page.
      if (apply.current) {
        clearTimeout(apply.current);
        reloadCore();
      }
    };
  }, []);

  /** Saves at once; the running core reloads after a pause, so ticking several apps costs one reload. */
  const changed = (nextMode: PerAppMode, nextSelected: string[]) => {
    setMode(nextMode);
    setSelected(nextSelected);
    Native.setPerApp(nextMode, nextSelected);
    if (apply.current) clearTimeout(apply.current);
    apply.current = setTimeout(() => {
      apply.current = null;
      reloadCore();
    }, 2000);
  };

  const f = filter.toLowerCase();
  const shown = (apps ?? [])
    .filter((a) => f === '' || a.label.toLowerCase().includes(f) || a.package.includes(f))
    // Selected apps first, so the choice is easy to review.
    .sort((a, b) => Number(selected.includes(b.package)) - Number(selected.includes(a.package)));

  return (
    <Screen
      title={t('perapp.title')}
      scroll={false}
      search={mode === 'all' ? undefined : { placeholder: t('perapp.search'), onChange: setFilter }}>
      <FlatList
        data={mode === 'all' ? [] : shown}
        keyExtractor={(a) => a.package}
        contentInsetAdjustmentBehavior="automatic"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ paddingBottom: 32 }}
        ListHeaderComponent={
          <View style={{ marginHorizontal: GUTTER, marginTop: 8 }}>
            <Segmented
              labels={[t('perapp.mode_all'), t('perapp.mode_include'), t('perapp.mode_exclude')]}
              index={MODES.indexOf(mode)}
              onChange={(i) => changed(MODES[i], selected)}
            />
            <Text style={{ fontSize: 13, lineHeight: 18, color: palette.secondary, margin: 12 }}>
              {`${t(`perapp.desc_${mode}`)} ${t('perapp.applies')}`}
            </Text>
            {mode === 'all' ? null : (
              <Text style={{ fontSize: 13, color: palette.secondary, marginLeft: 12, marginBottom: 8 }}>
                {t('perapp.selected', [selected.length])}
              </Text>
            )}
          </View>
        }
        ListEmptyComponent={
          mode !== 'all' && apps == null ? <EmptyState icon="apps" title={t('perapp.loading')} /> : undefined
        }
        renderItem={({ item, index }) => {
          const checked = selected.includes(item.package);
          const toggle = () =>
            changed(mode, checked ? selected.filter((p) => p !== item.package) : [...selected, item.package]);
          return (
            <View
              style={{
                marginHorizontal: GUTTER,
                backgroundColor: palette.card,
                borderTopLeftRadius: index === 0 ? 24 : 0,
                borderTopRightRadius: index === 0 ? 24 : 0,
                borderBottomLeftRadius: index === shown.length - 1 ? 24 : 0,
                borderBottomRightRadius: index === shown.length - 1 ? 24 : 0,
                overflow: 'hidden',
              }}>
              {index > 0 ? (
                <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: palette.separator, marginLeft: 72 }} />
              ) : null}
              <Pressable
                onPress={toggle}
                android_ripple={{ color: palette.fill }}
                style={{ flexDirection: 'row', alignItems: 'center', paddingLeft: 16, paddingRight: 8, paddingVertical: 8 }}>
                <AppIcon pkg={item.package} />
                <View style={{ flex: 1, marginLeft: 16 }}>
                  <Text numberOfLines={1} style={{ fontSize: 16, color: palette.text }}>
                    {item.label}
                  </Text>
                  <Text numberOfLines={1} style={{ fontSize: 13, color: palette.secondary, marginTop: 2 }}>
                    {item.package}
                  </Text>
                </View>
                <Checkbox status={checked ? 'checked' : 'unchecked'} onPress={toggle} />
              </Pressable>
            </View>
          );
        }}
      />
    </Screen>
  );
}
