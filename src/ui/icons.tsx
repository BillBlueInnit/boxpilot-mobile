// One icon set for both platforms: SF Symbols on iOS, Material Symbols on
// Android, by a shared name.

import { type AndroidSymbol, SymbolView } from 'expo-symbols';
import type { ColorValue, StyleProp, ViewStyle } from 'react-native';
import type { SFSymbol } from 'sf-symbols-typescript';

const icon = (ios: SFSymbol, android: AndroidSymbol) => ({ ios, android });

export const ICONS = {
  home: icon('house', 'home'),
  homeFilled: icon('house.fill', 'home'),
  proxies: icon('globe', 'public'),
  subscriptions: icon('square.stack.3d.up', 'layers'),
  subscriptionsFilled: icon('square.stack.3d.up.fill', 'layers'),
  settings: icon('gearshape', 'settings'),
  settingsFilled: icon('gearshape.fill', 'settings'),
  power: icon('power', 'power_settings_new'),
  refresh: icon('arrow.clockwise', 'refresh'),
  add: icon('plus', 'add'),
  more: icon('ellipsis.circle', 'more_vert'),
  edit: icon('pencil', 'edit'),
  delete: icon('trash', 'delete'),
  copy: icon('doc.on.doc', 'content_copy'),
  share: icon('square.and.arrow.up', 'share'),
  paste: icon('doc.on.clipboard', 'content_paste'),
  link: icon('link', 'link'),
  close: icon('xmark', 'close'),
  back: icon('chevron.left', 'arrow_back'),
  check: icon('checkmark', 'check'),
  chevron: icon('chevron.right', 'chevron_right'),
  expand: icon('chevron.down', 'keyboard_arrow_down'),
  search: icon('magnifyingglass', 'search'),
  speed: icon('speedometer', 'speed'),
  bolt: icon('bolt', 'bolt'),
  realLatency: icon('antenna.radiowaves.left.and.right', 'network_check'),
  download: icon('arrow.down.circle', 'download'),
  sort: icon('arrow.up.arrow.down', 'sort'),
  tune: icon('slider.horizontal.3', 'tune'),
  region: icon('globe.asia.australia', 'language'),
  connections: icon('arrow.up.arrow.down', 'swap_vert'),
  rules: icon('arrow.triangle.branch', 'alt_route'),
  logs: icon('doc.text', 'article'),
  up: icon('arrow.up', 'arrow_upward'),
  down: icon('arrow.down', 'arrow_downward'),
  language: icon('globe', 'translate'),
  theme: icon('moon', 'dark_mode'),
  palette: icon('paintbrush', 'palette'),
  autoconnect: icon('play.circle', 'play_circle'),
  apps: icon('square.grid.2x2', 'apps'),
  folder: icon('folder', 'folder_open'),
  offline: icon('globe', 'public_off'),
  hourglass: icon('hourglass', 'hourglass_empty'),
  error: icon('exclamationmark.circle.fill', 'error'),
  success: icon('checkmark.circle.fill', 'check_circle'),
  info: icon('info.circle', 'info'),
  block: icon('nosign', 'block'),
  direct: icon('arrow.right', 'arrow_forward'),
  node: icon('server.rack', 'dns'),
  group: icon('rectangle.stack', 'stacks'),
  clear: icon('trash', 'delete_sweep'),
  record: icon('record.circle', 'radio_button_checked'),
  stop: icon('stop.circle', 'stop_circle'),
  enable: icon('checkmark.circle', 'check_circle'),
  disable: icon('circle', 'radio_button_unchecked'),
  checked: icon('checkmark.square.fill', 'check_box'),
  unchecked: icon('square', 'check_box_outline_blank'),
} as const;

export type IconName = keyof typeof ICONS;

/** Icon names Paper's own components ask for (Material Design Icons names). */
const PAPER: Record<string, AndroidSymbol> = {
  'arrow-left': 'arrow_back',
  magnify: 'search',
  close: 'close',
  check: 'check',
  'chevron-down': 'keyboard_arrow_down',
  'chevron-up': 'keyboard_arrow_up',
  'chevron-right': 'chevron_right',
  'menu-down': 'arrow_drop_down',
  'checkbox-marked': 'check_box',
  'checkbox-blank-outline': 'check_box_outline_blank',
  'minus-box': 'indeterminate_check_box',
  'dots-vertical': 'more_vert',
};

/** The Material symbol for a name from [ICONS] or from Paper. */
export function androidSymbol(name: string): AndroidSymbol {
  return (ICONS as Record<string, { android: AndroidSymbol }>)[name]?.android ?? PAPER[name] ?? 'circle';
}

export function Icon({
  name,
  size = 22,
  color,
  style,
}: {
  name: IconName;
  size?: number;
  color: ColorValue;
  style?: StyleProp<ViewStyle>;
}) {
  return <SymbolView name={ICONS[name]} size={size} tintColor={color} style={style} />;
}
