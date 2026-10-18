import Foundation
import LyricsCore

enum PackagedSelfTests {
    @MainActor static func run() {
        let preview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        guard LyricsRuntimeCapabilities.current, LyricsClient().hasIdentityResolver else {
            fail("Spotify identity recovery missing from packaged configuration")
        }
        guard LyricsRuntimeCapabilities.enabled(preview: false, version: 1),
              !LyricsRuntimeCapabilities.enabled(preview: false, version: nil),
              !LyricsRuntimeCapabilities.enabled(preview: false, version: 2),
              LyricsRuntimeCapabilities.enabled(preview: true, version: nil) else { fail("capability policy") }
        let track = SpotifyTrack(name: "Synthetic", artist: "Fixture", album: "Fixture", duration: 180)
        guard MenuBarController.shouldUpdateTrack(current: track, currentIdentity: "same", next: track,
                nextIdentity: "same", force: false, resumed: true, playerSource: .netEaseMusic,
                identityRecoveryEnabled: LyricsRuntimeCapabilities.current),
              !MenuBarController.shouldUpdateTrack(current: track, currentIdentity: "same", next: track,
                nextIdentity: "same", force: false, resumed: true, playerSource: .spotify,
                identityRecoveryEnabled: LyricsRuntimeCapabilities.current),
              !MenuBarController.shouldUpdateTrack(current: track, currentIdentity: "same", next: track,
                nextIdentity: "same", force: false, identityRecoveryEnabled: true) else { fail("resume/seek routing") }
        guard LyricsFeedback.searching.displayText != LyricsFeedback.notFound.displayText,
              LyricsFeedback.timeout.displayText != LyricsFeedback.notFound.displayText,
              !LyricsClient.shouldSurfaceTimeout(candidates: [], statuses: ["source": "empty"]),
              LyricsClient.shouldSurfaceTimeout(candidates: [], statuses: ["source": "timeout"]) else { fail("loading/empty/timeout classification") }
        if !preview {
            guard Bundle.main.object(forInfoDictionaryKey: "NotchMuseShadowURL") == nil else { fail("production shadow endpoint") }
        }
        print("PASS: packaged core identity capability, resume routing, UI classification; preview=\(preview)")
        let gap = [LyricLine(time: 10, text: "123456", endTime: 12), LyricLine(time: 17, text: "Next")]
        guard LyricClock.moment(at: 12, in: gap)?.progress == 1,
              LyricClock.moment(at: 16, in: gap)?.progress == 1,
              LyricClock.moment(at: 17, in: gap)?.identity == 1 else { fail("rich timing trailing gap") }
        let words = LyricParser.parseYRC("[10000,2000](10000,300,0)A(11000,1000,0)B")
        guard words.first?.timingFidelity == .word,
              LyricClock.moment(at: 11.5, in: words)?.highlight?.fraction == 0.5 else { fail("nonuniform word timing") }
        guard let resources = Bundle.main.resourceURL else {
            fail("bundle resources are missing")
        }

        for path in [
            "en.lproj/Localizable.strings",
            "zh-Hans.lproj/Localizable.strings",
            "WeChatSupport.jpg",
            "LICENSES/Sparkle.txt",
            "../Frameworks/Sparkle.framework/Sparkle",
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
