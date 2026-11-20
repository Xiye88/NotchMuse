import AppKit
import Foundation

struct AnnouncementEntry: Codable, Equatable, Sendable {
    let id: String
    let kind: String?
    let date: String?
    let badgeZh: String?
    let badgeEn: String?
    let titleZh: String
    let titleEn: String
    let bodyZh: String
    let bodyEn: String
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, date, url
        case badgeZh = "badge_zh"
        case badgeEn = "badge_en"
        case titleZh = "title_zh"
        case titleEn = "title_en"
        case bodyZh = "body_zh"
        case bodyEn = "body_en"
    }

    var localizedBadge: String? {
        AppPreferences.language == .simplifiedChinese ? (badgeZh ?? badgeEn) : (badgeEn ?? badgeZh)
    }

    var localizedTitle: String {
        AppPreferences.language == .simplifiedChinese ? titleZh : titleEn
    }

    var localizedBody: String {
        AppPreferences.language == .simplifiedChinese ? bodyZh : bodyEn
    }

    var safeURL: URL? {
        guard let url, let parsed = URL(string: url),
              parsed.scheme?.lowercased() == "https",
              let host = parsed.host?.lowercased(),
              host == "notchmuse.com" || host == "www.notchmuse.com" || host == "github.com" else {
            return nil
        }
        return parsed
    }
}

struct AppAnnouncement: Codable, Equatable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let url: String
    let enabled: Bool
    let items: [AnnouncementEntry]?

    enum CodingKeys: String, CodingKey {
        case id, url, enabled, items
        case titleZh = "title_zh"
        case titleEn = "title_en"
    }

    var localizedTitle: String {
        AppPreferences.language == .simplifiedChinese ? titleZh : titleEn
    }

    var safeURL: URL? {
        guard let parsed = URL(string: url),
              parsed.scheme?.lowercased() == "https",
              let host = parsed.host?.lowercased(),
              host == "notchmuse.com" || host == "www.notchmuse.com" || host == "github.com" else {
            return nil
        }
        return parsed
    }
}

@MainActor
final class AnnouncementManager {
    static let shared = AnnouncementManager()
    static let notification = Notification.Name("NotchMuseAnnouncementDidChange")
    private static let feedURL = URL(string: "https://notchmuse.com/announcements.json")!

    private static let fallbackItems: [AnnouncementEntry] = [
        AnnouncementEntry(
            id: "v0.8.3",
            kind: "release",
            date: "2026-11-20",
            badgeZh: "最新版本",
            badgeEn: "Latest",
            titleZh: "v0.8.3 — 四平台歌词命中率提升至 90%",
            titleEn: "v0.8.3 — 90% Lyrics Match Rate Across 4 Players",
            bodyZh: "• Apple Music（43% → 90%）、Spotify（58% → 90%）、网易云音乐（45% → 90%）、汽水音乐（44% → 90%）\n• 恢复酷狗/QQ 音乐直连并支持逐字时间戳解析，消除 <00:12.34> 异常数字串\n• 启动自动静默检查更新 + 设置页独立「自动下载并安装更新」开关\n• 刘海/悬浮毛玻璃质感、0.5pt 描边与胶囊工具条升级",
            bodyEn: "• Apple Music (43% → 90%), Spotify (58% → 90%), NetEase Cloud (45% → 90%), Soda Music (44% → 90%)\n• Restored direct Kugou & QQ Music sources and Enhanced LRC word-timestamp parsing\n• Automatic launch update checks + independent auto download & install toggle\n• Upgraded Notch/Free Floating frosted vibrancy, 0.5pt rim, and capsule hover bar",
            url: "https://notchmuse.com/releases/v0.8.3/NotchMuse.html"
        ),
        AnnouncementEntry(
            id: "v0.8.2",
            kind: "release",
            date: "2026-11-10",
            badgeZh: "历史版本",
            badgeEn: "Release",
            titleZh: "v0.8.2 — 应用内自动更新与播放器识别增强",
            titleEn: "v0.8.2 — Built-in Auto-Updates & Player Detection",
            bodyZh: "• 正式集成 Sparkle 应用内更新机制与 EdDSA 签名校验\n• 增强网易云音乐、QQ 音乐、汽水音乐与 Spotify 的播放状态同步",
            bodyEn: "• Integrated Sparkle in-app updater with EdDSA signature verification\n• Improved playback sync across NetEase Cloud, QQ Music, Soda Music, and Spotify",
            url: "https://notchmuse.com/releases/v0.8.2/NotchMuse.md"
        ),
        AnnouncementEntry(
            id: "v0.8.1",
            kind: "release",
            date: "2026-10-18",
            badgeZh: "历史版本",
            badgeEn: "Release",
            titleZh: "v0.8.1 — 自由悬浮模式与时间轴精准同步",
            titleEn: "v0.8.1 — Free Floating Mode & Precision Timing Sync",
            bodyZh: "• 支持桌面自由悬浮词条、单行/双行切换与手动微调时间偏移\n• 优化菜单栏歌词渲染性能与低功耗表现",
            bodyEn: "• Added Free Floating desktop lyrics, 1/2-line modes, and manual timing offset\n• Optimized menu-bar rendering and low-power idle behavior",
            url: "https://notchmuse.com/releases/v0.8.1/NotchMuse.md"
        )
    ]

    private var hasRefreshed = false

    private(set) var current: AppAnnouncement? = AppAnnouncement(
        id: "v0.8.3",
        titleZh: "v0.8.3 已发布：四平台歌词命中率提升至 90%，点击查看更新与公告",
        titleEn: "v0.8.3 Released: 90% lyrics match rate across 4 players — View announcements",
        url: "https://notchmuse.com/releases/v0.8.3/NotchMuse.html",
        enabled: true,
        items: AnnouncementManager.fallbackItems
    )

    var activeAnnouncement: AppAnnouncement? {
        guard let current, current.enabled else { return nil }
        return current
    }

    var historyItems: [AnnouncementEntry] {
        if let items = current?.items, !items.isEmpty {
            return items
        }
        return Self.fallbackItems
    }

    func refreshIfNeeded() {
        guard !hasRefreshed else { return }
        hasRefreshed = true
        Task {
            await fetchRemote()
        }
    }

    func refreshNow() {
        Task {
            await fetchRemote()
        }
    }

    private func fetchRemote() async {
        var request = URLRequest(url: Self.feedURL)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(AppAnnouncement.self, from: data) else {
            return
        }
        if decoded != current {
            current = decoded
            NotificationCenter.default.post(name: Self.notification, object: nil)
        }
    }

    func openActive() {
        refreshNow()
        AnnouncementWindowController.shared.show()
    }
}
