import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = MenuBarController()
        controller?.start()
        if CommandLine.arguments.contains("--show-settings") {
            controller?.showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.reveal()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        controller = nil
    }
}
