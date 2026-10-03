import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(title: L10n.text("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        applicationMenu.addItem(quitItem)
        mainMenu.addItem(applicationItem)
        mainMenu.setSubmenu(applicationMenu, for: applicationItem)
        NSApp.mainMenu = mainMenu
        if UserDefaults.standard.object(forKey: AppPreferences.showInDockKey) == nil {
            UserDefaults.standard.set(AppPreferences.showInDock, forKey: AppPreferences.showInDockKey)
        }
        NSApp.setActivationPolicy(AppPreferences.showInDock ? .regular : .accessory)
        UpdateController.shared.startIfStable()
        controller = MenuBarController()
        controller?.start()
        LoginAtLaunchPolicy.configureIfNeeded()
        controller?.showSettings()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(reopenFromSecondLaunch(_:)),
            name: Notification.Name("\(Bundle.main.bundleIdentifier ?? "app.notchmuse.mac").reopen"), object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        controller?.stop()
        controller = nil
    }

    @objc private func reopenFromSecondLaunch(_ notification: Notification) {
        controller?.showSettings()
    }
}
