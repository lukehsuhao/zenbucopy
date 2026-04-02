import AppKit
import SwiftUI

/// 管理主視窗（使用 NSWindow，非 NSPanel，避免自動消失）
final class SearchPanelController {
    static let shared = SearchPanelController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<SearchPanelView>?
    let viewModel = SearchViewModel()

    private init() {}

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        viewModel.refresh()
        viewModel.searchText = ""

        if window == nil {
            createWindow()
        }

        guard let window = window else { return }

        // 只在首次顯示時設定位置
        if window.frame.origin == .zero {
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let w: CGFloat = 900
                let h: CGFloat = 580
                let x = screenFrame.midX - w / 2
                let y = screenFrame.midY + screenFrame.height * 0.05
                window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
            }
        }

        // 暫時提升層級讓它浮到最上面，顯示後降回 normal
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            window.level = .normal
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let contentView = SearchPanelView(viewModel: viewModel, onDismiss: { [weak self] in
            self?.hide()
        })

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Paster"
        win.titleVisibility = .visible
        win.isMovableByWindowBackground = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 650, height: 420)
        win.setFrameAutosaveName("ClipStashWindow")
        win.level = .normal

        let hosting = NSHostingView(rootView: contentView)
        win.contentView = hosting

        self.window = win
        self.hostingView = hosting
    }
}
