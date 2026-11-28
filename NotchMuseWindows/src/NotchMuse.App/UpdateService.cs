using System.Net.Http.Headers;
using System.Text.Json;
using System.Net.Http;
using NotchMuse.Core;

namespace NotchMuse.App;

public sealed record ReleaseInfo(string TagName, string Name, string Body, string HtmlUrl, string? DownloadUrl = null);
public sealed record AnnouncementInfo(string Id, string TitleZh, string TitleEn, string Url);

public sealed class UpdateService(HttpClient client)
{
    private const string LatestUrl = "https://api.github.com/repos/Xiye88/NotchMuse/releases/latest";
    private const string AnnouncementFeedUrl = "https://notchmuse.com/announcements.json";

    public static readonly AnnouncementInfo FallbackAnnouncement = new(
        "v0.9.0",
        "v0.9.0 最新版本进展",
        "v0.9.0 Latest Updates",
        "https://github.com/Xiye88/NotchMuse/releases");

    public async Task<AnnouncementInfo> GetAnnouncementAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, AnnouncementFeedUrl);
            request.Headers.UserAgent.Add(new ProductInfoHeaderValue("NotchMuse-Windows", "0.9"));
            using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode) return FallbackAnnouncement;
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return FallbackAnnouncement;
            if (root.TryGetProperty("enabled", out var enabledEl) && enabledEl.ValueKind == JsonValueKind.False)
                return FallbackAnnouncement;
            var id = root.TryGetProperty("id", out var idEl) && idEl.ValueKind == JsonValueKind.String ? idEl.GetString() ?? "v0.9.0" : "v0.9.0";
            var titleZh = root.TryGetProperty("title_zh", out var zhEl) && zhEl.ValueKind == JsonValueKind.String ? zhEl.GetString() : null;
            var titleEn = root.TryGetProperty("title_en", out var enEl) && enEl.ValueKind == JsonValueKind.String ? enEl.GetString() : null;
            var url = root.TryGetProperty("url", out var urlEl) && urlEl.ValueKind == JsonValueKind.String ? urlEl.GetString() : null;
            if (string.IsNullOrWhiteSpace(titleZh) && string.IsNullOrWhiteSpace(titleEn)) return FallbackAnnouncement;
            return new AnnouncementInfo(
                id,
                string.IsNullOrWhiteSpace(titleZh) ? titleEn! : titleZh,
                string.IsNullOrWhiteSpace(titleEn) ? titleZh! : titleEn,
                string.IsNullOrWhiteSpace(url) ? FallbackAnnouncement.Url : url);
        }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or OperationCanceledException or InvalidOperationException)
        {
            return FallbackAnnouncement;
        }
    }

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
