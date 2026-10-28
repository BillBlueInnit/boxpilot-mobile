import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../src/rust/api/engine.dart' as api;
import '../src/rust/frb_generated.dart';
import 'core_host.dart';
import 'models.dart';

enum NoticeKind { info, success, warning, error }

class Notice {
  const Notice(this.kind, this.text);
  final NoticeKind kind;
  final String text;
}

/// Up and down speed samples for the dashboard chart, newest last.
class TrafficHistory extends ChangeNotifier {
  static const length = 60;

  final List<int> up = List.filled(length, 0, growable: true);
  final List<int> down = List.filled(length, 0, growable: true);
  int sessionUp = 0;
  int sessionDown = 0;

  int get currentUp => up.last;
  int get currentDown => down.last;

  void add(int u, int d) {
    up
      ..removeAt(0)
      ..add(u);
    down
      ..removeAt(0)
      ..add(d);
    sessionUp += u;
    sessionDown += d;
    notifyListeners();
  }

  void reset() {
    up.fillRange(0, length, 0);
    down.fillRange(0, length, 0);
    sessionUp = 0;
    sessionDown = 0;
    notifyListeners();
  }
}

/// The phone app's mirror of the Rust engine: state comes from the engine's
/// getters and is refreshed on its events. Every action goes to the engine.
class AppState extends ChangeNotifier {
  AppState._();

  static final instance = AppState._();

  final host = CoreHost.instance;
  final traffic = TrafficHistory();

  /// Bumped when new log lines arrive.
  final logRevision = ValueNotifier<int>(0);

  final _notices = StreamController<Notice>.broadcast();
  Stream<Notice> get notices => _notices.stream;

  api.CoreState status = const api.CoreState.stopped();
  Map<String, dynamic> settings = {};
  List<Subscription> subscriptions = [];
  Set<String> updating = {};
  List<api.Group> groups = [];
  List<RuleProvider> ruleProviders = [];
  String coreVersion = '';
  String dataDir = '';
  DateTime? connectedSince;

  /// The wallpaper accent on Android 12+, for Material You.
  Color? systemAccent;

  Timer? _groupsDebounce;
  bool _ready = false;
  bool get ready => _ready;

  bool get running => status is api.CoreState_Running;
  bool get busy => status is api.CoreState_Starting || status is api.CoreState_Stopping;
  String? get failure => switch (status) {
    api.CoreState_Failed(:final field0) => field0,
    _ => null,
  };

  String get mode => settings['mode'] as String? ?? 'Rule';
  int get totalNodes => subscriptions.where((s) => s.enabled).fold(0, (n, s) => n + s.nodeCount);

  T setting<T>(String key, T fallback) {
    final v = settings[key];
    if (v is T) return v;
    if (fallback is int && v is num) return v.toInt() as T;
    return fallback;
  }

  // ------------------------------------------------------------- start-up

  Future<void> init() async {
    await RustLib.init();
    final info = await host.info();
    dataDir = info.dataDir;
    if (info.accent != null) systemAccent = Color(info.accent!);
    await api.init(
      root: info.dataDir,
      coreVersion: info.coreVersion,
      startCore: (config) => host.start(config),
      stopCore: () => host.stop(),
    );
    api.events().listen(_onEvent);
    host.events.listen(_onHostEvent);
    _reloadAll();
    _ready = true;
    notifyListeners();
  }

  void _reloadAll() {
    status = api.status();
    coreVersion = api.coreVersion();
    _loadSettings();
    _loadSubscriptions();
    _loadRuleProviders();
    groups = api.groups();
    if (running) connectedSince ??= DateTime.now();
  }

  void _loadSettings() {
    settings = Map<String, dynamic>.from(jsonDecode(api.settingsJson()) as Map);
    setLanguage(AppLanguage.fromSetting(settings['language'] as String?));
  }

  void _loadSubscriptions() {
    subscriptions = (jsonDecode(api.subscriptionsJson()) as List)
        .map((e) => Subscription(Map<String, dynamic>.from(e as Map)))
        .toList();
    updating = api.updatingSubscriptions().toSet();
  }

  void _loadRuleProviders() {
    ruleProviders = (jsonDecode(api.ruleProvidersJson()) as List)
        .map((e) => RuleProvider(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void _onEvent(api.UiEvent e) {
    switch (e) {
      case api.UiEvent_Status():
        final wasRunning = running;
        status = api.status();
        if (running && !wasRunning) {
          connectedSince = DateTime.now();
          traffic.reset();
        } else if (!running) {
          connectedSince = null;
        }
        groups = api.groups();
      case api.UiEvent_Traffic(:final up, :final down):
        traffic.add(up, down);
        return;
      case api.UiEvent_Log():
        logRevision.value++;
        return;
      case api.UiEvent_Subscriptions():
        _loadSubscriptions();
      case api.UiEvent_Settings():
        _loadSettings();
      case api.UiEvent_CoreInfo():
        coreVersion = api.coreVersion();
      case api.UiEvent_Proxies() || api.UiEvent_Delays():
        // Latency tests report node by node; redraw at most every 150 ms.
        _groupsDebounce ??= Timer(const Duration(milliseconds: 150), () {
          _groupsDebounce = null;
          groups = api.groups();
          notifyListeners();
        });
        return;
      case api.UiEvent_RuleProviders():
        _loadRuleProviders();
      case api.UiEvent_Notice(:final kind, :final key, :final args):
        _notices.add(Notice(NoticeKind.values[kind.index], tr(key, args)));
        return;
    }
    notifyListeners();
  }

  void _onHostEvent(HostEvent e) {
    switch (e) {
      case HostLogs(:final lines):
        if (lines.isNotEmpty) api.pushCoreLogs(lines: lines);
      case HostStopped(:final reason):
        api.coreExited(reason: reason);
      case HostToggle():
        running || busy ? disconnect() : connect();
      case HostDisconnect():
        disconnect();
    }
  }

  void notify(NoticeKind kind, String text) => _notices.add(Notice(kind, text));

  // ------------------------------------------------------------------ core

  Future<void> connect() async {
    if (running || busy) return;
    if (!await host.prepare()) {
      notify(NoticeKind.error, tr('vpn.denied'));
      return;
    }
    try {
      await api.start();
    } catch (_) {
      // The engine reports the failure through its status.
    }
  }

  void disconnect() => api.stop();

  void toggle() => running || busy ? disconnect() : connect();

  void setMode(String mode) {
    settings['mode'] = mode;
    notifyListeners();
    api.setMode(mode: mode);
  }

  /// Changes settings fields; the engine persists them and reloads what it must.
  void updateSettings(Map<String, dynamic> patch) {
    settings.addAll(patch);
    if (patch.containsKey('language')) setLanguage(AppLanguage.fromSetting(patch['language'] as String?));
    notifyListeners();
    try {
      api.updateSettings(patch: jsonEncode(patch));
    } catch (e) {
      notify(NoticeKind.error, tr('notice.save_failed', ['$e']));
      _loadSettings();
      notifyListeners();
    }
  }

  // --------------------------------------------------------- subscriptions

  Future<bool> addSubscription(Subscription sub, {String? content}) async {
    try {
      await api.addSubscription(json: sub.encode(), content: content);
      return true;
    } catch (e) {
      notify(NoticeKind.error, _message(e));
      return false;
    }
  }

  Future<bool> saveSubscription(Subscription sub, {String? content}) async {
    try {
      await api.saveSubscription(json: sub.encode(), content: content);
      return true;
    } catch (e) {
      notify(NoticeKind.error, _message(e));
      return false;
    }
  }

  void removeSubscriptions(List<String> ids) => api.removeSubscriptions(ids: ids);

  void setSubscriptionEnabled(String id, bool enabled) => api.setSubscriptionsEnabled(ids: [id], enabled: enabled);

  void updateSubscription(String id) => api.updateSubscriptions(ids: [id]);

  void updateAllSubscriptions() => api.updateAllSubscriptions();

  void moveSubscription(String id, int delta) => api.moveSubscription(id: id, delta: delta);

  List<api.NodeInfo> nodes(String subscriptionId) => api.nodes(subscriptionId: subscriptionId);

  // --------------------------------------------------------------- proxies

  void select(String group, String name) => api.selectProxy(group: group, name: name);

  void testLatency(List<String> names) => api.testDelays(names: names);

  void testRealLatency(List<String> names) => api.testRealLatency(names: names);

  void speedTest(List<String> names) => api.speedTest(names: names);

  List<api.CountryCount> countryCounts() => api.countryCounts();

  // ----------------------------------------------------------------- rules

  String saveRuleProvider(RuleProvider p) => api.saveRuleProvider(json: p.encode());

  void removeRuleProviders(List<String> ids) => api.removeRuleProviders(ids: ids);

  void setRuleProviderEnabled(String id, bool enabled) => api.setRuleProvidersEnabled(ids: [id], enabled: enabled);

  void updateRuleProviders(List<String> ids) => api.updateRuleProviders(ids: ids);

  void moveRuleProvider(String id, int delta) => api.moveRuleProvider(id: id, delta: delta);

  Future<int?> importAcl(String source) async {
    try {
      return await api.importAclIni(source: source);
    } catch (e) {
      notify(NoticeKind.error, _message(e));
      return null;
    }
  }

  // ------------------------------------------------------- logs, connections

  List<api.LogEntry> logs({int skip = 0}) => api.logs(skip: skip);

  void clearLogs() {
    api.clearLogs();
    logRevision.value++;
  }

  Future<api.Connections?> connections() async {
    try {
      return await api.connections();
    } catch (_) {
      return null;
    }
  }

  Future<void> closeConnection(String id) => api.closeConnection(id: id);

  Future<void> closeAllConnections() => api.closeAllConnections();

  String previewConfig() => api.previewConfig();

  Future<void> reset(api.ResetParts parts) => api.reset(parts: parts);

  static String _message(Object e) {
    final s = e.toString();
    return s.startsWith('AnyhowException(') ? s.substring(16, s.length - 1) : s;
  }
}
