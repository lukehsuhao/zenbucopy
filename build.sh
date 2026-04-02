#!/bin/bash
# Build Paster.app
set -e

SDK=$(xcrun --sdk macosx --show-sdk-path)
APP_DIR="Paster.app/Contents"

mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

echo "🔨 Compiling Paster..."
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  -lsqlite3 \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  -framework UserNotifications \
  -O \
  -o "$APP_DIR/MacOS/Paster" \
  Sources/ClipStash/Models/ClipItem.swift \
  Sources/ClipStash/Core/DatabaseManager.swift \
  Sources/ClipStash/Core/ClipboardMonitor.swift \
  Sources/ClipStash/Core/HotkeyManager.swift \
  Sources/ClipStash/Core/PasteService.swift \
  Sources/ClipStash/Core/SettingsManager.swift \
  Sources/ClipStash/Core/UpdateManager.swift \
  Sources/ClipStash/Views/SearchViewModel.swift \
  Sources/ClipStash/Views/SearchPanelView.swift \
  Sources/ClipStash/Views/SearchPanelController.swift \
  Sources/ClipStash/Views/MenuBarView.swift \
  Sources/ClipStash/Views/SetupWindowController.swift \
  Sources/ClipStash/App/AppDelegate.swift \
  Sources/ClipStash/App/ClipStashApp.swift

# 用 "Paster Dev" 自簽證書簽名（TCC 權限在重新 build 後仍有效）
codesign -f -s "Paster Dev" --identifier "com.luke.paster" Paster.app 2>/dev/null

echo "✅ Built: Paster.app"
echo "   Run: open Paster.app"
echo ""
echo "   部署到 Applications："
echo "   cp -R Paster.app /Applications/Paster.app"
