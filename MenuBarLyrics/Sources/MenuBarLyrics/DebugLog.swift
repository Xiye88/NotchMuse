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
}
