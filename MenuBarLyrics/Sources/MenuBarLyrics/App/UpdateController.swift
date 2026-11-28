import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = UpdateController()

    private let hostBundle: Bundle
    private var updater: SPUUpdater?
    private var userDriver: NotchMuseUpdateDriver?
    private var retryAfterCycle = false
    private var policy = UpdatePolicy()
    private var isPreview: Bool { hostBundle.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true }
    private var configuredFeed: URL? {
        (hostBundle.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap(URL.init(string:))
    }

    init(hostBundle: Bundle = .main, updater: SPUUpdater? = nil) {
        self.hostBundle = hostBundle
        self.updater = updater
        super.init()
    }

    var isAvailable: Bool { updater != nil }
    var automaticUpdatesEnabled: Bool {
        // An upgraded checks-only user must be able to turn checks off in one click.
        get { updater?.automaticallyChecksForUpdates ?? false }
        set {
            guard let updater, updater.allowsAutomaticUpdates else { return }
            if newValue {
                updater.automaticallyDownloadsUpdates = true
                updater.automaticallyChecksForUpdates = true
            } else {
                updater.automaticallyChecksForUpdates = false
                updater.automaticallyDownloadsUpdates = false
            }
        }
    }
    var automaticallyChecksWithoutDownloading: Bool {
        guard let updater else { return false }
        return updater.automaticallyChecksForUpdates && !updater.automaticallyDownloadsUpdates
    }
    var allowsAutomaticUpdates: Bool { updater?.allowsAutomaticUpdates ?? false }

    func startIfStable() {
        guard UpdatePolicy.permitsFeed(isPreview: isPreview, url: configuredFeed) else { return }
        guard updater == nil else { return }
        let driver = NotchMuseUpdateDriver(hostBundle: hostBundle, delegate: self)
        driver.retry = { [weak self] in
            guard let self else { return }
            if self.updater?.canCheckForUpdates == true { self.checkForUpdates() }
            else { self.retryAfterCycle = true }
        }
        let updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: driver, delegate: self)
        do {
            try updater.start()
            self.userDriver = driver
            self.updater = updater
            // Sparkle cancels its pending initial scheduler cycle when this immediate launch check begins.
            if policy.beginStartupCheck(checksEnabled: updater.automaticallyChecksForUpdates, sessionInProgress: updater.sessionInProgress) {
                updater.checkForUpdatesInBackground()
            }
        } catch {
            NSLog("[NotchMuse Sparkle] startup failed %@", String(describing: error))
        }
    }

    func checkForUpdates() {
        guard let updater else { return }
        guard updater.canCheckForUpdates else {
            let chinese = AppPreferences.language == .simplifiedChinese
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = chinese ? "正在后台检查或下载更新" : "Update Check in Progress"
            alert.informativeText = chinese
                ? "请等待后台操作完成，然后可再次手动检查。"
                : "You can check again when the background operation finishes."
            alert.addButton(withTitle: chinese ? "好" : "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        policy.beginUserCheck()
        updater.checkForUpdates()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        // A stale defaults override must not connect Preview to the Stable feed.
        isPreview ? configuredFeed?.absoluteString : nil
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard !isPreview || UpdatePolicy.isLoopback(item.fileURL) else {
            throw NSError(domain: SUSparkleErrorDomain, code: Int(SUError.appcastError.rawValue),
                          userInfo: [NSLocalizedDescriptionKey: "Preview updates must use the local Preview source."])
        }
    }

    nonisolated func standardUserDriverShouldShowVersionHistory(for item: SUAppcastItem) -> Bool { false }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        NSLog("[NotchMuse Sparkle] scheduledCheck delay=%.1f interval=%.1f", delay, updater.updateCheckInterval)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        policy.finishedCycle(succeeded: error == nil)
        // Sparkle finishes its current session before a prepared update can be resumed in its native UI.
        DispatchQueue.main.async { [weak self, weak updater] in
            guard let self, let updater, updater.canCheckForUpdates, !updater.sessionInProgress else { return }
            guard self.retryAfterCycle || self.policy.takePreparedNotice(canCheck: true) else { return }
            self.retryAfterCycle = false
            self.checkForUpdates()
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        guard UpdatePolicy.permitsFeed(isPreview: isPreview, url: configuredFeed),
              !isPreview || UpdatePolicy.isLoopback(item.fileURL) else { return false }
        guard policy.preparedUpdate(checksEnabled: updater.automaticallyChecksForUpdates,
                                    automaticInstall: updater.automaticallyDownloadsUpdates) else { return false }
        // Sparkle's handler already dispatches installation asynchronously onto the main queue.
        // Invoke before returning YES so ownership can never stall an update cycle.
        immediateInstallHandler()
        return true
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        NSLog("[NotchMuse Sparkle] didFindValidUpdate build=%@", item.versionString)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("[NotchMuse Sparkle] didAbortWithError %@", String(describing: error as NSError))
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        NSLog("[NotchMuse Sparkle] willInstallUpdate build=%@", item.versionString)
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        NSLog("[NotchMuse Sparkle] updaterWillRelaunchApplication pid=%d", ProcessInfo.processInfo.processIdentifier)
    }
}

/// Customize feedback only. Sparkle still owns discovery, validation, download and installation.
@MainActor
final class NotchMuseUpdateDriver: SPUStandardUserDriver {
    var retry: (() -> Void)?

    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let presentation = UpdateFeedback.noUpdateError(error as NSError,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            chinese: AppPreferences.language == .simplifiedChinese)
        super.showUpdateNotFoundWithError(presentation, acknowledgement: acknowledgement)
    }

    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        guard UpdateFeedback.isNetworkError(error as NSError) else {
            // Integrity/signature/installation errors retain Sparkle's actual explanation.
            super.showUpdaterError(error, acknowledgement: acknowledgement)
            return
        }
        dismissUpdateInstallation()
        let chinese = AppPreferences.language == .simplifiedChinese
        let alert = NSAlert()
        alert.messageText = chinese ? "无法连接更新服务器" : "Unable to reach the update server"
        alert.informativeText = chinese ? "请检查网络连接后重试。尚未确认是否有新版本。" : "Check your connection and retry. Update availability has not been confirmed."
        alert.addButton(withTitle: chinese ? "重试" : "Retry")
        alert.addButton(withTitle: chinese ? "好" : "OK")
        let shouldRetry = alert.runModal() == .alertFirstButtonReturn
        acknowledgement()
        if shouldRetry {
            // Finish Sparkle's current session before allowing a user-requested retry.
            DispatchQueue.main.async { [weak self] in self?.retry?() }
        }
    }
}
