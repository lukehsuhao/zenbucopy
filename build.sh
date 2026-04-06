#!/bin/bash
# Build ZenbuCopy.app
set -e

APP_DIR="ZenbuCopy.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

echo "🔨 Compiling ZenbuCopy..."
swift build -c release

# 複製編譯產物到 .app bundle
cp .build/release/ZenbuCopy "$APP_DIR/MacOS/ZenbuCopy"

# 複製 ShortcutRecorder 資源檔
rm -rf "$APP_DIR/Resources/ShortcutRecorder_ShortcutRecorder.bundle"
cp -R .build/arm64-apple-macosx/release/ShortcutRecorder_ShortcutRecorder.bundle "$APP_DIR/Resources/"

# 簽名
codesign -f -s "Developer ID Application: Hao Hsu (V6ZDDG5Z68)" --identifier "com.zenbu.copy" ZenbuCopy.app

echo "✅ Built: ZenbuCopy.app"
echo "   Run: open ZenbuCopy.app"
echo ""
echo "   部署到 Applications："
echo "   cp -R ZenbuCopy.app /Applications/ZenbuCopy.app"
