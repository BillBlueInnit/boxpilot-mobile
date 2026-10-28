#!/usr/bin/env bash
# Builds sing-box's libbox for the app: android/libs/libbox.aar or ios/Libbox.xcframework.
#
#   scripts/build_libbox.sh android|apple
#
# Needs Go, the SagerNet gomobile fork (installed here if missing) and, for Android,
# ANDROID_HOME with an NDK. Uses the build tags of the official sing-box apps.
set -euo pipefail

SING_BOX_VERSION="${SING_BOX_VERSION:-v1.14.4}"
GOMOBILE_VERSION="v0.1.12"
target="${1:?usage: build_libbox.sh android|apple}"

root="$(cd "$(dirname "$0")/.." && pwd)"
work="${LIBBOX_WORK:-$root/build/libbox}"
src="$work/sing-box-$SING_BOX_VERSION"

if [ ! -d "$src" ]; then
  mkdir -p "$work"
  git clone --depth 1 --branch "$SING_BOX_VERSION" https://github.com/SagerNet/sing-box.git "$src"
fi

gobin="$(go env GOPATH)/bin"
export PATH="$gobin:$PATH"
if ! command -v gobind >/dev/null; then
  go install "github.com/sagernet/gomobile/cmd/gomobile@$GOMOBILE_VERSION" \
             "github.com/sagernet/gomobile/cmd/gobind@$GOMOBILE_VERSION"
fi

tags="with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,badlinkname,tfogo_checklinkname0"
ldflags="-X github.com/sagernet/sing-box/constant.Version=${SING_BOX_VERSION#v} -X runtime.godebugDefault=multipathtcp=0,tlssha1=1 -checklinkname=0 -s -w -buildid="

cd "$src"
case "$target" in
  android)
    gomobile bind -v -o "$work/libbox.aar" \
      -target "${LIBBOX_ANDROID_TARGETS:-android/arm64,android/arm,android/amd64}" \
      -androidapi 24 -javapkg=io.nekohasekai -libname=box \
      -trimpath -buildvcs=false -ldflags "$ldflags" -tags "$tags" ./experimental/libbox
    mkdir -p "$root/android/app/libs"
    cp "$work/libbox.aar" "$root/android/app/libs/libbox.aar"
    echo "libbox.aar -> android/app/libs/"
    ;;
  apple)
    gomobile bind -v -target "${LIBBOX_APPLE_TARGETS:-ios,iossimulator}" -libname=box \
      -tags-not-macos=with_low_memory -iosversion=15.0 \
      -trimpath -buildvcs=false -ldflags "$ldflags" -tags "$tags,with_dhcp,grpcnotrace" ./experimental/libbox
    rm -rf "$root/ios/Libbox.xcframework"
    mv Libbox.xcframework "$root/ios/Libbox.xcframework"
    echo "Libbox.xcframework -> ios/"
    ;;
  *)
    echo "unknown target: $target" >&2
    exit 1
    ;;
esac
