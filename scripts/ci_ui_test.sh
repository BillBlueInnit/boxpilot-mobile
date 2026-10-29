#!/usr/bin/env bash
# Runs integration_test/app_test.dart on a device and screenshots each step.
#
#   scripts/ci_ui_test.sh android|ios <device-id> <out-dir> [flutter test args…]
#
# The test prints BOXPILOT_SHOT <name> at each screen (screenshot taken here, so
# native views such as the iOS 26 tab bar are included) and BOXPILOT_NEED_VPN
# before connecting (Android: VPN consent and notifications granted with adb).
set -uo pipefail

platform="$1"; device="$2"; out="$3"; shift 3
mkdir -p "$out"
package=io.github.billblueinnit.boxpilot

capture() {
  if [ "$platform" = android ]; then
    adb -s "$device" exec-out screencap -p > "$out/$1.png"
  else
    xcrun simctl io "$device" screenshot "$out/$1.png" > /dev/null 2>&1
  fi
}

flutter test integration_test/app_test.dart -d "$device" "$@" 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *BOXPILOT_SHOT\ *)
      name="${line##*BOXPILOT_SHOT }"
      capture "${name%%[[:space:]]*}"
      ;;
    *BOXPILOT_NEED_VPN*)
      adb -s "$device" shell appops set "$package" ACTIVATE_VPN allow
      adb -s "$device" shell pm grant "$package" android.permission.POST_NOTIFICATIONS || true
      ;;
  esac
done
status=$?
if [ "$platform" = android ]; then
  adb -s "$device" logcat -d -s BoxPilot flutter AndroidRuntime > "$out/logcat.txt" 2>&1 || true
fi
exit $status
