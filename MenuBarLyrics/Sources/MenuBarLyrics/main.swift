import AppKit

if CommandLine.arguments.contains("--self-test") {
    SelfTests.run()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
