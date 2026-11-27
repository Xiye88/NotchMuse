using System.Net;
using System.Text.Json.Nodes;
using NotchMuse.Core;

namespace NotchMuse.Sources;

public abstract class HttpLyricsSource(HttpClient client) : ILyricsSource
{
    public abstract string Name { get; }
    public abstract Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken);
    protected async Task<JsonNode> JsonAsync(string url, CancellationToken ct, HttpContent? content = null, string? referer = null)
    {
        using var request = new HttpRequestMessage(content is null ? HttpMethod.Get : HttpMethod.Post, url) { Content = content };
        request.Headers.UserAgent.ParseAdd("NotchMuse/0.9.0 (Windows)");
        if (referer is not null) request.Headers.Referrer = new Uri(referer);
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        // Bound both declared and streamed sizes, including chunked replies.
        if (response.Content.Headers.ContentLength > 4 * 1024 * 1024) throw new InvalidDataException("Response too large");
        await using var input = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        using var bytes = new MemoryStream(); var buffer = new byte[8192]; int count;
        while ((count = await input.ReadAsync(buffer, ct).ConfigureAwait(false)) > 0)
        {
            if (bytes.Length + count > 4 * 1024 * 1024) throw new InvalidDataException("Response too large");
            bytes.Write(buffer, 0, count);
        }
        var text = System.Text.Encoding.UTF8.GetString(bytes.ToArray()).Trim();
        if (!text.StartsWith('{') && !text.StartsWith('['))
        {
            var open = text.IndexOf('('); var close = text.LastIndexOf(')');
            if (open < 0 || close <= open) throw new InvalidDataException("Invalid response envelope");
            text = text[(open + 1)..close];
        }
        return JsonNode.Parse(text) ?? throw new InvalidDataException("Empty response");
    }
    protected static string Url(string baseUrl, params (string Key, string Value)[] query) => baseUrl + "?" + string.Join('&', query.Select(p => WebUtility.UrlEncode(p.Key) + "=" + WebUtility.UrlEncode(p.Value)));
    protected static string S(JsonNode? n) => n?.ToString() ?? "";
    protected static double D(JsonNode? n) => double.TryParse(S(n), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var d) ? d : 0;
    protected static IEnumerable<JsonNode> Rows(JsonNode? n) => n is JsonArray a ? a.OfType<JsonNode>() : [];
    protected static string Artists(JsonNode? n) => string.Join(", ", Rows(n).Select(a => S(a["name"])));

    protected static LyricsCandidate? Rank(Track track, IEnumerable<LyricsCandidate> candidates)
    {
        var pool = Ranked(track, candidates);
        if (pool.Count == 0) return null;
        if (pool.Count == 1) return pool[0];
        if (pool[0].MatcherScore - pool[1].MatcherScore >= 6) return pool[0];
        // If tied on metadata score, prefer the album-bound or strictly closer duration match (Mac Kugou/LRCLIB parity)
        var d0 = Math.Abs(pool[0].Duration - track.Duration);
        var d1 = Math.Abs(pool[1].Duration - track.Duration);
        var a0 = TrackMatcher.AlbumMatches(pool[0].Album, track);
        var a1 = TrackMatcher.AlbumMatches(pool[1].Album, track);
        if (a0 != a1) return a0 ? pool[0] : pool[1];
        if (d0 + 0.25 < d1) return pool[0];
        if (pool[0].Document.Lines.Count >= 5 && pool[1].Document.Lines.Count >= 5 && LyricsSelection.TimelinesAgree(pool[0], pool[1]))
            return pool[0];
        return null;
    }

    protected static IReadOnlyList<LyricsCandidate> Ranked(Track track, IEnumerable<LyricsCandidate> candidates)
    {
        var all = candidates.Where(c => c.MatcherScore >= 82 && TrackMatcher.IdentityRejection(track, c.Title, c.Artist, c.Album) is null).ToArray();
        var bound = all.Where(c => TrackMatcher.AlbumMatches(c.Album, track) && Math.Abs(c.Duration - track.Duration) <= 2).ToArray();
        return (bound.Length > 0 ? bound : all)
            .GroupBy(c => (TrackMatcher.ParseTitle(c.Title).Name, Artist: string.Join(',', TrackMatcher.ArtistGroup(c.Artist).Order()), Duration: Math.Round(c.Duration)))
            .Select(g => g.OrderByDescending(c => TrackMatcher.AlbumMatches(c.Album, track))
                .ThenByDescending(c => c.MatcherScore)
                .ThenBy(c => Math.Abs(c.Duration - track.Duration))
                .First())
            .OrderByDescending(c => TrackMatcher.AlbumMatches(c.Album, track))
            .ThenByDescending(c => c.MatcherScore)
            .ThenBy(c => Math.Abs(c.Duration - track.Duration))
            .ToArray();
    }
    protected LyricsCandidate Candidate(Track track, string platform, string id, string title, string artist, string? album, double duration, LyricDocument doc) =>
        new(Name, platform, id, title, artist, album, duration, doc, TrackMatcher.Score(track, title, artist, duration));
}
