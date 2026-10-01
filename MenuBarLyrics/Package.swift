// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchMuse",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchMuse", targets: ["MenuBarLyrics"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "LyricsCore"),
        .executableTarget(name: "MenuBarLyrics", dependencies: ["LyricsCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "MenuBarLyricsTests", dependencies: ["LyricsCore"])
    ]
)
