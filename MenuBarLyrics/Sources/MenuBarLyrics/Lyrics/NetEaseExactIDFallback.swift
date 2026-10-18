import Foundation
import CommonCrypto
import OSLog
import LyricsCore

/// Authorize a local ID only against live MediaRemote ownership.
/// Local-state format: CloudLyrics-for-macOS (MIT), commit 6ef1beff400aa6b2ffb9113fb67551c74924f8c5.
/// Reads focused values from the WAL without opening/mutating LevelDB; never reads SSTables.
struct NetEaseExactIDFallback {
    struct State: Equatable {
        let songID: String
        let position: Double
        let duration: Double
    }

    func syncedLyrics(for track: SpotifyTrack, expectedIdentifier: String?) async throws -> [LyricLine] {
        try await self.candidate(for: track, expectedIdentifier: expectedIdentifier)?.document.normalizedLines ?? []
    }

    func candidate(for track: SpotifyTrack, expectedIdentifier: String?) async throws -> LyricsCandidate? {
        guard LyricsRuntimeCapabilities.current else { return nil }
        guard let expectedIdentifier, !expectedIdentifier.isEmpty,
              let before = await snapshot(), (before.contentItemIdentifier ?? before.uniqueIdentifier?.rawValue) == expectedIdentifier, Self.matches(before, track: track),
              let candidate = await localState(for: before),
              let authorized = await snapshot(), Self.samePlayback(before, authorized) else { return nil }
        try Task.checkCancellation()
        let lines = try await NetEaseLyricsSource().lyricLines(songID: candidate.songID)
        try Task.checkCancellation()
        guard !lines.isEmpty, let after = await snapshot(), Self.samePlayback(before, after),
              let confirmed = await localState(for: after), confirmed.songID == candidate.songID,
              let final = await snapshot(), Self.samePlayback(before, final) else { return nil }
        try Task.checkCancellation()
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            Logger(subsystem: "app.notchmuse.mac.preview", category: "ExactID").notice("NetEaseExactID source=fresh_wal_queue_mediaremote song_id=\(candidate.songID, privacy: .public) line_count=\(lines.count)")
        }
        DebugLog.lyricsDiagnostic("matcher.exact_id provider=NetEaseExactID source=fresh_wal_queue_mediaremote song_id=\(candidate.songID) line_count=\(lines.count)")
        // WAL + queue + live ownership independently bind this metadata to the catalog ID.
        return LyricsCandidate(document: TimedLyricDocument(lines: lines), provider: "NetEaseExactID (Preview)",
            sourcePlatform: "netease", sourceTrackID: candidate.songID, sourceTitle: track.name,
            sourceArtist: track.artist, sourceAlbum: track.album, sourceDuration: candidate.duration,
            liveIdentityVerified: true)
    }

    private func snapshot() async -> MediaRemoteEvent? {
        await Task.detached { try? MediaRemoteBridge.bundled().get(timeout: 3) }.value
    }

    private func localState(for event: MediaRemoteEvent) async -> State? {
        await Task.detached {
            Self.authorizedState(root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.netease.163music"), event: event, now: Date())
        }.value
    }

    static func normalized(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func matches(_ event: MediaRemoteEvent, track: SpotifyTrack) -> Bool {
        event.bundleIdentifier == "com.netease.163music" && event.playing &&
        !(event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue ?? "").isEmpty &&
        normalized(event.title) == normalized(track.name) &&
        normalized(event.artist ?? "") == normalized(track.artist) &&
        normalized(event.album ?? "") == normalized(track.album) &&
        track.duration > 0 && abs((event.duration ?? 0) - track.duration) < 1
    }

    static func samePlayback(_ before: MediaRemoteEvent, _ after: MediaRemoteEvent) -> Bool {
        matches(after, track: SpotifyTrack(name: before.title, artist: before.artist ?? "", album: before.album ?? "", duration: before.duration ?? 0)) &&
        before.contentItemIdentifier == after.contentItemIdentifier && before.uniqueIdentifier == after.uniqueIdentifier
    }

    static func authorizedState(root: URL, event: MediaRemoteEvent, now: Date) -> State? {
        guard event.bundleIdentifier == "com.netease.163music", event.playing else { return nil }
        let directory = root.appendingPathComponent("Documents/storage/CEFCache/Local Storage/leveldb")
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
        let logs = files.filter { $0.pathExtension == "log" }.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]), let date = values.contentModificationDate, let size = values.fileSize else { return nil }
            return (url, date, size)
        }.sorted { $0.1 > $1.1 }
        // Only the newest live WAL can authorize playback. No older-file fallback.
        guard let (url, modified, size) = logs.first, now.timeIntervalSince(modified) >= -1,
              now.timeIntervalSince(modified) <= 5, let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        let start = max(0, ((size - 128 * 1024 + 32767) / 32768) * 32768)
        guard (try? file.seek(toOffset: UInt64(start))) != nil,
              let data = try? file.read(upToCount: 128 * 1024), let state = latestState(in: data) else { return nil }
        let queueURL = root.appendingPathComponent("Documents/storage/file_storage/webdata/file/playingList")
        guard let queueFile = try? FileHandle(forReadingFrom: queueURL) else { return nil }
        defer { try? queueFile.close() }
        guard let queueData = try? queueFile.read(upToCount: 4 * 1024 * 1024 + 1), queueData.count <= 4 * 1024 * 1024,
              let queue = try? JSONSerialization.jsonObject(with: queueData) as? [String: Any], let items = queue["list"] as? [[String: Any]],
              let item = items.first(where: { String(describing: $0["id"] ?? "") == state.songID }),
              item["resourceType"] as? String == "track", let song = item["track"] as? [String: Any] else { return nil }
        return correlated(state: state, song: song, event: event) ? state : nil
    }

    static func correlated(state: State, song: [String: Any], event: MediaRemoteEvent) -> Bool {
        let artists = (song["artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }.map(normalized)
        let currentArtists = (event.artist ?? "").components(separatedBy: "/").map(normalized).filter { !$0.isEmpty }
        guard let title = song["name"] as? String, let milliseconds = song["duration"] as? Double,
              let position = event.elapsedTimeNow, let duration = event.duration,
              duration > 0, position.isFinite, state.position.isFinite, state.duration.isFinite,
              normalized(title) == normalized(event.title), !currentArtists.isEmpty,
              currentArtists.allSatisfy({ artists.contains($0) }),
              abs(milliseconds / 1000 - duration) < 1, abs(state.duration - duration) < 1,
              abs(state.position - position) < 3 else { return false }
        if let album = song["album"] as? [String: Any], let name = album["name"] as? String, !name.isEmpty {
            guard normalized(name) == normalized(event.album ?? "") else { return false }
        }
        return true
    }

    /// Parse complete LevelDB physical records, then exact WriteBatch key/value pairs.
    /// A deleted/corrupt lastPlaying value clears the candidate instead of reviving an older one.
    static func latestState(in data: Data) -> State? {
        let bytes = [UInt8](data)
        var index = 0, fragment = [UInt8]()
        var candidate: State?
        func consume(_ record: [UInt8]) {
            guard record.count >= 12 else { candidate = nil; return }
            let count = Int(record[8]) | Int(record[9]) << 8 | Int(record[10]) << 16 | Int(record[11]) << 24
            guard count <= 10000 else { candidate = nil; return }
            var cursor = 12
            for _ in 0..<count {
                guard cursor < record.count else { candidate = nil; return }
                let tag = record[cursor]; cursor += 1
                guard tag == 0 || tag == 1, let key = field(record, cursor: &cursor) else { candidate = nil; return }
                let value = tag == 1 ? field(record, cursor: &cursor) : []
                guard let value else { candidate = nil; return }
                if key.suffix(13) == [0, 1] + Array("lastPlaying".utf8) { candidate = tag == 1 ? decode(value) : nil }
            }
            if cursor != record.count { candidate = nil }
        }
        while index + 7 <= bytes.count {
            let remaining = 32768 - index % 32768
            if remaining < 7 {
                let end = min(index + remaining, bytes.count)
                guard bytes[index..<end].allSatisfy({ $0 == 0 }) else { return nil }
                index = end
                continue
            }
            let length = Int(bytes[index + 4]) | Int(bytes[index + 5]) << 8
            let type = bytes[index + 6]
            if length == 0 && type == 0 {
                let end = min(index + remaining, bytes.count)
                guard fragment.isEmpty, bytes[index..<end].allSatisfy({ $0 == 0 }) else { return nil }
                index = end
                continue
            }
            guard length <= remaining - 7, index + 7 + length <= bytes.count else { return nil }
            let payload = Array(bytes[(index + 7)..<(index + 7 + length)])
            let checksum = UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2]) << 16 | UInt32(bytes[index + 3]) << 24
            guard checksum == maskedCRC([type] + payload) else { return nil }
            index += 7 + length
            switch type {
            case 1: guard fragment.isEmpty else { return nil }; consume(payload)
            case 2: guard fragment.isEmpty else { return nil }; fragment = payload
            case 3: guard !fragment.isEmpty else { return nil }; fragment += payload
            case 4: guard !fragment.isEmpty else { return nil }; fragment += payload; consume(fragment); fragment = []
            default: return nil
            }
        }
        guard fragment.isEmpty, index == bytes.count else { return nil }
        return candidate
    }

    static func maskedCRC(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0x82f63b78 : 0) }
        }
        crc = ~crc
        return ((crc >> 15) | (crc << 17)) &+ 0xa282ead8
    }

    private static func field(_ bytes: [UInt8], cursor: inout Int) -> [UInt8]? {
        var length = 0, shift = 0
        while cursor < bytes.count && shift <= 28 {
            let byte = bytes[cursor]; cursor += 1
            length |= Int(byte & 127) << shift
            if byte < 128 {
                guard length <= bytes.count - cursor else { return nil }
                defer { cursor += length }
                return Array(bytes[cursor..<(cursor + length)])
            }
            shift += 7
        }
        return nil
    }

    private static func decode(_ value: [UInt8]) -> State? {
        guard value.first == 1, let base64 = String(bytes: value.dropFirst(), encoding: .utf8),
              let encrypted = Data(base64Encoded: base64), !encrypted.isEmpty, encrypted.count % 16 == 0 else { return nil }
        // Fixed public local format key; not a user credential.
        let key = Array(")(13daqP@ssw0rd~".utf8)
        var output = [UInt8](repeating: 0, count: encrypted.count + 16), written = 0
        let status = output.withUnsafeMutableBytes { out in
            encrypted.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), keyBytes.baseAddress, key.count, nil, input.baseAddress, encrypted.count, out.baseAddress, out.count, &written)
                }
            }
        }
        guard status == kCCSuccess, let json = try? JSONSerialization.jsonObject(with: Data(output.prefix(written))) as? [String: Any],
              let id = json["resourceId"] ?? json["trackId"], let position = json["current"] as? Double,
              let duration = json["resourceDuration"] as? Double else { return nil }
        if let type = json["resourceType"] as? String, type != "track" { return nil }
        let songID = String(describing: id)
        guard !songID.isEmpty, songID.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }), position.isFinite, duration.isFinite, position >= 0, duration > 0 else { return nil }
        return State(songID: songID, position: position, duration: duration)
    }
}
