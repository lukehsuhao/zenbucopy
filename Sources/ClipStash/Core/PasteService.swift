import AppKit
import Foundation

/// 快速貼上服務
final class PasteService {
    static let shared = PasteService()

    /// 開啟搜尋面板前的前景 App（在 hotkey 觸發時記下來）
    var previousApp: NSRunningApplication?

    /// 排除的 bundle ID（系統 UI、自己）
    private let ignoredBundleIDs: Set<String> = [
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.loginwindow",
    ]

    private init() {}

    /// 記住前景 App（排除系統 UI 和自己）
    func capturePreviousApp() {
        let app = NSWorkspace.shared.frontmostApplication
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        let appBundleID = app?.bundleIdentifier ?? ""

        if appBundleID != myBundleID && !ignoredBundleIDs.contains(appBundleID) {
            previousApp = app
        }
    }

    /// 將 ClipItem 寫入系統剪貼簿
    func writeToClipboard(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text, .rtf:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .url:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
                pasteboard.setString(text, forType: .URL)
            }
        case .filePath:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .png)
            }
        }
    }

    /// 一鍵完成：寫入剪貼簿 → 切回前一個 App → 模擬 Cmd+V
    func pasteItem(_ item: ClipItem) {
        writeToClipboard(item)

        guard let targetApp = previousApp else { return }

        // 1. 隱藏 Paster 視窗
        SearchPanelController.shared.hide()

        // 2. 切回前一個 App
        targetApp.activate(options: [.activateIgnoringOtherApps])

        // 3. 等目標 App 到前景後模擬 Cmd+V
        let targetPID = targetApp.processIdentifier
        let startTime = Date()

        func tryPaste() {
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            let elapsed = Date().timeIntervalSince(startTime)

            if frontPID == targetPID || elapsed > 0.5 {
                let source = CGEventSource(stateID: .combinedSessionState)

                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                keyDown?.flags = .maskCommand
                keyDown?.post(tap: .cghidEventTap)

                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                keyUp?.flags = .maskCommand
                keyUp?.post(tap: .cghidEventTap)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    tryPaste()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tryPaste()
        }
    }

    /// 手動請求輔助使用權限（從設定頁呼叫）
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
