// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchMuse",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchMuse", targets: ["MenuBarLyrics"])
    ],
    targets: [
        .target(name: "LyricsCore"),
        .executableTarget(name: "MenuBarLyrics", dependencies: ["LyricsCore"]),
        .testTarget(name: "MenuBarLyricsTests", dependencies: ["LyricsCore"])
    ]
)
