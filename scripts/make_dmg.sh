#!/bin/bash
# 把 build/WarpCursor.app 打成 DMG，放到 dist/。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/WarpCursor.app"
DIST="dist"
DMG="$DIST/WarpCursor.dmg"

[ -d "$APP" ] || { echo "先运行 ./build_app.sh"; exit 1; }
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create -volname "WarpCursor" -srcfolder "$APP" -ov -format UDZO "$DMG"
echo "wrote $DMG"
