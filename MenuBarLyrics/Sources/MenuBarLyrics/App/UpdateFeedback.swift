import Foundation
import Sparkle

enum UpdateFeedback {
    // Build numbers, not localized display versions, are Sparkle's update identity.
    static func isCurrentOrAhead(currentBuild: String, latestBuild: String?) -> Bool {
        guard let latestBuild,
              let current = UInt64(currentBuild), current > 0,
              let latest = UInt64(latestBuild), latest > 0 else { return false }
        return SUStandardVersionComparator.default.compareVersion(latestBuild, toVersion: currentBuild) != .orderedDescending
    }

    static func noUpdateError(_ error: NSError, version: String, build: String, chinese: Bool) -> NSError {
        let item = error.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem
        let reason = error.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber
        let confirmed = reason?.intValue == Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue)
            || reason?.intValue == Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue)
        var info = error.userInfo
        if confirmed && isCurrentOrAhead(currentBuild: build, latestBuild: item?.versionString) {
            info[NSLocalizedDescriptionKey] = chinese ? "已是最新版本" : "You're up to date"
            info[NSLocalizedRecoverySuggestionErrorKey] = chinese
                ? "当前版本：NotchMuse \(version)（Build \(build)）。更新源中没有更高版本。"
                : "Current version: NotchMuse \(version) (Build \(build)). No newer version is available in this update source."
        } else {
            info[NSLocalizedDescriptionKey] = chinese ? "无法确认更新状态" : "Unable to confirm update status"
            info[NSLocalizedRecoverySuggestionErrorKey] = chinese
                ? "更新信息无效或没有适用于此 Mac 的更新。请稍后重新检查。"
                : "The update information is invalid or no update is compatible with this Mac. Please check again later."
        }
        return NSError(domain: error.domain, code: error.code, userInfo: info)
    }

    static func isNetworkError(_ error: NSError) -> Bool {
        var current: NSError? = error
        for _ in 0..<8 {
            guard let value = current else { return false }
            if value.domain == NSURLErrorDomain {
                return [NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                        NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed,
                        NSURLErrorNotConnectedToInternet, NSURLErrorSecureConnectionFailed].contains(value.code)
            }
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }
}
