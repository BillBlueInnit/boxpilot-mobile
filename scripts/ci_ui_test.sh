#!/usr/bin/env bash
# Runs integration_test/app_test.dart on a device and screenshots each step.
#
#   scripts/ci_ui_test.sh android|ios <device-id> <out-dir> [flutter test args…]
#
# `flutter test` passes the device's output on in batches, too late to time a
# screenshot, so the test and this script hand off through files instead: the
# test creates <app temp>/boxpilot-shots/<name> and waits; this script sees it,
# takes the screenshot (native views such as the iOS 26 tab bar included) and
# deletes the file. On Android the same loop grants VPN consent and the
# notification permission as soon as the app is installed.
set -uo pipefail

platform="$1"; device="$2"; out="$3"; shift 3
mkdir -p "$out"
package=io.github.billblueinnit.boxpilot
log="$out/flutter-test.log"

watch_android() {
  local granted=0
  while :; do
    if [ "$granted" = 0 ] && adb -s "$device" shell pm path "$package" < /dev/null 2>/dev/null | grep -q package:; then
      adb -s "$device" shell appops set "$package" ACTIVATE_VPN allow < /dev/null && granted=1
      adb -s "$device" shell pm grant "$package" android.permission.POST_NOTIFICATIONS < /dev/null 2>/dev/null || true
    fi
    for name in $(adb -s "$device" shell run-as "$package" ls cache/boxpilot-shots < /dev/null 2>/dev/null | tr -d '\r'); do
      adb -s "$device" exec-out screencap -p < /dev/null > "$out/$name.png"
      adb -s "$device" shell run-as "$package" rm "cache/boxpilot-shots/$name" < /dev/null
    done
    sleep 0.5
  done
}

watch_ios() {
  while :; do
    data=$(xcrun simctl get_app_container "$device" "$package" data 2>/dev/null)
    if [ -n "$data" ] && [ -d "$data/tmp/boxpilot-shots" ]; then
      for f in "$data/tmp/boxpilot-shots"/*; do
        [ -e "$f" ] || continue
        xcrun simctl io "$device" screenshot "$out/$(basename "$f").png" > /dev/null 2>&1
        rm -f "$f"
      done
    fi
    sleep 0.5
  done
}

if [ "$platform" = android ]; then
  # A slow emulator's "app isn't responding" dialogs would cover screenshots.
  adb -s "$device" shell settings put global hide_error_dialogs 1 < /dev/null || true
  watch_android &
else
  watch_ios &
fi
watcher=$!

flutter test integration_test/app_test.dart -d "$device" "$@" < /dev/null 2>&1 | tee "$log" &
test_job=$!

# A hung app would otherwise run into the job's limit with nothing to show for
# it; stop in time to keep a last screenshot and the device log.
deadline=$((SECONDS + ${UI_TEST_TIMEOUT:-1500}))
while kill -0 "$test_job" 2> /dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "UI test still running after ${UI_TEST_TIMEOUT:-1500}s; stopping it." | tee -a "$log"
    if [ "$platform" = android ]; then
      adb -s "$device" exec-out screencap -p < /dev/null > "$out/zz_timeout.png"
    else
      xcrun simctl io "$device" screenshot "$out/zz_timeout.png" > /dev/null 2>&1
    fi
    pkill -f 'flutter_tools.snapshot test' || true
    break
  fi
  sleep 5
done
wait "$test_job"
status=$?
[ "$SECONDS" -ge "$deadline" ] && status=1

kill "$watcher" 2> /dev/null
if [ "$platform" = android ]; then
  adb -s "$device" logcat -d < /dev/null > "$out/logcat.txt" 2>&1 || true
else
  xcrun simctl spawn "$device" log show --last 40m --style compact --predicate 'process == "Runner"' \
    > "$out/device.log" 2>&1 || true
fi
exit "$status"
