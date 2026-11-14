// What `npx expo prebuild` cannot know about BoxPilot's Android app:
//
// - the app packages libbox.aar (the module only compiles against it: Gradle
//   does not let a library carry a local .aar);
// - release signing from android/key.properties or BOXPILOT_KEYSTORE_* (CI);
// - one APK per ABI, since each carries a core;
// - long-pressing the Quick Settings tile opens the app.
//
// iOS needs the PacketTunnel extension target; native/ios/add_packet_tunnel.rb
// adds it after prebuild, on macOS.

const { withAppBuildGradle, withAndroidManifest } = require('expo/config-plugins');

const MARK = '// BoxPilot (plugins/with-boxpilot.js)';

const SIGNING = `
${MARK}: release signing from key.properties (kept next to the project, outside
// the generated android folder) or the BOXPILOT_KEYSTORE_* environment variables.
def boxpilotKeys = new Properties()
def boxpilotKeysFile = new File(rootDir, "../key.properties")
if (boxpilotKeysFile.isFile()) {
    boxpilotKeysFile.withInputStream { boxpilotKeys.load(it) }
}
def boxpilotSigning = { String name, String env -> boxpilotKeys.getProperty(name) ?: System.getenv(env) }
`;

const RELEASE_CONFIG = `        release {
            def boxpilotStore = boxpilotSigning("storeFile", "BOXPILOT_KEYSTORE_FILE")
            if (boxpilotStore != null) {
                storeFile file(boxpilotStore)
                storePassword boxpilotSigning("storePassword", "BOXPILOT_KEYSTORE_PASSWORD")
                keyAlias boxpilotSigning("keyAlias", "BOXPILOT_KEY_ALIAS")
                keyPassword boxpilotSigning("keyPassword", "BOXPILOT_KEY_PASSWORD")
            }
        }
`;

const SPLITS = `
    ${MARK}: one APK per ABI (most phones want arm64-v8a); a universal APK
    // would carry three cores.
    splits {
        abi {
            enable true
            reset()
            include(*(findProperty('reactNativeArchitectures') ?: 'armeabi-v7a,arm64-v8a,x86_64').split(','))
            universalApk false
        }
    }
`;

const LIBBOX = `    ${MARK}: sing-box, built by scripts/build_libbox.sh.
    implementation files("\${rootDir}/../modules/boxpilot-core/android/libs/libbox.aar")
`;

function replaceOnce(text, find, replacement, what) {
  const index = text.indexOf(find);
  if (index < 0) throw new Error(`with-boxpilot: could not find ${what} in app/build.gradle`);
  return text.slice(0, index) + replacement + text.slice(index + find.length);
}

function withGradle(config) {
  return withAppBuildGradle(config, (c) => {
    let g = c.modResults.contents;
    if (g.includes(MARK)) return c;
    g = replaceOnce(g, 'android {', `${SIGNING}\nandroid {`, 'the android block');
    g = replaceOnce(g, '    signingConfigs {\n', `    signingConfigs {\n${RELEASE_CONFIG}`, 'signingConfigs');
    // The release build type signs with the debug key in the template.
    const release = g.indexOf('        release {', g.indexOf('buildTypes {'));
    const debugSigning = g.indexOf('signingConfig signingConfigs.debug', release);
    if (release < 0 || debugSigning < 0) throw new Error('with-boxpilot: could not find the release build type');
    g =
      g.slice(0, debugSigning) +
      'signingConfig boxpilotSigning("storeFile", "BOXPILOT_KEYSTORE_FILE") != null ? signingConfigs.release : signingConfigs.debug' +
      g.slice(debugSigning + 'signingConfig signingConfigs.debug'.length);
    g = replaceOnce(g, '    buildTypes {', `${SPLITS}\n    buildTypes {`, 'buildTypes');
    g = replaceOnce(g, 'dependencies {\n', `dependencies {\n${LIBBOX}`, 'dependencies');
    c.modResults.contents = g;
    return c;
  });
}

function withManifest(config) {
  return withAndroidManifest(config, (c) => {
    const activity = c.modResults.manifest.application?.[0]?.activity?.find(
      (a) => a.$['android:name'] === '.MainActivity',
    );
    if (activity) {
      const action = 'android.service.quicksettings.action.QS_TILE_PREFERENCES';
      const filters = (activity['intent-filter'] ??= []);
      if (!filters.some((f) => f.action?.some((a) => a.$['android:name'] === action))) {
        filters.push({ action: [{ $: { 'android:name': action } }] });
      }
    }
    return c;
  });
}

module.exports = (config) => withManifest(withGradle(config));
