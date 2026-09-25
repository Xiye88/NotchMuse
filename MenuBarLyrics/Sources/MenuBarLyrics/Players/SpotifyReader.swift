import Foundation

struct SpotifyTrack: Equatable {
    let name: String
    let artist: String
    let album: String
    let duration: TimeInterval
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
            return s & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (duration of t as string) & sep & (player position as string)
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

        if output.trimmingCharacters(in: .whitespacesAndNewlines) == "closed" {
            return .closed
        }

        let fields = output.trimmingCharacters(in: .newlines).split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 6,
              let durationMs = Double(fields[4]),
              let position = Double(fields[5]) else {
            DebugLog.spotify("Spotify returned an unreadable response")
            return .unavailable
        }

        let track = SpotifyTrack(
            name: fields[1],
            artist: fields[2],
            album: fields[3],
            duration: durationMs / 1000
        )

        return fields[0] == "playing"
            ? .playing(track: track, position: position)
            : .paused(track: track, position: position)
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
