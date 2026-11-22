// The app's mirror of the Rust engine: state comes from the engine's getters
// and is refreshed on its events. Every action goes to the engine.

import { Alert, PermissionsAndroid, Platform } from 'react-native';
import { create } from 'zustand';

import Native, { type HostInfo } from '../../modules/boxpilot-core';
import { type LanguageCode, resolveLanguage, setLanguage, tr } from '../i18n';
import {
  type CoreStatus,
  type CustomRuleGroup,
  type EngineEvent,
  type Group,
  type RuleProvider,
  type Settings,
  type Subscription,
  engine,
} from './engine';

export type NoticeKind = 'info' | 'success' | 'warning' | 'error';
export type Notice = { id: number; kind: NoticeKind; text: string };

/** Speed samples kept for the dashboard chart, newest last. */
export const TRAFFIC_SAMPLES = 60;

type State = {
  /** The engine answered and the first state is loaded. */
  ready: boolean;
  /** Why the engine could not start, if it could not. */
  fatal: string | null;
  host: HostInfo | null;
  status: CoreStatus;
  settings: Settings;
  language: LanguageCode;
  subscriptions: Subscription[];
  /** The "Local nodes" group, when it has nodes. */
  local: Subscription | null;
  updating: string[];
  totalNodes: number;
  groups: Group[];
  ruleProviders: RuleProvider[];
  customRuleGroups: CustomRuleGroup[];
  coreVersion: string;
  /** When the core came up, in ms. */
  connectedSince: number | null;
  /** Bumped when new log lines arrive. */
  logRevision: number;
  up: number[];
  down: number[];
  sessionUp: number;
  sessionDown: number;
  notice: Notice | null;
  /** Group name to expand and scroll to when navigating to Proxies from Rules. */
  pendingProxyGroup: string | null;
};

const zeros = () => new Array<number>(TRAFFIC_SAMPLES).fill(0);

export const useStore = create<State>(() => ({
  ready: false,
  fatal: null,
  host: null,
  status: { state: 'stopped' },
  settings: {},
  language: 'en',
  subscriptions: [],
  local: null,
  updating: [],
  totalNodes: 0,
  groups: [],
  ruleProviders: [],
  customRuleGroups: [],
  coreVersion: '',
  connectedSince: null,
  logRevision: 0,
  up: zeros(),
  down: zeros(),
  sessionUp: 0,
  sessionDown: 0,
  notice: null,
  pendingProxyGroup: null,
}));

const set = useStore.setState;
const get = useStore.getState;

/** Queues a proxy group to be expanded & focused when Proxies opens. */
export function focusProxyGroup(name: string | null) {
  set({ pendingProxyGroup: name });
}

export const isRunning = (s: CoreStatus) => s.state === 'running';
export const isBusy = (s: CoreStatus) => s.state === 'starting' || s.state === 'stopping';

type Widen<T> = T extends string ? string : T extends number ? number : T extends boolean ? boolean : T;

/** A settings field with its type taken from the fallback. */
export function settingOf<T>(settings: Settings, key: string, fallback: T): Widen<T> {
  const v = settings[key];
  return (typeof v === typeof fallback ? v : fallback) as Widen<T>;
}

export function useSetting<T>(key: string, fallback: T): Widen<T> {
  return useStore((s) => settingOf(s.settings, key, fallback));
}

let noticeId = 0;

export function notify(kind: NoticeKind, text: string) {
  set({ notice: { id: ++noticeId, kind, text } });
}

const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

// ------------------------------------------------------------------ loading

async function loadSettings() {
  const settings = await engine.settings();
  const language = resolveLanguage(settings.language);
  setLanguage(language);
  set({ settings, language });
}

async function loadSubscriptions() {
  const s = await engine.subscriptions();
  set({ subscriptions: s.items, local: s.local, updating: s.updating, totalNodes: s.total_nodes });
}

async function loadStatus() {
  const [status, groups] = await Promise.all([engine.status(), engine.groups()]);
  const was = get().status;
  if (isRunning(status) && !isRunning(was)) {
    set({ connectedSince: Date.now(), up: zeros(), down: zeros(), sessionUp: 0, sessionDown: 0 });
  } else if (!isRunning(status)) {
    set({ connectedSince: null });
  }
  set({ status, groups });
}

let groupsTimer: ReturnType<typeof setTimeout> | null = null;

function onEvent(e: EngineEvent) {
  switch (e.type) {
    case 'status':
      void loadStatus();
      break;
    case 'traffic': {
      const s = get();
      set({
        up: [...s.up.slice(1), e.up],
        down: [...s.down.slice(1), e.down],
        sessionUp: s.sessionUp + e.up,
        sessionDown: s.sessionDown + e.down,
      });
      break;
    }
    case 'log':
      set({ logRevision: get().logRevision + 1 });
      break;
    case 'subscriptions':
      void loadSubscriptions();
      break;
    case 'settings':
      void loadSettings();
      void engine.customRuleGroups().then((customRuleGroups) => set({ customRuleGroups }), () => {});
      break;
    case 'coreInfo':
      void engine.coreVersion().then((coreVersion) => set({ coreVersion }));
      break;
    case 'proxies':
    case 'delays':
      // Latency tests report node by node; redraw at most every 150 ms.
      groupsTimer ??= setTimeout(() => {
        groupsTimer = null;
        void engine.groups().then((groups) => set({ groups }));
      }, 150);
      break;
    case 'ruleProviders':
      void engine.ruleProviders().then((ruleProviders) => set({ ruleProviders }));
      void engine.customRuleGroups().then((customRuleGroups) => set({ customRuleGroups }), () => {});
      break;
    case 'notice':
      notify(e.kind, tr(e.key, e.args));
      break;
  }
}

let started = false;

/** Attaches to the engine (creating it on first launch) and loads the first state. */
export async function startApp() {
  if (started) return;
  started = true;
  try {
    const host = await Promise.resolve(Native.info());
    if (host.error) throw new Error(host.error);
    Native.addListener('onEvent', ({ json }) => {
      try {
        onEvent(JSON.parse(json) as EngineEvent);
      } catch {
        // An event this version does not know.
      }
    });
    const [coreVersion, ruleProviders, customRuleGroups] = await Promise.all([
      engine.coreVersion(),
      engine.ruleProviders(),
      engine.customRuleGroups().catch(() => [] as CustomRuleGroup[]),
    ]);
    await Promise.all([loadSettings(), loadSubscriptions(), loadStatus()]);
    set({ host, coreVersion, ruleProviders, customRuleGroups, ready: true });
    // The tunnel outlived the app (iOS keeps it when the app is closed): take it
    // over again. Starting a running core reloads it in place.
    if (host.tunnelRunning && !isRunning(get().status)) {
      engine.start().catch(() => {});
    }
  } catch (e) {
    set({ fatal: message(e), ready: true });
  }
}

// --------------------------------------------------------------------- core

export async function connect() {
  const { status } = get();
  if (isRunning(status) || isBusy(status)) return;
  // The only place that may bring up the system's VPN permission prompt.
  const permission = await Native.prepare();
  if (!permission.ok) {
    if (permission.reason === 'unsigned' || permission.reason === 'no_extension') {
      // iOS will never show its VPN prompt for this copy of the app: say why.
      Alert.alert(tr('vpn.unavailable'), tr(`vpn.${permission.reason}`));
    } else {
      notify('error', permission.detail ? `${tr('vpn.denied')} (${permission.detail})` : tr('vpn.denied'));
    }
    return;
  }
  await engine.setVpnReady(true);
  if (Platform.OS === 'android' && Platform.Version >= 33) {
    // The VPN notification (with Disconnect) needs this on Android 13+. Android
    // itself stops asking after two refusals.
    void PermissionsAndroid.request('android.permission.POST_NOTIFICATIONS').catch(() => {});
  }
  // The engine reports a failure through its status.
  await engine.start().catch(() => {});
}

export const disconnect = () => void engine.stop();

export function toggle() {
  const { status } = get();
  if (isRunning(status) || isBusy(status)) disconnect();
  else void connect();
}

/** Reloads a running core after a change the engine doesn't know about (per-app proxy). */
export function reloadCore() {
  if (isRunning(get().status)) void engine.restart();
}

export function setMode(mode: string) {
  set({ settings: { ...get().settings, mode } });
  void engine.setMode(mode);
}

/** Changes settings fields; the engine persists them and reloads what it must. */
export function updateSettings(patch: Settings) {
  const settings = { ...get().settings, ...patch };
  if ('language' in patch) {
    const language = resolveLanguage(patch.language);
    setLanguage(language);
    set({ settings, language });
  } else {
    set({ settings });
  }
  engine.updateSettings(patch).catch((e) => {
    notify('error', tr('notice.save_failed', [message(e)]));
    void loadSettings();
  });
}

/** Runs an engine call and shows its error as a notice. Returns whether it worked. */
export async function attempt<T>(work: Promise<T>): Promise<T | undefined> {
  try {
    return await work;
  } catch (e) {
    notify('error', message(e));
    return undefined;
  }
}

/** The enabled subscriptions' nodes, as the dashboard counts them. */
export const enabledNodes = (s: State) =>
  [...s.subscriptions, ...(s.local ? [s.local] : [])].filter((x) => x.enabled).reduce((n, x) => n + x.node_count, 0);
