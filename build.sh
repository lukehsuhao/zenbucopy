#!/bin/bash
# Build Paster.app
set -e

SDK=$(xcrun --sdk macosx --show-sdk-path)
APP_DIR="Paster.app/Contents"

mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

echo "🔨 Compiling..."
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  -lsqlite3 \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  -O \
  -o "$APP_DIR/MacOS/Paster" \
  Sources/ClipStash/Models/ClipItem.swift \
  Sources/ClipStash/Core/DatabaseManager.swift \
  Sources/ClipStash/Core/ClipboardMonitor.swift \
  Sources/ClipStash/Core/HotkeyManager.swift \
  Sources/ClipStash/Core/PasteService.swift \
  Sources/ClipStash/Core/SettingsManager.swift \
  Sources/ClipStash/Views/SearchViewModel.swift \
  Sources/ClipStash/Views/SearchPanelView.swift \
  Sources/ClipStash/Views/SearchPanelController.swift \
  Sources/ClipStash/Views/MenuBarView.swift \
  Sources/ClipStash/App/AppDelegate.swift \
  Sources/ClipStash/App/ClipStashApp.swift

# 簽名（固定 identifier，讓輔助使用權限在重新 build 後仍有效）
codesign -f -s - --identifier "com.luke.paster" Paster.app 2>/dev/null

echo "✅ Built: Paster.app"
echo "   Run: open Paster.app"
