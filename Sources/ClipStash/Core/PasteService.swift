import AppKit
import Foundation

/// 快速貼上服務
final class PasteService {
    static let shared = PasteService()

    var previousApp: NSRunningApplication?

    private let ignoredBundleIDs: Set<String> = [
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.loginwindow",
    ]

    private init() {}

    func capturePreviousApp() {
        let app = NSWorkspace.shared.frontmostApplication
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        let appBundleID = app?.bundleIdentifier ?? ""
        if appBundleID != myBundleID && !ignoredBundleIDs.contains(appBundleID) {
            previousApp = app
        }
    }

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

    func pasteItem(_ item: ClipItem) {
        writeToClipboard(item)

        guard let targetApp = previousApp else { return }

        SearchPanelController.shared.hide()
        targetApp.activate(options: [.activateIgnoringOtherApps])

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            tryPaste()
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
