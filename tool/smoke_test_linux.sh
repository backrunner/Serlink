#!/usr/bin/env bash
# Launch smoke test for a packaged Serlink Linux bundle.
#
# Starts serlink, waits for the window (shown only after Flutter's first
# frame), checks the process stays up, resizes the window from its border,
# verifies a second launch hands off to the running instance, then closes the
# window through the window manager and expects a clean exit. Writes
# screenshots and the app's redacted diagnostic logs to the artifacts dir.
#
# Always run on a private Xvfb display and D-Bus session. A second launch
# must reach the smoke-test instance even on a developer desktop.
#
# Needs: xdotool, wmctrl, xvfb, xauth, openbox and dbus. Uses
# ImageMagick's `import` for screenshots when it is installed.
#
#   tool/smoke_test_linux.sh build/linux/x64/release/bundle/serlink
#   tool/smoke_test_linux.sh path/to/serlink build/smoke
set -euo pipefail

if [[ "${1:-}" != --isolated-session ]]; then
  profile="$(mktemp -d)"
  trap 'rm -rf -- "$profile"' EXIT
  export XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" \
    XDG_CACHE_HOME="$profile/cache" XDG_RUNTIME_DIR="$profile/runtime" GDK_BACKEND=x11
  mkdir -m 700 "$XDG_RUNTIME_DIR"
  unset DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY DESKTOP_STARTUP_ID XDG_ACTIVATION_TOKEN
  xvfb-run -a -s '-screen 0 1600x1000x24 -nolisten tcp' \
    dbus-run-session -- "$0" --isolated-session "$@"
  exit
fi
shift

exe="${1:?usage: smoke_test_linux.sh <serlink executable> [artifacts dir]}"
artifacts="${2:-build/smoke}"
startup_timeout="${SMOKE_STARTUP_TIMEOUT:-60}"
stable_seconds="${SMOKE_STABLE_SECONDS:-15}"

exe="$(realpath "$exe")"
mkdir -p "$artifacts"
artifacts="$(realpath "$artifacts")"
for tool in xdotool wmctrl; do
  command -v "$tool" >/dev/null || { echo "$tool is required." >&2; exit 1; }
done

pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT

openbox >"$artifacts/openbox.log" 2>&1 &
pids+=("$!")
for _ in $(seq 1 50); do
  wmctrl -m >/dev/null 2>&1 && break
  sleep 0.1
done
wmctrl -m >/dev/null || { echo "Openbox failed to start." >&2; exit 1; }

screenshot() {
  if command -v import >/dev/null; then
    import -window root "$artifacts/$1" 2>/dev/null && echo "Screenshot: $artifacts/$1" ||
      echo "Screenshot failed." >&2
  fi
}

save_logs() {
  local logs="$XDG_DATA_HOME/com.alkinum.serlink/Serlink/logs"
  if [[ -d "$logs" ]]; then cp -r "$logs" "$artifacts/logs"; fi
}

fail() {
  echo "::error::$1" >&2
  screenshot serlink-failure.png
  save_logs
  exit 1
}

serlink_windows() {
  xdotool search --onlyvisible --name '^Serlink$' 2>/dev/null || true
}

geometry() {
  # Prints "x y width height" for a window.
  xdotool getwindowgeometry --shell "$1" | awk -F= '
    { fields[$1] = $2 }
    END { print fields["X"], fields["Y"], fields["WIDTH"], fields["HEIGHT"] }'
}

"$exe" >"$artifacts/serlink-stdout.log" 2>&1 &
app=$!
pids+=("$app")

window=""
deadline=$((SECONDS + startup_timeout))
while [[ -z "$window" ]]; do
  kill -0 "$app" 2>/dev/null || { wait "$app" && code=0 || code=$?; fail "Serlink exited during startup with code $code."; }
  ((SECONDS < deadline)) || fail "Serlink showed no window within ${startup_timeout}s."
  window="$(serlink_windows | head -1)"
  [[ -n "$window" ]] || sleep 0.5
done
echo "Window shown: '$(xdotool getwindowname "$window")' ($window)"

sleep "$stable_seconds"
kill -0 "$app" 2>/dev/null || fail 'Serlink exited after startup.'
screenshot serlink-started.png

# The window is undecorated; the runner provides the resize border.
read -r x y width height < <(geometry "$window")
echo "Window geometry: ${width}x${height} at $x,$y"
xdotool mousemove $((x + width - 2)) $((y + height - 2)) mousedown 1
for _ in $(seq 1 8); do xdotool mousemove_relative -- -15 -10; sleep 0.05; done
xdotool mouseup 1
sleep 1
read -r _ _ resized_width resized_height < <(geometry "$window")
echo "Resized from the corner: ${resized_width}x${resized_height}"
if ((resized_width >= width || resized_height >= height)); then
  fail "Border resize had no effect (${width}x${height} -> ${resized_width}x${resized_height})."
fi

# A second launch must activate the running window and exit on its own.
if ! timeout 15 "$exe" >"$artifacts/serlink-second-launch.log" 2>&1; then
  fail 'Second launch did not hand off to the running instance.'
fi
kill -0 "$app" 2>/dev/null || fail 'The first instance exited when a second launch started.'
count="$(serlink_windows | wc -l)"
((count == 1)) || fail "Expected one Serlink window after the second launch, found $count."
echo 'Second launch handed off.'

wmctrl -i -c "$window"
deadline=$((SECONDS + 20))
while kill -0 "$app" 2>/dev/null; do
  ((SECONDS < deadline)) || fail 'Serlink did not exit within 20s of closing its window.'
  sleep 0.5
done
wait "$app" && code=0 || code=$?
((code == 0)) || fail "Serlink exited with code $code after closing its window."
echo 'Serlink closed cleanly.'
save_logs
echo 'Smoke test passed.'
