#!/usr/bin/env bash
# Runs the Maestro tours against an installed build and collects screenshots.
#
#   scripts/ci_ui_test.sh android <apk> <out-dir>
#   scripts/ci_ui_test.sh ios <simulator-udid> <out-dir>
#
# A subscription for the tour is served from this machine: the node in
# BOXPILOT_TEST_NODE (an ss:// link to a server on the runner; Android), or a
# placeholder. The emulator reaches the runner at 10.0.2.2, the simulator at
# 127.0.0.1.
set -uo pipefail

platform="$1"; target="$2"; out="$3"
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
package=io.github.billblueinnit.boxpilot
export PATH="$HOME/.maestro/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1 MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

node="${BOXPILOT_TEST_NODE:-ss://MjAyMi1ibGFrZTMtYWVzLTEyOC1nY206YWFhYWFhYWFhYWFhYWFhYWFhYWFhQT09@203.0.113.7:8388#CI%20Node%20US}"
serve="$(mktemp -d)"
printf '%s\n%s\n' "$node" "${node/\#/#2-}" > "$serve/sub.txt"
(cd "$serve" && exec python3 -m http.server 18000 --bind 0.0.0.0) > "$out/http.log" 2>&1 &
server=$!
trap 'kill "$server" 2> /dev/null' EXIT

if [ "$platform" = android ]; then
  host=10.0.2.2
  adb install -r "$target" < /dev/null
  # VPN consent and the notification permission: what the user would grant on Connect.
  adb shell appops set "$package" ACTIVATE_VPN allow < /dev/null
  adb shell pm grant "$package" android.permission.POST_NOTIFICATIONS < /dev/null || true
  # A slow emulator's "app isn't responding" dialogs would cover screenshots.
  adb shell settings put global hide_error_dialogs 1 < /dev/null || true
else
  host=127.0.0.1
fi
link="boxpilot://install-config?url=http%3A%2F%2F$host%3A18000%2Fsub.txt&name=CI%20Test"

cd "$out"
status=0
maestro test -e IMPORT_LINK="$link" "$root/.maestro/tour.yaml" < /dev/null 2>&1 | tee "$out/maestro-tour.log"
[ "${PIPESTATUS[0]}" = 0 ] || status=1
if [ "$platform" = android ] && [ -n "${BOXPILOT_TEST_NODE:-}" ] && [ "$status" = 0 ]; then
  maestro test "$root/.maestro/connect.yaml" < /dev/null 2>&1 | tee "$out/maestro-connect.log"
  [ "${PIPESTATUS[0]}" = 0 ] || status=1
fi

if [ "$platform" = android ]; then
  adb logcat -d < /dev/null > "$out/logcat.txt" 2>&1 || true
else
  xcrun simctl spawn "$target" log show --last 30m --style compact --predicate 'process == "BoxPilot"' \
    > "$out/device.log" 2>&1 || true
fi
# Maestro's own record of a failure (screenshot and view hierarchy).
cp -r "$HOME/.maestro/tests" "$out/maestro-debug" 2> /dev/null || true
exit "$status"
