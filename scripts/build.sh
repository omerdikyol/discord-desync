#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SWIFT_SOURCES=("$ROOT_DIR"/Sources/DiscordDesync/*.swift)
APP_NAME="Discord Desync"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
INSTALL_DIR="/Applications"
LOCAL_SIGN_IDENTITY="Discord Desync Local"

usage() {
  print -r -- "Usage: scripts/build.sh [--install]"
}

INSTALL_APP=0
case "${1:-}" in
  "")
    ;;
  --install)
    INSTALL_APP=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

command -v swiftc >/dev/null || {
  print -r -- "swiftc is required. Install Xcode Command Line Tools first." >&2
  exit 1
}

if [[ ! -x "$ROOT_DIR/byedpi/ciadpi" ]]; then
  print -r -- "Building ByeDPI..."
  make -C "$ROOT_DIR/byedpi" CC=clang
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES/byedpi"

swiftc "${SWIFT_SOURCES[@]}" \
  -framework Cocoa \
  -framework WebKit \
  -framework Network \
  -o "$APP_MACOS/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/discord-desync-proxy.sh" "$APP_RESOURCES/discord-desync-proxy.sh"
cp "$ROOT_DIR/byedpi/ciadpi" "$APP_RESOURCES/byedpi/ciadpi"
chmod +x "$APP_MACOS/$APP_NAME" "$APP_RESOURCES/discord-desync-proxy.sh" "$APP_RESOURCES/byedpi/ciadpi"

SIGN_IDENTITY="${DISCORD_DESYNC_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  if security find-identity -v -p codesigning | grep -Fq "$LOCAL_SIGN_IDENTITY"; then
    SIGN_IDENTITY="$LOCAL_SIGN_IDENTITY"
  else
    SIGN_IDENTITY="-"
  fi
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

print -r -- "Built $APP_BUNDLE"
print -r -- "Signed with: $SIGN_IDENTITY"

if [[ "$INSTALL_APP" -eq 1 ]]; then
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
  cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$INSTALL_DIR/$APP_NAME.app" >/dev/null
  print -r -- "Installed $INSTALL_DIR/$APP_NAME.app"
fi
