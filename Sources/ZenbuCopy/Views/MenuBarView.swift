import SwiftUI

/// Menubar 下拉選單
struct MenuBarView: View {
    @State private var recentItems: [ClipItem] = []

    var body: some View {
        Group {
            Button("🔍 開啟 ZenbuCopy") {
                SearchPanelController.shared.show()
            }

            Divider()

            if recentItems.isEmpty {
                Text("尚無紀錄")
            } else {
                ForEach(Array(recentItems.prefix(10).enumerated()), id: \.element.id) { index, item in
                    Button {
                        PasteService.shared.pasteItem(item)
                    } label: {
                        HStack {
                            if item.isPinned { Text("📌") }
                            Text(item.displayText)
                        }
                    }
                }
            }

            Divider()

            Button("清除全部（保留釘選）") {
                DatabaseManager.shared.clearUnpinned()
            }

            Divider()

            Button("結束 ZenbuCopy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            recentItems = DatabaseManager.shared.recent(limit: 10)
        }
    }
}
