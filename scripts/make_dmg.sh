#!/bin/bash
# 把 build/WarpCursor.app 打成 DMG，放到 dist/。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/WarpCursor.app"
DIST="dist"
DMG="$DIST/WarpCursor.dmg"

if [ ! -d "$APP" ]; then
  echo "错误：找不到 $APP，先运行 ./build_app.sh"
  exit 1
fi
echo "App bundle 存在: $APP ($(du -sh "$APP" | cut -f1))"

mkdir -p "$DIST"
rm -f "$DMG"

echo "正在创建 DMG（hdiutil）..."
if hdiutil create -volname "WarpCursor" -srcfolder "$APP" -ov -format UDZO "$DMG"; then
  echo "wrote $DMG ($(du -h "$DMG" | cut -f1))"
else
  echo "hdiutil 失败（退出码 $?），请查看上方 hdiutil 的具体报错"
  exit 1
fi
