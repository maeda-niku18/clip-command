#!/bin/bash
#
# release.sh — clip-command の配布物（公証済み DMG + appcast）を作る
#
# 前提（初回のみ・あなたの作業）:
#   1) Developer ID Application 証明書を作成済み（Xcode > Settings > Accounts）
#   2) 公証用の認証情報を Keychain に保存済み:
#        xcrun notarytool store-credentials "WindowFinderNotary" \
#          --apple-id "<Apple ID>" --team-id "<TEAM_ID>" --password "<App用パスワード>"
#   3) Sparkle の EdDSA 秘密鍵が Keychain にある（generate_keys 実行済み）
#
# 使い方:
#   ./release.sh 1.0.0
#
set -euo pipefail

# ===== 設定（要編集） =====================================================
APP_NAME="clip-command"
SCHEME="clip-command"
# `security find-identity -v -p codesigning` の表示名:
DEV_ID_APP="Developer ID Application: SATOSHI MAEDA (Z89YBVR7QV)"
TEAM_ID="Z89YBVR7QV"
NOTARY_PROFILE="WindowFinderNotary"                       # store-credentials の名前（同一 Apple ID/チームのため流用）
GITHUB_REPO="maeda-niku18/clip-command"
# =========================================================================

VERSION="${1:?バージョンを指定してください 例: ./release.sh 1.0.0}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "▶︎ 1/7 プロジェクト生成"
xcodegen generate

echo "▶︎ 2/7 Developer ID で署名ビルド"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$DEV_ID_APP" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build

echo "▶︎ 2.5/7 Sparkle 内部バイナリを Developer ID で再署名（内側→外側）"
# Xcode は framework 内部の入れ子ヘルパーを Developer ID で再署名しないことがあり、
# その場合公証が Invalid になる。XPC → Updater.app → Autoupdate → framework → app の順に明示署名する。
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
# 入れ子を署名し直したので外側アプリも再署名（封印を貼り直す）。
codesign "${SIGN_OPTS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=1 "$APP_PATH"

mkdir -p "$DIST_DIR"

echo "▶︎ 3/7 DMG 作成"
rm -f "$DMG_PATH"
TMP_DMG_DIR="$(mktemp -d)"
cp -R "$APP_PATH" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TMP_DMG_DIR"

echo "▶︎ 4/7 DMG を署名"
codesign --force --sign "$DEV_ID_APP" --timestamp "$DMG_PATH"

echo "▶︎ 5/7 公証（数分かかります）"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler staple "$APP_PATH"

echo "▶︎ 6/7 appcast 生成（EdDSA 署名込み）"
GEN_APPCAST="$(find "$BUILD_DIR/SourcePackages/artifacts" -name generate_appcast -type f | head -1)"
# 小さなアプリでは差分(delta)更新は不要なため生成しない（フル DMG のみで更新）。
rm -f "$DIST_DIR"/*.delta
"$GEN_APPCAST" \
  --maximum-deltas 0 \
  --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
  "$DIST_DIR"
cp "$DIST_DIR/appcast.xml" "$ROOT/appcast.xml"

echo "▶︎ 7/7 GitHub Release へアップロード（DMG のみ）"
gh release create "v$VERSION" "$DMG_PATH" \
  --repo "$GITHUB_REPO" --title "v$VERSION" --notes "clip-command v$VERSION" || \
gh release upload "v$VERSION" "$DMG_PATH" --repo "$GITHUB_REPO" --clobber
# appcast.xml は main にコミット/プッシュ（SUFeedURL が raw main を指すため）
git -C "$ROOT" add appcast.xml && git -C "$ROOT" commit -m "Update appcast for v$VERSION" && git -C "$ROOT" push

echo "✅ 完了: $DMG_PATH を配布、appcast.xml を更新しました"
