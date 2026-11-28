using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

namespace NotchMuse.Core;

public static partial class TrackMatcher
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int LCMapStringEx(string locale, uint flags, string source, int sourceLength,
        StringBuilder destination, int destinationLength, IntPtr version, IntPtr reserved, IntPtr sortHandle);

    public static string Simplified(string text)
    {
        if (!OperatingSystem.IsWindows()) return text;
        var output = new StringBuilder(text.Length * 3 + 1);
        var result = LCMapStringEx("zh-CN", 0x02000000, text, -1, output, output.Capacity, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        return result > 0 ? output.ToString() : text;
    }

    public static string Normalize(string text)
    {
        // Contextual 乾淨/乾净 -> 干净 while preserving standalone 乾/幹 (e.g. 乾隆) and 髮/發.
        text = text.Replace("乾淨", "干净", StringComparison.Ordinal).Replace("乾净", "干净", StringComparison.Ordinal);
        text = text.Replace('妳', '你').Replace('乾', '\uE000').Replace('幹', '\uE001').Replace('髮', '\uE002').Replace('發', '\uE003');
        text = Simplified(text).Replace('\uE000', '乾').Replace('\uE001', '幹').Replace('\uE002', '髮').Replace('\uE003', '發').Normalize(NormalizationForm.FormD);
        return string.Concat(text.Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark && char.IsLetterOrDigit(c)))
            .Normalize(NormalizationForm.FormC)
            .ToLowerInvariant();
    }

    private static string StripSoundtrackBilling(string title)
    {
        const string medium = @"(?:[电電][视視][剧劇]|[连連][续續][剧劇]|[网網][剧劇]|[电電]影|[动動][画畫]|[动動]漫|[游遊][戏戲]|[综綜][艺藝])";
        const string role = @"(?:心[动動]曲|片尾曲|主[题題]曲|插曲|片[头頭]曲|[开開][场場]曲)";
        const string bracketed = @"[\(\[（【]\s*(?:" + medium + @")?《[^》]+》[^)\]）】]*[\)\]）】]";
        const string suffix = @"\s*(?:[-–—:：|·]\s*)?(?:" + medium + @"\s*)?《[^》]+》\s*(?:的\s*)?" + role + @"\s*$";
        return Regex.Replace(Regex.Replace(title, bracketed, ""), suffix, "").Trim();
    }

    public static string ArtistKey(string artist)
    {
        var key = Normalize(artist.Replace("JC 陈咏桐", "JC", StringComparison.OrdinalIgnoreCase));
        return Aliases.TryGetValue(key, out var mapped) ? Normalize(mapped) : key;
    }

    public static string[] Collaborators(string title) => Regex.Matches(title,
        @"(?:[\(\[（]\s*(?:feat\.?|ft\.?|featuring|with)|\s+(?:feat\.?|ft\.?|featuring))\s+([^\)\]）]+)", RegexOptions.IgnoreCase)
        .Select(m => m.Groups[1].Value.Trim()).Where(s => s.Length > 0).ToArray();

    public static HashSet<string> ArtistGroup(string value) => Regex.Split(
        Regex.Replace(value, @"\b(?:feat\.?|ft\.?|featuring)\s*", ",", RegexOptions.IgnoreCase), @"[,;&/×、]")
        .Select(ArtistKey).Where(s => s.Length > 0).ToHashSet(StringComparer.Ordinal);

    public static (string Name, HashSet<string> Versions) ParseTitle(string title)
    {
        var name = title.ToLowerInvariant();
        name = Regex.Replace(name, @"[\(\[（][^\)\]）]*\b(?:feat\.?|ft\.?|featuring|with)\s+[^\)\]）]*[\)\]）]|\s+\b(?:feat\.?|ft\.?|featuring)\s+.*$", "");
        name = StripSoundtrackBilling(name);
        var versions = Regex.Matches(name, @"\b(live|remix|acoustic|instrumental|remaster(?:ed)?|cover|rerecorded)\b")
            .Select(m => m.Value.Replace("remastered", "remaster")).ToHashSet();
        foreach (var hint in new[] { "现场", "翻唱", "伴奏", "混音", "重录" })
            if (name.Contains(hint, StringComparison.Ordinal)) versions.Add(hint);
        if (name.Contains("現場", StringComparison.Ordinal)) versions.Add("现场");
        if (versions.Contains("remaster"))
            foreach (Match year in Regex.Matches(name, @"\b(?:19|20)\d{2}\b")) versions.Add("remaster:" + year.Value);
        name = Regex.Replace(name, @"[\(\[][^\)\]]*\b(?:remaster(?:ed)?|live|remix|acoustic|instrumental)\b[^\)\]]*[\)\]]|\s+-\s+.*\b(?:remaster(?:ed)?|live|remix|acoustic|instrumental)\b.*$", "");
        var subtitle = Regex.Match(name, @"\s*[\(（][^\(\)（）]*[\u4e00-\u9fff][^\(\)（）]*[\)）]\s*$");
        if (subtitle.Success && versions.Count == 0 && name[..subtitle.Index].Trim().Length > 0 && name[..subtitle.Index].All(c => c < 0x3400))
            name = name[..subtitle.Index];
        return (Normalize(name), versions);
    }

    public static string? IdentityRejection(Track track, string title, string artist, string? album)
    {
        var a = ParseTitle(track.Title); var b = ParseTitle(title);
        if (a.Name.Length == 0 || a.Name != b.Name) return "title_mismatch";
        if (!a.Versions.SetEquals(b.Versions)) return "version_mismatch";
        var source = ArtistGroup(track.Artist + "," + string.Join(',', Collaborators(track.Title)));
        var candidate = ArtistGroup(artist + "," + string.Join(',', Collaborators(title)));
        var andParts = Regex.Split(artist, @"\s+and\s+", RegexOptions.IgnoreCase).Select(ArtistKey).ToArray();
        if (andParts.Length > 1 && andParts.All(source.Contains)) candidate = andParts.ToHashSet();
        var subset = source.Count == 1 && candidate.Count >= 2 && source.IsSubsetOf(candidate)
            || track.IsMusicVideo && candidate.Count == 1 && source.Count >= 2 && candidate.IsSubsetOf(source);
        if (source.Count == 0 || !source.SetEquals(candidate) && !subset) return "artist_mismatch";
        if (!string.IsNullOrWhiteSpace(track.Album) && album is not null &&
            !ParseTitle(track.Title + " " + track.Album).Versions.SetEquals(ParseTitle(title + " " + album).Versions))
            return "album_version_mismatch";
        if (string.IsNullOrWhiteSpace(track.Album) && !string.IsNullOrWhiteSpace(album) &&
            !a.Versions.Contains("live") && !a.Versions.Contains("现场"))
        {
            var albumVersions = ParseTitle(album).Versions;
            var simplifiedAlbum = Simplified(album);
            if ((track.IsMusicVideo && (albumVersions.Contains("live") || albumVersions.Contains("现场"))) ||
                simplifiedAlbum.Contains("演唱会", StringComparison.Ordinal) ||
                simplifiedAlbum.Contains("演唱會", StringComparison.Ordinal) ||
                Regex.IsMatch(album, @"\b(?:in concert|concert recording)\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
                return "album_version_mismatch";
        }
        return null;
    }

    public static int Score(Track track, string title, string artist, double duration)
    {
        if (!double.IsFinite(duration) || duration <= 0 || !double.IsFinite(track.Duration) || track.Duration <= 0 ||
            Math.Abs(track.Duration - duration) > (track.IsMusicVideo ? 22 : 5) || IdentityRejection(track, title, artist, null) is not null) return 0;
        var a = ArtistGroup(track.Artist + "," + string.Join(',', Collaborators(track.Title)));
        var b = ArtistGroup(artist + "," + string.Join(',', Collaborators(title)));
        var delta = Math.Abs(track.Duration - duration);
        return 55 + (a.SetEquals(b) ? 30 : 27) + (delta <= 2 ? 15 : delta <= 5 ? 11 : delta <= 8 ? 7 : 3);
    }

    public static bool AlbumMatches(string? album, Track track)
    {
        if (string.IsNullOrWhiteSpace(album) || string.IsNullOrWhiteSpace(track.Album)) return false;
        static string Key(string s)
        {
            var stripped = Regex.Replace(s, @"\s*[-–—]\s*(Single|EP)\s*$", "", RegexOptions.IgnoreCase);
            var canonical = Simplified(stripped)
                .Replace("十二月", "12月", StringComparison.Ordinal)
                .Replace("十一月", "11月", StringComparison.Ordinal)
                .Replace("十月", "10月", StringComparison.Ordinal);
            return ParseTitle(canonical).Name;
        }
        if (Key(album) == Key(track.Album)) return true;
        var hanA = string.Concat(Key(album).Where(c => c is >= '\u3400' and <= '\u9fff'));
        var hanB = string.Concat(Key(track.Album).Where(c => c is >= '\u3400' and <= '\u9fff'));
        if (hanA.Length >= 2 && hanA == hanB && Key(album).Any(char.IsAsciiLetter) != Key(track.Album).Any(char.IsAsciiLetter) &&
            ParseTitle(album).Versions.SetEquals(ParseTitle(track.Album).Versions)) return true;
        return Key(Regex.Replace(album, @"\s*[\(（][^\(\)（）]+[\)）]\s*$", "")) == Key(Regex.Replace(track.Album, @"\s*[\(（][^\(\)（）]+[\)）]\s*$", ""));
    }

    public static string SearchQuery(Track t)
    {
        var title = StripSoundtrackBilling(Regex.Replace(t.Title,
            @"[\(\[（][^\)\]）]*(?:feat\.?|ft\.?|featuring|with)\s+[^\)\]）]*[\)\]）]",
            "", RegexOptions.IgnoreCase));
        var artistSeparators = Regex.IsMatch(t.Artist, @"[\u4e00-\u9fff]") ? @"[,;&/×、]" : @"[,;/×、]";
        var artists = Regex.Split(t.Artist, artistSeparators)
            .Select(a => a.Trim())
            .Where(a => a.Length > 0)
            .Select(a => a.Equals("JC", StringComparison.OrdinalIgnoreCase)
                ? "JC"
                : Aliases.GetValueOrDefault(Normalize(a), Simplified(a)))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        return $"{Simplified(title)} {string.Join(' ', artists)}".Trim();
    }
}
