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

    private func debugLog(_ msg: String) {
        let line = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(msg)\n"
        let path = NSHomeDirectory() + "/paster-debug.log"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
        }
    }

    func pasteItem(_ item: ClipItem) {
        writeToClipboard(item)

        let axTrusted = AXIsProcessTrusted()
        debugLog("AXIsProcessTrusted: \(axTrusted)")
        debugLog("previousApp: \(previousApp?.localizedName ?? "nil") (pid: \(previousApp?.processIdentifier ?? -1))")

        guard let targetApp = previousApp else {
            debugLog("ABORT: previousApp is nil")
            return
        }

        SearchPanelController.shared.hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            targetApp.activate(options: [.activateIgnoringOtherApps])

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let frontApp = NSWorkspace.shared.frontmostApplication
                self.debugLog("After activate, front app: \(frontApp?.localizedName ?? "nil")")
                self.simulatePaste()
            }
        }
    }

    private func simulatePaste() {
        let axTrusted = AXIsProcessTrusted()
        debugLog("simulatePaste called, AXTrusted: \(axTrusted)")

        let clipContent = NSPasteboard.general.string(forType: .string) ?? "(nil)"
        debugLog("Clipboard content: \(String(clipContent.prefix(50)))")

        if !axTrusted {
            debugLog("ABORT: no accessibility permission")
            return
        }

        // CGEvent — nil source, .cghidEventTap, 在背景線程執行
        DispatchQueue.global(qos: .userInteractive).async {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand

            self.debugLog("Posting CGEvent keyDown (flags: \(keyDown?.flags.rawValue ?? 0))")
            keyDown?.post(tap: .cghidEventTap)
            usleep(100_000) // 0.1s
            keyUp?.post(tap: .cghidEventTap)
            self.debugLog("CGEvent keyUp posted")
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
