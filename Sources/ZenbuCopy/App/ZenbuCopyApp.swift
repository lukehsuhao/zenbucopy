import SwiftUI

@main
struct ZenbuCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "clipboard")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}
