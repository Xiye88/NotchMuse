import Foundation

enum DebugLog {
    static func spotify(_ message: String) { }
}

@main struct SpotifyIdentityTests {
    static func main() {
        var checks = 0
        func check(_ result: Bool, _ name: String) {
            precondition(result, name)
            checks += 1
        }
        let identifier = "4uLU6hMCjMI75M1A2tKUQC"
        let uri = "spotify:track:\(identifier)"
        for input in [identifier, uri, " \(uri)\n", "https://open.spotify.com/track/\(identifier)?si=ignored", "https://open.spotify.com/intl-zh/track/\(identifier)"] {
            check(SpotifyReader.nativeTrackID(from: input) == uri, "normalizes catalog identity")
        }
        for input in ["", "missing value", "spotify:episode:\(identifier)", "spotify:local:artist:album:track:200", "spotify:track:\(identifier):extra", "https://example.com/track/\(identifier)", "https://open.spotify.com.evil.example/track/\(identifier)", "https://open.spotify.com/album/\(identifier)", "https://user@open.spotify.com/track/\(identifier)", "http://open.spotify.com/track/\(identifier)", "https://open.spotify.com:444/track/\(identifier)", "https://open.spotify.com/track/short", "é1234567890123456789012", "123456789012345678901_"] {
            check(SpotifyReader.nativeTrackID(from: input) == nil, "rejects non-catalog identity")
        }
        let sep = "\u{1F}"
        let metadata = ["playing", "A Song (Live)", "Artist", "Album", "242500", "30.4"]
        guard case let .playing(track, position) = SpotifyReader.parse((metadata + [uri, ""]).joined(separator: sep)) else {
            fatalError("playing parse failed")
        }
        check(track.nativeTrackID == uri, "preserves identity")
        check(track.name == metadata[1] && track.artist == metadata[2] && track.album == metadata[3], "preserves metadata and version")
        check(track.duration == 242.5 && position == 30.4, "preserves clock units")
        guard case let .playing(fallback, _) = SpotifyReader.parse((metadata + ["missing value", "https://open.spotify.com/track/\(identifier)"]).joined(separator: sep)) else {
            fatalError("URL fallback failed")
        }
        check(fallback.nativeTrackID == uri, "URL rescues unavailable ID")
        guard case let .playing(noID, _) = SpotifyReader.parse((metadata + ["", ""]).joined(separator: sep)) else {
            fatalError("optional identity suppressed metadata")
        }
        check(noID.nativeTrackID == nil, "missing identity keeps metadata path")
        guard case let .playing(legacy, _) = SpotifyReader.parse(metadata.joined(separator: sep)) else {
            fatalError("legacy response failed")
        }
        check(legacy.nativeTrackID == nil, "legacy response remains valid")
        check(SpotifyTrack(name: "A", artist: "B", album: "C", duration: 1).nativeTrackID == nil, "existing initializer remains valid")
        var paused = metadata; paused[0] = "paused"
        guard case .paused = SpotifyReader.parse((paused + [uri, ""]).joined(separator: sep)) else { fatalError("paused mapping") }
        checks += 1
        check(SpotifyReader.parse("closed\n") == .closed, "closed mapping")
        check(SpotifyReader.parse("broken") == .unavailable, "invalid response safely fails")
        print("PASS \(checks) Spotify identity checks")
    }
}
