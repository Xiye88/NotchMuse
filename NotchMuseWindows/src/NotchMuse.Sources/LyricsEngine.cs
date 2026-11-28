using System.Diagnostics;
using NotchMuse.Core;

namespace NotchMuse.Sources;

public sealed record EngineResult(SelectionDecision Decision, IReadOnlyList<SourceResult> Sources, bool Cached = false);

public sealed class LyricsEngine(IReadOnlyList<ILyricsSource> sources)
{
    private readonly Dictionary<Track, (DateTimeOffset Expires, EngineResult Result)> cache = new();
    private readonly object cacheLock = new();

    public static LyricsEngine Create(HttpClient client) =>
        new([new LrclibSource(client), new NetEaseSource(client), new QqSource(client), new KugouSource(client), new LrcMuxSource(client)]);

    private static TimeSpan SourceTimeout(string name) => name switch
    {
        "LRCLIB" => TimeSpan.FromMilliseconds(3800),
        "NetEase" => TimeSpan.FromMilliseconds(3600),
        "QQ" => TimeSpan.FromMilliseconds(3600),
        "Kugou" => TimeSpan.FromMilliseconds(3800),
        "LRCMux" => TimeSpan.FromMilliseconds(3200),
        _ => TimeSpan.FromMilliseconds(4000)
    };

    private static bool IsTransientError(SourceResult r) =>
        r.Status == "error" && r.Error is "request_timeout" or "network_or_tls_failure";

    public async Task<EngineResult> FindAsync(Track track, CancellationToken ct, bool force = false)
    {
        lock (cacheLock)
            if (!force && cache.TryGetValue(track, out var hit) && hit.Expires > DateTimeOffset.UtcNow)
                return hit.Result with { Cached = true };

        var directSources = sources.Where(s => s.Name != "LRCMux").ToArray();
        var muxSource = sources.FirstOrDefault(s => s.Name == "LRCMux");
        var results = new List<SourceResult>(sources.Count);

        using var roundCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var pending = directSources.ToDictionary(s => Fetch(s, track, roundCts.Token), s => s);
        var hasNetEase = directSources.Any(s => s.Name == "NetEase");
        var netEaseDone = !hasNetEase;
        DateTimeOffset? consensusReadyAt = null;
        SelectionDecision decision = new(null, "no_verified_candidate", new Dictionary<string, string>());

        // Progressive early-exit consensus loop:
        // Never block 7-10s on a slow/stalled straggler (e.g. Kugou) once NetEase + an agreeing direct peer have already answered!
        while (pending.Count > 0)
        {
            Task<SourceResult> completed;
            if (consensusReadyAt.HasValue && !netEaseDone)
            {
                var remainingGrace = consensusReadyAt.Value.AddMilliseconds(600) - DateTimeOffset.UtcNow;
                if (remainingGrace <= TimeSpan.Zero) break;
                var graceDelay = Task.Delay(remainingGrace, ct);
                var winnerTask = await Task.WhenAny(pending.Keys.Cast<Task>().Append(graceDelay)).ConfigureAwait(false);
                if (winnerTask == graceDelay) break;
                completed = (Task<SourceResult>)winnerTask;
            }
            else
            {
                completed = await Task.WhenAny(pending.Keys).ConfigureAwait(false);
            }

            pending.Remove(completed);
            var item = await completed.ConfigureAwait(false);
            results.Add(item);
            if (item.Provider == "NetEase") netEaseDone = true;

            var arrivedCandidates = results.Where(r => r.Candidate is not null).Select(r => r.Candidate!).ToArray();
            if (arrivedCandidates.Length == 0) continue;

            decision = LyricsSelection.Select(arrivedCandidates, track);

            // Fast-exit A: NetEase confirmed instrumental_recording with Tier<=2 or exact album match and no higher-tier source pending
            if (decision.Reason == "instrumental_recording" && netEaseDone &&
                arrivedCandidates.Any(c => c.Provider == "NetEase" && c.Evidence == LyricsEvidence.Instrumental))
            {
                var noHigherTierPossible = string.IsNullOrEmpty(track.NativeId) && string.IsNullOrEmpty(track.Isrc);
                if (noHigherTierPossible) break;
            }

            // Fast-exit B: 2+ independent direct timed sources already agree with zero conflict!
            var validDirect = arrivedCandidates.Where(c =>
                c.Provider != "LRCMux" && c.Evidence == LyricsEvidence.TimedLyrics &&
                LyricsSelection.Rejection(c, track) is null).ToArray();
            var hasIndependentAgreement = validDirect.Length >= 2 && validDirect.Any(a =>
                validDirect.Any(b => a.Provider != b.Provider && a.Platform != b.Platform && LyricsSelection.TimelinesAgree(a, b)));

            if (decision.Winner is not null && hasIndependentAgreement)
            {
                if (netEaseDone) break; // NetEase already checked -> return immediately (~0.9-1.5s)!
                consensusReadyAt ??= DateTimeOffset.UtcNow;
            }
        }

        // Cancel any still-in-flight stragglers so sockets release immediately
        roundCts.Cancel();

        var collectedCandidates = results.Where(r => r.Candidate is not null).Select(r => r.Candidate!).ToList();
        decision = LyricsSelection.Select(collectedCandidates, track);

        // Recovery pass: if no winner yet (and NOT confirmed instrumental), retry transient direct timeouts in parallel with LRCMux
        if (decision.Winner is null && decision.Reason != "instrumental_recording")
        {
            var retryTasks = new List<Task<SourceResult>>();
            var failedProviders = results.Where(IsTransientError).Select(r => r.Provider).ToHashSet(StringComparer.Ordinal);
            foreach (var src in directSources.Where(s => failedProviders.Contains(s.Name)))
            {
                retryTasks.Add(Fetch(src, track, ct));
            }
            if (muxSource is not null)
            {
                retryTasks.Add(Fetch(muxSource, track, ct));
            }

            if (retryTasks.Count > 0)
            {
                var recovered = await Task.WhenAll(retryTasks).ConfigureAwait(false);
                foreach (var r in recovered)
                {
                    if (r.Provider == "LRCMux" || r.Candidate is not null)
                    {
                        results.RemoveAll(existing => existing.Provider == r.Provider);
                        results.Add(r);
                    }
                }
                decision = LyricsSelection.Select(results.Where(r => r.Candidate is not null).Select(r => r.Candidate!), track);
            }
        }

        ct.ThrowIfCancellationRequested();
        var result = new EngineResult(decision, results);
        // Never cache transient network errors as a no-lyrics result.
        if (decision.Winner is not null || decision.Reason == "instrumental_recording" || results.All(r => r.Status != "error"))
        {
            lock (cacheLock)
            {
                if (cache.Count >= 64) cache.Remove(cache.MinBy(kv => kv.Value.Expires).Key);
                cache[track] = (DateTimeOffset.UtcNow.AddMinutes(decision.Winner is null ? 1 : 30), result);
            }
        }
        return result;
    }

    private static async Task<SourceResult> Fetch(ILyricsSource source, Track track, CancellationToken ct)
    {
        var clock = Stopwatch.StartNew();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(SourceTimeout(source.Name));
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
