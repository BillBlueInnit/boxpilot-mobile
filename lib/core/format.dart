import '../i18n/i18n.dart';

/// `1.2 MB`, `830 KB`: binary units like the desktop app.
String formatBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final digits = i == 0 || v >= 100 ? 0 : (v >= 10 ? 1 : 2);
  return '${v.toStringAsFixed(digits)} ${units[i]}';
}

String formatSpeed(num bytesPerSec) => '${formatBytes(bytesPerSec)}/s';

/// A duration in the desktop's short form: `45s`, `12m`, `3h 5m`, `2d`.
String formatDuration(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return tr('time.s', [s]);
  if (s < 3600) return tr('time.m', [s ~/ 60]);
  if (s < 86400) {
    final m = (s % 3600) ~/ 60;
    return m == 0 ? tr('time.h', [s ~/ 3600]) : tr('time.hm', [s ~/ 3600, m]);
  }
  return tr('time.d', [s ~/ 86400]);
}

/// `just now`, `5m ago` for a unix time in seconds.
String formatAgo(int unixSeconds) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000));
  if (d.inSeconds < 45) return tr('time.just_now');
  return tr('time.ago', [formatDuration(d)]);
}

/// Update interval in minutes as the desktop shows it.
String formatInterval(int minutes) => minutes <= 0 ? tr('time.manual') : formatDuration(Duration(minutes: minutes));

/// The regional-indicator flag for an ISO country code (`JP` → 🇯🇵).
String flagEmoji(String code) {
  if (code.length != 2) return '';
  final upper = code.toUpperCase();
  return String.fromCharCodes(upper.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

/// Clock time for a log line (seconds since local midnight).
String formatClock(int secondsOfDay) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(secondsOfDay ~/ 3600)}:${two((secondsOfDay % 3600) ~/ 60)}:${two(secondsOfDay % 60)}';
}
