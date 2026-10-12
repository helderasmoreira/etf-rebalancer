#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ETF Rebalancer.app"

if [[ ! -f Resources/AppIcon.icns ]]; then
  ICONSET="build/AppIcon.iconset"
  rm -rf "$ICONSET"
  swift scripts/make-icon.swift "$ICONSET"
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
  rm -rf "$ICONSET"
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ETFRebalancer"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ETFRebalancer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/ETF Rebalancer.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/ETF Rebalancer.app"
else
  echo "Built $APP"
fi
