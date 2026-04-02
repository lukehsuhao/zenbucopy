import Foundation
import AppKit

/// 透過 GitHub Releases API 檢查並安裝更新
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let repo = "lukehsuhao/paster"
    let currentVersionString = "1.1.1"
    private var currentVersion: String { currentVersionString }

    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var lastCheckDate: Date? = nil
    @Published var errorMessage: String? = nil

    private var downloadURL: URL?

    private init() {}

    /// 啟動時自動檢查（每 6 小時最多一次）
    func checkOnLaunchIfNeeded() {
        let defaults = UserDefaults.standard
        let lastCheck = defaults.double(forKey: "lastUpdateCheck")
        let now = Date().timeIntervalSince1970
        // 距離上次檢查超過 6 小時
        if now - lastCheck > 6 * 3600 {
            checkForUpdate()
        }
    }

    /// 手動檢查更新
    func checkForUpdate() {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                self.lastCheckDate = Date()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")

                if let error = error {
                    self.errorMessage = "無法連線：\(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.errorMessage = "無法解析版本資訊"
                    return
                }

                let remoteVersion = tagName.replacingOccurrences(of: "v", with: "")
                self.latestVersion = remoteVersion
                self.releaseNotes = (json["body"] as? String) ?? ""

                // 找到 .zip asset
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name.hasSuffix(".zip"),
                           let urlStr = asset["browser_download_url"] as? String {
                            self.downloadURL = URL(string: urlStr)
                            break
                        }
                    }
                }

                self.updateAvailable = self.isNewer(remote: remoteVersion, current: self.currentVersion)
            }
        }.resume()
    }

    /// 下載並安裝更新
    func downloadAndInstall() {
        guard let url = downloadURL else {
            errorMessage = "找不到下載連結"
            return
        }
        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isDownloading = false

                if let error = error {
                    self.errorMessage = "下載失敗：\(error.localizedDescription)"
                    return
                }

                guard let tempURL = tempURL else {
                    self.errorMessage = "下載失敗"
                    return
                }

                self.installUpdate(from: tempURL)
            }
        }
        task.resume()
    }

    private func installUpdate(from zipURL: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("PasterUpdate_\(UUID().uuidString)")

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // 解壓
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", zipURL.path, tempDir.path]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                errorMessage = "解壓失敗"
                return
            }

            // 找到 .app
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                errorMessage = "找不到 .app"
                return
            }

            // 取得目前 App 的路徑
            let currentApp = Bundle.main.bundleURL

            // 用 shell script 替換並重啟
            let script = """
            #!/bin/bash
            sleep 1
            rm -rf "\(currentApp.path)"
            cp -R "\(newApp.path)" "\(currentApp.path)"
            codesign -f -s - --identifier "com.luke.paster" "\(currentApp.path)" 2>/dev/null
            open "\(currentApp.path)"
            rm -rf "\(tempDir.path)"
            """

            let scriptPath = tempDir.appendingPathComponent("update.sh")
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)

            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
            launcher.arguments = [scriptPath.path]
            try launcher.run()

            // 結束當前 App
            NSApp.terminate(nil)

        } catch {
            errorMessage = "安裝失敗：\(error.localizedDescription)"
        }
    }

    /// 比較版本號
    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}
