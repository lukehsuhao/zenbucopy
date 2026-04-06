#!/bin/bash
# ZenbuCopy Release Script
# 編譯 Universal Binary → 簽名 → 公證 → 打包 → 上傳 GitHub Release
set -e

VERSION="${1:?用法: ./release.sh <版本號> (例: ./release.sh 1.3.0)}"
SIGNING_ID="Developer ID Application: Hao Hsu (V6ZDDG5Z68)"
BUNDLE_ID="com.luke.zenbucopy"
NOTARY_PROFILE="ZenbuCopy"
GITHUB_REPO="lukehsuhao/zenbucopy"

APP_DIR="ZenbuCopy.app/Contents"
DMG_NAME="ZenbuCopy-${VERSION}.dmg"
ZIP_NAME="ZenbuCopy-${VERSION}.zip"

echo "========================================="
echo "  ZenbuCopy v${VERSION} Release"
echo "========================================="

# ── 1. 更新版本號 ──
echo ""
echo "📝 Step 1: 更新版本號為 ${VERSION}..."
sed -i '' "s/let currentVersionString = \".*\"/let currentVersionString = \"${VERSION}\"/" Sources/ZenbuCopy/Core/UpdateManager.swift
sed -i '' "s/<string>[0-9]*\.[0-9]*\.[0-9]*<\/string>/<string>${VERSION}<\/string>/g" "${APP_DIR}/../Info.plist" 2>/dev/null || true
# 也更新 app bundle 裡的 Info.plist
if [ -f "${APP_DIR}/Info.plist" ]; then
    sed -i '' "s/<string>[0-9]*\.[0-9]*\.[0-9]*<\/string>/<string>${VERSION}<\/string>/g" "${APP_DIR}/Info.plist"
fi

# ── 2. 編譯 Universal Binary (arm64 + x86_64) ──
echo ""
echo "🔨 Step 2: 編譯 Universal Binary..."
swift build -c release --arch arm64 --arch x86_64

mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/apple/Products/Release/ZenbuCopy "$APP_DIR/MacOS/ZenbuCopy"

# 複製 ShortcutRecorder 資源檔
rm -rf "$APP_DIR/Resources/ShortcutRecorder_ShortcutRecorder.bundle"
cp -R .build/arm64-apple-macosx/release/ShortcutRecorder_ShortcutRecorder.bundle "$APP_DIR/Resources/" 2>/dev/null || true

echo "   架構: $(file "$APP_DIR/MacOS/ZenbuCopy" | sed 's/.*: //')"

# ── 3. 簽名 (Hardened Runtime) ──
echo ""
echo "🔏 Step 3: 簽名 (Developer ID + Hardened Runtime)..."
codesign -f -s "$SIGNING_ID" \
    --identifier "$BUNDLE_ID" \
    --deep \
    --options runtime \
    --timestamp \
    ZenbuCopy.app

codesign -vvv ZenbuCopy.app
echo "   ✅ 簽名驗證通過"

# ── 4. 打包 ZIP 送公證 ──
echo ""
echo "📦 Step 4: 打包並送 Apple 公證..."
rm -f "$ZIP_NAME"
ditto -c -k --keepParent ZenbuCopy.app "$ZIP_NAME"

xcrun notarytool submit "$ZIP_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# ── 5. Staple 公證票 ──
echo ""
echo "📎 Step 5: Staple 公證票到 app..."
xcrun stapler staple ZenbuCopy.app
echo "   ✅ Staple 完成"

# ── 6. 重新打包最終版本 ──
echo ""
echo "📦 Step 6: 打包最終發佈檔..."
rm -f "$ZIP_NAME"
ditto -c -k --keepParent ZenbuCopy.app "$ZIP_NAME"

# 也製作 DMG
rm -f "$DMG_NAME"
hdiutil create -volname "ZenbuCopy" \
    -srcfolder ZenbuCopy.app \
    -ov -format UDZO \
    "$DMG_NAME"
codesign -f -s "$SIGNING_ID" --timestamp "$DMG_NAME"

echo ""
echo "========================================="
echo "  ✅ ZenbuCopy v${VERSION} 發佈準備完成！"
echo "========================================="
echo ""
echo "  檔案："
echo "    - ${ZIP_NAME} ($(du -h "$ZIP_NAME" | awk '{print $1}'))"
echo "    - ${DMG_NAME} ($(du -h "$DMG_NAME" | awk '{print $1}'))"
echo ""
echo "  上傳到 GitHub Release："
echo "    gh release create v${VERSION} ${ZIP_NAME} ${DMG_NAME} \\"
echo "      --title \"ZenbuCopy v${VERSION}\" \\"
echo "      --notes \"Release notes here\""
echo ""
