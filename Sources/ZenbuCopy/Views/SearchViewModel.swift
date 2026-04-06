import Foundation
import AppKit

enum PanelTab {
    case history
    case pinned
    case settings
}

/// 搜尋視窗的 ViewModel
final class SearchViewModel: ObservableObject {
    // 分頁
    @Published var currentTab: PanelTab = .history

    // 歷史分頁
    @Published var items: [ClipItem] = []
    @Published var searchText: String = "" {
        didSet { performSearch() }
    }
    @Published var selectedIndex: Int = 0
    @Published var selectedItem: ClipItem? = nil
    @Published var totalCount: Int = 0

    /// 鍵盤導航時為 true，滑鼠點擊不觸發捲動
    @Published var scrollToSelection: Bool = false

    /// Grid 欄數（由 View 回報）
    var gridColumns: Int = 2

    // 篩選
    @Published var filterContentType: ClipContentType? = nil {
        didSet { performSearch() }
    }
    @Published var filterSourceApp: String? = nil {
        didSet { performSearch() }
    }
    @Published var sourceApps: [String] = []

    // 釘選分頁
    @Published var pinnedItems: [ClipItem] = []
    @Published var filteredPinnedItems: [ClipItem] = []
    @Published var pinnedSelectedIndex: Int = 0
    @Published var categories: [ClipCategory] = []
    @Published var selectedCategoryId: Int64? = nil {
        didSet { refreshPinned() }
    }

    // 設定
    @Published var launchAtLogin: Bool = SettingsManager.shared.launchAtLogin {
        didSet { SettingsManager.shared.launchAtLogin = launchAtLogin }
    }
    @Published var retentionDays: Int = SettingsManager.shared.retentionDays {
        didSet { SettingsManager.shared.retentionDays = retentionDays }
    }
    @Published var maxItems: Int = SettingsManager.shared.maxItems {
        didSet { SettingsManager.shared.maxItems = maxItems }
    }
    @Published var detectSensitive: Bool = SettingsManager.shared.detectSensitive {
        didSet { SettingsManager.shared.detectSensitive = detectSensitive }
    }

    private let db = DatabaseManager.shared

    func refresh() {
        performSearch()
        totalCount = db.count()
        categories = db.allCategories()
        sourceApps = db.distinctSourceApps()
        refreshPinned()
    }

    func performSearch() {
        items = db.filtered(
            keyword: searchText.trimmingCharacters(in: .whitespaces),
            contentType: filterContentType,
            sourceApp: filterSourceApp
        )
        totalCount = db.count()
        selectedIndex = 0
        updateSelectedItem()
    }

    private func refreshPinned() {
        pinnedItems = db.pinnedItems()
        filteredPinnedItems = db.pinnedItems(categoryId: selectedCategoryId)
        pinnedSelectedIndex = 0
    }

    private func updateSelectedItem() {
        switch currentTab {
        case .history:
            selectedItem = selectedIndex < items.count ? items[selectedIndex] : nil
        case .pinned:
            selectedItem = pinnedSelectedIndex < filteredPinnedItems.count ? filteredPinnedItems[pinnedSelectedIndex] : nil
        case .settings:
            selectedItem = nil
        }
    }

    func selectIndex(_ index: Int) {
        switch currentTab {
        case .history: selectedIndex = index
        case .pinned: pinnedSelectedIndex = index
        case .settings: break
        }
        updateSelectedItem()
    }

    func moveUp() {
        let cols = gridColumns
        switch currentTab {
        case .history: if selectedIndex >= cols { selectedIndex -= cols }
        case .pinned: if pinnedSelectedIndex >= cols { pinnedSelectedIndex -= cols }
        case .settings: break
        }
        scrollToSelection = true
        updateSelectedItem()
    }

    func moveDown() {
        let cols = gridColumns
        switch currentTab {
        case .history: if selectedIndex + cols < items.count { selectedIndex += cols }
        case .pinned: if pinnedSelectedIndex + cols < filteredPinnedItems.count { pinnedSelectedIndex += cols }
        case .settings: break
        }
        scrollToSelection = true
        updateSelectedItem()
    }

    func moveLeft() {
        switch currentTab {
        case .history: if selectedIndex > 0 { selectedIndex -= 1 }
        case .pinned: if pinnedSelectedIndex > 0 { pinnedSelectedIndex -= 1 }
        case .settings: break
        }
        scrollToSelection = true
        updateSelectedItem()
    }

    func moveRight() {
        switch currentTab {
        case .history: if selectedIndex < items.count - 1 { selectedIndex += 1 }
        case .pinned: if pinnedSelectedIndex < filteredPinnedItems.count - 1 { pinnedSelectedIndex += 1 }
        case .settings: break
        }
        scrollToSelection = true
        updateSelectedItem()
    }

    // MARK: - Paste

    func pasteSelected(onDismiss: () -> Void) {
        switch currentTab {
        case .history: pasteAtIndex(selectedIndex, onDismiss: onDismiss)
        case .pinned: pastePinnedAtIndex(pinnedSelectedIndex, onDismiss: onDismiss)
        case .settings: break
        }
    }

    func pasteAtIndex(_ index: Int, onDismiss: () -> Void) {
        guard index < items.count else { return }
        PasteService.shared.pasteItem(items[index])
    }

    func pastePinnedAtIndex(_ index: Int, onDismiss: () -> Void) {
        guard index < filteredPinnedItems.count else { return }
        PasteService.shared.pasteItem(filteredPinnedItems[index])
    }

    // MARK: - Item Actions

    func togglePin(item: ClipItem) {
        guard let id = item.id else { return }
        db.togglePin(id: id)
        refresh()
    }

    func setCategory(item: ClipItem, categoryId: Int64?) {
        guard let id = item.id else { return }
        db.setCategory(clipId: id, categoryId: categoryId)
        refresh()
    }

    func deleteItem(item: ClipItem) {
        guard let id = item.id else { return }
        db.delete(id: id)
        refresh()
    }

    func clearAll() {
        db.clearUnpinned()
        refresh()
    }

    // MARK: - Category Actions

    func addCategory(name: String) {
        db.addCategory(name: name)
        categories = db.allCategories()
    }

    func deleteCategory(_ cat: ClipCategory) {
        guard let id = cat.id else { return }
        db.deleteCategory(id: id)
        if selectedCategoryId == id { selectedCategoryId = nil }
        categories = db.allCategories()
        refreshPinned()
    }

    func startRenaming(_ cat: ClipCategory) {}

    func pinnedCount(for cat: ClipCategory) -> Int {
        guard let id = cat.id else { return 0 }
        return db.pinnedCount(categoryId: id)
    }

    // MARK: - Filter helpers

    func clearFilters() {
        filterContentType = nil
        filterSourceApp = nil
        searchText = ""
    }

    var hasActiveFilters: Bool {
        filterContentType != nil || filterSourceApp != nil || !searchText.isEmpty
    }
}
