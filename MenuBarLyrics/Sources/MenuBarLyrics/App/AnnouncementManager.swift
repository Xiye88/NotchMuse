import AppKit
import Foundation

struct AppAnnouncement: Codable, Equatable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let url: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, url, enabled
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
    private static let dismissedKey = "DismissedAnnouncementIDs"
    private static let feedURL = URL(string: "https://notchmuse.com/announcements.json")!

    private let defaults: UserDefaults
    private var hasRefreshed = false

    private(set) var current: AppAnnouncement? = AppAnnouncement(
        id: "v0.8.3",
        titleZh: "v0.8.3 已发布：四平台歌词命中率提升至 90%，点击查看更新说明",
        titleEn: "v0.8.3 Released: 90% lyrics match rate across 4 players — View notes",
        url: "https://notchmuse.com/releases/v0.8.3/NotchMuse.html",
        enabled: true
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeAnnouncement: AppAnnouncement? {
        guard let current, current.enabled, current.safeURL != nil else { return nil }
        guard !dismissedIDs.contains(current.id) else { return nil }
        return current
    }

    private var dismissedIDs: Set<String> {
        Set(defaults.stringArray(forKey: Self.dismissedKey) ?? [])
    }

    func refreshIfNeeded() {
        guard !hasRefreshed else { return }
        hasRefreshed = true
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
        guard let item = activeAnnouncement, let url = item.safeURL else { return }
        NSWorkspace.shared.open(url)
        dismissCurrent()
    }

    func dismissCurrent() {
        guard let id = current?.id else { return }
        var ids = dismissedIDs
        ids.insert(id)
        defaults.set(Array(ids).sorted(), forKey: Self.dismissedKey)
        NotificationCenter.default.post(name: Self.notification, object: nil)
    }
}
