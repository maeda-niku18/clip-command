#!/bin/bash
#
# build.sh — 配布と同じ Developer ID 署名で .app をビルドするだけ（公証/DMG/リリースはしない）
#
# Debug ビルドは get-task-allow が付くため、再ビルドのたびに macOS が別アプリとみなし
# アクセシビリティ許可を再要求する。配布版と同一の Developer ID + Hardened Runtime で
# Release ビルドすれば署名要件が安定し、一度許可すれば以降のビルドで再要求されない。
#
# 使い方:
#   ./build.sh          # ビルドのみ
#   ./build.sh --run    # ビルドして起動
#
set -euo pipefail

APP_NAME="clip-command"
SCHEME="clip-command"
# 配布と同じ署名（release.sh と一致させる）:
DEV_ID_APP="Developer ID Application: SATOSHI MAEDA (Z89YBVR7QV)"
TEAM_ID="Z89YBVR7QV"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

echo "▶︎ プロジェクト生成"
xcodegen generate

echo "▶︎ Developer ID で署名ビルド（Release / get-task-allow なし）"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$DEV_ID_APP" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build

echo "▶︎ Sparkle 内部バイナリを Developer ID で再署名（内側→外側）"
SIGN_OPTS=(--force --options runtime --timestamp --sign "$DEV_ID_APP")
SPARKLE="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
  SPV="$SPARKLE/Versions/B"
  for item in \
    "$SPV/XPCServices/Installer.xpc" \
    "$SPV/XPCServices/Downloader.xpc" \
    "$SPV/Updater.app" \
    "$SPV/Autoupdate"; do
    [ -e "$item" ] && codesign "${SIGN_OPTS[@]}" "$item"
  done
  codesign "${SIGN_OPTS[@]}" "$SPARKLE"
fi
codesign "${SIGN_OPTS[@]}" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "✅ ビルド完了: $APP_PATH"

if [ "${1:-}" = "--run" ]; then
  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  open "$APP_PATH"
  echo "▶︎ 起動しました"
fi
