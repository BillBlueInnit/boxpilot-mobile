// Colours for both platforms.
//
// iOS: the system's own colours (grouped backgrounds, labels, separators) and
// the system or chosen tint. Android: a Material 3 scheme, taken from the
// wallpaper (Material You) or grown from the chosen colour.

import {
  type Scheme,
  argbFromHex,
  hexFromArgb,
  themeFromSourceColor,
} from '@material/material-color-utilities';
import { createContext, useContext } from 'react';
import { Platform } from 'react-native';
import { MD3DarkTheme, MD3LightTheme, type MD3Theme } from 'react-native-paper';

export const isIOS = Platform.OS === 'ios';

/** Theme colours: [dark, light], the desktop's accent pairs. */
export const ACCENTS: Record<string, [string, string]> = {
  blue: ['#60CDFF', '#005FB8'],
  teal: ['#4FD8CF', '#00777B'],
  green: ['#6CCB5F', '#0F7B0F'],
  violet: ['#B9A3FF', '#6B48C8'],
  pink: ['#FF8FC8', '#BF1F6A'],
  orange: ['#FFB066', '#B94A00'],
};
export const ACCENT_NAMES = ['blue', 'teal', 'green', 'violet', 'pink', 'orange', 'graphite'];

/** BoxPilot's brand blue, for "System" when the device has no dynamic colours. */
const BRAND = '#3B82F6';

export type Palette = {
  dark: boolean;
  /** Page background. */
  background: string;
  /** Cards and grouped rows. */
  card: string;
  text: string;
  /** Descriptions, values, section headers. */
  secondary: string;
  /** Placeholders and disabled text. */
  tertiary: string;
  separator: string;
  /** Tint: buttons, selections, links. */
  accent: string;
  onAccent: string;
  /** A quiet fill: search fields, chips, pressed rows. */
  fill: string;
  good: string;
  fair: string;
  bad: string;
  /** Section header colour (the accent on Android, grey on iOS). */
  header: string;
};

export type AppTheme = {
  palette: Palette;
  /** The Material 3 theme for Paper components (Android). */
  paper: MD3Theme;
};

function withAlpha(hex: string, alpha: number): string {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}

/** `top` laid over `base` at `alpha`. */
function blend(base: string, top: string, alpha: number): string {
  const b = parseInt(base.slice(1), 16);
  const t = parseInt(top.slice(1), 16);
  const mix = (shift: number) =>
    Math.round(((b >> shift) & 255) * (1 - alpha) + ((t >> shift) & 255) * alpha)
      .toString(16)
      .padStart(2, '0');
  return `#${mix(16)}${mix(8)}${mix(0)}`;
}

// ---------------------------------------------------------------------- iOS

function iosPalette(dark: boolean, accent: string): Palette {
  const tint =
    accent === 'graphite'
      ? dark
        ? '#FFFFFF'
        : '#000000'
      : ACCENTS[accent]
        ? ACCENTS[accent][dark ? 0 : 1]
        : dark
          ? '#0A84FF'
          : '#007AFF';
  return {
    dark,
    background: dark ? '#000000' : '#F2F2F7',
    card: dark ? '#1C1C1E' : '#FFFFFF',
    text: dark ? '#FFFFFF' : '#000000',
    secondary: dark ? 'rgba(235, 235, 245, 0.6)' : 'rgba(60, 60, 67, 0.6)',
    tertiary: dark ? 'rgba(235, 235, 245, 0.3)' : 'rgba(60, 60, 67, 0.3)',
    separator: dark ? 'rgba(84, 84, 88, 0.6)' : 'rgba(60, 60, 67, 0.29)',
    accent: tint,
    onAccent: accent === 'graphite' ? (dark ? '#000000' : '#FFFFFF') : '#FFFFFF',
    fill: dark ? 'rgba(118, 118, 128, 0.24)' : 'rgba(118, 118, 128, 0.12)',
    good: dark ? '#30D158' : '#34C759',
    fair: dark ? '#FF9F0A' : '#FF9500',
    bad: dark ? '#FF453A' : '#FF3B30',
    header: dark ? 'rgba(235, 235, 245, 0.6)' : 'rgba(60, 60, 67, 0.6)',
  };
}

// ------------------------------------------------------------------ Android

type Roles = Omit<MD3Theme['colors'], 'elevation' | 'surfaceDisabled' | 'onSurfaceDisabled' | 'backdrop'>;

function rolesFromScheme(s: Scheme): Roles {
  const hex = (v: number) => hexFromArgb(v);
  return {
    primary: hex(s.primary),
    onPrimary: hex(s.onPrimary),
    primaryContainer: hex(s.primaryContainer),
    onPrimaryContainer: hex(s.onPrimaryContainer),
    secondary: hex(s.secondary),
    onSecondary: hex(s.onSecondary),
    secondaryContainer: hex(s.secondaryContainer),
    onSecondaryContainer: hex(s.onSecondaryContainer),
    tertiary: hex(s.tertiary),
    onTertiary: hex(s.onTertiary),
    tertiaryContainer: hex(s.tertiaryContainer),
    onTertiaryContainer: hex(s.onTertiaryContainer),
    error: hex(s.error),
    onError: hex(s.onError),
    errorContainer: hex(s.errorContainer),
    onErrorContainer: hex(s.onErrorContainer),
    background: hex(s.background),
    onBackground: hex(s.onBackground),
    surface: hex(s.surface),
    onSurface: hex(s.onSurface),
    surfaceVariant: hex(s.surfaceVariant),
    onSurfaceVariant: hex(s.onSurfaceVariant),
    outline: hex(s.outline),
    outlineVariant: hex(s.outlineVariant),
    shadow: hex(s.shadow),
    scrim: hex(s.scrim),
    inverseSurface: hex(s.inverseSurface),
    inverseOnSurface: hex(s.inverseOnSurface),
    inversePrimary: hex(s.inversePrimary),
  };
}

/** Material You: the roles from the system's tonal palettes, as Android maps them. */
function rolesFromWallpaper(p: Record<string, string>, dark: boolean): Roles | null {
  const t = (family: string, light: number, darkTone: number) => p[`${family}_${dark ? darkTone : light}`];
  const base = dark ? MD3DarkTheme.colors : MD3LightTheme.colors;
  const roles: Roles = {
    primary: t('accent1', 600, 200),
    onPrimary: t('accent1', 0, 800),
    primaryContainer: t('accent1', 100, 700),
    onPrimaryContainer: t('accent1', 900, 100),
    secondary: t('accent2', 600, 200),
    onSecondary: t('accent2', 0, 800),
    secondaryContainer: t('accent2', 100, 700),
    onSecondaryContainer: t('accent2', 900, 100),
    tertiary: t('accent3', 600, 200),
    onTertiary: t('accent3', 0, 800),
    tertiaryContainer: t('accent3', 100, 700),
    onTertiaryContainer: t('accent3', 900, 100),
    error: base.error,
    onError: base.onError,
    errorContainer: base.errorContainer,
    onErrorContainer: base.onErrorContainer,
    background: t('neutral1', 10, 900),
    onBackground: t('neutral1', 900, 100),
    surface: t('neutral1', 10, 900),
    onSurface: t('neutral1', 900, 100),
    surfaceVariant: t('neutral2', 100, 700),
    onSurfaceVariant: t('neutral2', 700, 200),
    outline: t('neutral2', 500, 400),
    outlineVariant: t('neutral2', 200, 700),
    shadow: '#000000',
    scrim: '#000000',
    inverseSurface: t('neutral1', 800, 100),
    inverseOnSurface: t('neutral1', 50, 800),
    inversePrimary: t('accent1', 200, 600),
  };
  return Object.values(roles).every((v) => typeof v === 'string') ? roles : null;
}

function paperTheme(roles: Roles, dark: boolean): MD3Theme {
  const base = dark ? MD3DarkTheme : MD3LightTheme;
  const level = (alpha: number) => blend(roles.surface, roles.primary, alpha);
  return {
    ...base,
    colors: {
      ...roles,
      surfaceDisabled: withAlpha(roles.onSurface, 0.12),
      onSurfaceDisabled: withAlpha(roles.onSurface, 0.38),
      backdrop: withAlpha(roles.onSurfaceVariant, 0.4),
      elevation: {
        level0: 'transparent',
        level1: level(0.05),
        level2: level(0.08),
        level3: level(0.11),
        level4: level(0.12),
        level5: level(0.14),
      },
    },
  };
}

function androidTheme(dark: boolean, accent: string, wallpaper: Record<string, string> | null): AppTheme {
  let roles: Roles | null = null;
  if (accent === 'system' && wallpaper) roles = rolesFromWallpaper(wallpaper, dark);
  if (!roles) {
    // Graphite: a neutral grey seed gives a near-monochrome scheme.
    const seed = accent === 'graphite' ? '#6B6B6B' : (ACCENTS[accent]?.[1] ?? BRAND);
    const theme = themeFromSourceColor(argbFromHex(seed));
    roles = rolesFromScheme(dark ? theme.schemes.dark : theme.schemes.light);
  }
  const paper = paperTheme(roles, dark);
  return {
    paper,
    palette: {
      dark,
      background: roles.surface,
      card: paper.colors.elevation.level1,
      text: roles.onSurface,
      secondary: roles.onSurfaceVariant,
      tertiary: withAlpha(roles.onSurface, 0.38),
      separator: withAlpha(roles.outlineVariant, 0.6),
      accent: roles.primary,
      onAccent: roles.onPrimary,
      fill: paper.colors.elevation.level3,
      good: dark ? '#81C784' : '#2E7D32',
      fair: dark ? '#FFB74D' : '#EF6C00',
      bad: roles.error,
      header: roles.primary,
    },
  };
}

/** The theme for a colour scheme, the `accent` setting and (Android) the wallpaper palette. */
export function buildTheme(dark: boolean, accent: string, wallpaper: Record<string, string> | null): AppTheme {
  if (!isIOS) return androidTheme(dark, accent, wallpaper);
  const palette = iosPalette(dark, accent);
  // Paper is not drawn on iOS; its provider still wants a theme.
  return { palette, paper: dark ? MD3DarkTheme : MD3LightTheme };
}

const ThemeContext = createContext<AppTheme>(buildTheme(false, 'system', null));
export const ThemeProvider = ThemeContext.Provider;

export const useAppTheme = () => useContext(ThemeContext);
export const usePalette = () => useContext(ThemeContext).palette;

/** For a latency in ms (`-1` failed). */
export function latencyColor(p: Palette, ms: number): string {
  if (ms < 0) return p.bad;
  if (ms < 300) return p.good;
  if (ms < 800) return p.fair;
  return p.bad;
}
