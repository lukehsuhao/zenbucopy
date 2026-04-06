import AppKit
import Foundation
import CommonCrypto

/// 剪貼簿監聽引擎 — 每 0.5 秒檢查 NSPasteboard 變化
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published var lastClipItem: ClipItem?
    @Published var isPaused: Bool = false

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private let db = DatabaseManager.shared

    /// 排除的 App bundle IDs（密碼管理器等）
    private let excludedApps: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-ios",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
    ]

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        isPaused.toggle()
    }

    private func checkClipboard() {
        guard !isPaused else { return }
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // 檢查是否為「隱藏」類型（密碼欄位）
        if pasteboard.types?.contains(NSPasteboard.PasteboardType(rawValue: "org.nspasteboard.ConcealedType")) == true {
            return
        }

        // 檢查來源 App
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""
        if excludedApps.contains(bundleID) { return }

        let appName = frontApp?.localizedName ?? ""

        // 嘗試讀取各種類型
        if let item = readClipboard(sourceApp: bundleID, sourceAppName: appName) {
            db.insert(item)
            DispatchQueue.main.async {
                self.lastClipItem = item
            }
        }
    }

    private func readClipboard(sourceApp: String, sourceAppName: String) -> ClipItem? {
        let now = Date()

        // 1. 嘗試讀取圖片
        if let imgData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let hash = sha256(imgData)
            let thumbnail = createThumbnail(from: imgData, maxSize: 256)
            return ClipItem(
                contentType: .image,
                imageData: compressImage(imgData),
                thumbnailData: thumbnail,
                sourceApp: sourceApp,
                sourceAppName: sourceAppName,
                contentHash: hash,
                isPinned: false,
                createdAt: now
            )
        }

        // 2. 嘗試讀取 URL
        if let urlString = pasteboard.string(forType: .URL), !urlString.isEmpty {
            return ClipItem(
                contentType: .url,
                textContent: urlString,
                sourceApp: sourceApp,
                sourceAppName: sourceAppName,
                contentHash: sha256(urlString.data(using: .utf8) ?? Data()),
                isPinned: false,
                createdAt: now
            )
        }

        // 3. 嘗試讀取檔案路徑
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let fileURL = urls.first, fileURL.isFileURL {
            let path = fileURL.path
            return ClipItem(
                contentType: .filePath,
                textContent: path,
                sourceApp: sourceApp,
                sourceAppName: sourceAppName,
                contentHash: sha256(path.data(using: .utf8) ?? Data()),
                isPinned: false,
                createdAt: now
            )
        }

        // 4. 嘗試讀取純文字
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipItem(
                contentType: .text,
                textContent: text,
                sourceApp: sourceApp,
                sourceAppName: sourceAppName,
                contentHash: sha256(text.data(using: .utf8) ?? Data()),
                isPinned: false,
                createdAt: now
            )
        }

        return nil
    }

    // MARK: - Helpers

    private func sha256(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_SHA256(buf.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func compressImage(_ data: Data) -> Data {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return data
        }
        return jpeg
    }

    private func createThumbnail(from data: Data, maxSize: CGFloat) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumb.unlockFocus()

        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }
}
