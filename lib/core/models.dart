import 'dart:convert';

/// A subscription as the engine stores it. Kept as the JSON map so fields the
/// phone app does not know about survive a round trip.
class Subscription {
  Subscription(this.json);

  factory Subscription.blank({required int intervalMin}) => Subscription({
    'id': '',
    'name': '',
    'url': '',
    'enabled': true,
    'auto_update': true,
    'interval_min': intervalMin,
    'update_on_start': true,
    'update_via': 'auto',
    'user_agent': '',
    'include': '',
    'exclude': '',
  });

  final Map<String, dynamic> json;

  String get id => json['id'] as String? ?? '';
  String get name => json['name'] as String? ?? '';
  String get url => json['url'] as String? ?? '';
  bool get isRemote => url.trim().isNotEmpty;
  bool get enabled => json['enabled'] as bool? ?? true;
  bool get autoUpdate => json['auto_update'] as bool? ?? true;
  int get intervalMin => (json['interval_min'] as num?)?.toInt() ?? 720;
  bool get updateOnStart => json['update_on_start'] as bool? ?? true;
  String get updateVia => json['update_via'] as String? ?? 'auto';
  String get userAgent => json['user_agent'] as String? ?? '';
  String get include => json['include'] as String? ?? '';
  String get exclude => json['exclude'] as String? ?? '';
  int? get lastUpdate => (json['last_update'] as num?)?.toInt();
  String? get lastError => json['last_error'] as String?;
  int get nodeCount => (json['node_count'] as num?)?.toInt() ?? 0;
  String? get webPage => json['web_page'] as String?;

  /// Traffic quota from the provider, when it reports one.
  SubInfo? get info {
    final i = json['info'];
    return i is Map ? SubInfo(Map<String, dynamic>.from(i)) : null;
  }

  Subscription copyWith(Map<String, dynamic> changes) => Subscription({...json, ...changes});

  String encode() => jsonEncode(json);
}

class SubInfo {
  SubInfo(this.json);
  final Map<String, dynamic> json;

  int get upload => (json['upload'] as num?)?.toInt() ?? 0;
  int get download => (json['download'] as num?)?.toInt() ?? 0;
  int get total => (json['total'] as num?)?.toInt() ?? 0;
  int get used => upload + download;

  /// Unix seconds; 0 when there is no expiry.
  int get expire => (json['expire'] as num?)?.toInt() ?? 0;
}

/// An imported rule-set (`rules::RuleProvider`).
class RuleProvider {
  RuleProvider(this.json);

  factory RuleProvider.blank() => RuleProvider({
    'id': '',
    'name': '',
    'source': '',
    'format': 'auto',
    'target': 'proxy',
    'enabled': true,
    'interval_hours': 24,
  });

  final Map<String, dynamic> json;

  String get id => json['id'] as String? ?? '';
  String get name => json['name'] as String? ?? '';
  String get source => json['source'] as String? ?? '';
  String get format => json['format'] as String? ?? 'auto';
  String get target => json['target'] as String? ?? 'proxy';
  bool get enabled => json['enabled'] as bool? ?? true;
  int get intervalHours => (json['interval_hours'] as num?)?.toInt() ?? 24;
  int? get lastUpdate => (json['last_update'] as num?)?.toInt();
  String? get lastError => json['last_error'] as String?;
  int get ruleCount => (json['rule_count'] as num?)?.toInt() ?? 0;

  RuleProvider copyWith(Map<String, dynamic> changes) => RuleProvider({...json, ...changes});

  String encode() => jsonEncode(json);
}

/// The rule-set formats the engine converts (`rules::RuleFormat`) and their labels.
const ruleFormats = {
  'auto': '',
  'sing_box_binary': 'sing-box .srs',
  'sing_box_source': 'sing-box .json',
  'clash': 'Clash / ACL4SSR',
  'clash_domain': 'Clash domain',
  'clash_ip_cidr': 'Clash ipcidr',
};

/// Auto group strategies (`model::AutoStrategy`), in the desktop's order.
const autoStrategies = ['quickest', 'steady', 'ordered', 'bandwidth'];
