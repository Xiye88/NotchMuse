using System.Net.Http.Headers;
using System.Text.Json;
using System.Net.Http;
using NotchMuse.Core;

namespace NotchMuse.App;

public sealed record ReleaseInfo(string TagName, string Name, string Body, string HtmlUrl);

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
        var root = document.RootElement;
        return new ReleaseInfo(
            root.TryGetProperty("tag_name", out var tag) ? tag.GetString() ?? "" : "",
            root.TryGetProperty("name", out var name) ? name.GetString() ?? "" : "",
            root.TryGetProperty("body", out var body) ? body.GetString() ?? "" : "",
            root.TryGetProperty("html_url", out var url) ? url.GetString() ?? "" : "");
    }

    public static bool IsNewer(string current, ReleaseInfo latest) => VersionComparison.Compare(current, latest.TagName) < 0;
}
