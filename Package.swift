// swift-tools-version: 5.9
// 最低支持 macOS 14 Sonoma；向上兼容 macOS 15 / 26 / 27。
import PackageDescription

let package = Package(
    name: "WarpCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WarpCursor",
            path: "Sources/WarpCursor"
        )
    ]
)
