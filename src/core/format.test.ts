import assert from 'node:assert/strict';
import { test } from 'node:test';

import { languageForLocale, setLanguage, tr } from '../i18n';
import { desktopStrings } from '../i18n/strings.desktop';
import { mobileStrings } from '../i18n/strings.mobile';
import { flagEmoji, formatBytes, formatClock, formatDuration, parseImportLink } from './format';

test('formats bytes in binary units', () => {
  assert.equal(formatBytes(0), '0 B');
  assert.equal(formatBytes(1536), '1.50 KB');
  assert.equal(formatBytes(15 * 1024 * 1024), '15.0 MB');
  assert.equal(formatBytes(300 * 1024 ** 3), '300 GB');
});

test('formats durations like the desktop', () => {
  setLanguage('en');
  assert.equal(formatDuration(45), '45s');
  assert.equal(formatDuration(12 * 60), '12m');
  assert.equal(formatDuration(3 * 3600 + 5 * 60), '3h 5m');
  assert.equal(formatDuration(3 * 3600), '3h');
  assert.equal(formatDuration(2 * 86400 + 5), '2d');
});

test('formats clock times and flags', () => {
  assert.equal(formatClock(3 * 3600 + 4 * 60 + 5), '03:04:05');
  assert.equal(flagEmoji('JP'), '🇯🇵');
  assert.equal(flagEmoji('jpn'), '');
});

test('import links: clash and clashmeta', () => {
  assert.deepEqual(parseImportLink('clash://install-config?url=https%3A%2F%2Fexample.com%2Fsub%3Ftoken%3D1&name=My%20Sub'), {
    url: 'https://example.com/sub?token=1',
    name: 'My Sub',
  });
  assert.deepEqual(parseImportLink('clashmeta://install-config?url=https://example.com/s'), {
    url: 'https://example.com/s',
  });
  assert.deepEqual(parseImportLink('boxpilot://install-config?url=http%3A%2F%2F10.0.2.2%3A8000%2Fsub.txt'), {
    url: 'http://10.0.2.2:8000/sub.txt',
  });
});

test('import links: sing-box takes the name from the fragment', () => {
  assert.deepEqual(parseImportLink('sing-box://import-remote-profile?url=https%3A%2F%2Fexample.com%2Fp#Tokyo%20Nodes'), {
    url: 'https://example.com/p',
    name: 'Tokyo Nodes',
  });
});

test('import links: rejects other schemes and non-http subscriptions', () => {
  assert.equal(parseImportLink('https://example.com/sub'), null);
  assert.equal(parseImportLink('clash://install-config?url=file%3A%2F%2F%2Fetc%2Fpasswd'), null);
  assert.equal(parseImportLink('clash://install-config'), null);
  assert.equal(parseImportLink('clash://install-config?url=https%3A%2F%2F'), null);
  assert.equal(parseImportLink('vless://uuid@host:443'), null);
});

test('maps device locales to the four languages', () => {
  assert.equal(languageForLocale('zh-Hant-HK'), 'zh-TW');
  assert.equal(languageForLocale('zh_TW'), 'zh-TW');
  assert.equal(languageForLocale('zh-Hans-CN'), 'zh-CN');
  assert.equal(languageForLocale('zh'), 'zh-CN');
  assert.equal(languageForLocale('ru-RU'), 'ru');
  assert.equal(languageForLocale('fr-FR'), 'en');
});

test('translations: four columns each, mobile keys do not shadow desktop ones', () => {
  for (const [key, row] of Object.entries({ ...desktopStrings, ...mobileStrings })) {
    assert.equal(row.length, 4, key);
    assert.notEqual(row[0], '', key);
  }
  // nav.home differs on purpose ("Home" for the phone's dashboard tab).
  const shadowed = Object.keys(mobileStrings).filter((k) => k in desktopStrings);
  assert.deepEqual(shadowed, []);
});

test('tr falls back to English, then to the key', () => {
  setLanguage('ru');
  assert.equal(tr('no.such.key'), 'no.such.key');
  assert.equal(tr('time.s', [5]), '5 с');
  setLanguage('en');
  assert.equal(tr('meta.nodes', [3]), '3 nodes');
});
