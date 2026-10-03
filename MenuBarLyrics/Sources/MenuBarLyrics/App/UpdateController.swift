import AppKit
import Sparkle

@MainActor
final class UpdateController {
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
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
