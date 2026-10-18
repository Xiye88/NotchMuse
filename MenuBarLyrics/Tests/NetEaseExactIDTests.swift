import Foundation
import CommonCrypto
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyrics(_ text: String) { }
    static func lyricsDiagnostic(_ text: @autoclosure () -> String) { }
}
actor FallbackEntry {
    var entered = false
    func enter() { entered = true }
}
@main struct ExactIDTests {
    static var checks = 0
    static func check(_ result: Bool, _ message: String) {
        precondition(result, message); checks += 1
    }
    static func event(_ updates: [String: Any] = [:]) throws -> MediaRemoteEvent {
        var data: [String: Any] = ["bundleIdentifier":"com.netease.163music", "playing":true, "title":"Song (Live)", "artist":"Artist", "album":"Album", "duration":242.5, "elapsedTimeNow":30.4, "contentItemIdentifier":"generation-1"]
        data.merge(updates) { _, new in new }
        return try JSONDecoder().decode(MediaRemoteEvent.self, from: JSONSerialization.data(withJSONObject:data))
    }
    static func varint(_ number: Int) -> [UInt8] {
        var n = number, bytes = [UInt8]()
        repeat { bytes.append(UInt8(n & 127) | (n > 127 ? 128 : 0)); n >>= 7 } while n > 0
        return bytes
    }
    static func value(_ updates: [String: Any] = [:]) throws -> [UInt8] {
        var json: [String: Any] = ["resourceId":"123", "current":30, "resourceDuration":242]
        json.merge(updates) { _, new in new }
        let plain = try JSONSerialization.data(withJSONObject:json)
        let key = Array(")(13daqP@ssw0rd~".utf8)
        var output = [UInt8](repeating:0, count:plain.count+16), written = 0
        let status = output.withUnsafeMutableBytes { out in plain.withUnsafeBytes { input in key.withUnsafeBytes { k in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), k.baseAddress,key.count,nil,input.baseAddress,plain.count,out.baseAddress,out.count,&written)
        } } }
        precondition(status == kCCSuccess)
        return [1] + Array(Data(output.prefix(written)).base64EncodedString().utf8)
    }
    static func batch(_ value: [UInt8], tag: UInt8 = 1, key: [UInt8] = [0,1] + Array("lastPlaying".utf8)) -> [UInt8] {
        Array(repeating:0, count:8) + [1,0,0,0,tag] + varint(key.count) + key + (tag == 1 ? varint(value.count) + value : [])
    }
    static func physical(_ payload: [UInt8], type: UInt8 = 1) -> [UInt8] {
        let crc = NetEaseExactIDFallback.maskedCRC([type] + payload)
        return [UInt8(crc & 255), UInt8((crc >> 8) & 255), UInt8((crc >> 16) & 255), UInt8(crc >> 24),UInt8(payload.count & 255),UInt8(payload.count >> 8),type] + payload
    }
    @MainActor static func main() async throws {
        let original = try event(), track = SpotifyTrack(name:"Song (Live)", artist:"Artist", album:"Album", duration:242.5)
        check(NetEaseExactIDFallback.matches(original, track:track), "valid current identity")
        for change in [["playing":false],["bundleIdentifier":"com.spotify.client"],["title":"Song"],["artist":"Other"],["duration":260],["contentItemIdentifier":""]] as [[String: Any]] {
            check(!NetEaseExactIDFallback.matches(try event(change), track:track), "reject changed identity")
        }
        check(!NetEaseExactIDFallback.samePlayback(original, try event(["contentItemIdentifier":"generation-2"])), "generation switch")
        check(!NetEaseExactIDFallback.samePlayback(original, try event(["playing":false])), "pause race")
        let state = NetEaseExactIDFallback.State(songID:"123",position:30,duration:242)
        let song: [String: Any] = ["name":"Song (Live)","duration":242500.0,"artists":[["name":"Artist"],["name":"OST"]],"album":["name":"Album"]]
        check(NetEaseExactIDFallback.correlated(state:state,song:song,event:original), "exact member match")
        check(!NetEaseExactIDFallback.correlated(state:state,song:song,event:try event(["artist":"Art"])), "no substring artist")
        check(!NetEaseExactIDFallback.correlated(state:state,song:song,event:try event(["title":"Song"])), "no live stripping")
        check(!NetEaseExactIDFallback.correlated(state:state,song:song,event:try event(["elapsedTimeNow":90])), "stale position")
        check(!NetEaseExactIDFallback.correlated(state:state,song:song,event:try event(["album":"Other"])), "album mismatch")
        let wal = physical(batch(try value()))
        check(NetEaseExactIDFallback.latestState(in:Data(wal)) == state, "decrypt exact WAL value")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch([],tag:0)))) == nil, "tombstone clears")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch([1,2,3])))) == nil, "corrupt newest clears")
        check(NetEaseExactIDFallback.latestState(in:Data(physical(batch(try value(),key:Array("unrelatedlastPlaying".utf8))))) == nil, "no marker scan")
        check(NetEaseExactIDFallback.latestState(in:Data(wal.dropLast())) == nil, "truncated record")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + wal.dropLast())) == nil, "prior valid plus truncated newest")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical([1,2,3]))) == nil, "prior valid plus malformed batch")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch(try value()),type:2))) == nil, "unfinished fragment")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch(try value()),type:8))) == nil, "unknown physical type")
        var corrupt = wal; corrupt[0] ^= 1
        check(NetEaseExactIDFallback.latestState(in:Data(wal + corrupt)) == nil, "bad CRC rejects prior valid")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch(try value(["resourceType":"podcast"]))))) == nil, "local nontrack denied")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + [0,0,0,0,0,0,0,9])) == nil, "nonzero padding denied")
        check(NetEaseExactIDFallback.latestState(in:Data(wal + physical(batch(try value()),type:2) + Array(repeating:0,count:8))) == nil, "padding cannot discard unfinished fragment")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let logs = root.appendingPathComponent("Documents/storage/CEFCache/Local Storage/leveldb")
        let queue = root.appendingPathComponent("Documents/storage/file_storage/webdata/file")
        try FileManager.default.createDirectory(at:logs,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:queue,withIntermediateDirectories:true)
        let log = logs.appendingPathComponent("000001.log")
        try Data(wal).write(to:log)
        var item: [String: Any] = ["id":"123","resourceType":"track","track":song]
        func writeQueue() throws { try JSONSerialization.data(withJSONObject:["list":[item]]).write(to:queue.appendingPathComponent("playingList")) }
        try writeQueue()
        check(NetEaseExactIDFallback.authorizedState(root:root,event:original,now:Date()) == state, "fresh WAL queue authorization")
        item["resourceType"] = "podcast"; try writeQueue()
        check(NetEaseExactIDFallback.authorizedState(root:root,event:original,now:Date()) == nil, "nontrack denied")
        item["resourceType"] = "track"; try writeQueue()
        try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSinceNow:-30)],ofItemAtPath:log.path)
        check(NetEaseExactIDFallback.authorizedState(root:root,event:original,now:Date()) == nil, "old WAL denied")
        try FileManager.default.moveItem(at:log,to:logs.appendingPathComponent("000001.ldb"))
        check(NetEaseExactIDFallback.authorizedState(root:root,event:original,now:Date()) == nil, "SSTable denied")
        let disabled = try await NetEaseExactIDFallback().syncedLyrics(for:track,expectedIdentifier:nil)
        check(disabled.isEmpty, "nonPreview bundle always disabled")
        let hit = [LyricLine(time:1,text:"test")]
        let client = LyricsClient(sources:[{ _ in hit }])
        let first = try await client.syncedLyrics(for:track,fallback:{ _ in fatalError("HIT invoked fallback") })
        check(first == hit, "pipeline HIT untouched")
        let missClient = LyricsClient(sources:[{ _ in [] }])
        let recovered = try await missClient.syncedLyrics(for:track,fallback:{ _ in hit })
        check(recovered == hit && missClient.selectedProvider == "NetEaseExactID (Preview)", "MISS fallback records provider")
        let repeated = try await missClient.syncedLyrics(for:track,fallback:{ _ in [] })
        check(repeated.isEmpty, "exact results excluded from metadata cache")
        let errorClient = LyricsClient(sources:[{ _ in throw URLError(.timedOut) }])
        let rescue = try await errorClient.syncedLyrics(for:track,fallback:{ _ in hit })
        check(rescue == hit, "all-errors rescued")
        do { _ = try await errorClient.syncedLyrics(for:track,fallback:{ _ in [] }); fatalError("lost original network error") }
        catch LyricsClientError.networkFailure { checks += 1 }
        let entry = FallbackEntry()
        let cancelled = Task { @MainActor in
            let c = LyricsClient(sources:[{ _ in [] }]); return try await c.syncedLyrics(for:track,fallback:{ _ in
                await entry.enter()
                try? await Task.sleep(for:.milliseconds(20)); return hit
            })
        }
        while await !entry.entered { await Task.yield() }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("cancelled result returned") } catch is CancellationError { checks += 1 }
        if CommandLine.arguments.contains("--current") {
            let bundle = Bundle(path:"/Applications/NotchMuse.app")!
            let live = try MediaRemoteBridge.bundled(in:bundle).get()
            let current = NetEaseExactIDFallback.authorizedState(root:FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.netease.163music"),event:live,now:Date())
            print("LIVE title=\(live.title) authorized_song_id=\(current?.songID ?? "none")")
        }
        print("PASS \(checks) Exact-ID guards and fallback checks")
    }
}
