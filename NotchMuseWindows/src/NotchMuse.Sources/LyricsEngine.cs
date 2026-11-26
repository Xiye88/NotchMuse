using System.Diagnostics;
using NotchMuse.Core;

namespace NotchMuse.Sources;

public sealed record EngineResult(SelectionDecision Decision, IReadOnlyList<SourceResult> Sources, bool Cached = false);
public sealed class LyricsEngine(IReadOnlyList<ILyricsSource> sources)
{
    private readonly Dictionary<Track, (DateTimeOffset Expires, EngineResult Result)> cache = new();
    private readonly object cacheLock = new();
    public static LyricsEngine Create(HttpClient client) => new([new LrclibSource(client), new NetEaseSource(client), new QqSource(client), new KugouSource(client), new LrcMuxSource(client)]);
    public async Task<EngineResult> FindAsync(Track track, CancellationToken ct, bool force = false)
    {
        lock (cacheLock)
            if (!force && cache.TryGetValue(track, out var hit) && hit.Expires > DateTimeOffset.UtcNow) return hit.Result with { Cached = true };
        var direct = await Task.WhenAll(sources.Where(s => s.Name != "LRCMux").Select(s => Fetch(s, track, ct))).ConfigureAwait(false);
        var results = direct.ToList();
        var decision = LyricsSelection.Select(results.Where(r => r.Candidate is not null).Select(r => r.Candidate!), track);
        if (decision.Winner is null && sources.FirstOrDefault(s => s.Name == "LRCMux") is { } mux)
        {
            results.Add(await Fetch(mux, track, ct).ConfigureAwait(false));
            decision = LyricsSelection.Select(results.Where(r => r.Candidate is not null).Select(r => r.Candidate!), track);
        }
        ct.ThrowIfCancellationRequested();
        var result = new EngineResult(decision, results);
        // Never cache transient network errors as a no-lyrics result.
        if (decision.Winner is not null || results.All(r => r.Status != "error"))
        lock (cacheLock)
        {
            if (cache.Count >= 64) cache.Remove(cache.MinBy(kv => kv.Value.Expires).Key);
            cache[track] = (DateTimeOffset.UtcNow.AddMinutes(decision.Winner is null ? 1 : 30), result);
        }
        return result;
    }
    private static async Task<SourceResult> Fetch(ILyricsSource source, Track track, CancellationToken ct)
    {
        var clock = Stopwatch.StartNew();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(10));
        try
        {
            var candidate = await source.FetchAsync(track, timeout.Token).ConfigureAwait(false);
            return new(source.Name, candidate, candidate is null ? "no_candidate" : "candidate", ElapsedMs: clock.Elapsed.TotalMilliseconds);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception e) when (e is HttpRequestException or OperationCanceledException or System.Text.Json.JsonException or InvalidDataException or FormatException or InvalidOperationException)
        {
            var reason = e switch
            {
                OperationCanceledException => "request_timeout",
                HttpRequestException h when h.StatusCode is not null => "provider_http_" + h.StatusCode.Value.ToString(),
                HttpRequestException => "network_or_tls_failure",
                _ => "invalid_provider_payload"
            };
            return new(source.Name, null, "error", reason, clock.Elapsed.TotalMilliseconds);
        }
    }
}
