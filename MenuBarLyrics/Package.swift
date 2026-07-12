// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuBarLyrics",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MenuBarLyrics", targets: ["MenuBarLyrics"])
    ],
    targets: [
        .executableTarget(name: "MenuBarLyrics")
    ]
)
