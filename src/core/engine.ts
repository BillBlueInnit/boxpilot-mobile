// Typed wrappers over the engine's JSON entry point (rust/src/api.rs).
// Field names are the engine's own (snake_case), so objects round-trip with
// fields this app does not know about intact.

import Native from '../../modules/boxpilot-core';

/** Calls an engine method. Rejects with the engine's error text. */
export async function call<T = null>(method: string, args?: Record<string, unknown>): Promise<T> {
  const answer = JSON.parse(await Native.invoke(method, args ? JSON.stringify(args) : ''));
  if (answer.error != null) throw new Error(String(answer.error));
  return answer.ok as T;
}

export type CoreStatus =
  | { state: 'stopped' | 'starting' | 'running' | 'stopping' }
  | { state: 'failed'; error: string };

export type Settings = Record<string, unknown>;

export type SubInfo = { upload: number; download: number; total: number; expire: number };

export type Subscription = {
  id: string;
  name: string;
  /** Empty for a local (pasted) subscription. */
  url: string;
  enabled: boolean;
  auto_update: boolean;
  interval_min: number;
  update_on_start: boolean;
  update_via: 'auto' | 'direct' | 'proxy';
  user_agent: string;
  include: string;
  exclude: string;
  last_update?: number | null;
  last_error?: string | null;
  node_count: number;
  info?: SubInfo | null;
  web_page?: string | null;
};

/** The reserved subscription that holds nodes added one by one. */
export const LOCAL_NODES_ID = 'local-nodes';

export function blankSubscription(intervalMin: number): Subscription {
  return {
    id: '',
    name: '',
    url: '',
    enabled: true,
    auto_update: true,
    interval_min: intervalMin,
    update_on_start: true,
    update_via: 'auto',
    user_agent: '',
    include: '',
    exclude: '',
    node_count: 0,
  };
}

export type Subscriptions = {
  items: Subscription[];
  /** The "Local nodes" group, when it has nodes. */
  local: Subscription | null;
  updating: string[];
  total_nodes: number;
};

export type NodeInfo = { name: string; protocol: string; server: string; port: number };

export type AutoStrategy = 'quickest' | 'steady' | 'ordered' | 'bandwidth';
export const AUTO_STRATEGIES: AutoStrategy[] = ['quickest', 'steady', 'ordered', 'bandwidth'];

export type Member = {
  name: string;
  protocol: string;
  is_group: boolean;
  /** Clash API latency: null untested, -1 failed, else ms. */
  delay: number | null;
  /** Real-connection latency, same encoding. */
  real_delay: number | null;
  testing: boolean;
  /** Download speed in bytes per second, when measured. */
  speed: number | null;
  speed_testing: boolean;
  /** ISO country code. */
  country: string | null;
  /** How the country is known: by name, server GeoIP, or measured exit. */
  country_origin: 'name' | 'ip' | 'exit' | null;
  country_ip: string | null;
};

export type Group = {
  name: string;
  /** `Selector` or `URLTest`. */
  kind: string;
  now: string;
  selectable: boolean;
  local_nodes: boolean;
  /** Set for a rule-set's or custom rule group's own node group. */
  rule_group: {
    id: string;
    pick: AutoStrategy | null;
    region: string;
    source?: 'rule_set' | 'custom_group';
  } | null;
  members: Member[];
};

export type RuleFormat = 'auto' | 'sing_box_binary' | 'sing_box_source' | 'clash' | 'clash_domain' | 'clash_ip_cidr';

/** The rule-set formats the engine converts, and their labels. */
export const RULE_FORMATS: Record<RuleFormat, string> = {
  auto: '',
  sing_box_binary: 'sing-box .srs',
  sing_box_source: 'sing-box .json',
  clash: 'Clash / ACL4SSR',
  clash_domain: 'Clash domain',
  clash_ip_cidr: 'Clash ipcidr',
};

export type RuleProvider = {
  id: string;
  name: string;
  /** `http(s)://…` or a local file path. */
  source: string;
  format: RuleFormat;
  /** `proxy`, `direct`, `reject` or an outbound / group name. */
  target: string;
  enabled: boolean;
  interval_hours: number;
  last_update?: number | null;
  last_error?: string | null;
  rule_count: number;
  stored?: RuleFormat | null;
  /** Matches go through a node group of their own, shown on the Proxies page. */
  own_group: boolean;
  pick?: AutoStrategy | null;
  region: string;
  /** Built-in service preset id when created from the curated library. */
  preset?: string | null;
  /** Short human-readable subtitle for curated/external rule-sets. */
  description?: string;
};

export type RuleProfileId = 'daily' | 'minimal' | 'streaming' | 'direct_first';
export const RULE_PROFILES: RuleProfileId[] = ['daily', 'minimal', 'streaming', 'direct_first'];

export type ServiceCategoryId = 'ai_dev' | 'streaming' | 'social_gaming' | 'domestic' | 'general';
export const SERVICE_CATEGORIES: ServiceCategoryId[] = ['ai_dev', 'streaming', 'social_gaming', 'domestic', 'general'];

export type ServicePreset = {
  id: string;
  category: ServiceCategoryId;
  name: string;
  geosite: string;
  default_target: string;
  default_own_group: boolean;
  added: boolean;
};

export type CustomRuleKind =
  | 'DOMAIN-SUFFIX'
  | 'DOMAIN'
  | 'DOMAIN-KEYWORD'
  | 'PROCESS-NAME'
  | 'IP-CIDR'
  | 'DST-PORT'
  | 'GEOSITE'
  | 'GEOIP'
  | 'DOMAIN-REGEX'
  | 'PROCESS-PATH'
  | 'SRC-IP-CIDR'
  | 'NETWORK';

export const CUSTOM_RULE_KINDS: CustomRuleKind[] = [
  'DOMAIN-SUFFIX',
  'DOMAIN',
  'DOMAIN-KEYWORD',
  'PROCESS-NAME',
  'IP-CIDR',
  'DST-PORT',
  'GEOSITE',
  'GEOIP',
  'DOMAIN-REGEX',
  'PROCESS-PATH',
  'SRC-IP-CIDR',
  'NETWORK',
];

export type CustomRule = {
  line_index: number;
  kind: CustomRuleKind | null;
  kind_raw: string;
  value: string;
  target: string;
  enabled: boolean;
  raw: string;
  error: string | null;
  group: string | null;
};

export type CustomRuleGroup = {
  id: string;
  name: string;
  target: string;
  enabled: boolean;
  own_group: boolean;
  pick?: AutoStrategy | null;
  region: string;
};

export type RuleMatchLayer =
  | { kind: 'private_ip' }
  | { kind: 'custom_rule'; line_index: number }
  | { kind: 'custom_group'; id: string; name: string }
  | { kind: 'rule_set'; id: string; name: string }
  | { kind: 'built_in'; name: string }
  | { kind: 'fallback' };

export type RuleMatchResult = {
  query: string;
  layer: RuleMatchLayer;
  rule: string;
  target: string;
  approximate: boolean;
};

export function blankRuleProvider(): RuleProvider {
  return {
    id: '',
    name: '',
    source: '',
    format: 'auto',
    target: 'proxy',
    enabled: true,
    interval_hours: 24,
    rule_count: 0,
    own_group: false,
    region: '',
  };
}

export type LogEntry = {
  /** Local time of day in seconds. */
  time: number;
  /** 0 trace … 4 error. */
  level: number;
  message: string;
};

export type ConnectionInfo = {
  id: string;
  network: string;
  target: string;
  host: string;
  destination_ip: string;
  process: string;
  outbound: string;
  chains: string[];
  rule: string;
  upload: number;
  download: number;
  /** RFC 3339 start time. */
  start: string;
};

export type Connections = {
  upload_total: number;
  download_total: number;
  memory: number;
  items: ConnectionInfo[];
};

export type ResetParts = { settings: boolean; subscriptions: boolean; rule_sets: boolean; caches: boolean };

export type EngineEvent =
  | { type: 'status' | 'log' | 'subscriptions' | 'settings' | 'coreInfo' | 'proxies' | 'delays' | 'ruleProviders' }
  | { type: 'traffic'; up: number; down: number }
  | { type: 'notice'; kind: 'info' | 'success' | 'warning' | 'error'; key: string; args: string[] };

export const engine = {
  status: () => call<CoreStatus>('status'),
  start: () => call('start'),
  stop: () => call('stop'),
  restart: () => call('restart'),
  coreVersion: () => call<string>('coreVersion'),
  previewConfig: () => call<string>('previewConfig'),
  setMode: (mode: string) => call('setMode', { mode }),
  setVpnReady: (ready: boolean) => call('setVpnReady', { ready }),

  settings: () => call<Settings>('settings'),
  updateSettings: (patch: Settings) => call('updateSettings', { patch }),
  reset: (parts: ResetParts) => call('reset', parts),

  subscriptions: () => call<Subscriptions>('subscriptions'),
  addSubscription: (sub: Subscription, content?: string) => call<string>('addSubscription', { sub, content }),
  saveSubscription: (sub: Subscription, content?: string) => call('saveSubscription', { sub, content }),
  removeSubscriptions: (ids: string[]) => call('removeSubscriptions', { ids }),
  setSubscriptionsEnabled: (ids: string[], enabled: boolean) => call('setSubscriptionsEnabled', { ids, enabled }),
  updateSubscriptions: (ids: string[]) => call('updateSubscriptions', { ids }),
  updateAllSubscriptions: () => call('updateAllSubscriptions'),
  moveSubscription: (id: string, delta: number) => call('moveSubscription', { id, delta }),
  nodes: (id: string) => call<NodeInfo[]>('nodes', { id }),
  addLocalNodes: (text: string) => call<{ added: number; skipped: string[] }>('addLocalNodes', { text }),
  removeLocalNode: (index: number) => call('removeLocalNode', { index }),
  shareNode: (id: string, index: number) => call<string>('shareNode', { id, index }),
  shareSubscription: (id: string) => call<{ text: string; skipped: string[] }>('shareSubscription', { id }),
  shareLinkFor: (tag: string) => call<string>('shareLinkFor', { tag }),

  groups: () => call<Group[]>('groups'),
  selectProxy: (group: string, name: string) => call('selectProxy', { group, name }),
  testDelays: (names: string[]) => call('testDelays', { names }),
  testRealLatency: (names: string[]) => call('testRealLatency', { names }),
  speedTest: (names: string[]) => call('speedTest', { names }),
  cancelSpeedTest: () => call('cancelSpeedTest'),
  refreshProxies: () => call('refreshProxies'),
  countryCounts: () => call<{ code: string; nodes: number }[]>('countryCounts'),

  ruleProviders: () => call<RuleProvider[]>('ruleProviders'),
  saveRuleProvider: (provider: RuleProvider) => call<string>('saveRuleProvider', { provider }),
  removeRuleProviders: (ids: string[]) => call('removeRuleProviders', { ids }),
  setRuleProvidersEnabled: (ids: string[], enabled: boolean) => call('setRuleProvidersEnabled', { ids, enabled }),
  updateRuleProviders: (ids: string[]) => call('updateRuleProviders', { ids }),
  moveRuleProvider: (id: string, delta: number) => call('moveRuleProvider', { id, delta }),
  importAclIni: (source: string) => call<number>('importAclIni', { source }),
  setRuleProviderGroup: (id: string, on: boolean) => call('setRuleProviderGroup', { id, on }),
  setRuleProviderTarget: (id: string, target: string, own_group: boolean) =>
    call('setRuleProviderTarget', { id, target, own_group }),
  ruleGroupTagFor: (id: string) => call<string | null>('ruleGroupTagFor', { id }),
  servicePresets: () => call<ServicePreset[]>('servicePresets'),
  addServicePreset: (id: string) => call<string | null>('addServicePreset', { id }),
  removeServicePreset: (id: string) => call('removeServicePreset', { id }),
  activeRuleProfile: () => call<RuleProfileId | null>('activeRuleProfile'),
  applyRuleProfile: (profile: RuleProfileId) => call('applyRuleProfile', { profile }),
  setRuleGroupPick: (id: string, pick: AutoStrategy | null, region: string) =>
    call('setRuleGroupPick', { id, pick, region }),
  ruleProviderText: (id: string) => call<{ text: string; local_source: boolean } | null>('ruleProviderText', { id }),
  saveRuleProviderText: (id: string, text: string) => call('saveRuleProviderText', { id, text }),
  customRules: () => call<string>('customRules'),
  setCustomRules: (text: string) => call('setCustomRules', { text }),
  customRulesParsed: () => call<CustomRule[]>('customRulesParsed'),
  addStructuredCustomRule: (kind: CustomRuleKind, value: string, target: string) =>
    call<boolean>('addStructuredCustomRule', { kind, value, target }),
  updateCustomRule: (line_index: number, kind: CustomRuleKind, value: string, target: string, enabled: boolean) =>
    call('updateCustomRule', { line_index, kind, value, target, enabled }),
  setCustomRuleEnabled: (line_index: number, enabled: boolean) =>
    call('setCustomRuleEnabled', { line_index, enabled }),
  removeCustomRule: (line_index: number) => call('removeCustomRule', { line_index }),
  moveCustomRule: (line_index: number, delta: number) => call('moveCustomRule', { line_index, delta }),
  customRuleGroups: () => call<CustomRuleGroup[]>('customRuleGroups'),
  createCustomRuleGroup: (name: string, target: string, own_group: boolean) =>
    call<string>('createCustomRuleGroup', { name, target, own_group }),
  renameCustomRuleGroup: (id: string, name: string) => call('renameCustomRuleGroup', { id, name }),
  setCustomRuleGroupTarget: (id: string, target: string, own_group: boolean) =>
    call('setCustomRuleGroupTarget', { id, target, own_group }),
  setCustomRuleGroupEnabled: (id: string, enabled: boolean) => call('setCustomRuleGroupEnabled', { id, enabled }),
  moveCustomRuleGroup: (id: string, delta: number) => call('moveCustomRuleGroup', { id, delta }),
  removeCustomRuleGroup: (id: string) => call('removeCustomRuleGroup', { id }),
  customRuleGroupTagFor: (id: string) => call<string | null>('customRuleGroupTagFor', { id }),
  setCustomRuleGroupPick: (id: string, pick: AutoStrategy | null, region: string) =>
    call('setCustomRuleGroupPick', { id, pick, region }),
  addStructuredCustomRuleInGroup: (kind: CustomRuleKind, value: string, target: string, group_id: string | null) =>
    call<boolean>('addStructuredCustomRuleInGroup', { kind, value, target, group_id }),
  moveCustomRuleToGroup: (line_index: number, group_id: string | null) =>
    call('moveCustomRuleToGroup', { line_index, group_id }),
  testRuleMatch: (query: string) => call<RuleMatchResult | null>('testRuleMatch', { query }),
  addCustomRule: (rule: string) => call<boolean>('addCustomRule', { rule }),
  baseDomain: (host: string) => call<string | null>('baseDomain', { host }),

  logs: (skip = 0) => call<LogEntry[]>('logs', { skip }),
  clearLogs: () => call('clearLogs'),

  connections: () => call<Connections>('connections'),
  closeConnection: (id: string) => call('closeConnection', { id }),
  closeAllConnections: () => call('closeAllConnections'),
};
