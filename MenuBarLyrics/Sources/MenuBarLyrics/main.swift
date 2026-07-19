import AppKit
import Darwin

final class SingleInstanceLock {
    private let descriptor: Int32

    init?(path: String) {
        let descriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        self.descriptor = descriptor
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}

if CommandLine.arguments.contains("--self-test") {
    SelfTests.run()
    exit(0)
}

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app.notchmuse.mac"
let lockPath = FileManager.default.temporaryDirectory
    .appendingPathComponent("\(bundleIdentifier).lock").path

guard let instanceLock = SingleInstanceLock(path: lockPath) else {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
        .activate(options: .activateAllWindows)
    exit(0)
}

if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    runningApp.activate(options: .activateAllWindows)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
withExtendedLifetime(instanceLock) {
    app.run()
}
