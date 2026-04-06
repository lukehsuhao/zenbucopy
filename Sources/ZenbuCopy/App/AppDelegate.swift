import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ClipboardMonitor.shared
    private var cleanupTimer: Timer?

    private let allTabs: [PanelTab] = [.history, .pinned, .settings]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.start()

        HotkeyManager.shared.onHotkey = {
            PasteService.shared.capturePreviousApp()
            SearchPanelController.shared.toggle()
        }
        HotkeyManager.shared.onPinnedHotkey = {
            PasteService.shared.capturePreviousApp()
            SearchPanelController.shared.showPinned()
        }
        HotkeyManager.shared.register()

        // 首次啟動顯示權限引導
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        if !hasCompletedSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                SetupWindowController.shared.show()
            }
        }

        // 檢查更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateManager.shared.checkOnLaunchIfNeeded()
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleLocalKeyEvent(event)
        }

        // 啟動時執行一次清理，之後每小時清理一次
        runCleanup()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        HotkeyManager.shared.unregister()
        cleanupTimer?.invalidate()
    }

    private func runCleanup() {
        let settings = SettingsManager.shared
        let db = DatabaseManager.shared

        let days = settings.retentionDays
        if days > 0 {
            db.purgeOlderThan(days: days)
        }

        let maxItems = settings.maxItems
        if maxItems > 0 {
            db.purgeExceedingMax(maxCount: maxItems)
        }
    }

    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        let panel = SearchPanelController.shared
        guard panel.isVisible else { return event }

        let vm = panel.viewModel
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Esc 關閉
        if event.keyCode == 53 {
            panel.hide()
            return nil
        }

        // Ctrl+Tab → 下一個分頁 / Ctrl+Shift+Tab → 上一個
        if event.keyCode == 48 && flags.contains(.control) {
            if let idx = allTabs.firstIndex(of: vm.currentTab) {
                if flags.contains(.shift) {
                    vm.currentTab = allTabs[(idx - 1 + allTabs.count) % allTabs.count]
                } else {
                    vm.currentTab = allTabs[(idx + 1) % allTabs.count]
                }
            }
            return nil
        }

        // 設定分頁不需要鍵盤導航
        if vm.currentTab == .settings { return event }

        if event.keyCode == 126 { vm.moveUp(); return nil }    // ↑
        if event.keyCode == 125 { vm.moveDown(); return nil }  // ↓
        if event.keyCode == 123 { vm.moveLeft(); return nil }  // ←
        if event.keyCode == 124 { vm.moveRight(); return nil } // →

        // Enter — 輸入法選字中不攔截
        if event.keyCode == 36 {
            if let inputContext = NSTextInputContext.current {
                let client = inputContext.client
                if client.hasMarkedText() { return event }
            }
            if let window = NSApp.keyWindow,
               let responder = window.firstResponder as? NSTextView,
               responder.hasMarkedText() {
                return event
            }
            vm.pasteSelected(onDismiss: { panel.hide() })
            return nil
        }

        // Cmd+1~9
        if flags.contains(.command) && !flags.contains(.control) {
            let numberKeys: [UInt16: Int] = [
                18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
                22: 5, 26: 6, 28: 7, 25: 8
            ]
            if let index = numberKeys[event.keyCode] {
                vm.pasteAtIndex(index, onDismiss: { panel.hide() })
                return nil
            }
        }

        return event
    }
}
