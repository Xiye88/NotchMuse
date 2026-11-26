using System.Net;
using System.Text;
using System.Text.Json;
using NotchMuse.Core;

namespace NotchMuse.Sources;

public sealed class LrclibSource(HttpClient client) : HttpLyricsSource(client)
{
    public override string Name => "LRCLIB";
    public override async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
    {
        var search = await JsonAsync(Url("https://lrclib.net/api/search", ("track_name", track.Title), ("artist_name", track.Artist)), cancellationToken);
        var candidates = Rows(search).Where(r => S(r["instrumental"]) != "true" && !string.IsNullOrWhiteSpace(S(r["syncedLyrics"])))
            .Select(r => Candidate(track, "lrclib", S(r["id"]), S(r["trackName"]), S(r["artistName"]), S(r["albumName"]), D(r["duration"]), LyricParser.Parse(S(r["syncedLyrics"])))).ToArray();
        if (candidates.Length == 0)
        {
            try
            {
                var direct = await JsonAsync(Url("https://lrclib.net/api/get", ("track_name", track.Title), ("artist_name", track.Artist),
                    ("album_name", track.Album), ("duration", Math.Round(track.Duration).ToString(System.Globalization.CultureInfo.InvariantCulture))), cancellationToken);
                if (S(direct["instrumental"]) != "true" && !string.IsNullOrWhiteSpace(S(direct["syncedLyrics"])))
                    candidates = [Candidate(track, "lrclib", S(direct["id"]), S(direct["trackName"]), S(direct["artistName"]), S(direct["albumName"]), D(direct["duration"]), LyricParser.Parse(S(direct["syncedLyrics"])))];
            }
            catch (HttpRequestException) { }
        }
        var contenders = candidates.Where(c => c.MatcherScore >= 82).ToArray();
        for (var i = 0; i < contenders.Length; i++)
        for (var j = i + 1; j < contenders.Length; j++)
            if (TrackMatcher.AlbumMatches(contenders[i].Album, track) == TrackMatcher.AlbumMatches(contenders[j].Album, track) &&
                Math.Abs(contenders[i].MatcherScore - contenders[j].MatcherScore) < 6 && !LyricsSelection.TimelinesAgree(contenders[i], contenders[j])) return null;
        return Rank(track, candidates);
    }
}

public sealed class NetEaseSource(HttpClient client) : HttpLyricsSource(client)
{
    public override string Name => "NetEase";
    public override async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
    {
        var queries = new[] { TrackMatcher.SearchQuery(track), TrackMatcher.Simplified(track.Title) }
            .Where(q => !string.IsNullOrWhiteSpace(q))
            .Distinct(StringComparer.Ordinal);
        foreach (var query in queries)
        {
            var content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["s"] = query, ["type"] = "1", ["limit"] = "20", ["offset"] = "0"
            });
            var json = await JsonAsync("https://music.163.com/api/cloudsearch/pc", cancellationToken, content, "https://music.163.com/");
            var cloudCandidates = Rows(json["result"]?["songs"]).Select(r =>
            {
                var original = r["originSongSimpleData"];
                var title = string.IsNullOrWhiteSpace(S(original?["name"])) ? S(r["name"]) : S(original?["name"]);
                var artists = Rows(original?["artists"]).Any() ? Artists(original?["artists"]) : Artists(r["ar"]);
                var album = string.IsNullOrWhiteSpace(S(original?["albumMeta"]?["name"])) ? S(r["al"]?["name"]) : S(original?["albumMeta"]?["name"]);
                return Candidate(track, "netease", S(r["id"]), title, artists, album, D(r["dt"]) / 1000, new([]));
            });
            foreach (var song in Ranked(track, cloudCandidates).Take(8))
            {
                var lyrics = await JsonAsync(Url("https://music.163.com/api/song/lyric/v1", ("id", song.Id!), ("lv", "-1"), ("yv", "-1"), ("tv", "-1")), cancellationToken, referer: "https://music.163.com/");
                var yrc = S(lyrics["yrc"]?["lyric"]);
                var doc = string.IsNullOrWhiteSpace(yrc) ? LyricParser.Parse(S(lyrics["lrc"]?["lyric"])) : LyricParser.ParseRich(yrc, false);
                if (doc.Lines.Count == 0)
                {
                    lyrics = await JsonAsync(Url("https://music.163.com/api/song/lyric", ("id", song.Id!), ("lv", "-1"), ("tv", "-1"), ("kv", "-1")), cancellationToken, referer: "https://music.163.com/");
                    doc = LyricParser.Parse(S(lyrics["lrc"]?["lyric"]));
                }
                if (doc.Lines.Count == 0) continue;
                var translations = LyricParser.Parse(S(lyrics["tlyric"]?["lyric"])).Normalized;
                doc = doc with { Lines = doc.Lines.Select(l =>
                {
                    var matches = translations.Where(t => Math.Abs(t.Start - (l.Start - doc.Offset)) <= .45).ToArray();
                    return matches.Length == 1 && doc.Normalized.Count(o => Math.Abs(o.Start - matches[0].Start) <= .45) == 1 ? l with { Translation = matches[0].Text } : l;
                }).ToArray() };
                return song with { Document = doc };
            }
        }
        return null;
    }
}

public sealed class QqSource(HttpClient client) : HttpLyricsSource(client)
{
    public override string Name => "QQ";
    public override async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
    {
        IReadOnlyList<LyricsCandidate> songs = [];
        foreach (var query in new[] { TrackMatcher.SearchQuery(track), track.Title + " " + track.Artist, TrackMatcher.Simplified(track.Title), track.Title }.Distinct())
        {
            var body = new { comm = new { ct = 19, cv = "1859", uin = "0" }, req_1 = new { method = "DoSearchForQQMusicDesktop", module = "music.search.SearchCgiService", param = new { grp = 1, num_per_page = 20, page_num = 1, query, search_type = 0 } } };
            var content = new StringContent(JsonSerializer.Serialize(body,
                new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }), Encoding.UTF8);
            content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");
            var json = await JsonAsync("https://u.y.qq.com/cgi-bin/musicu.fcg", cancellationToken, content, "https://y.qq.com/");
            songs = Ranked(track, Rows(json["req_1"]?["data"]?["body"]?["song"]?["list"]).Select(r => Candidate(track, "qq", S(r["mid"]), S(r["title"]), Artists(r["singer"]), S(r["album"]?["name"]), D(r["interval"]), new([]))));
            if (songs.Count > 0) break;
        }
        foreach (var song in songs.Take(8))
        {
            var lyrics = await JsonAsync(Url("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg", ("callback", "MusicJsonCallback_lrc"),
                ("songmid", song.Id!), ("g_tk", "5381"), ("jsonpCallback", "MusicJsonCallback_lrc"), ("format", "jsonp"),
                ("loginUin", "0"), ("hostUin", "0"), ("inCharset", "utf8"), ("outCharset", "utf8"),
                ("notice", "0"), ("platform", "yqq"), ("needNewCode", "0")), cancellationToken, referer: "https://c.y.qq.com/");
            var raw = WebUtility.HtmlDecode(S(lyrics["lyric"]));
            if (!raw.Contains('[')) { try { raw = Encoding.UTF8.GetString(Convert.FromBase64String(raw)); } catch (FormatException) { continue; } }
            var doc = LyricParser.Parse(raw);
            if (doc.Lines.Count > 0) return song with { Document = doc };
        }
        return null;
    }
}
