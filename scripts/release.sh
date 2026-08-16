#!/usr/bin/env bash
#
# scripts/release.sh — ローカル実行専用。Developer ID署名 + notarize（公証）+
# dmg化までを行う（docs/implementation-plan.md Phase 6の方針：署名鍵はCIに
# 置かず、リリースビルドはローカル開発機で実施する）。
#
# GitHub Releaseへの添付は別ステップ（このスクリプトはdmgを作るところまで。
# `gh release create` は生成物を確認してから手動で実行する）。
#
# 事前準備: 会社共通のキーチェーンプロファイル "bitz-app-notarization" を
# 使う（Apple IDのアプリ用パスワードはApple ID単位であってアプリ単位では
# ないため、他の自社アプリ（SeqGrab/EisuKana）と共用できる。詳細は
# ~/Development/Projects/bitzcojp/SeqGrab/docs/release-process.md 参照）。
# 万一未設定の環境で実行する場合は、事前に以下を一度だけ実行しておく:
#
#   xcrun notarytool store-credentials "bitz-app-notarization" \
#     --apple-id "<Apple ID>" --team-id XKY95WKF3J --password "<アプリ用パスワード>"
#
# パスワード/APIキーはこのスクリプトやリポジトリには一切含まれない
# （macOSのキーチェーンにプロファイル名で保存されるのみ。publicリポジトリ
# のため、秘密鍵・証明書ファイル・アクセスキー等は一切コミットしない）。
#
# 使い方:
#   scripts/release.sh 0.1.0

set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 0.1.0>}"

TEAM_ID="XKY95WKF3J"
SIGN_IDENTITY="Developer ID Application: Bitz Co., Ltd. ($TEAM_ID)"
NOTARY_PROFILE="bitz-app-notarization"
APP_NAME="radioORCA"
SCHEME="radioORCA"
PROJECT="radioORCA.xcodeproj"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Checking signing identity"
if ! security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
  echo "error: signing identity not found in keychain: $SIGN_IDENTITY" >&2
  exit 1
fi

echo "==> Checking notarytool credentials (profile: $NOTARY_PROFILE)"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "error: notarytool credentials not found for profile '$NOTARY_PROFILE'." >&2
  echo "       Run 'xcrun notarytool store-credentials $NOTARY_PROFILE ...' first (see this script's header)." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> xcodegen generate"
xcodegen generate

echo "==> Archiving (Release configuration, Developer ID signing)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID"

cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$SIGN_IDENTITY</string>
</dict>
</plist>
PLIST

echo "==> Exporting signed .app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST"

APP_PATH="$EXPORT_PATH/$APP_NAME.app"

echo "==> Verifying code signature"
codesign -dvvv --strict "$APP_PATH"

echo "==> Building dmg"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"

echo "==> Signing dmg"
codesign --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "==> Submitting for notarization (this can take a few minutes)"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo
echo "==> Done: $DMG_PATH"
echo "    Next step (manual, not run by this script):"
echo "      gh release create v$VERSION \"$DMG_PATH\" --title \"radioORCA v$VERSION\" --notes \"...\""
