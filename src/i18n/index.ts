import { desktopStrings } from './strings.desktop';
import { mobileStrings } from './strings.mobile';

/** The four UI languages, in the column order of the string tables. */
export const LANGUAGES = [
  { code: 'en', name: 'English' },
  { code: 'zh-CN', name: '简体中文' },
  { code: 'zh-TW', name: '繁體中文' },
  { code: 'ru', name: 'Русский' },
] as const;

export type LanguageCode = (typeof LANGUAGES)[number]['code'];

let current = 0;

/** Maps a locale such as `zh-Hant-HK` or `ru-RU` to a supported language. */
export function languageForLocale(locale: string): LanguageCode {
  const parts = locale.replace(/_/g, '-').split('-');
  const lang = parts[0]?.toLowerCase();
  if (lang === 'zh') {
    const rest = parts.slice(1).map((p) => p.toLowerCase());
    const hant = rest.includes('hant') || rest.some((p) => p === 'tw' || p === 'hk' || p === 'mo');
    return hant ? 'zh-TW' : 'zh-CN';
  }
  return lang === 'ru' ? 'ru' : 'en';
}

function deviceLocale(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().locale;
  } catch {
    return 'en';
  }
}

/** The language for the `language` setting; `System` (or anything unknown) follows the device. */
export function resolveLanguage(setting: unknown): LanguageCode {
  const found = LANGUAGES.find((l) => l.code === setting);
  return found ? found.code : languageForLocale(deviceLocale());
}

export function setLanguage(code: LanguageCode) {
  current = Math.max(
    0,
    LANGUAGES.findIndex((l) => l.code === code),
  );
}

export function currentLanguage(): LanguageCode {
  return LANGUAGES[current].code;
}

/**
 * The string for `key` in the current language, with `{0}`, `{1}`… replaced.
 * Missing translations fall back to English, then to the key.
 */
export function tr(key: string, args: unknown[] = []): string {
  const row = mobileStrings[key] ?? desktopStrings[key];
  let s = row ? row[current] || row[0] : key;
  for (let i = 0; i < args.length; i++) {
    s = s.split(`{${i}}`).join(String(args[i] ?? ''));
  }
  return s;
}
