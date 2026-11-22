import { tr } from '../i18n';
import type { Subscription } from './engine';

/** `1.2 MB`, `830 KB`: binary units like the desktop app. */
export function formatBytes(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let v = bytes;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  const digits = i === 0 || v >= 100 ? 0 : v >= 10 ? 1 : 2;
  return `${v.toFixed(digits)} ${units[i]}`;
}

export const formatSpeed = (bytesPerSec: number) => `${formatBytes(bytesPerSec)}/s`;

/** A duration in the desktop's short form: `45s`, `12m`, `3h 5m`, `2d`. */
export function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  if (s < 60) return tr('time.s', [s]);
  if (s < 3600) return tr('time.m', [Math.floor(s / 60)]);
  if (s < 86400) {
    const m = Math.floor((s % 3600) / 60);
    return m === 0 ? tr('time.h', [Math.floor(s / 3600)]) : tr('time.hm', [Math.floor(s / 3600), m]);
  }
  return tr('time.d', [Math.floor(s / 86400)]);
}

/** `just now`, `5m ago` for a unix time in seconds. */
export function formatAgo(unixSeconds: number, now = Date.now()): string {
  const d = now / 1000 - unixSeconds;
  if (d < 45) return tr('time.just_now');
  return tr('time.ago', [formatDuration(d)]);
}

/** Update interval in minutes as the desktop shows it. */
export const formatInterval = (minutes: number) =>
  minutes <= 0 ? tr('time.manual') : formatDuration(minutes * 60);

/** The regional-indicator flag for an ISO country code (`JP` → 🇯🇵). */
export function flagEmoji(code: string): string {
  if (code.length !== 2) return '';
  const upper = code.toUpperCase();
  return String.fromCodePoint(...[0, 1].map((i) => 0x1f1e6 + upper.charCodeAt(i) - 0x41));
}

/** Clock time for a log line (seconds since local midnight). */
export function formatClock(secondsOfDay: number): string {
  const two = (v: number) => String(Math.floor(v)).padStart(2, '0');
  return `${two(secondsOfDay / 3600)}:${two((secondsOfDay % 3600) / 60)}:${two(secondsOfDay % 60)}`;
}

/** A date as `2026-11-05`, for a unix time in seconds. */
export function formatDate(unixSeconds: number): string {
  const d = new Date(unixSeconds * 1000);
  const two = (v: number) => String(v).padStart(2, '0');
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}`;
}

/** The engine's group and outbound tags, translated where they are the app's own. */
export function outboundLabel(name: string): string {
  switch (name) {
    case 'Proxy':
      return tr('group.proxy');
    case 'Auto':
      return tr('group.auto');
    case 'direct':
    case 'DIRECT':
      return tr('group.direct');
    case 'Local nodes':
      return tr('local.title');
    case 'AI Services':
      return tr('svc.ai');
    case 'Bilibili':
      return tr('svc.bilibili');
    case 'Apple CN':
      return tr('svc.apple');
    case 'Microsoft CN':
      return tr('svc.microsoft');
    case 'Overseas Sites':
      return tr('svc.overseas');
    default:
      return name;
  }
}

/** A subscription offered by a provider's one-tap import button. */
export type ImportLink = { url: string; name?: string };

const IMPORT_SCHEMES = ['clash', 'clashmeta', 'sing-box', 'boxpilot'];

/**
 * Reads the import links proxy apps share:
 * `clash://install-config?url=…&name=…`, `clashmeta://…` (same form),
 * `sing-box://import-remote-profile?url=…#name` and `boxpilot://install-config?url=…`.
 * Returns null for anything else, or when the subscription isn't http(s).
 */
export function parseImportLink(raw: string): ImportLink | null {
  const text = raw.trim();
  const scheme = /^([a-z][a-z0-9+.-]*):/i.exec(text)?.[1]?.toLowerCase();
  if (!scheme || !IMPORT_SCHEMES.includes(scheme)) return null;
  const hash = text.indexOf('#');
  const fragment = hash >= 0 ? text.slice(hash + 1) : '';
  const beforeHash = hash >= 0 ? text.slice(0, hash) : text;
  const q = beforeHash.indexOf('?');
  if (q < 0) return null;
  const params = new Map<string, string>();
  for (const pair of beforeHash.slice(q + 1).split('&')) {
    const eq = pair.indexOf('=');
    const key = eq < 0 ? pair : pair.slice(0, eq);
    const value = eq < 0 ? '' : pair.slice(eq + 1);
    try {
      params.set(decodeURIComponent(key), decodeURIComponent(value.replace(/\+/g, ' ')));
    } catch {
      return null;
    }
  }
  const url = (params.get('url') ?? '').trim();
  if (!/^https?:\/\/[^\s/?#]+/i.test(url) || /\s/.test(url)) return null;
  let name = params.get('name') ?? '';
  if (!name && fragment) {
    try {
      name = decodeURIComponent(fragment);
    } catch {
      name = fragment;
    }
  }
  name = name.trim();
  return name ? { url, name } : { url };
}

/** Traffic quota and expiry, when the provider reports them. */
export function usageText(sub: Subscription): string | null {
  const info = sub.info;
  if (!info) return null;
  const used = info.upload + info.download;
  const parts: string[] = [];
  if (info.total > 0) parts.push(tr('usage.of', [formatBytes(used), formatBytes(info.total)]));
  else if (used > 0) parts.push(tr('usage.used', [formatBytes(used)]));
  if (info.expire > 0) {
    const left = info.expire - Date.now() / 1000;
    parts.push(
      left <= 0
        ? tr('usage.expired')
        : tr('usage.expires', [formatDate(info.expire), tr('usage.left', [formatDuration(left)])]),
    );
  }
  return parts.length > 0 ? parts.join(' · ') : null;
}
