#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-Diptych}"
IOS_EXPORT_PRESET="${IOS_EXPORT_PRESET:-iOS}"
BUNDLE_ID="${BUNDLE_ID:-com.diptych.app}"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
DEVICE_ID="${DEVICE_ID:-${1:-}}"
CLEAN_BUILD="${CLEAN_BUILD:-1}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

auto_detect_device() {
  xcrun xctrace list devices 2>/dev/null \
    | grep -vE 'Simulator|unavailable|MacBook|iMac|Mac mini|Mac Pro|Apple TV|Watch' \
    | sed -nE 's/.*\(([0-9A-Fa-f-]{24,})\).*/\1/p' \
    | head -n1
}

need_cmd scons
need_cmd xcrun
[[ -x "$GODOT_BIN" ]] || fail "Godot binary not found or not executable: $GODOT_BIN"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(auto_detect_device)"
fi

[[ -n "$DEVICE_ID" ]] || fail "No connected iPhone/iPad detected. Connect a device or pass DEVICE_ID=<udid>."

log "Using device: $DEVICE_ID"

if [[ "$CLEAN_BUILD" == "1" ]]; then
  log "Cleaning bin/ and build/"
  rm -rf "$ROOT_DIR/bin" "$ROOT_DIR/build"
fi

mkdir -p "$ROOT_DIR/bin" "$ROOT_DIR/build/ios"

log "Building iOS extension (arm64 template_debug)"
(
  cd "$ROOT_DIR/extension"
  scons platform=ios arch=arm64 target=template_debug
)

log "Building macOS editor extension (required for Godot export)"
(
  cd "$ROOT_DIR/extension"
  scons platform=macos arch=arm64 target=editor
)

log "Exporting iOS project + archive + IPA via Godot"
(
  cd "$ROOT_DIR"
  "$GODOT_BIN" --headless --export-debug "$IOS_EXPORT_PRESET" "build/ios/${PROJECT_NAME}.xcodeproj"
)

APP_PATH="$ROOT_DIR/build/ios/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"
[[ -d "$APP_PATH" ]] || fail "Built .app not found at: $APP_PATH"

if command -v ios-deploy >/dev/null 2>&1; then
  log "Installing with ios-deploy"
  ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH" --justlaunch
else
  log "Installing with devicectl"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

  log "Launching app (${BUNDLE_ID}) with devicectl"
  xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
fi

log "Done"
log "Artifacts: $ROOT_DIR/build/ios/${PROJECT_NAME}.xcodeproj, $ROOT_DIR/build/ios/${PROJECT_NAME}.xcarchive, $ROOT_DIR/build/ios/${PROJECT_NAME}.ipa"
