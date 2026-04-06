import AppKit
import ShortcutRecorder

/// 全域熱鍵管理 — 使用 ShortcutRecorder
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// UserDefaults 儲存快捷鍵的 key
    static let defaultsKey = "globalShortcut"
    static let pinnedDefaultsKey = "globalShortcutPinned"

    private var action: ShortcutAction?
    private var pinnedAction: ShortcutAction?
    var onHotkey: (() -> Void)?
    var onPinnedHotkey: (() -> Void)?
    /// 錄製快捷鍵時暫停回呼
    var suspended = false

    private init() {}

    func register() {
        setDefaultShortcutIfNeeded()

        // 主快捷鍵（開啟歷史）
        let action = ShortcutAction(
            keyPath: "values.\(Self.defaultsKey)",
            of: NSUserDefaultsController.shared
        ) { [weak self] _ in
            guard self?.suspended != true else { return true }
            self?.onHotkey?()
            return true
        }
        GlobalShortcutMonitor.shared.addAction(action, forKeyEvent: .down)
        self.action = action

        // 釘選快捷鍵
        let pinnedAction = ShortcutAction(
            keyPath: "values.\(Self.pinnedDefaultsKey)",
            of: NSUserDefaultsController.shared
        ) { [weak self] _ in
            guard self?.suspended != true else { return true }
            self?.onPinnedHotkey?()
            return true
        }
        GlobalShortcutMonitor.shared.addAction(pinnedAction, forKeyEvent: .down)
        self.pinnedAction = pinnedAction
    }

    func unregister() {
        if let action = action {
            GlobalShortcutMonitor.shared.removeAction(action, forKeyEvent: .down)
            self.action = nil
        }
        if let pinnedAction = pinnedAction {
            GlobalShortcutMonitor.shared.removeAction(pinnedAction, forKeyEvent: .down)
            self.pinnedAction = nil
        }
    }

    /// 首次啟動時設定預設快捷鍵
    private func setDefaultShortcutIfNeeded() {
        if UserDefaults.standard.data(forKey: Self.defaultsKey) == nil {
            let shortcut = Shortcut(code: .ansiV,
                                    modifierFlags: [.command, .shift],
                                    characters: "V",
                                    charactersIgnoringModifiers: "v")
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: shortcut,
                                                             requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            }
        }
        if UserDefaults.standard.data(forKey: Self.pinnedDefaultsKey) == nil {
            let shortcut = Shortcut(code: .ansiP,
                                    modifierFlags: [.command, .shift],
                                    characters: "P",
                                    charactersIgnoringModifiers: "p")
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: shortcut,
                                                             requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: Self.pinnedDefaultsKey)
            }
        }
    }
}
