#!/usr/bin/env bash
# Builds the Rust bridge (rust/) for the native module.
#
#   scripts/build_rust.sh android|ios
#
# android: shared libraries into the module's jniLibs. Needs cargo-ndk and
#   ANDROID_NDK_HOME. RUST_ANDROID_ABIS picks the ABIs (default: all three).
# ios: BoxpilotBridge.xcframework for the pod (device and simulator). Needs a
#   Mac. RUST_IOS_TARGETS picks the targets.
set -euo pipefail

target="${1:?usage: build_rust.sh android|ios}"
root="$(cd "$(dirname "$0")/.." && pwd)"
module="$root/modules/boxpilot-core"
cd "$root/rust"

case "$target" in
  android)
    abis="${RUST_ANDROID_ABIS:-arm64-v8a armeabi-v7a x86_64}"
    args=()
    for abi in $abis; do args+=(-t "$abi"); done
    # API 29: the app's minSdk.
    cargo ndk "${args[@]}" --platform 29 -o "$module/android/src/main/jniLibs" build --release
    echo "libboxpilot_bridge.so -> modules/boxpilot-core/android/src/main/jniLibs ($abis)"
    ;;
  ios)
    targets="${RUST_IOS_TARGETS:-aarch64-apple-ios aarch64-apple-ios-sim}"
    libs=()
    for t in $targets; do
      cargo build --release --target "$t"
      libs+=(-library "target/$t/release/libboxpilot_bridge.a")
    done
    out="$module/ios/BoxpilotBridge.xcframework"
    rm -rf "$out"
    xcodebuild -create-xcframework "${libs[@]}" -output "$out"
    echo "BoxpilotBridge.xcframework -> modules/boxpilot-core/ios ($targets)"
    ;;
  *)
    echo "unknown target: $target" >&2
    exit 1
    ;;
esac
