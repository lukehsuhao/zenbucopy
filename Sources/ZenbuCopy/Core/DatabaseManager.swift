import Foundation
import SQLite3
import CommonCrypto

/// SQLite 資料庫管理（使用原生 SQLite3 C API）
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("ZenbuCopy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("clipstash.sqlite").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            fatalError("Failed to open database")
        }

        exec("PRAGMA journal_mode=WAL")
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    private func createTables() {
        // 分類表
        exec("""
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                icon TEXT NOT NULL DEFAULT 'folder',
                sortOrder INTEGER NOT NULL DEFAULT 0
            )
        """)

        // 剪貼紀錄表
        exec("""
            CREATE TABLE IF NOT EXISTS clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                contentType TEXT NOT NULL,
                textContent TEXT,
                imageData BLOB,
                thumbnailData BLOB,
                sourceApp TEXT,
                sourceAppName TEXT,
                contentHash TEXT NOT NULL,
                isPinned INTEGER NOT NULL DEFAULT 0,
                categoryId INTEGER,
                createdAt REAL NOT NULL,
                FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
            )
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_clips_created ON clips(createdAt DESC)")
        exec("CREATE INDEX IF NOT EXISTS idx_clips_hash ON clips(contentHash)")

        // 新增 categoryId 欄位（如果是舊資料庫）
        exec("ALTER TABLE clips ADD COLUMN categoryId INTEGER REFERENCES categories(id) ON DELETE SET NULL")

        // 預設分類
        let catCount = scalarInt("SELECT COUNT(*) FROM categories")
        if catCount == 0 {
            exec("INSERT INTO categories (name, icon, sortOrder) VALUES ('一般', 'tray', 0)")
            exec("INSERT INTO categories (name, icon, sortOrder) VALUES ('程式碼', 'chevron.left.forwardslash.chevron.right', 1)")
            exec("INSERT INTO categories (name, icon, sortOrder) VALUES ('網址', 'link', 2)")
            exec("INSERT INTO categories (name, icon, sortOrder) VALUES ('帳號密碼', 'key', 3)")
        }
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func scalarInt(_ sql: String) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    // MARK: - Clip Insert

    @discardableResult
    func insert(_ item: ClipItem) -> Bool {
        if let latest = fetchLatestHash(), latest == item.contentHash {
            return false
        }

        let sql = """
            INSERT INTO clips (contentType, textContent, imageData, thumbnailData,
                               sourceApp, sourceAppName, contentHash, isPinned, categoryId, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, item.contentType.rawValue, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, 2, item.textContent)
        bindOptionalBlob(stmt, 3, item.imageData)
        bindOptionalBlob(stmt, 4, item.thumbnailData)
        bindOptionalText(stmt, 5, item.sourceApp)
        bindOptionalText(stmt, 6, item.sourceAppName)
        sqlite3_bind_text(stmt, 7, item.contentHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 8, item.isPinned ? 1 : 0)
        if let catId = item.categoryId {
            sqlite3_bind_int64(stmt, 9, catId)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        sqlite3_bind_double(stmt, 10, item.createdAt.timeIntervalSince1970)

        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func fetchLatestHash() -> String? {
        let sql = "SELECT contentHash FROM clips ORDER BY id DESC LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }
        return nil
    }

    // MARK: - Clip Query

    func recent(limit: Int = 50) -> [ClipItem] {
        let sql = """
            SELECT c.*, cat.name as catName FROM clips c
            LEFT JOIN categories cat ON c.categoryId = cat.id
            ORDER BY c.isPinned DESC, c.id DESC LIMIT ?
        """
        return queryClips(sql: sql, bind: { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
        })
    }

    func search(keyword: String, limit: Int = 50) -> [ClipItem] {
        let sql = """
            SELECT c.*, cat.name as catName FROM clips c
            LEFT JOIN categories cat ON c.categoryId = cat.id
            WHERE c.textContent LIKE ?
            ORDER BY c.id DESC LIMIT ?
        """
        let pattern = "%\(keyword)%"
        return queryClips(sql: sql, bind: { stmt in
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        })
    }

    func pinnedItems(categoryId: Int64? = nil) -> [ClipItem] {
        let sql: String
        if let catId = categoryId {
            sql = """
                SELECT c.*, cat.name as catName FROM clips c
                LEFT JOIN categories cat ON c.categoryId = cat.id
                WHERE c.isPinned = 1 AND c.categoryId = \(catId)
                ORDER BY c.id DESC
            """
        } else {
            sql = """
                SELECT c.*, cat.name as catName FROM clips c
                LEFT JOIN categories cat ON c.categoryId = cat.id
                WHERE c.isPinned = 1
                ORDER BY c.id DESC
            """
        }
        return queryClips(sql: sql, bind: { _ in })
    }

    // MARK: - Clip Update / Delete

    func togglePin(id: Int64) {
        exec("UPDATE clips SET isPinned = CASE WHEN isPinned=1 THEN 0 ELSE 1 END WHERE id = \(id)")
    }

    func setCategory(clipId: Int64, categoryId: Int64?) {
        if let catId = categoryId {
            exec("UPDATE clips SET categoryId = \(catId) WHERE id = \(clipId)")
        } else {
            exec("UPDATE clips SET categoryId = NULL WHERE id = \(clipId)")
        }
    }

    func delete(id: Int64) {
        exec("DELETE FROM clips WHERE id = \(id)")
    }

    func clearUnpinned() {
        exec("DELETE FROM clips WHERE isPinned = 0")
    }

    /// 帶篩選條件的查詢
    func filtered(keyword: String, contentType: ClipContentType?, sourceApp: String?, limit: Int = 100) -> [ClipItem] {
        var conditions: [String] = ["c.isPinned = 0"]
        if !keyword.isEmpty {
            conditions.append("c.textContent LIKE '%\(keyword.replacingOccurrences(of: "'", with: "''"))%'")
        }
        if let ct = contentType {
            conditions.append("c.contentType = '\(ct.rawValue)'")
        }
        if let app = sourceApp {
            conditions.append("c.sourceAppName = '\(app.replacingOccurrences(of: "'", with: "''"))'")
        }
        let whereClause = "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
            SELECT c.*, cat.name as catName FROM clips c
            LEFT JOIN categories cat ON c.categoryId = cat.id
            \(whereClause)
            ORDER BY c.id DESC LIMIT \(limit)
        """
        return queryClips(sql: sql, bind: { _ in })
    }

    /// 取得所有不重複的來源 App 名稱
    func distinctSourceApps() -> [String] {
        let sql = "SELECT DISTINCT sourceAppName FROM clips WHERE sourceAppName IS NOT NULL AND sourceAppName != '' ORDER BY sourceAppName"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var apps: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            apps.append(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return apps
    }

    /// 手動新增一筆文字項目
    @discardableResult
    func insertManual(text: String, contentType: ClipContentType = .text, categoryId: Int64? = nil) -> Bool {
        let hash = text.data(using: .utf8).map { data -> String in
            var h = [UInt8](repeating: 0, count: 32)
            data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &h) }
            return h.map { String(format: "%02x", $0) }.joined()
        } ?? UUID().uuidString
        var item = ClipItem(
            contentType: contentType,
            textContent: text,
            contentHash: hash,
            isPinned: true,
            categoryId: categoryId,
            createdAt: Date()
        )
        item.sourceAppName = "手動新增"
        return insert(item)
    }

    func count() -> Int {
        return scalarInt("SELECT COUNT(*) FROM clips")
    }

    // MARK: - 歷史清理

    /// 刪除超過指定天數的非釘選紀錄
    func purgeOlderThan(days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        exec("DELETE FROM clips WHERE isPinned = 0 AND createdAt < \(cutoff)")
    }

    /// 保留最新 N 筆，刪除多餘的非釘選紀錄
    func purgeExceedingMax(maxCount: Int) {
        guard maxCount > 0 else { return }
        // 取得第 maxCount 筆的 id
        let sql = "SELECT id FROM clips ORDER BY id DESC LIMIT 1 OFFSET \(maxCount)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            let cutoffId = sqlite3_column_int64(stmt, 0)
            exec("DELETE FROM clips WHERE isPinned = 0 AND id <= \(cutoffId)")
        }
    }

    // MARK: - Category CRUD

    func allCategories() -> [ClipCategory] {
        let sql = "SELECT id, name, icon, sortOrder FROM categories ORDER BY sortOrder, id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var cats: [ClipCategory] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            cats.append(ClipCategory(
                id: sqlite3_column_int64(stmt, 0),
                name: String(cString: sqlite3_column_text(stmt, 1)),
                icon: String(cString: sqlite3_column_text(stmt, 2)),
                sortOrder: Int(sqlite3_column_int(stmt, 3))
            ))
        }
        return cats
    }

    @discardableResult
    func addCategory(name: String, icon: String = "folder") -> Int64 {
        let maxOrder = scalarInt("SELECT COALESCE(MAX(sortOrder),0) FROM categories")
        let sql = "INSERT INTO categories (name, icon, sortOrder) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, icon, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(maxOrder + 1))
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func renameCategory(id: Int64, name: String) {
        let sql = "UPDATE categories SET name = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, id)
        sqlite3_step(stmt)
    }

    func deleteCategory(id: Int64) {
        exec("UPDATE clips SET categoryId = NULL WHERE categoryId = \(id)")
        exec("DELETE FROM categories WHERE id = \(id)")
    }

    func pinnedCount(categoryId: Int64) -> Int {
        return scalarInt("SELECT COUNT(*) FROM clips WHERE isPinned = 1 AND categoryId = \(categoryId)")
    }

    // MARK: - Helpers

    private func queryClips(sql: String, bind: (OpaquePointer?) -> Void) -> [ClipItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        bind(stmt)

        var items: [ClipItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            items.append(readRow(stmt))
        }
        return items
    }

    private func readRow(_ stmt: OpaquePointer?) -> ClipItem {
        let id = sqlite3_column_int64(stmt, 0)
        let typeStr = String(cString: sqlite3_column_text(stmt, 1))
        let contentType = ClipContentType(rawValue: typeStr) ?? .text

        var textContent: String?
        if sqlite3_column_type(stmt, 2) != SQLITE_NULL {
            textContent = String(cString: sqlite3_column_text(stmt, 2))
        }

        var imageData: Data?
        if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
            let bytes = sqlite3_column_blob(stmt, 3)
            let count = sqlite3_column_bytes(stmt, 3)
            imageData = Data(bytes: bytes!, count: Int(count))
        }

        var thumbnailData: Data?
        if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
            let bytes = sqlite3_column_blob(stmt, 4)
            let count = sqlite3_column_bytes(stmt, 4)
            thumbnailData = Data(bytes: bytes!, count: Int(count))
        }

        var sourceApp: String?
        if sqlite3_column_type(stmt, 5) != SQLITE_NULL {
            sourceApp = String(cString: sqlite3_column_text(stmt, 5))
        }

        var sourceAppName: String?
        if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
            sourceAppName = String(cString: sqlite3_column_text(stmt, 6))
        }

        let contentHash = String(cString: sqlite3_column_text(stmt, 7))
        let isPinned = sqlite3_column_int(stmt, 8) != 0

        var categoryId: Int64?
        if sqlite3_column_type(stmt, 9) != SQLITE_NULL {
            categoryId = sqlite3_column_int64(stmt, 9)
        }

        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))

        // catName 是 JOIN 欄位，index 11
        var categoryName: String?
        let colCount = sqlite3_column_count(stmt)
        if colCount > 11 && sqlite3_column_type(stmt, 11) != SQLITE_NULL {
            categoryName = String(cString: sqlite3_column_text(stmt, 11))
        }

        return ClipItem(
            id: id,
            contentType: contentType,
            textContent: textContent,
            imageData: imageData,
            thumbnailData: thumbnailData,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            contentHash: contentHash,
            isPinned: isPinned,
            categoryId: categoryId,
            categoryName: categoryName,
            createdAt: createdAt
        )
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalBlob(_ stmt: OpaquePointer?, _ index: Int32, _ value: Data?) {
        if let value = value {
            _ = value.withUnsafeBytes { buf in
                sqlite3_bind_blob(stmt, index, buf.baseAddress, Int32(value.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
}
