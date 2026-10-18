import Foundation

struct SpotifyTrack: Equatable, Sendable {
    let name: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let nativeTrackID: String?

    init(name: String, artist: String, album: String, duration: TimeInterval, nativeTrackID: String? = nil) {
        self.name = name
        self.artist = artist
        self.album = album
        self.duration = duration
        self.nativeTrackID = nativeTrackID
    }
}

enum SpotifyState: Equatable {
    case closed
    case unavailable
    case playing(track: SpotifyTrack, position: TimeInterval)
    case paused(track: SpotifyTrack, position: TimeInterval)
}

enum SpotifyReader {
    static func read() async -> SpotifyState {
        let script = """
        if application "Spotify" is running then
          tell application "Spotify"
            set s to player state as string
            set t to current track
            set sep to ASCII character 31
            set trackID to ""
            set trackURL to ""
            try
              set trackID to id of t as string
            end try
            try
              set trackURL to spotify url of t as string
            end try
            return s & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (duration of t as string) & sep & (player position as string) & sep & trackID & sep & trackURL
          end tell
        else
          return "closed"
        end if
        """

        let output: String
        do {
            output = try runOSAScript(script)
        } catch {
            DebugLog.spotify("Spotify read failed: \(error.localizedDescription)")
            return .unavailable
        }

        return parse(output)
    }

    static func parse(_ output: String) -> SpotifyState {
        if output.trimmingCharacters(in: .whitespacesAndNewlines) == "closed" {
            return .closed
        }

        let fields = output.trimmingCharacters(in: .newlines).split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard (fields.count == 6 || fields.count == 8),
              let durationMs = Double(fields[4]),
              let position = Double(fields[5]) else {
            DebugLog.spotify("Spotify returned an unreadable response")
            return .unavailable
        }

        let track = SpotifyTrack(
            name: fields[1],
            artist: fields[2],
            album: fields[3],
            duration: durationMs / 1000,
            nativeTrackID: fields.count == 8 ? (nativeTrackID(from: fields[6]) ?? nativeTrackID(from: fields[7])) : nil
        )

        return fields[0] == "playing"
            ? .playing(track: track, position: position)
            : .paused(track: track, position: position)
    }

    /// Preserve only a canonical Spotify catalog track URI. Local files and episodes
    /// are not track IDs and must never be submitted to a catalog lookup.
    static func nativeTrackID(from value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: String
        if value.hasPrefix("spotify:track:") {
            identifier = String(value.dropFirst("spotify:track:".count))
        } else if let url = URLComponents(string: value),
                  url.scheme == "https", url.host == "open.spotify.com",
                  url.user == nil, url.password == nil, url.port == nil {
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.count == 2, parts[0] == "track" {
                identifier = parts[1]
            } else if parts.count == 3, parts[0].hasPrefix("intl-"), parts[1] == "track" {
                identifier = parts[2]
            } else {
                return nil
            }
        } else {
            identifier = value
        }
        guard identifier.count == 22,
              identifier.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else { return nil }
        return "spotify:track:\(identifier)"
    }

    private static func runOSAScript(_ script: String) throws -> String {
        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()
        input.fileHandleForWriting.write(Data(script.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "SpotifyReader", code: Int(process.terminationStatus))
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
