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
        var songCandidates = Rows(json["data"]?["info"])
            .SelectMany(r => new[] { r }.Concat(Rows(r["group"])))
            .Select(r => Candidate(track, "kugou", S(r["hash"]), S(r["songname"]), S(r["singername"]), S(r["album_name"]), D(r["duration"]), new([])))
            .Where(c => c.MatcherScore >= 82 && TrackMatcher.IdentityRejection(track, c.Title, c.Artist, c.Album) is null)
            .GroupBy(c => (TrackMatcher.Normalize(c.Title), TrackMatcher.Normalize(c.Artist), Math.Round(c.Duration)))
            .Select(g => g.OrderByDescending(c => TrackMatcher.AlbumMatches(c.Album, track)).ThenByDescending(c => c.MatcherScore).First())
            .OrderByDescending(c => TrackMatcher.AlbumMatches(c.Album, track))
            .ThenBy(c => Math.Abs(c.Duration - track.Duration))
            .ToArray();
        var song = songCandidates.FirstOrDefault();
        if (song is null) return null;

        var search = await JsonAsync(Url("https://lyrics.kugou.com/search", ("ver", "1"), ("man", "yes"), ("client", "pc"), ("keyword", song.Title + " " + song.Artist), ("duration", (song.Duration * 1000).ToString(CultureInfo.InvariantCulture)), ("hash", song.Id!)), cancellationToken);
        var rows = Rows(search["candidates"]).ToArray();
        var lyricCandidates = rows
            .Select(r => (Raw: r, Cand: Candidate(track, "kugou", S(r["id"]), S(r["song"]), S(r["singer"]), song.Album, D(r["duration"]) / 1000, new([]))))
            .Where(x => x.Cand.MatcherScore >= 82 && TrackMatcher.IdentityRejection(track, x.Cand.Title, x.Cand.Artist, x.Cand.Album) is null)
            .GroupBy(x => (TrackMatcher.Normalize(x.Cand.Title), TrackMatcher.Normalize(x.Cand.Artist), Math.Round(x.Cand.Duration)))
            .Select(g => g.First())
            .OrderBy(x => Math.Abs(x.Cand.Duration - track.Duration))
            .ToArray();
        if (lyricCandidates.Length == 0) return null;
        var picked = lyricCandidates[0];

        System.Text.Json.Nodes.JsonNode? download = null;
        foreach (var host in new[] { "http://lyrics.kugou.com/download", "http://krcs.kugou.com/download" })
        {
            try
            {
                download = await JsonAsync(Url(host, ("ver", "1"), ("client", "pc"), ("id", picked.Cand.Id!), ("accesskey", S(picked.Raw["accesskey"])), ("fmt", "krc"), ("charset", "utf8")), cancellationToken);
                if (!string.IsNullOrWhiteSpace(S(download["content"]))) break;
            }
            catch (HttpRequestException) { }
        }
        var content = S(download?["content"]);
        if (string.IsNullOrWhiteSpace(content)) return null;
        var doc = LyricParser.ParseRich(DecodeKrc(content), true);
        var isUgc = string.Equals(S(picked.Raw["product_from"]), "ugc", StringComparison.OrdinalIgnoreCase);
        return doc.Lines.Count > 0
            ? picked.Cand with
            {
                Id = song.Id,
                Document = doc,
                Evidence = isUgc ? LyricsEvidence.UserContribution : LyricsEvidence.TimedLyrics
            }
            : null;
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
        var source = json["meta"]?["source"];
        var platform = S(source?["id"]).ToLowerInvariant();
        var explicitId = new[]
        {
            S(source?["trackId"]), S(source?["trackID"]), S(source?["track_id"]),
            S(t["sourceTrackId"]), S(t["sourceTrackID"]), S(t["source_track_id"]),
            ExtractSourceTrackId(S(source?["url"]), platform)
        }.FirstOrDefault(id => !string.IsNullOrWhiteSpace(id));

        return Candidate(track, platform, explicitId ?? "", S(t["title"]), S(t["artist"]), S(t["album"]), D(t["duration"]), new(lines)) with { Isrc = S(t["isrc"]) };
    }

    public static string? ExtractSourceTrackId(string url, string platform)
    {
        if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri) ||
            !string.Equals(uri.Scheme, "https", StringComparison.OrdinalIgnoreCase) || !string.IsNullOrEmpty(uri.UserInfo) || !uri.IsDefaultPort)
            return null;
        var host = uri.Host.ToLowerInvariant();
        if (platform == "netease" && (host == "music.163.com" || host == "y.music.163.com"))
        {
            var combined = uri.Query + "&" + uri.Fragment;
            var m = System.Text.RegularExpressions.Regex.Match(combined, @"(?:[?&#]|^)id=(\d+)(?:&|$)");
            return m.Success ? m.Groups[1].Value : null;
        }
        if (platform == "spotify" && host == "open.spotify.com" && uri.AbsolutePath.StartsWith("/track/", StringComparison.Ordinal))
        {
            var seg = uri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault();
            return seg is { Length: 22 } && seg.All(char.IsAsciiLetterOrDigit) ? seg : null;
        }
        if (platform == "lrclib" && host == "lrclib.net" && uri.AbsolutePath.StartsWith("/api/get/", StringComparison.Ordinal))
        {
            var seg = uri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault();
            return !string.IsNullOrWhiteSpace(seg) ? seg : null;
        }
        return null;
    }
}
