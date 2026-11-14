import { parseImportLink } from '@/core/format';

/**
 * Links that open the app. A provider's one-tap import link
 * (`clash://install-config?url=…`, `sing-box://import-remote-profile?url=…#name`,
 * `boxpilot://…`) opens the subscription editor, prefilled, for the user to
 * confirm. Anything else lands on the dashboard.
 */
export function redirectSystemPath({ path }: { path: string; initial: boolean }): string {
  const link = parseImportLink(path);
  if (!link) return '/';
  const query = `url=${encodeURIComponent(link.url)}${link.name ? `&name=${encodeURIComponent(link.name)}` : ''}`;
  return `/edit-subscription?${query}`;
}
