import Foundation

/// 剪貼簿項目的內容類型
enum ClipContentType: String, Codable {
    case text
    case image
    case url
    case filePath
    case rtf
}

/// 自訂分類
struct ClipCategory: Identifiable {
    var id: Int64?
    var name: String
    var icon: String      // SF Symbol name
    var sortOrder: Int
}

/// 單筆剪貼簿紀錄
struct ClipItem: Identifiable {
    var id: Int64?
    var contentType: ClipContentType
    var textContent: String?
    var imageData: Data?
    var thumbnailData: Data?
    var sourceApp: String?
    var sourceAppName: String?
    var contentHash: String
    var isPinned: Bool
    var categoryId: Int64?     // 釘選後可歸類
    var categoryName: String?  // JOIN 查詢用
    var createdAt: Date

    /// 用於顯示的預覽文字
    var displayText: String {
        switch contentType {
        case .text, .rtf:
            let text = textContent ?? ""
            let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            if cleaned.count > 80 {
                return String(cleaned.prefix(80)) + "…"
            }
            return cleaned
        case .url:
            return textContent ?? "(URL)"
        case .filePath:
            return textContent ?? "(File)"
        case .image:
            return "[圖片]"
        }
    }

    /// 用於顯示的時間文字
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "剛剛" }
        if interval < 3600 { return "\(Int(interval / 60)) 分鐘前" }
        if interval < 86400 { return "\(Int(interval / 3600)) 小時前" }
        if interval < 604800 { return "\(Int(interval / 86400)) 天前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: createdAt)
    }
}
