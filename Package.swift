// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "ZenbuCopy",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/Kentzo/ShortcutRecorder.git", from: "3.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "ZenbuCopy",
            dependencies: ["ShortcutRecorder"],
            path: "Sources/ZenbuCopy",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
