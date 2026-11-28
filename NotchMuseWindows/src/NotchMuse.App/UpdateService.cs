using System.Net.Http.Headers;
using System.Text.Json;
using System.Net.Http;
using NotchMuse.Core;

namespace NotchMuse.App;

public sealed record ReleaseInfo(string TagName, string Name, string Body, string HtmlUrl, string? DownloadUrl = null);

public sealed record AnnouncementInfo(
    string Id,
    string TitleZh,
    string TitleEn,
    string Url,
    string? SummaryZh = null,
    string? SummaryEn = null,
    IReadOnlyList<string>? HighlightsZh = null,
    IReadOnlyList<string>? HighlightsEn = null);

public sealed class UpdateService(HttpClient client)
{
    private const string LatestUrl = "https://api.github.com/repos/Xiye88/NotchMuse/releases/latest";
    private const string AnnouncementFeedUrl = "https://notchmuse.com/announcements.json";

    public static readonly AnnouncementInfo FallbackAnnouncement = new(
        "v0.9.0",
        "v0.9.0 最新版本进展",
        "v0.9.0 Latest Updates",
        "https://github.com/Xiye88/NotchMuse/releases",
        SummaryZh: "NotchMuse for Windows v0.9.0 现已全面拉齐 Mac 端 Vinyl Studio 质感与多源歌词精准度引擎，支持 Win11 任务栏嵌入、顶部悬浮岛与桌面自由悬浮三大模式。",
        SummaryEn: "NotchMuse for Windows v0.9.0 brings Mac-parity Vinyl Studio aesthetics, our high-precision multi-source lyrics engine, and Win11 Taskbar / Top Island / Free Float desktop modes.",
        HighlightsZh:
        [
            "歌词匹配提速 3.6×：多源渐进式早停引擎，实测 100 首命中率 99.0%，纯音乐 0 误匹配",
            "桌面三模式全线双行：Win11 居中任务栏左下角、顶部悬浮岛与自由悬浮均实时响应单/双行切换",
            "自由悬浮更跟手：基于真实歌词胶囊贴边拖拽（直达顶/底边），6 键全图标悬停栏紧贴操控",
            "智能鼠标穿透避让：锁定穿透状态下鼠标移近歌词自动隐藏避让，零遮挡点击后方窗口",
            "自动更新检测已默认开启：后台静默监测 GitHub Releases 新版并在左下角即时提醒"
        ],
        HighlightsEn:
        [
            "3.6× faster lyrics lookup with progressive early-exit consensus (99.0% hit rate, 0% instrumental FP)",
            "Full double-line lyrics across Win11 Taskbar bottom-left, Top Island, and Free Float overlays",
            "Smart capsule-edge free dragging right up to top/bottom edges with compact 6-icon hover bar",
            "Auto-dodge click-through: locked lyrics softly fade out on cursor hover so underlying clicks are unobstructed",
            "Automatic update checks enabled by default with instant bottom-left alerts for new releases"
        ]);

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

            var id = GetStringProp(root, "id") ?? FallbackAnnouncement.Id;
            var titleZh = GetStringProp(root, "title_zh");
            var titleEn = GetStringProp(root, "title_en");
            var url = GetStringProp(root, "url") ?? FallbackAnnouncement.Url;
            if (string.IsNullOrWhiteSpace(titleZh) && string.IsNullOrWhiteSpace(titleEn)) return FallbackAnnouncement;

            var summaryZh = GetStringProp(root, "body_zh") ?? GetStringProp(root, "summary_zh") ?? FallbackAnnouncement.SummaryZh;
            var summaryEn = GetStringProp(root, "body_en") ?? GetStringProp(root, "summary_en") ?? FallbackAnnouncement.SummaryEn;
            var highlightsZh = GetStringArrayProp(root, "highlights_zh") ?? FallbackAnnouncement.HighlightsZh;
            var highlightsEn = GetStringArrayProp(root, "highlights_en") ?? FallbackAnnouncement.HighlightsEn;

            return new AnnouncementInfo(
                id,
                string.IsNullOrWhiteSpace(titleZh) ? titleEn! : titleZh,
                string.IsNullOrWhiteSpace(titleEn) ? titleZh! : titleEn,
                url,
                summaryZh,
                summaryEn,
                highlightsZh,
                highlightsEn);
        }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or OperationCanceledException or InvalidOperationException)
        {
            return FallbackAnnouncement;
        }
    }

    private static string? GetStringProp(JsonElement root, string name) =>
        root.TryGetProperty(name, out var el) && el.ValueKind == JsonValueKind.String ? el.GetString() : null;

    private static IReadOnlyList<string>? GetStringArrayProp(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var el) || el.ValueKind != JsonValueKind.Array) return null;
        var list = new List<string>();
        foreach (var item in el.EnumerateArray())
        {
            if (item.ValueKind == JsonValueKind.String)
            {
                var s = item.GetString();
                if (!string.IsNullOrWhiteSpace(s)) list.Add(s.Trim());
            }
        }
        return list.Count > 0 ? list : null;
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
