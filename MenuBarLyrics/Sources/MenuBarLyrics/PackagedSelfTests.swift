import Foundation

enum PackagedSelfTests {
    static func run() {
        guard let resources = Bundle.main.resourceURL else {
            fail("bundle resources are missing")
        }

        for path in [
            "en.lproj/Localizable.strings",
            "zh-Hans.lproj/Localizable.strings",
            "MediaRemoteBridge/MediaRemoteAdapter.framework/MediaRemoteAdapter",
            "MediaRemoteBridge/MediaRemoteAdapterTestClient",
            "MediaRemoteBridge/mediaremote-adapter.pl",
            "MediaRemoteBridge/mediaremote-watchdog.sh"
        ] {
            guard FileManager.default.fileExists(atPath: resources.appendingPathComponent(path).path) else {
                fail("packaged resource is missing: \(path)")
            }
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Packaged self-test failed: \(message)\n", stderr)
        exit(1)
    }
}
