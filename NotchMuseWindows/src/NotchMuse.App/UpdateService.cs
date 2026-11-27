using System.Net.Http.Headers;
using System.Text.Json;
using System.Net.Http;
using NotchMuse.Core;

namespace NotchMuse.App;

public sealed record ReleaseInfo(string TagName, string Name, string Body, string HtmlUrl, string? DownloadUrl = null);

public sealed class UpdateService(HttpClient client)
{
    private const string LatestUrl = "https://api.github.com/repos/Xiye88/NotchMuse/releases/latest";

    public async Task<ReleaseInfo?> GetLatestAsync(CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, LatestUrl);
        request.Headers.UserAgent.Add(new ProductInfoHeaderValue("NotchMuse-Windows", "0.9"));
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode) return null;
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        return ParseReleaseJson(document.RootElement);
    }

    public static ReleaseInfo ParseReleaseJson(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object)
            throw new JsonException("Release payload is not a JSON object.");

        var tag = root.TryGetProperty("tag_name", out var tagEl) && tagEl.ValueKind == JsonValueKind.String ? tagEl.GetString() ?? "" : "";
        if (string.IsNullOrWhiteSpace(tag))
            throw new JsonException("Release payload missing tag_name.");

        var name = root.TryGetProperty("name", out var nameEl) && nameEl.ValueKind == JsonValueKind.String ? nameEl.GetString() ?? "" : "";
        var body = root.TryGetProperty("body", out var bodyEl) && bodyEl.ValueKind == JsonValueKind.String ? bodyEl.GetString() ?? "" : "";
        var htmlUrl = root.TryGetProperty("html_url", out var urlEl) && urlEl.ValueKind == JsonValueKind.String ? urlEl.GetString() ?? "" : "";
        string? downloadUrl = null;

        if (root.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array)
        {
            string? setupAsset = null;
            string? portableAsset = null;
            foreach (var asset in assets.EnumerateArray())
            {
                if (asset.ValueKind != JsonValueKind.Object) continue;
                var assetName = asset.TryGetProperty("name", out var an) && an.ValueKind == JsonValueKind.String ? an.GetString() ?? "" : "";
                var browserUrl = asset.TryGetProperty("browser_download_url", out var bu) && bu.ValueKind == JsonValueKind.String ? bu.GetString() : null;
                if (string.IsNullOrWhiteSpace(browserUrl)) continue;
                if (assetName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                {
                    if (assetName.Contains("Setup", StringComparison.OrdinalIgnoreCase))
                        setupAsset ??= browserUrl;
                    else if (assetName.Contains("Windows", StringComparison.OrdinalIgnoreCase) || assetName.Contains("win-x64", StringComparison.OrdinalIgnoreCase))
                        portableAsset ??= browserUrl;
                }
            }
            downloadUrl = setupAsset ?? portableAsset;
        }

        return new ReleaseInfo(tag, name, body, htmlUrl, downloadUrl);
    }

    public static bool IsNewer(string current, ReleaseInfo latest) => VersionComparison.Compare(current, latest.TagName) < 0;
}
