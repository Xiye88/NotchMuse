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
        .executableTarget(
            name: "MenuBarLyrics",
            dependencies: ["LyricsCore", .product(name: "Sparkle", package: "Sparkle")],
            path: ".",
            exclude: ["Sources/LyricsCore", "Tests", "Vendor", "Resources/en.lproj", "Resources/zh-Hans.lproj",
                      "Resources/AppIcon.icns", "Resources/NotchMuse.entitlements",
                      "Resources/SettingsPreviewWallpaper.png",
                      "Resources/mediaremote-watchdog.sh"],
            sources: ["Sources/MenuBarLyrics"],
            resources: [.copy("Resources/qq-group-qr.png"), .copy("Resources/WeChatSupport.jpg")]
        ),
        .testTarget(name: "MenuBarLyricsTests", dependencies: ["LyricsCore"])
    ]
)
