using System.Diagnostics;
using System.Globalization;
using System.Collections.Concurrent;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using NotchMuse.Core;
using NotchMuse.Sources;

const string reference = "895bc4cc479a802f4785620fc2c10faeae152c81";
string Option(string name, string fallback) { var index = Array.IndexOf(args, name); return index >= 0 && index + 1 < args.Length ? args[index + 1] : fallback; }
var repo = Path.GetFullPath(Option("--repo", Directory.GetCurrentDirectory()));
var output = Path.GetFullPath(Option("--output", Path.Combine(repo, "NotchMuseWindows", "artifacts", "benchmark")));
var limit = int.Parse(Option("--limit", "100"), CultureInfo.InvariantCulture);
var requested = Option("--platform", "all");
if (limit < 1 || limit > 100) throw new ArgumentException("--limit must be between 1 and 100");
Directory.CreateDirectory(output);
Console.OutputEncoding = Encoding.UTF8;
using var cancel = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cancel.Cancel(); };
async Task<string> ReadFixture(string option, string file)
{
    var path = Option(option, "");
    if (path.Length > 0) return await File.ReadAllTextAsync(path, cancel.Token);
    var psi = new ProcessStartInfo("git") { WorkingDirectory = repo, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, UseShellExecute = false, CreateNoWindow = true };
    foreach (var a in new[] { "-c", "safe.directory=" + repo.Replace('\\', '/'), "show", reference + ":scripts/fixtures/" + file }) psi.ArgumentList.Add(a);
    using var process = Process.Start(psi) ?? throw new InvalidOperationException("Cannot start git");
    var stdout = process.StandardOutput.ReadToEndAsync(cancel.Token); var stderr = process.StandardError.ReadToEndAsync(cancel.Token);
    await process.WaitForExitAsync(cancel.Token); var text = await stdout; var error = await stderr;
    if (process.ExitCode != 0) throw new InvalidOperationException("Cannot read pinned fixture: " + error);
    return text;
}
string FailureCategory(EngineResult result, bool guard)
{
    if (guard) return result.Decision.Winner is null ? "guard_correct_reject" : "guard_false_positive";
    if (result.Decision.Winner is not null) return "matched";
    if (result.Sources.Any(s => s.Error?.Contains("timeout", StringComparison.OrdinalIgnoreCase) == true)) return "http_timeout";
    if (result.Decision.Rejected.Values.Any(v => v.Contains("duration", StringComparison.OrdinalIgnoreCase))) return "duration_mismatch";
    if (result.Decision.Rejected.Values.Any(v => v.Contains("timeline", StringComparison.OrdinalIgnoreCase))) return "timeline_conflict";
    if (result.Decision.Rejected.Values.Any(v => v.Contains("score", StringComparison.OrdinalIgnoreCase))) return "low_score";
    return result.Sources.All(s => s.Status == "no_candidate" || s.Status == "error") ? "provider_empty" : "identity_ambiguous";
}
var catalogText = await ReadFixture("--catalog", "benchmark_100_catalog.tsv");
var youtubeText = await ReadFixture("--youtube", "ytm_100.tsv");
static Track[] Parse(string text, bool youtube) => text.Replace("\r", "").Split('\n', StringSplitOptions.RemoveEmptyEntries).Skip(1).Select(row =>
{
    var c = row.Split('\t'); var i = youtube ? 1 : 0;
    if (c.Length < i + 4) throw new InvalidDataException("Malformed fixture row");
    return new Track(c[i], c[i + 1], c[i + 2], double.Parse(c[i + 3], CultureInfo.InvariantCulture), youtube);
}).ToArray();
var catalog = Parse(catalogText, false); var youtube = Parse(youtubeText, true);
if (catalog.Length != 100 || youtube.Length != 100) throw new InvalidDataException("Expected exactly 100 rows in each original fixture");
Track[] guards = [new("River Flows in You", "Yiruma", "First Love", 218), new("Kiss the Rain", "Yiruma", "From The Yellow Room", 256),
    new("Clair de Lune", "Claude Debussy", "Suite bergamasque", 310), new("Nocturne Op. 9 No. 2", "Frédéric Chopin", "Nocturnes", 270), new("Summer", "Joe Hisaishi", "Kikujiro", 153)];
string[] platforms = ["apple", "spotify", "netease", "qq", "kugou", "soda", "youtube"];
if (requested != "all" && !platforms.Contains(requested)) throw new ArgumentException("Unknown platform");
using var http = new HttpClient(new BenchmarkResponseCacheHandler(new HttpClientHandler { AutomaticDecompression = DecompressionMethods.All })) { Timeout = TimeSpan.FromSeconds(12) };
var engine = LyricsEngine.Create(http);
var summaries = new List<object>(); var allPass = true;
var summary = new StringBuilder("# Windows M1 online metadata-profile benchmark\n\nReference: `" + reference + "`. These are simulated metadata profiles, not physical player QA.\n\n| Platform | Vocal hits | Guard false positives | Source errors | Result |\n|---|---:|---:|---:|---|\n");
foreach (var platform in platforms.Where(p => requested == "all" || requested == p))
{
    var raw = (platform == "youtube" ? youtube : catalog).Take(limit).Concat(guards).ToArray();
    var results = new BenchmarkRow[raw.Length];
    await Parallel.ForEachAsync(Enumerable.Range(0, raw.Length), new ParallelOptions { MaxDegreeOfParallelism = 2, CancellationToken = cancel.Token }, async (index, ct) =>
    {
        var guard = index >= limit; var t = raw[index];
        if (!guard)
        {
            t = platform switch
            {
                "apple" when index % 5 == 0 => t with { Album = t.Album + " - Single" },
                "qq" when index % 4 == 0 => t with { Album = "" },
                "kugou" => t with { Title = index % 2 == 0 ? t.Artist + " - " + t.Title : t.Title, Artist = index % 2 == 0 ? "" : t.Artist, Album = "" },
                "soda" when index % 3 == 0 => t with { Album = "" },
                _ => t
            };
        }
        t = MediaMetadataSanitizer.Clean(t with { Platform = platform, IsMusicVideo = platform == "youtube" }, platform == "kugou");
        await Task.Delay(150, ct);
        var watch = Stopwatch.StartNew();
        var result = await engine.FindAsync(t, ct, force: true);
        var winner = result.Decision.Winner;
        results[index] = new(index, guard, raw[index], t, winner is not null, winner?.Provider, result.Decision.Reason,
            FailureCategory(result, guard),
            result.Decision.Rejected, result.Sources.Select(s => new SourceEvidence(s.Provider, s.Status, s.Error, s.ElapsedMs, s.Candidate?.MatcherScore)).ToArray(), watch.Elapsed.TotalMilliseconds);
        Console.WriteLine($"{platform} {index + 1}/{raw.Length}: {(winner is null ? "MISS" : winner.Provider)} · {t.Title}");
    });
    var hits = results.Count(r => !r.Guard && r.Matched); var fp = results.Count(r => r.Guard && r.Matched);
    var errors = results.Sum(r => r.Sources.Count(s => s.Status == "error"));
    var pass = limit == 100 && hits >= 95 && fp == 0; allPass &= pass;
    summary.AppendLine($"| {platform} | {hits}/{limit} ({100d * hits / limit:F1}%) | {fp}/5 | {errors} | {(pass ? "PASS" : "FAIL / partial sample")} |");
    await File.WriteAllTextAsync(Path.Combine(output, platform + ".json"), JsonSerializer.Serialize(new { Reference = reference, Platform = platform, Complete = true, VocalCount = limit, Hits = hits, GuardFalsePositives = fp, Results = results }, new JsonSerializerOptions { WriteIndented = true }), cancel.Token);
    summaries.Add(new { Platform = platform, Hits = hits, Count = limit, GuardFalsePositives = fp, SourceErrors = errors, Pass = pass });
    await File.WriteAllTextAsync(Path.Combine(output, "summary.md"), summary.ToString(), cancel.Token);
}
await File.WriteAllTextAsync(Path.Combine(output, "summary.json"), JsonSerializer.Serialize(new { Reference = reference, CompleteMatrix = requested == "all" && limit == 100, Pass = allPass, Platforms = summaries }, new JsonSerializerOptions { WriteIndented = true }), cancel.Token);
Console.WriteLine(summary); return allPass ? 0 : 1;

internal sealed record SourceEvidence(string Provider, string Status, string? Error, double ElapsedMs, int? MatcherScore);
internal sealed record BenchmarkRow(int Index, bool Guard, Track Raw, Track Sanitized, bool Matched, string? Provider, string Reason, string FailureCategory,
    IReadOnlyDictionary<string, string> Rejected, IReadOnlyList<SourceEvidence> Sources, double ElapsedMs);

internal sealed class BenchmarkResponseCacheHandler(HttpMessageHandler inner) : DelegatingHandler(inner)
{
    private readonly ConcurrentDictionary<string, CachedResponse> cache = new(StringComparer.Ordinal);

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
        var key = request.Method.Method + " " + request.RequestUri + "\n" + body;
        if (cache.TryGetValue(key, out var cached))
            return cached.CreateResponse(request);

        var response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode) return response;
        var statusCode = response.StatusCode;
        var reasonPhrase = response.ReasonPhrase;
        var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken).ConfigureAwait(false);
        var headers = response.Headers.ToDictionary(h => h.Key, h => h.Value.ToArray(), StringComparer.OrdinalIgnoreCase);
        var contentHeaders = response.Content.Headers.ToDictionary(h => h.Key, h => h.Value.ToArray(), StringComparer.OrdinalIgnoreCase);
        response.Dispose();
        var entry = new CachedResponse((int)statusCode, reasonPhrase, headers, contentHeaders, bytes);
        cache.TryAdd(key, entry);
        return entry.CreateResponse(request);
    }

    private sealed record CachedResponse(int StatusCode, string? ReasonPhrase,
        IReadOnlyDictionary<string, string[]> Headers,
        IReadOnlyDictionary<string, string[]> ContentHeaders,
        byte[] Body)
    {
        public HttpResponseMessage CreateResponse(HttpRequestMessage request)
        {
            var response = new HttpResponseMessage((HttpStatusCode)StatusCode)
            {
                ReasonPhrase = ReasonPhrase,
                RequestMessage = request,
                Content = new ByteArrayContent(Body)
            };
            foreach (var pair in Headers) response.Headers.TryAddWithoutValidation(pair.Key, pair.Value);
            foreach (var pair in ContentHeaders) response.Content.Headers.TryAddWithoutValidation(pair.Key, pair.Value);
            return response;
        }
    }
}
