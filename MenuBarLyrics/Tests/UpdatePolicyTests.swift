import AppKit
import Sparkle

enum AppLanguage { case english, simplifiedChinese }
enum AppPreferences { static let language = AppLanguage.english }

@main enum UpdatePolicyTests {
    @MainActor static func main() throws {
        var checks = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label)
            checks += 1
        }
        var launch = UpdatePolicy()
        check(launch.beginStartupCheck(checksEnabled: true, sessionInProgress: false), "enabled launch starts background check regardless of previous schedule")
        check(!launch.beginStartupCheck(checksEnabled: true, sessionInProgress: true), "busy launch cannot start concurrent check")
        check(launch.preparedUpdate(checksEnabled: true, automaticInstall: true), "startup automatic update takes immediate installation ownership")
        launch.finishedCycle(succeeded: true)
        check(!launch.takePreparedNotice(canCheck: true), "startup install does not duplicate a prepared notice")

        var disabled = UpdatePolicy()
        check(!disabled.beginStartupCheck(checksEnabled: false, sessionInProgress: false), "explicit check-off prevents startup request")
        check(!disabled.preparedUpdate(checksEnabled: false, automaticInstall: true), "automatic install requires enabled checks")
        disabled.finishedCycle(succeeded: true)
        check(disabled.takePreparedNotice(canCheck: true), "already prepared update falls back to user-confirmed installation")

        var toggled = UpdatePolicy()
        _ = toggled.beginStartupCheck(checksEnabled: true, sessionInProgress: false)
        check(!toggled.preparedUpdate(checksEnabled: true, automaticInstall: false), "switch off while downloading prevents immediate restart")
        toggled.finishedCycle(succeeded: true)
        check(!toggled.takePreparedNotice(canCheck: false), "busy cycle retains prepared notification without another check")
        check(toggled.takePreparedNotice(canCheck: true), "prepared notification resumes when Sparkle is ready")
        check(!toggled.takePreparedNotice(canCheck: true), "prepared notification is consumed once")

        var periodic = UpdatePolicy()
        check(!periodic.preparedUpdate(checksEnabled: true, automaticInstall: true), "long-running periodic download cannot restart unexpectedly")
        periodic.finishedCycle(succeeded: true)
        check(periodic.takePreparedNotice(canCheck: true), "periodic prepared update prompts without waiting for an impatient weekly reminder")
        var failed = UpdatePolicy()
        _ = failed.preparedUpdate(checksEnabled: true, automaticInstall: true)
        failed.finishedCycle(succeeded: false)
        check(!failed.takePreparedNotice(canCheck: true), "failed background cycle does not generate a notice")
        var manual = UpdatePolicy()
        _ = manual.beginStartupCheck(checksEnabled: true, sessionInProgress: false)
        manual.beginUserCheck()
        check(!manual.preparedUpdate(checksEnabled: true, automaticInstall: true), "manual update retains user installation control")
        manual.beginUserCheck()
        check(!manual.takePreparedNotice(canCheck: true), "manual flow supersedes queued prepared notice")

        check(UpdatePolicy.permitsFeed(isPreview: true, url: URL(string:"http://127.0.0.1:1337/appcast.xml")), "Preview loopback allowed")
        for url in ["https://notchmuse.com/appcast.xml", "https://invalid.localhost/appcast.xml", "http://127.0.0.1:1337/wrong", "http://user@127.0.0.1:1337/appcast.xml"] {
            check(!UpdatePolicy.permitsFeed(isPreview:true,url:URL(string:url)), "Preview cannot adopt a public or malformed feed")
        }
        check(UpdatePolicy.permitsFeed(isPreview:false,url:URL(string:"https://notchmuse.com/appcast.xml")), "Stable feed remains permitted")

        // Exercise Sparkle's real preference fallback and setters using a disposable host domain.
        let identity = "app.notchmuse.updater-tests.\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identity).appendingPathComponent("Host.app")
        let contents = directory.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: identity)!
        defer {
            defaults.removePersistentDomain(forName: identity)
            try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
        }
        let info: [String:Any] = ["CFBundleIdentifier":identity,"CFBundleName":"Host","CFBundleVersion":"71","CFBundlePackageType":"APPL",
                                "SUFeedURL":"http://127.0.0.1:1337/appcast.xml","SUEnableAutomaticChecks":true,
                                "SUAllowsAutomaticUpdates":true,"SUAutomaticallyUpdate":true,"SUScheduledCheckInterval":86400,"NotchMusePreview":true]
        try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:contents.appendingPathComponent("Info.plist"))
        let bundle = Bundle(url: directory)!
        func updater() -> SPUUpdater {
            SPUUpdater(hostBundle:bundle,applicationBundle:bundle,userDriver:SPUStandardUserDriver(hostBundle:bundle,delegate:nil),delegate:nil)
        }
        let initial = updater()
        check(initial.automaticallyChecksForUpdates && initial.automaticallyDownloadsUpdates, "unset preferences inherit enabled plist defaults")
        check(initial.updateCheckInterval == 86400, "native Sparkle timer inherits daily interval")
        check(defaults.object(forKey:"SUAutomaticallyUpdate") == nil && defaults.object(forKey:"SUEnableAutomaticChecks") == nil, "reading defaults does not write an opt-in on each launch")
        initial.automaticallyDownloadsUpdates = false
        initial.automaticallyChecksForUpdates = false
        let relaunched = updater()
        check(!relaunched.automaticallyChecksForUpdates && !relaunched.automaticallyDownloadsUpdates, "explicit false persists across updater creation")
        check(defaults.object(forKey:"SUAutomaticallyUpdate") as? Bool == false, "explicit automatic-install off is stored")
        relaunched.automaticallyDownloadsUpdates = true
        check(!relaunched.automaticallyChecksForUpdates && relaunched.automaticallyDownloadsUpdates, "independent install selection does not turn automatic checks back on")
        relaunched.automaticallyChecksForUpdates = true
        check(relaunched.automaticallyDownloadsUpdates, "re-enabling checks preserves independent installation preference")
        let controller = UpdateController(hostBundle: bundle)
        check(controller.responds(to: NSSelectorFromString("updater:shouldProceedWithUpdate:updateCheck:error:")), "Sparkle can actually invoke the optional Objective-C enclosure guard")
        check(controller.responds(to: NSSelectorFromString("updater:willInstallUpdateOnQuit:immediateInstallationBlock:")), "Sparkle can invoke automatic installation delegate")
        check(controller.responds(to:NSSelectorFromString("feedURLStringForUpdater:")), "Sparkle invokes Preview feed override through its actual selector")
        check(controller.feedURLString(for:initial) == "http://127.0.0.1:1337/appcast.xml", "Preview feed callback ignores any stale external override")
        // Invoke the actual Objective-C callback ABI; Swift 6.3 crashes compiling optional throwing protocol calls.
        let selector = NSSelectorFromString("updater:shouldProceedWithUpdate:updateCheck:error:")
        typealias Proceed = @convention(c) (AnyObject, Selector, SPUUpdater, SUAppcastItem, Int, AutoreleasingUnsafeMutablePointer<NSError?>) -> ObjCBool
        let proceed = unsafeBitCast(controller.method(for: selector), to: Proceed.self)
        let external = SUAppcastItem(dictionary:["enclosure":["url":"https://example.com/Stable.dmg","sparkle:version":"72"]])!
        var refusal: NSError?
        check(!proceed(controller, selector, initial, external, SPUUpdateCheck.updatesInBackground.rawValue, &refusal).boolValue,
              "actual Sparkle Objective-C callback rejects an external archive")
        check(refusal?.domain == SUSparkleErrorDomain, "real refusal propagates through NSError bridge")
        let local = SUAppcastItem(dictionary:["enclosure":["url":"http://127.0.0.1:1337/Preview.dmg","sparkle:version":"72"]])!
        var localError: NSError?
        check(proceed(controller, selector, initial, local, SPUUpdateCheck.updatesInBackground.rawValue, &localError).boolValue && localError == nil,
              "actual Sparkle Objective-C callback accepts a loopback archive")
        print("PASS: \(checks) update-policy and real Sparkle preference checks (no updater started)")
    }
}
