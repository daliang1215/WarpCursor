#!/bin/bash
# 构建 WarpCursor.app。
# 只需要 Xcode Command Line Tools（xcode-select --install），不需要完整 Xcode。
#
#   ./build_app.sh              # 纯 arm64（Apple Silicon 原生）
#   UNIVERSAL=1 ./build_app.sh  # arm64 + x86_64 双架构
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="WarpCursor"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
UNIVERSAL="${UNIVERSAL:-0}"

export MACOSX_DEPLOYMENT_TARGET=14.0

ARCH_FLAGS=(--arch arm64)
if [ "$UNIVERSAL" = "1" ]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> swift build（release）..."
swift build -c release "${ARCH_FLAGS[@]}"
# 注意：--show-bin-path 只打印路径、不会触发构建，所以上面必须先单独构建一次
BIN_PATH="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"
BIN="$BIN_PATH/$APP_NAME"
if [ ! -x "$BIN" ]; then
  echo "构建失败：找不到 $BIN"
  exit 1
fi
echo "    二进制: $BIN"
file "$BIN" | sed 's/^/    /'

echo "==> 组装 $APP_BUNDLE ..."
# 图标缺失时自动生成（CI 环境不提交二进制图标）
if [ ! -f "Resources/AppIcon.icns" ] || [ ! -f "Resources/MenuBarIcon.png" ]; then
  echo "    图标缺失，正在生成..."
  python3 -c "import PIL" 2>/dev/null || python3 -m pip install --quiet pillow
  python3 scripts/generate_icon.py
fi
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "Resources/MenuBarIcon.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png"

echo "==> ad-hoc 签名..."
if /usr/bin/codesign --force --sign - "$APP_BUNDLE"; then
  echo "    签名完成"
else
  echo "    警告：签名失败，应用仍可运行（首次打开可能需要右键 > 打开）"
fi

echo ""
echo "==> 完成: $APP_BUNDLE"
echo ""
echo "安装运行："
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
echo "  open /Applications/$APP_NAME.app"
