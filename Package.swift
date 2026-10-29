// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clawd",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Clawd", path: "Sources/Clawd")
    ]
)
