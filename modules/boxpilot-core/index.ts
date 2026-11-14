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
  prepare(): Promise<boolean>;
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
