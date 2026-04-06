import Foundation
import ServiceManagement
import AppKit

/// 持久化設定管理
final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    /// 設定變更通知
    static let menuBarIconDidChange = Notification.Name("SettingsManager.menuBarIconDidChange")

    private init() {}

    // MARK: - 開機啟動

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // 如果註冊失敗（例如非正式 .app），回退設定
                    defaults.set(false, forKey: "launchAtLogin")
                }
            }
        }
    }

    // MARK: - 選單列圖示

    var showMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") == nil ? true : defaults.bool(forKey: "showMenuBarIcon") }
        set {
            defaults.set(newValue, forKey: "showMenuBarIcon")
            NotificationCenter.default.post(name: Self.menuBarIconDidChange, object: nil)
        }
    }

    // MARK: - 歷史

    var retentionDays: Int {
        get {
            let v = defaults.integer(forKey: "retentionDays")
            return v == 0 && defaults.object(forKey: "retentionDays") == nil ? 30 : v
        }
        set { defaults.set(newValue, forKey: "retentionDays") }
    }

    var maxItems: Int {
        get {
            let v = defaults.integer(forKey: "maxItems")
            return v == 0 && defaults.object(forKey: "maxItems") == nil ? 5000 : v
        }
        set { defaults.set(newValue, forKey: "maxItems") }
    }

    // MARK: - 隱私

    var detectSensitive: Bool {
        get { defaults.object(forKey: "detectSensitive") == nil ? true : defaults.bool(forKey: "detectSensitive") }
        set { defaults.set(newValue, forKey: "detectSensitive") }
    }
}
