import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = UpdateController()

    private var updater: SPUUpdater?
    private var userDriver: NotchMuseUpdateDriver?
    private var retryAfterCycle = false

    var isAvailable: Bool { updater != nil }
    var automaticallyChecksForUpdates: Bool {
        get { updater?.automaticallyChecksForUpdates ?? false }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }

    func startIfStable() {
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        guard !isPreview || URL(string: feed)?.host == "127.0.0.1" else { return }
        guard updater == nil else { return }
        let driver = NotchMuseUpdateDriver(hostBundle: .main, delegate: self)
        driver.retry = { [weak self] in
            guard let self else { return }
            if self.updater?.canCheckForUpdates == true { self.checkForUpdates() }
            else { self.retryAfterCycle = true }
        }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        do {
            try updater.start()
            self.userDriver = driver
            self.updater = updater
        } catch {
            NSLog("[NotchMuse Sparkle] startup failed %@", String(describing: error))
        }
    }

    func checkForUpdates() {
        guard let updater, updater.canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    nonisolated func standardUserDriverShouldShowVersionHistory(for item: SUAppcastItem) -> Bool { false }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        guard retryAfterCycle else { return }
        retryAfterCycle = false
        // Sparkle finishes cleanup asynchronously; retry only after its session is ready.
        DispatchQueue.main.async { [weak self] in self?.checkForUpdates() }
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
