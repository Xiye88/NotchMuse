import Foundation

struct AppleMusicAdapter: MusicPlayerAdapter {
    let source = PlayerSource.appleMusic

    func snapshot() async -> MusicPlayerSnapshot {
        let script = """
        if application "Music" is running then
          tell application "Music"
            set s to player state as string
            if s is "stopped" then return "stopped"
            set t to current track
            set sep to ASCII character 31
            set trackID to ""
            try
              set trackID to persistent ID of t as string
            end try
            return s & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (duration of t as string) & sep & (player position as string) & sep & trackID
          end tell
        else
          return "closed"
        end if
        """

        do {
            return Self.parse(try runOSAScript(script))
        } catch {
            DebugLog.spotify("Apple Music read failed: \(error.localizedDescription)")
            return .unavailable
        }
    }

    static func parse(_ output: String) -> MusicPlayerSnapshot {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "closed" else { return .closed }
        guard trimmed != "stopped" else { return .stopped }
        let fields = trimmed.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 7,
              let duration = Double(fields[4]),
              let position = Double(fields[5]) else {
            return .unavailable
        }
        guard fields[0] == "playing" || fields[0] == "paused" else { return .unavailable }
        let state: PlayerPlaybackState = fields[0] == "playing" ? .playing : .paused
        let track = NowPlayingTrack(
            title: fields[1],
            artist: fields[2],
            album: fields[3],
            duration: duration,
            playbackPosition: position,
            playbackState: state,
            playerSource: .appleMusic,
            nativeTrackID: fields[6].isEmpty ? nil : fields[6],
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: fields[1], album: fields[3])
        )
        return state == .playing ? .playing(track) : .paused(track)
    }

    private func runOSAScript(_ script: String) throws -> String {
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
            throw NSError(domain: "AppleMusicAdapter", code: Int(process.terminationStatus))
        }
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}
