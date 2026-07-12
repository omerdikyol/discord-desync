#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SWIFT_SOURCES=("$ROOT_DIR"/Sources/DiscordDesync/*.swift)
APP_BUNDLE="$ROOT_DIR/build/Discord Desync.app"
PROXY_SCRIPT="$APP_BUNDLE/Contents/Resources/discord-desync-proxy.sh"

zsh -n "$ROOT_DIR/Resources/discord-desync-proxy.sh"
plutil -lint "$ROOT_DIR/Resources/Info.plist" >/dev/null
swiftc "${SWIFT_SOURCES[@]}" \
  -framework Cocoa \
  -framework WebKit \
  -framework Network \
  -o /tmp/discord-desync-compile-check
rm -f /tmp/discord-desync-compile-check

"$ROOT_DIR/scripts/build.sh"
plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

"$PROXY_SCRIPT" proxy-start
"$PROXY_SCRIPT" status
"$PROXY_SCRIPT" stop-check

print -r -- "All checks passed."
