#!/bin/bash
# 把 build/WarpCursor.app 打成带安装界面的 DMG，放到 dist/。
#
# DMG 内容：
#   - WarpCursor.app + Applications 快捷方式（符号链接），用户拖拽即可安装
#   - 自定义卷图标（取 App 自带图标），挂载后显示 Logo 而不是通用磁盘图标
#   - Finder 窗口布局：660x400、图标 128、带箭头背景图
#
# 首选 dmgbuild：直接写 .DS_Store 布局数据，不经过 Finder，
# 不受 macOS 自动化（TCC）权限影响，本地与 CI 行为一致。
# dmgbuild 不可用时退回 hdiutil + osascript 方案（布局那步在无权限
# 的环境会失败并退回默认布局，但 DMG 仍可用）。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/WarpCursor.app"
APP_NAME="WarpCursor.app"
VOLNAME="WarpCursor"
DIST="dist"
DMG="$DIST/WarpCursor.dmg"

if [ ! -d "$APP" ]; then
  echo "错误：找不到 $APP，先运行 ./build_app.sh"
  exit 1
fi
echo "App bundle 存在: $APP ($(du -sh "$APP" | cut -f1))"

# 背景图缺失时现生成（CI 不提交二进制资源，与图标同一套路）
BG_SRC="Resources/dmg-background.png"
if [ ! -f "$BG_SRC" ]; then
  echo "背景图缺失，正在生成..."
  python3 -c "import PIL" 2>/dev/null || python3 -m pip install --quiet --break-system-packages pillow
  python3 scripts/generate_dmg_background.py
fi

mkdir -p "$DIST"
rm -f "$DMG"

# ---------- 首选：dmgbuild ----------
ensure_dmgbuild() {
  python3 -c "import dmgbuild" 2>/dev/null && return 0
  python3 -m pip install --quiet --break-system-packages dmgbuild 2>/dev/null && return 0
  python3 -m pip install --quiet dmgbuild 2>/dev/null && return 0
  return 1
}

if ensure_dmgbuild; then
  echo "正在用 dmgbuild 打包（布局不经过 Finder，无需自动化权限）..."
  if python3 -m dmgbuild "$VOLNAME" "$DMG" \
      -s scripts/dmg_settings.py \
      -D "app=$APP" \
      -D "background=$BG_SRC" \
      -D "icon=$APP/Contents/Resources/AppIcon.icns"; then
    echo "wrote $DMG ($(du -h "$DMG" | cut -f1))"
    exit 0
  fi
  echo "警告：dmgbuild 打包失败，退回 hdiutil 方案..."
  rm -f "$DMG"
else
  echo "警告：dmgbuild 不可用，退回 hdiutil 方案..."
fi

# ---------- 备选：hdiutil + osascript ----------
WORK="$(mktemp -d)"
STAGE="$WORK/stage"
TMPDMG="$WORK/tmp.dmg"
MOUNT="$WORK/mount"
mkdir -p "$STAGE/.background" "$MOUNT"

cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "正在组装 DMG 内容..."
cp -R "$APP" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"
cp "$BG_SRC" "$STAGE/.background/background.png"
# 卷图标：用 App 自带图标，挂载后 Finder/Launchpad 显示 Logo
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

echo "正在创建可写镜像..."
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDRW "$TMPDMG" >/dev/null

echo "正在挂载并设置卷图标/窗口布局..."
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT" "$TMPDMG" >/dev/null

# 给卷根目录打上“自定义图标”标记，Finder 才会使用 .VolumeIcon.icns
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT" || echo "警告：SetFile 设置卷图标失败，挂载后将显示通用磁盘图标"
else
  echo "警告：找不到 SetFile（Xcode 命令行工具），卷图标可能不生效"
fi

# Finder 窗口布局（最佳努力：失败只警告，不中断构建）
if ! DMG_VOLNAME="$VOLNAME" osascript >/dev/null 2>&1 <<'APPLESCRIPT'
set volName to system attribute "DMG_VOLNAME"
tell application "Finder"
  tell disk volName
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set sidebar width of container window to 0
    set bounds of container window to {120, 120, 780, 548}
    set opts to icon view options of container window
    set icon size of opts to 128
    set text size of opts to 13
    set arrangement of opts to not arranged
    set background picture of opts to file ".background:background.png"
    set position of item "WarpCursor.app" of container window to {185, 175}
    set position of item "Applications" of container window to {475, 175}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
then
  echo "警告：Finder 布局设置失败（无 GUI 或自动化权限未授予），DMG 将使用默认布局"
fi

sync
hdiutil detach "$MOUNT" >/dev/null || { sleep 2; hdiutil detach -force "$MOUNT" >/dev/null; }

echo "正在压缩为最终 DMG..."
hdiutil convert "$TMPDMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

trap - EXIT
rm -rf "$WORK"
echo "wrote $DMG ($(du -h "$DMG" | cut -f1))"
