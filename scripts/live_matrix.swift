import Foundation

private let tracks = [
    SpotifyTrack(name: "成都", artist: "赵雷", album: "无法长大", duration: 328),
    SpotifyTrack(name: "七里香", artist: "周杰伦", album: "七里香", duration: 299),
    SpotifyTrack(name: "演员", artist: "薛之谦", album: "绅士", duration: 261),
    SpotifyTrack(name: "光年之外", artist: "G.E.M. 邓紫棋", album: "光年之外", duration: 235),
    SpotifyTrack(name: "童话", artist: "光良", album: "童话", duration: 241),
    SpotifyTrack(name: "平凡之路", artist: "朴树", album: "猎户星座", duration: 301),
    SpotifyTrack(name: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200),
    SpotifyTrack(name: "Shape of You", artist: "Ed Sheeran", album: "÷", duration: 234),
    SpotifyTrack(name: "Someone Like You", artist: "Adele", album: "21", duration: 285),
    SpotifyTrack(name: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 354),
    SpotifyTrack(name: "Anti-Hero", artist: "Taylor Swift", album: "Midnights", duration: 201),
    SpotifyTrack(name: "Hotel California", artist: "Eagles", album: "Hotel California", duration: 391),
    SpotifyTrack(name: "Lemon", artist: "Kenshi Yonezu", album: "STRAY SHEEP", duration: 255),
    SpotifyTrack(name: "Pretender", artist: "Official HIGE DANdism", album: "Traveler", duration: 327),
    SpotifyTrack(name: "夜に駆ける", artist: "YOASOBI", album: "THE BOOK", duration: 262),
    SpotifyTrack(name: "First Love", artist: "Hikaru Utada", album: "First Love", duration: 257),
    SpotifyTrack(name: "Dynamite", artist: "BTS", album: "BE", duration: 199),
    SpotifyTrack(name: "Ditto", artist: "NewJeans", album: "OMG", duration: 186),
    SpotifyTrack(name: "Gangnam Style", artist: "PSY", album: "PSY 6 (Six Rules), Pt. 1", duration: 219),
    SpotifyTrack(name: "LOVE SCENARIO", artist: "iKON", album: "Return", duration: 209),
]

@main enum LiveMatrix {
    static func main() async {
        guard CommandLine.arguments.count == 2,
              let index = Int(CommandLine.arguments[1]),
              tracks.indices.contains(index) else { exit(2) }
        let track = tracks[index]
        let start = ContinuousClock.now
        let result = await withTaskGroup(of: (String, [LyricLine]?).self) { group in
            group.addTask { ("LRCLIB", try? await LRCLIBLyricsSource().syncedLyrics(for: track)) }
            group.addTask { ("NetEase", try? await NetEaseLyricsSource().syncedLyrics(for: track)) }
            group.addTask { ("LRCMux", try? await LRCMuxLyricsSource().syncedLyrics(for: track)) }
            group.addTask { ("QQ", try? await QQMusicLyricsSource().syncedLyrics(for: track)) }
            for await result in group where !(result.1?.isEmpty ?? true) {
                group.cancelAll()
                return result
            }
            return ("MISS", nil)
        }
        let duration = start.duration(to: .now).components
        let milliseconds = Int(duration.seconds) * 1000 + Int(duration.attoseconds / 1_000_000_000_000_000)
        print([track.name, track.artist, result.0, String(result.1?.count ?? 0), String(milliseconds)].joined(separator: "\t"))
    }
}
