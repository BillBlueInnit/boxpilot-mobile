import 'package:boxpilot/core/format.dart';
import 'package:boxpilot/core/models.dart';
import 'package:boxpilot/i18n/i18n.dart';
import 'package:boxpilot/i18n/strings_desktop.g.dart';
import 'package:boxpilot/i18n/strings_mobile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('i18n', () {
    tearDown(() => setLanguage(AppLanguage.english));

    test('every row has four columns', () {
      for (final e in {...desktopStrings, ...mobileStrings}.entries) {
        expect(e.value.length, 4, reason: e.key);
      }
    });

    test('mobile keys do not shadow desktop keys by accident', () {
      final shared = mobileStrings.keys.toSet().intersection(desktopStrings.keys.toSet());
      expect(shared, isEmpty);
    });

    test('placeholders and fallbacks', () {
      expect(tr('meta.nodes', [12]), '12 nodes');
      setLanguage(AppLanguage.simplifiedChinese);
      expect(tr('status.connected'), '已连接');
      expect(tr('no.such.key'), 'no.such.key');
    });

    test('locale mapping matches the desktop', () {
      expect(AppLanguage.fromLocale(const Locale('zh', 'TW')), AppLanguage.traditionalChinese);
      expect(
        AppLanguage.fromLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
        AppLanguage.traditionalChinese,
      );
      expect(AppLanguage.fromLocale(const Locale('zh', 'CN')), AppLanguage.simplifiedChinese);
      expect(AppLanguage.fromLocale(const Locale('ru', 'RU')), AppLanguage.russian);
      expect(AppLanguage.fromLocale(const Locale('de')), AppLanguage.english);
      expect(AppLanguage.fromSetting('zh-TW'), AppLanguage.traditionalChinese);
    });
  });

  group('format', () {
    test('bytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1536), '1.50 KB');
      expect(formatBytes(10 * 1024 * 1024), '10.0 MB');
      expect(formatSpeed(2048), '2.00 KB/s');
    });

    test('durations', () {
      expect(formatDuration(const Duration(seconds: 42)), '42s');
      expect(formatDuration(const Duration(minutes: 125)), '2h 5m');
      expect(formatDuration(const Duration(days: 3)), '3d');
      expect(formatInterval(0), 'manual');
    });

    test('flags and clock', () {
      expect(flagEmoji('jp'), '🇯🇵');
      expect(flagEmoji('JPN'), '');
      expect(formatClock(3661), '01:01:01');
    });
  });

  group('models', () {
    test('subscription round trip keeps unknown fields', () {
      final sub = Subscription({'id': 'a', 'url': 'https://x', 'node_count': 3, 'future_field': 1});
      final edited = sub.copyWith({'name': 'Home'});
      expect(edited.name, 'Home');
      expect(edited.isRemote, isTrue);
      expect(edited.json['future_field'], 1);
    });

    test('usage info', () {
      final sub = Subscription({
        'info': {'upload': 1, 'download': 2, 'total': 10, 'expire': 0},
      });
      expect(sub.info!.used, 3);
      expect(sub.info!.expire, 0);
    });
  });
}
