// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchMuse",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchMuse", targets: ["MenuBarLyrics"])
    ],
    targets: [
        .executableTarget(name: "MenuBarLyrics")
    ]
)
