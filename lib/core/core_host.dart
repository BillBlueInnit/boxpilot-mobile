import 'dart:async';

import 'package:flutter/services.dart';

/// Events from the platform's VPN host (Android `CoreChannel`, iOS `CoreHost`).
sealed class HostEvent {
  const HostEvent();
}

/// The VPN stopped without the engine asking (revoked, another VPN, killed).
class HostStopped extends HostEvent {
  const HostStopped(this.reason);
  final String reason;
}

/// Quick Settings tile / Control Center: connect or disconnect.
class HostToggle extends HostEvent {
  const HostToggle();
}

/// The notification's Disconnect action.
class HostDisconnect extends HostEvent {
  const HostDisconnect();
}

/// A provider's one-tap import link (`clash://install-config?url=…` and similar).
class HostImport extends HostEvent {
  const HostImport(this.url);
  final String url;
}

/// Per-app proxy (Android): which apps the VPN carries.
enum PerAppMode { all, include, exclude }

class InstalledApp {
  const InstalledApp(this.package, this.label);
  final String package;
  final String label;
}

/// What the platform reports at start-up.
class HostInfo {
  const HostInfo({
    required this.coreVersion,
    required this.dataDir,
    required this.running,
    required this.vpnReady,
    this.accent,
  });
  final String coreVersion;
  final String dataDir;
  final bool running;

  /// VPN permission already granted, so connecting needs no prompt.
  final bool vpnReady;

  /// The wallpaper accent colour (Android 12+), as ARGB.
  final int? accent;
}

/// The engine's way to the embedded core: the platform starts libbox inside
/// its VPN service (Android) or packet tunnel extension (iOS).
class CoreHost {
  CoreHost._();

  static final instance = CoreHost._();

  static const _methods = MethodChannel('boxpilot/core');
  static const _events = EventChannel('boxpilot/core/events');

  late final Stream<HostEvent> events = _events
      .receiveBroadcastStream()
      .map<HostEvent?>((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return switch (m['type']) {
          'stopped' => HostStopped(m['reason'] as String? ?? ''),
          'toggle' => const HostToggle(),
          'disconnect' => const HostDisconnect(),
          'import' => HostImport(m['url'] as String? ?? ''),
          _ => null,
        };
      })
      .where((e) => e != null)
      .cast<HostEvent>();

  Future<HostInfo> info() async {
    final m = Map<String, dynamic>.from(await _methods.invokeMethod('info') as Map);
    return HostInfo(
      coreVersion: m['coreVersion'] as String? ?? '',
      dataDir: m['dataDir'] as String,
      running: m['running'] as bool? ?? false,
      vpnReady: m['vpnReady'] as bool? ?? false,
      accent: m['accent'] as int?,
    );
  }

  /// Asks for VPN permission when needed (system dialog). `true` when allowed.
  Future<bool> prepare() async => await _methods.invokeMethod<bool>('prepare') ?? false;

  /// Starts or reloads the core. Returns an empty string on success, else the error.
  Future<String> start(String config) async =>
      await _methods.invokeMethod<String>('start', {'config': config}) ?? 'no answer from the VPN service';

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  /// An import link that opened the app before the UI was listening.
  Future<String?> takeImport() => _methods.invokeMethod<String>('takeImport');

  Future<(PerAppMode, Set<String>)> perApp() async {
    final m = Map<String, dynamic>.from(await _methods.invokeMethod('perApp') as Map);
    final mode = PerAppMode.values.firstWhere((v) => v.name == m['mode'], orElse: () => PerAppMode.all);
    return (mode, Set<String>.from(m['packages'] as List? ?? const []));
  }

  Future<void> setPerApp(PerAppMode mode, Set<String> packages) =>
      _methods.invokeMethod('setPerApp', {'mode': mode.name, 'packages': packages.toList()});

  /// Apps with a launcher entry, sorted by name.
  Future<List<InstalledApp>> apps() async {
    final list = await _methods.invokeMethod<List>('apps') ?? const [];
    return [for (final raw in list) InstalledApp((raw as Map)['package'] as String, raw['label'] as String)];
  }

  Future<Uint8List?> appIcon(String package) => _methods.invokeMethod<Uint8List>('appIcon', {'package': package});
}
