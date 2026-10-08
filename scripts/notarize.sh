#!/bin/bash
# 用 Developer ID 签名 + 公证，产出可直接分发的 DMG（无 Gatekeeper 拦截）。
# 需要 Apple Developer Program，并设置以下环境变量：
#   APPLE_TEAM_ID        10 位 Team ID
#   SIGNING_IDENTITY     如 "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_APPLE_ID      Apple ID 邮箱
#   NOTARY_APP_PASSWORD  app 专用密码（appleid.apple.com 生成）
#   NOTARY_TEAM_ID       同 APPLE_TEAM_ID
# 用法（本地或 CI）：先 ./build_app.sh，再 ./scripts/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/WarpCursor.app"
for v in APPLE_TEAM_ID SIGNING_IDENTITY NOTARY_APPLE_ID NOTARY_APP_PASSWORD NOTARY_TEAM_ID; do
  [ -n "${!v:-}" ] || { echo "缺少环境变量 $v"; exit 1; }
done

echo "==> Developer ID 签名..."
codesign --force --deep --options runtime --timestamp \
  --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --verbose "$APP"

./scripts/make_dmg.sh
DMG="dist/WarpCursor.dmg"

echo "==> 提交公证..."
xcrun notarytool submit "$DMG" \
  --apple-id "$NOTARY_APPLE_ID" \
  --password "$NOTARY_APP_PASSWORD" \
  --team-id "$NOTARY_TEAM_ID" \
  --wait

echo "==> 装订公证票..."
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG" || true
echo "完成: $DMG"
