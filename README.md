# BoxPilot for Android and iOS

The phone version of [BoxPilot](https://github.com/BillBlueInnit/boxpilot): the same proxy client
with the same built-in subscription converter, built with Flutter. It runs the core as the
device VPN, with no separate download.

- **Android** (10 and later): Material 3 with Material You colours, large collapsing app bars, a
  Quick Settings tile, and a VPN notification with a Disconnect action.
- **iOS** (15 and later): native Liquid Glass tab bar, toolbar, buttons and controls on iOS 26,
  with classic Cupertino controls on older versions. Inset grouped lists and sheets throughout.

## What it does

The same as the desktop app, because it runs the desktop app's engine (`boxpilot-core`)
unchanged:

- Subscriptions: v2ray/Shadowrocket links, Clash / Clash.Meta YAML and sing-box JSON. Covers
  VLESS (REALITY, Vision), VMess, Trojan, Shadowsocks, Hysteria 2, TUIC, AnyTLS, WireGuard and more.
  Includes interval and startup updates, include/exclude filters, traffic and expiry info, and
  pasted (local) subscriptions.
- Proxies: Rule / Global / Direct modes, selector and Auto groups per subscription, latency, real
  latency and speed tests, and country flags. Auto picks nodes by quickest, steady, list order or
  most bandwidth, optionally limited to one region.
- Rules: built-in China bypass and ad blocking, rule-sets from URLs (sing-box, Clash, ACL4SSR),
  ACL4SSR `.ini` import, and custom rules.
- DNS (DoH/DoT/DoQ/UDP, FakeIP, IPv6), UDP and QUIC options, LAN sharing (hotspot).
- Live traffic chart, connections (close one or all), logs, and the generated config.
- English, 简体中文, 繁體中文 and Русский (the desktop's translations).

## How it fits together

```
Flutter UI (lib/)                   Material 3 on Android, Liquid Glass / Cupertino on iOS
   │  flutter_rust_bridge
Rust bridge (rust/) → boxpilot-core::Engine   state, scheduler, converter, config, Clash API
   │  CoreHost: start(config) / stop()
Platform host                       Android: BoxVpnService (VpnService)
   │                                iOS: PacketTunnel network extension
libbox (sing-box)                   the core, in-process, serving the Clash API on 127.0.0.1
```

The engine reaches the core only through the generated config and the Clash API, as on desktop.
The only mobile-specific piece is `CoreHost`. Instead of spawning the sing-box executable, the
engine asks the platform to run libbox inside its VPN service.

## Building

Requirements: Flutter 3.47, Rust with the mobile targets, Go 1.25+, and the Android SDK with
NDK 28.2 (Android) or Xcode 26 (iOS).

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android aarch64-apple-ios
```

```bash
bash scripts/build_libbox.sh android
```

```bash
flutter build apk --release --split-per-abi
```

For iOS, on a Mac:

```bash
bash scripts/build_libbox.sh apple && ruby ios/scripts/add_packet_tunnel.rb && flutter build ios --release
```

`rust/Cargo.toml` takes `boxpilot-core` from GitHub. To build against a local checkout of the
desktop repository, add `.cargo/config.toml` (ignored by git):

```toml
[patch."https://github.com/BillBlueInnit/boxpilot"]
boxpilot-core = { path = "../../rust/boxpilot/crates/core" }
```

Other scripts:
- `python scripts/gen_i18n.py` regenerates `lib/i18n/strings_desktop.g.dart` from the desktop
  translations.
- `python scripts/make_icons.py` renders the launcher icons from the desktop icon's geometry.

## Releases

`.github/workflows/build.yml` runs the analyzer and tests, then builds:
- APKs (one per ABI; most phones want arm64-v8a), signed with the release key when the `BOXPILOT_KEYSTORE_*`
  secrets are set;
- an unsigned IPA. Re-sign it with a provisioning profile that has the Network Extension
  (packet tunnel) and App Group capabilities. That requires a paid Apple developer account,
  because free accounts can't use Network Extension.

Push a `v*` tag to publish both to GitHub Releases.

## License

MIT for this repository's code. Release builds include sing-box (GPL-3.0-or-later), so the
APK and IPA are distributed under the GPL. See [NOTICE](NOTICE).
