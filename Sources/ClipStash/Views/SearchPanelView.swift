import SwiftUI
import AppKit

// MARK: - Main Panel View

struct SearchPanelView: View {
    @ObservedObject var viewModel: SearchViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 頂部
            TopBarView(viewModel: viewModel, onDismiss: onDismiss)

            Divider()

            // 內容區
            switch viewModel.currentTab {
            case .history:
                HistoryTabView(viewModel: viewModel, onDismiss: onDismiss)
            case .pinned:
                PinnedTabView(viewModel: viewModel, onDismiss: onDismiss)
            case .settings:
                SettingsTabView(viewModel: viewModel)
            }

            Divider()

            // 底部
            BottomBarView(viewModel: viewModel)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    @ObservedObject var viewModel: SearchViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                TabButton(title: "歷史", icon: "clock", isSelected: viewModel.currentTab == .history) {
                    viewModel.currentTab = .history
                }
                TabButton(title: "釘選", icon: "pin.fill", isSelected: viewModel.currentTab == .pinned) {
                    viewModel.currentTab = .pinned
                }
                TabButton(title: "設定", icon: "gearshape", isSelected: viewModel.currentTab == .settings) {
                    viewModel.currentTab = .settings
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // 搜尋列（僅歷史分頁）
            if viewModel.currentTab == .history {
                SearchBarView(text: $viewModel.searchText)
                FilterBarView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Bottom Bar

struct BottomBarView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        HStack {
            Text("\(viewModel.totalCount) 筆紀錄")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
            Text("⌘⇧V 開啟 · 雙擊/Enter 貼上 · Esc 關閉")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "全部", isSelected: viewModel.filterContentType == nil) {
                    viewModel.filterContentType = nil
                }
                FilterChip(label: "文字", icon: "doc.text", isSelected: viewModel.filterContentType == .text) {
                    viewModel.filterContentType = (viewModel.filterContentType == .text) ? nil : .text
                }
                FilterChip(label: "圖片", icon: "photo", isSelected: viewModel.filterContentType == .image) {
                    viewModel.filterContentType = (viewModel.filterContentType == .image) ? nil : .image
                }
                FilterChip(label: "連結", icon: "link", isSelected: viewModel.filterContentType == .url) {
                    viewModel.filterContentType = (viewModel.filterContentType == .url) ? nil : .url
                }
                FilterChip(label: "檔案", icon: "folder", isSelected: viewModel.filterContentType == .filePath) {
                    viewModel.filterContentType = (viewModel.filterContentType == .filePath) ? nil : .filePath
                }

                if !viewModel.sourceApps.isEmpty {
                    Divider().frame(height: 18)

                    Menu {
                        Button("全部 App") { viewModel.filterSourceApp = nil }
                        Divider()
                        ForEach(viewModel.sourceApps, id: \.self) { app in
                            Button(app) { viewModel.filterSourceApp = app }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "app.badge").font(.system(size: 11))
                            Text(viewModel.filterSourceApp ?? "來源 App").font(.system(size: 12))
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(viewModel.filterSourceApp != nil ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .foregroundColor(viewModel.filterSourceApp != nil ? .accentColor : .secondary)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.hasActiveFilters {
                    Button(action: { viewModel.clearFilters() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
    }
}

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 11))
                }
                Text(label).font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06))
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    var onDismiss: () -> Void

    var body: some View {
        if viewModel.items.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "clipboard")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("尚無剪貼紀錄")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
                    .padding(.top, 8)
                if viewModel.hasActiveFilters {
                    Button("清除篩選") { viewModel.clearFilters() }
                        .font(.system(size: 13))
                        .padding(.top, 6)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // 左側：卡片 Grid — 佔 60%
                    CardGridView(
                        items: viewModel.items,
                        selectedIndex: viewModel.selectedIndex,
                        onSelect: { index in viewModel.selectIndex(index) },
                        onPaste: { index in viewModel.pasteAtIndex(index, onDismiss: onDismiss) },
                        onTogglePin: { item in viewModel.togglePin(item: item) },
                        onDelete: { item in viewModel.deleteItem(item: item) },
                        categories: viewModel.categories,
                        onSetCategory: { item, catId in viewModel.setCategory(item: item, categoryId: catId) }
                    )
                    .frame(width: geo.size.width * 0.58)

                    Divider()

                    // 右側：預覽面板 — 佔 40%
                    PreviewPanelView(item: viewModel.selectedItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Card Grid

struct CardGridView: View {
    let items: [ClipItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onPaste: (Int) -> Void
    let onTogglePin: (ClipItem) -> Void
    let onDelete: (ClipItem) -> Void
    let categories: [ClipCategory]
    let onSetCategory: (ClipItem, Int64?) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 170, maximum: 250), spacing: 10)
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CardView(
                            item: item,
                            isSelected: index == selectedIndex,
                            shortcutNumber: index < 9 ? index + 1 : nil
                        )
                        .id(item.id)
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded { onPaste(index) }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 1).onEnded { onSelect(index) }
                        )
                        .contextMenu {
                            Button(item.isPinned ? "取消釘選" : "📌 釘選") { onTogglePin(item) }
                            if item.isPinned {
                                Menu("📁 移動到分類") {
                                    Button("（無分類）") { onSetCategory(item, nil) }
                                    ForEach(categories) { cat in
                                        Button(cat.name) { onSetCategory(item, cat.id) }
                                    }
                                }
                            }
                            Divider()
                            Button("🗑 刪除") { onDelete(item) }
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: selectedIndex) { newIndex in
                if newIndex < items.count {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(items[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let item: ClipItem
    let isSelected: Bool
    let shortcutNumber: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 內容區
            Group {
                switch item.contentType {
                case .image:
                    if let data = item.thumbnailData ?? item.imageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 100)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        cardText("[圖片]")
                    }
                case .url:
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text(item.textContent ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .lineLimit(3)
                    }
                    .padding(10)
                default:
                    cardText(item.textContent ?? "")
                }
            }
            .frame(minHeight: 65, maxHeight: 100)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 底部
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
                if let appName = item.sourceAppName, !appName.isEmpty {
                    Text(appName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let num = shortcutNumber {
                    Text("⌘\(num)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(3)
                }
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), lineWidth: isSelected ? 2 : 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func cardText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
    }
}

// MARK: - Preview Panel

struct PreviewPanelView: View {
    let item: ClipItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題
            HStack {
                Image(systemName: "eye").font(.system(size: 13))
                Text("預覽").font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if let item = item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch item.contentType {
                        case .image:
                            if let data = item.imageData, let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(6)
                            }
                        case .url:
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "link").foregroundColor(.blue)
                                Text(item.textContent ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                    .textSelection(.enabled)
                            }
                        default:
                            Text(item.textContent ?? "")
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()

                        // 元資料
                        VStack(alignment: .leading, spacing: 8) {
                            metaRow(icon: "doc", label: "類型", value: typeName(item.contentType))
                            if let text = item.textContent {
                                metaRow(icon: "textformat.123", label: "字數", value: "\(text.count) 字")
                            }
                            if let appName = item.sourceAppName, !appName.isEmpty {
                                metaRow(icon: "app", label: "來源", value: appName)
                            }
                            if let catName = item.categoryName {
                                metaRow(icon: "folder", label: "分類", value: catName)
                            }
                            metaRow(icon: "clock", label: "時間", value: formatDate(item.createdAt))
                            if item.isPinned {
                                HStack(spacing: 4) {
                                    Image(systemName: "pin.fill").font(.system(size: 11)).foregroundColor(.orange)
                                    Text("已釘選").font(.system(size: 12)).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("選取項目以預覽")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    private func typeName(_ type: ClipContentType) -> String {
        switch type {
        case .text: return "文字"
        case .image: return "圖片"
        case .url: return "連結"
        case .filePath: return "檔案路徑"
        case .rtf: return "RTF"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 快捷鍵
                settingsSection(title: "快捷鍵", icon: "keyboard") {
                    settingsRow(label: "開啟 Paster") {
                        HotkeyRecorderView(
                            displayString: $viewModel.hotkeyDisplay,
                            isRecording: $viewModel.isRecordingHotkey,
                            onRecord: { event in viewModel.recordHotkey(event: event) }
                        )
                    }
                    settingsRow(label: "快速貼上 (第 1~9 項)") {
                        Text("⌘1 ~ ⌘9")
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    settingsRow(label: "切換分頁") {
                        Text("⌃Tab / ⌃⇧Tab")
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }

                // 一般
                settingsSection(title: "一般", icon: "gearshape") {
                    settingsToggle(label: "開機時啟動", isOn: $viewModel.launchAtLogin)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("輔助使用權限").font(.system(size: 13))
                            Text("需要此權限才能自動貼上到其他 App").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        if AXIsProcessTrusted() {
                            Text("✓ 已授權")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else {
                            Button("開啟授權") {
                                PasteService.requestAccessibility()
                            }
                            .font(.system(size: 12))
                        }
                    }
                }

                // 歷史紀錄
                settingsSection(title: "歷史紀錄", icon: "clock") {
                    settingsRow(label: "保留天數") {
                        Picker("", selection: $viewModel.retentionDays) {
                            Text("7 天").tag(7)
                            Text("30 天").tag(30)
                            Text("90 天").tag(90)
                            Text("365 天").tag(365)
                            Text("永久").tag(0)
                        }
                        .frame(width: 120)
                    }
                    Text("超過保留天數的紀錄（釘選項目除外）會自動刪除")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    settingsRow(label: "最大紀錄筆數") {
                        Picker("", selection: $viewModel.maxItems) {
                            Text("500").tag(500)
                            Text("1,000").tag(1000)
                            Text("5,000").tag(5000)
                            Text("無限制").tag(0)
                        }
                        .frame(width: 120)
                    }
                    Text("超過上限時，最舊的非釘選紀錄會自動刪除")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // 隱私
                settingsSection(title: "隱私", icon: "lock.shield") {
                    settingsToggle(label: "自動偵測機密內容（密碼管理器）", isOn: $viewModel.detectSensitive)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("排除的 App")
                            .font(.system(size: 13))
                        Text("來自以下 App 的複製內容將不會被記錄")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(["1Password", "Bitwarden", "KeePassXC"], id: \.self) { app in
                                HStack {
                                    Image(systemName: "app").font(.system(size: 11)).foregroundColor(.secondary)
                                    Text(app).font(.system(size: 12))
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }

                // 更新
                UpdateSectionView()

                // 關於
                settingsSection(title: "關於", icon: "info.circle") {
                    HStack {
                        Text("Paster v\(UpdateManager.shared.currentVersionString)")
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
            }
            .padding(24)
        }
    }

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            trailing()
        }
    }

    private func settingsToggle(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.system(size: 13))
            .toggleStyle(.switch)
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: View {
    @Binding var displayString: String
    @Binding var isRecording: Bool
    var onRecord: (NSEvent) -> Void

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Text(isRecording ? "請按下新的快捷鍵…" : displayString)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(minWidth: 120)
                .background(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundColor(isRecording ? .accentColor : .primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .background(isRecording ? HotkeyListenerView(onKeyDown: onRecord) : nil)
    }
}

/// 隱藏的 NSView 用來攔截鍵盤事件
struct HotkeyListenerView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> HotkeyCapture {
        let view = HotkeyCapture()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: HotkeyCapture, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

class HotkeyCapture: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // 需要至少一個 modifier key
        if mods.contains(.command) || mods.contains(.control) || mods.contains(.option) {
            onKeyDown?(event)
        }
    }
}

// MARK: - Pinned Tab

struct PinnedTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    var onDismiss: () -> Void
    @State private var showAddCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // 左側：分類列表
                VStack(alignment: .leading, spacing: 0) {
                    CategoryRow(
                        name: "全部釘選", icon: "pin.fill",
                        count: viewModel.pinnedItems.count,
                        isSelected: viewModel.selectedCategoryId == nil,
                        action: { viewModel.selectedCategoryId = nil }
                    )

                    Divider().padding(.vertical, 4).padding(.horizontal, 8)

                    ForEach(viewModel.categories) { cat in
                        CategoryRow(
                            name: cat.name, icon: cat.icon,
                            count: viewModel.pinnedCount(for: cat),
                            isSelected: viewModel.selectedCategoryId == cat.id,
                            action: { viewModel.selectedCategoryId = cat.id }
                        )
                        .contextMenu {
                            Button("🗑 刪除分類") { viewModel.deleteCategory(cat) }
                        }
                    }

                    Divider().padding(.vertical, 4).padding(.horizontal, 8)

                    // 新增分類
                    if showAddCategory {
                        HStack(spacing: 6) {
                            TextField("分類名稱", text: $newCategoryName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onSubmit {
                                    if !newCategoryName.isEmpty {
                                        viewModel.addCategory(name: newCategoryName)
                                        newCategoryName = ""
                                        showAddCategory = false
                                    }
                                }
                            Button(action: { showAddCategory = false; newCategoryName = "" }) {
                                Image(systemName: "xmark").font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                            Text("新增分類")
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { showAddCategory = true }
                        .padding(.horizontal, 4)
                    }

                    Spacer()
                }
                .frame(width: 170)
                .padding(.vertical, 8)

                Divider()

                // 右側
                HStack(spacing: 0) {
                    if viewModel.filteredPinnedItems.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "pin.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("尚無釘選項目")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                                .padding(.top, 6)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let rightWidth = geo.size.width - 170
                        CardGridView(
                            items: viewModel.filteredPinnedItems,
                            selectedIndex: viewModel.pinnedSelectedIndex,
                            onSelect: { index in viewModel.selectIndex(index) },
                            onPaste: { index in viewModel.pastePinnedAtIndex(index, onDismiss: onDismiss) },
                            onTogglePin: { item in viewModel.togglePin(item: item) },
                            onDelete: { item in viewModel.deleteItem(item: item) },
                            categories: viewModel.categories,
                            onSetCategory: { item, catId in viewModel.setCategory(item: item, categoryId: catId) }
                        )
                        .frame(width: rightWidth * 0.55)

                        Divider()

                        PreviewPanelView(item: viewModel.selectedItem)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Shared Components

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12))
            Text(title).font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(minWidth: 60)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .foregroundColor(isSelected ? .accentColor : .secondary)
        .cornerRadius(6)
        .onTapGesture { action() }
    }
}

struct CategoryRow: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .font(.system(size: 12))
            Text(name)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .onTapGesture { action() }
        .padding(.horizontal, 6)
    }
}

struct SearchBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
            TextField("搜尋剪貼簿…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Update Section

struct UpdateSectionView: View {
    @ObservedObject private var updater = UpdateManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("軟體更新")
                    .font(.system(size: 15, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                if updater.updateAvailable {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("有新版本 v\(updater.latestVersion) 可用")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            if !updater.releaseNotes.isEmpty {
                                Text(updater.releaseNotes)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        Spacer()
                        if updater.isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button("下載更新") {
                                updater.downloadAndInstall()
                            }
                            .font(.system(size: 12))
                        }
                    }
                } else {
                    HStack {
                        Text(updater.isChecking ? "正在檢查更新…" : "目前是最新版本")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        if updater.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button("檢查更新") {
                                updater.checkForUpdate()
                            }
                            .font(.system(size: 12))
                        }
                    }
                }

                if let error = updater.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }

                if let date = updater.lastCheckDate {
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "yyyy/MM/dd HH:mm"
                    Text("上次檢查：\(formatter.string(from: date))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
