// The native module: the engine's JSON entry point and what only the platform
// knows (VPN consent, per-app proxy, installed apps, wallpaper colours).
// App code uses the typed wrappers in src/core, not this directly.

import { NativeModule, requireNativeModule } from 'expo';

export type HostInfo = {
  /** Version of the embedded core. */
  coreVersion: string;
  dataDir: string;
  /** Whether VPN permission is already granted. */
  vpnReady: boolean;
  /** iOS: a tunnel outlived the app and is still up. */
  tunnelRunning?: boolean;
  /** Whether per-app proxy exists on this platform (Android). */
  perApp: boolean;
  /** Why the engine could not be created, if it could not. */
  error?: string | null;
  /**
   * iOS: why this copy of the app cannot use VPN at all, if it cannot. The
   * PacketTunnel extension is missing, or the app was signed without the
   * Network Extension capability (iOS then never shows its VPN prompt).
   */
  vpnProblem?: 'unsigned' | 'no_extension';
};

export type VpnPermission = {
  ok: boolean;
  /** `denied`: the user said no or the system refused; else see `HostInfo.vpnProblem`. */
  reason?: 'denied' | 'unsigned' | 'no_extension';
  /** The system's own words for a refusal. */
  detail?: string;
};

export type PerAppMode = 'all' | 'include' | 'exclude';

type Events = {
  /** An engine event, as JSON text. */
  onEvent(event: { json: string }): void;
};

declare class BoxpilotCoreModule extends NativeModule<Events> {
  info(): HostInfo | Promise<HostInfo>;
  /** Calls an engine method; resolves to `{"ok": …}` or `{"error": "…"}` as text. */
  invoke(method: string, args: string): Promise<string>;
  /** Asks for VPN permission if needed. Only Connect calls this. */
  prepare(): Promise<VpnPermission>;
  /** Android: ends the process (after a reset). Does nothing on iOS. */
  exit(): void;
  perApp(): { mode: PerAppMode; packages: string[] };
  setPerApp(mode: PerAppMode, packages: string[]): void;
  apps(): Promise<{ package: string; label: string }[]>;
  /** An app's icon as a data URI. */
  appIcon(pkg: string): Promise<string | null>;
  /** Android 12+: the wallpaper's tonal palettes, `accent1_600` -> `#rrggbb`. */
  palette(): Record<string, string> | null;
}

export default requireNativeModule<BoxpilotCoreModule>('BoxpilotCore');
