using System.Globalization;
using System.IO.Compression;
using System.Text;
using NotchMuse.Core;

namespace NotchMuse.Sources;

public sealed class KugouSource(HttpClient client) : HttpLyricsSource(client)
{
    public override string Name => "Kugou";
    public static string DecodeKrc(string encoded)
    {
        var bytes = Convert.FromBase64String(encoded);
        if (bytes.Length < 5 || Encoding.ASCII.GetString(bytes, 0, 4) != "krc1") throw new InvalidDataException("Invalid KRC header");
        byte[] key = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69];
        for (var i = 4; i < bytes.Length; i++) bytes[i] ^= key[(i - 4) % key.Length];
        using var input = new MemoryStream(bytes, 4, bytes.Length - 4);
        using var zlib = new ZLibStream(input, CompressionMode.Decompress);
        using var output = new MemoryStream(); var buffer = new byte[8192]; int count;
        while ((count = zlib.Read(buffer)) > 0)
        {
            if (output.Length + count > 4 * 1024 * 1024) throw new InvalidDataException("KRC too large");
            output.Write(buffer, 0, count);
        }
        return Encoding.UTF8.GetString(output.ToArray());
    }
    public override async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
    {
        var json = await JsonAsync(Url("http://mobilecdn.kugou.com/api/v3/search/song", ("format", "json"), ("keyword", TrackMatcher.SearchQuery(track)), ("page", "1"), ("pagesize", "20"), ("showtype", "1")), cancellationToken);
        var song = Rank(track, Rows(json["data"]?["info"]).SelectMany(r => new[] { r }.Concat(Rows(r["group"]))).Select(r => Candidate(track, "kugou", S(r["hash"]), S(r["songname"]), S(r["singername"]), S(r["album_name"]), D(r["duration"]), new([]))));
        if (song is null) return null;
        var search = await JsonAsync(Url("https://lyrics.kugou.com/search", ("ver", "1"), ("man", "yes"), ("client", "pc"), ("keyword", song.Title + " " + song.Artist), ("duration", (song.Duration * 1000).ToString(CultureInfo.InvariantCulture)), ("hash", song.Id!)), cancellationToken);
        var rows = Rows(search["candidates"]).ToArray();
        var selected = Rank(track, rows.Select(r => Candidate(track, "kugou", S(r["id"]), S(r["song"]), S(r["singer"]), song.Album, D(r["duration"]) / 1000, new([]))));
        if (selected is null) return null;
        var raw = rows.First(r => S(r["id"]) == selected.Id);
        var download = await JsonAsync(Url("http://lyrics.kugou.com/download", ("ver", "1"), ("client", "pc"), ("id", selected.Id!), ("accesskey", S(raw["accesskey"])), ("fmt", "krc"), ("charset", "utf8")), cancellationToken);
        var doc = LyricParser.ParseRich(DecodeKrc(S(download["content"])), true);
        return doc.Lines.Count > 0 ? selected with { Id = song.Id, Document = doc } : null;
    }
}

public sealed class LrcMuxSource(HttpClient client) : HttpLyricsSource(client)
{
    public override string Name => "LRCMux";
    public override async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
    {
        var json = await JsonAsync(Url("https://api.lrcmux.dev/get", ("title", track.Title), ("artist", track.Artist), ("album", track.Album), ("duration", Math.Round(track.Duration).ToString(CultureInfo.InvariantCulture)), ("level", "line"), ("strict", "true"), ("format", "json")), cancellationToken);
        var t = json["track"]; if (t is null) return null;
        var lines = Rows(json["lines"]).Where(l => !string.IsNullOrEmpty(S(l["text"])))
            .Select(l => new LyricLine(D(l["start"]) / 1000, S(l["text"]), D(l["end"]) / 1000,
                Rows(l["words"]).Select(w => new LyricWord(D(w["start"]) / 1000, D(w["end"]) / 1000, S(w["text"]))).ToArray())).OrderBy(l => l.Start).ToArray();
        if (S(t["isrc"]).StartsWith("KR", StringComparison.OrdinalIgnoreCase) &&
            !System.Text.RegularExpressions.Regex.IsMatch(track.Title + " " + track.Album, @"\b(jp|japanese)\b", System.Text.RegularExpressions.RegexOptions.IgnoreCase))
        {
            var text = string.Concat(lines.Select(l => l.Text));
            var kana = text.Count(c => c is >= '\u3040' and <= '\u30ff'); var hangul = text.Count(c => c is >= '\uac00' and <= '\ud7af');
            if (kana >= 4 && hangul * 10 < kana) return null;
        }
        return Candidate(track, S(json["meta"]?["source"]?["id"]).ToLowerInvariant(), "", S(t["title"]), S(t["artist"]), S(t["album"]), D(t["duration"]), new(lines)) with { Isrc = S(t["isrc"]) };
    }
}
