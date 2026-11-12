import Foundation

/// Sparkle owns scheduling and preferences; this only tracks the current launch and prepared notice.
struct UpdatePolicy {
    private var startupCheck = false
    private var preparedNotice = false

    mutating func beginStartupCheck(checksEnabled: Bool, sessionInProgress: Bool) -> Bool {
        guard checksEnabled, !sessionInProgress else { return false }
        startupCheck = true
        return true
    }

    mutating func beginUserCheck() {
        startupCheck = false
        preparedNotice = false
    }

    mutating func preparedUpdate(checksEnabled: Bool, automaticInstall: Bool) -> Bool {
        if startupCheck && checksEnabled && automaticInstall {
            startupCheck = false
            return true
        }
        preparedNotice = true
        return false
    }

    mutating func finishedCycle(succeeded: Bool) {
        startupCheck = false
        if !succeeded { preparedNotice = false }
    }

    mutating func takePreparedNotice(canCheck: Bool) -> Bool {
        guard canCheck, preparedNotice else { return false }
        preparedNotice = false
        return true
    }

    static func isLoopback(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "http" && url.host == "127.0.0.1" && url.port != nil &&
            url.user == nil && url.password == nil
    }

    static func permitsFeed(isPreview: Bool, url: URL?) -> Bool {
        !isPreview || (isLoopback(url) && url?.path == "/appcast.xml" && url?.query == nil && url?.fragment == nil)
    }
}
