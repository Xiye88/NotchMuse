import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    private var controller: SPUStandardUpdaterController?

    var isAvailable: Bool { controller != nil }
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    func startIfStable() {
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        guard !isPreview || URL(string: feed)?.host == "127.0.0.1" else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
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
