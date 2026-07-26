import Foundation

#if DEBUG
import OSLog
#endif

enum DebugLog {
#if DEBUG
    private static let spotifyLogger = Logger(subsystem: "app.notchmuse.mac", category: "Spotify")
    private static let lyricsLogger = Logger(subsystem: "app.notchmuse.mac", category: "Lyrics")
#endif

    static func spotify(_ message: String) {
#if DEBUG
        spotifyLogger.debug("\(message, privacy: .public)")
#endif
    }

    static func lyrics(_ message: String) {
#if DEBUG
        lyricsLogger.debug("\(message, privacy: .public)")
#endif
    }

    static func lyricsDiagnostic(_ message: @autoclosure () -> String) {
#if DEBUG
        let text = message()
        lyricsLogger.debug("\(text, privacy: .public)")
#endif
    }

    static func metadata(_ text: String) -> String {
#if DEBUG
        if ProcessInfo.processInfo.environment["NOTCHMUSE_MATCHER_AUDIT_PLAINTEXT"] == "1" {
            return String(text.prefix(80))
        }
        var hash: UInt64 = 5381
        for scalar in text.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return String(format: "%08llx", hash & 0xffff_ffff)
#else
        return ""
#endif
    }
}
