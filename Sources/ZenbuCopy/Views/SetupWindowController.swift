import AppKit
import SwiftUI

final class SetupWindowController {
    static let shared = SetupWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SetupView(onDone: { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
            self?.close()
        })

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "設定 ZenbuCopy"
        win.center()
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.close()
        window = nil
    }
}

struct SetupView: View {
    var onDone: () -> Void
    @State private var isGranted = AXIsProcessTrusted()
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("開啟輔助使用權限")
                .font(.system(size: 20, weight: .bold))

            Text("ZenbuCopy 需要輔助使用權限\n才能自動貼上到其他 App")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 狀態
            HStack(spacing: 10) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 18))
                    .foregroundColor(isGranted ? .green : .orange)
                Text(isGranted ? "已開啟，準備就緒！" : "尚未開啟")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(12)
            .background(isGranted ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
            .cornerRadius(8)

            if isGranted {
                Button(action: onDone) {
                    Text("開始使用")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { PasteService.openAccessibilitySettings() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("開啟輔助使用設定")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Text("開啟後在列表中找到 ZenbuCopy，打開開關即可")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(28)
        .frame(width: 440)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                isGranted = AXIsProcessTrusted()
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}
