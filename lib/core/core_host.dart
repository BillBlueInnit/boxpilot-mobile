import 'dart:async';

import 'package:flutter/services.dart';

/// Events from the platform's VPN host (Android `CoreChannel`, iOS `CoreHost`).
sealed class HostEvent {
  const HostEvent();
}

/// Log lines written by the embedded core.
class HostLogs extends HostEvent {
  const HostLogs(this.lines);
  final List<String> lines;
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

/// What the platform reports at start-up.
class HostInfo {
  const HostInfo({required this.coreVersion, required this.dataDir, required this.running, this.accent});
  final String coreVersion;
  final String dataDir;
  final bool running;

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

  late final Stream<HostEvent> events = _events.receiveBroadcastStream().map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    return switch (m['type']) {
      'logs' => HostLogs(List<String>.from(m['lines'] as List)),
      'stopped' => HostStopped(m['reason'] as String? ?? ''),
      'toggle' => const HostToggle(),
      'disconnect' => const HostDisconnect(),
      _ => const HostLogs([]),
    };
  });

  Future<HostInfo> info() async {
    final m = Map<String, dynamic>.from(await _methods.invokeMethod('info') as Map);
    return HostInfo(
      coreVersion: m['coreVersion'] as String? ?? '',
      dataDir: m['dataDir'] as String,
      running: m['running'] as bool? ?? false,
      accent: m['accent'] as int?,
    );
  }

  /// Asks for VPN permission when needed (system dialog). `true` when allowed.
  Future<bool> prepare() async => await _methods.invokeMethod<bool>('prepare') ?? false;

  /// Starts or reloads the core. Returns an empty string on success, else the error.
  Future<String> start(String config) async =>
      await _methods.invokeMethod<String>('start', {'config': config}) ?? 'no answer from the VPN service';

  Future<void> stop() => _methods.invokeMethod<void>('stop');
}
