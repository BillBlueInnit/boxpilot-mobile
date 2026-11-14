import { NativeTabs } from 'expo-router/native-tabs';

import { useT } from '@/core/hooks';
import { ICONS, type IconName } from '@/ui/icons';
import { isIOS, usePalette } from '@/ui/theme';

const TABS: { name: string; label: string; icon: IconName; selected: IconName }[] = [
  { name: '(home)', label: 'nav.home', icon: 'home', selected: 'homeFilled' },
  { name: 'proxies', label: 'nav.proxies', icon: 'proxies', selected: 'proxies' },
  { name: 'subscriptions', label: 'nav.subscriptions', icon: 'subscriptions', selected: 'subscriptionsFilled' },
  { name: 'settings', label: 'nav.settings', icon: 'settings', selected: 'settingsFilled' },
];

/** The tab bar: UITabBar (Liquid Glass on iOS 26), Material 3 navigation bar on Android. */
export default function Tabs() {
  const t = useT();
  const palette = usePalette();
  return (
    <NativeTabs
      // The iOS 26 bar would otherwise shrink to a pill when a page scrolls down.
      minimizeBehavior="never"
      tintColor={palette.accent}
      backgroundColor={isIOS ? undefined : palette.card}
      indicatorColor={isIOS ? undefined : palette.fill}
      rippleColor={isIOS ? undefined : palette.fill}
      labelVisibilityMode="labeled"
      iconColor={isIOS ? undefined : { default: palette.secondary, selected: palette.text }}
      labelStyle={isIOS ? undefined : { default: { color: palette.secondary }, selected: { color: palette.text } }}>
      {TABS.map((tab) => (
        <NativeTabs.Trigger key={tab.name} name={tab.name} contentStyle={{ backgroundColor: palette.background }}>
          <NativeTabs.Trigger.Label>{t(tab.label)}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon
            sf={{ default: ICONS[tab.icon].ios, selected: ICONS[tab.selected].ios }}
            md={ICONS[tab.icon].android}
          />
        </NativeTabs.Trigger>
      ))}
    </NativeTabs>
  );
}
