// app.json holds the configuration; this adds what comes from the build
// environment. BUILD_NUMBER (CI's run number) becomes the Android versionCode
// and the iOS build number, so each release can update the one before.
module.exports = ({ config }) => {
  const build = Number(process.env.BUILD_NUMBER) || 1;
  return {
    ...config,
    android: { ...config.android, versionCode: build },
    ios: { ...config.ios, buildNumber: String(build) },
  };
};
