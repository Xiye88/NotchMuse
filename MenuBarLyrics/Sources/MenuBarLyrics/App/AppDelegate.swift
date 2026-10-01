import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateController.shared.startIfStable()
        controller = MenuBarController()
        controller?.start()
        LoginAtLaunchPolicy.configureIfNeeded()
        controller?.showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        controller = nil
    }
}
