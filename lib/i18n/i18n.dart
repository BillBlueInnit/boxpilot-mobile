import 'dart:ui';

import 'strings_desktop.g.dart';
import 'strings_mobile.dart';

/// The four UI languages, in the column order of the string tables.
enum AppLanguage {
  english('en', Locale('en')),
  simplifiedChinese('zh-CN', Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')),
  traditionalChinese('zh-TW', Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
  russian('ru', Locale('ru'));

  const AppLanguage(this.code, this.locale);

  /// The value stored in settings (`language`), same as desktop.
  final String code;
  final Locale locale;

  /// Maps a locale such as `zh-Hant-HK` or `ru-RU` to a supported language.
  static AppLanguage fromLocale(Locale l) {
    if (l.languageCode == 'zh') {
      final hant = l.scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(l.countryCode);
      return hant ? traditionalChinese : simplifiedChinese;
    }
    if (l.languageCode == 'ru') return russian;
    return english;
  }

  /// `System` (or anything unknown) follows the device.
  static AppLanguage fromSetting(String? value) {
    for (final lang in values) {
      if (lang.code == value) return lang;
    }
    return fromLocale(PlatformDispatcher.instance.locale);
  }

  String get nativeName => switch (this) {
    english => 'English',
    simplifiedChinese => '简体中文',
    traditionalChinese => '繁體中文',
    russian => 'Русский',
  };
}

AppLanguage _current = AppLanguage.english;

AppLanguage get currentLanguage => _current;

void setLanguage(AppLanguage lang) => _current = lang;

/// The string for `key` in the current language, with `{0}`, `{1}`… replaced.
/// Missing translations fall back to English, then to the key.
String tr(String key, [List<Object?> args = const []]) {
  final row = mobileStrings[key] ?? desktopStrings[key];
  var s = row == null ? key : row[_current.index];
  if (s.isEmpty && row != null) s = row[0];
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return s;
}
