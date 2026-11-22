// Shared formatting and option helpers for the Rules, Custom Rules,
// Service Library and Rule Tester screens.

import type { CustomRuleGroup, CustomRuleKind, Group, RuleProfileId, RuleProvider } from './engine';
import { outboundLabel } from './format';
import { tr } from '../i18n';
import type { Palette } from '../ui/theme';

export const OWN_GROUP_VALUE = '__own_group__';

/** Human-readable name for a rule-set (prefers localized preset name). */
export function providerTitle(p: RuleProvider): string {
  if (p.preset) return tr(`svc.${p.preset}`);
  return p.name;
}

/** Short description for a rule-set row (hides noisy raw URLs). */
export function providerSummary(p: RuleProvider): string {
  if (p.preset) return tr(`svc.${p.preset}_desc`);
  if (p.description && p.description.trim() !== '') return p.description;
  try {
    if (/^https?:\/\//i.test(p.source)) {
      const u = new URL(p.source);
      const leaf = u.pathname.split('/').filter(Boolean).pop();
      return leaf ? `${u.host} / ${leaf}` : u.host;
    }
  } catch {
    // Fall through to plain filename.
  }
  return p.source.split(/[\\/]/).pop() ?? p.source;
}

/** Compact label for a rule-set's or custom group's destination (including Own node group). */
export function providerTargetLabel(p: Pick<RuleProvider, 'own_group' | 'target'>): string {
  if (p.own_group && p.target !== 'reject') return tr('rules.own_group_short');
  return targetLabel(p.target);
}

/** Compact label for any routing target (`proxy`, `direct`, `reject`, or group name). */
export function targetLabel(target: string): string {
  if (target === 'proxy' || target === 'direct' || target === 'reject') return tr(`target.${target}`);
  return outboundLabel(target);
}

/** Semantic tint colour for a routing target badge. */
export function targetTint(palette: Palette, target: string, ownGroup = false): string {
  if (ownGroup && target !== 'reject') return palette.accent;
  if (target === 'proxy') return palette.accent;
  if (target === 'direct') return palette.good;
  if (target === 'reject') return palette.bad;
  return palette.accent;
}

/** Localized display label for a CustomRuleKind token. */
export function kindLabel(kind: CustomRuleKind | null, fallback = ''): string {
  switch (kind) {
    case 'DOMAIN-SUFFIX':
      return tr('kind.domain_suffix');
    case 'DOMAIN':
      return tr('kind.domain');
    case 'DOMAIN-KEYWORD':
      return tr('kind.domain_keyword');
    case 'PROCESS-NAME':
      return tr('kind.process_name');
    case 'IP-CIDR':
      return tr('kind.ip_cidr');
    case 'DST-PORT':
      return tr('kind.dst_port');
    case 'GEOSITE':
      return tr('kind.geosite');
    case 'GEOIP':
      return tr('kind.geoip');
    case 'DOMAIN-REGEX':
      return tr('kind.domain_regex');
    case 'PROCESS-PATH':
      return tr('kind.process_path');
    case 'SRC-IP-CIDR':
      return tr('kind.src_ip_cidr');
    case 'NETWORK':
      return tr('kind.network');
    default:
      return fallback;
  }
}

/** Contextual input placeholder for a CustomRuleKind. */
export function kindPlaceholder(kind: CustomRuleKind): string {
  switch (kind) {
    case 'DOMAIN-SUFFIX':
    case 'DOMAIN':
      return tr('rules.quick_placeholder_domain');
    case 'DOMAIN-KEYWORD':
      return tr('rules.quick_placeholder_keyword');
    case 'PROCESS-NAME':
    case 'PROCESS-PATH':
      return tr('rules.quick_placeholder_process_mobile');
    case 'IP-CIDR':
    case 'SRC-IP-CIDR':
      return tr('rules.quick_placeholder_ip');
    case 'DST-PORT':
      return tr('rules.quick_placeholder_port');
    case 'GEOSITE':
    case 'GEOIP':
      return tr('rules.quick_placeholder_geo');
    default:
      return tr('rules.quick_placeholder_other');
  }
}

/** Localized profile title & description. */
export function profileMeta(profile: RuleProfileId): { title: string; desc: string } {
  return { title: tr(`profile.${profile}`), desc: tr(`profile.${profile}_desc`) };
}

/**
 * Extra selectable proxy groups (rule-set own groups, custom rule groups, and
 * subscription groups), excluding the built-in `Proxy` and `Auto` groups.
 */
export function extraTargetGroups(
  groups: Group[],
  providers: RuleProvider[],
  customGroups: CustomRuleGroup[] = [],
): string[] {
  const seen = new Set<string>(['proxy', 'direct', 'reject', 'Proxy', 'Auto']);
  const out: string[] = [];
  for (const g of groups) {
    if (!seen.has(g.name)) {
      seen.add(g.name);
      out.push(g.name);
    }
  }
  for (const cg of customGroups) {
    if (cg.enabled && cg.own_group && cg.target !== 'reject' && cg.name !== '' && !seen.has(cg.name)) {
      seen.add(cg.name);
      out.push(cg.name);
    }
  }
  // Also surface enabled own-group rule-sets even while offline so users can
  // point custom rules at them before connecting.
  for (const p of providers) {
    if (p.enabled && p.own_group && p.target !== 'reject' && p.name !== '' && !seen.has(p.name)) {
      seen.add(p.name);
      out.push(p.name);
    }
  }
  return out;
}
