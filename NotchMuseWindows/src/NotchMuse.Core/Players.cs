using System.Text.RegularExpressions;

namespace NotchMuse.Core;

public sealed record PlayerProfile(string Id, string Label, string Group, string[] Tokens, bool ManualOnly = false);
public static class PlayerCatalog
{
    public static readonly PlayerProfile[] Players =
    [
        new("spotify", "Spotify", "主流播放器", ["spotify"]),
        new("apple", "Apple Music", "主流播放器", ["applemusic", "appleinc.applemusic"]),
        new("youtube", "YouTube Music", "主流播放器", ["youtube", "th-ch", "ytmdesktop"]),
        new("netease", "网易云音乐", "主流播放器", ["cloudmusic", "netease"]),
        new("qq", "QQ 音乐", "主流播放器", ["qqmusic"]),
        new("soda", "汽水音乐", "主流播放器", ["sodamusic", "汽水"]),
        new("kugou", "酷狗音乐", "主流播放器", ["kugou"]),
        new("kuwo", "酷我音乐", "国内与开源播放器", ["kuwo"]),
        new("migu", "咪咕音乐", "国内与开源播放器", ["migu"]),
        new("bodian", "波点音乐", "国内与开源播放器", ["bodian"]),
        new("qianqian", "千千音乐", "国内与开源播放器", ["qianqian", "ttplayer"]),
        new("lx", "洛雪音乐（LX Music）", "国内与开源播放器", ["lx-music", "lxmusic"]),
        new("yesplay", "YesPlayMusic", "国内与开源播放器", ["yesplaymusic"]),
        new("alger", "AlgerMusicPlayer", "国内与开源播放器", ["algermusic"]),
        new("listen1", "Listen 1", "国内与开源播放器", ["listen1", "listen 1"]),
        new("splayer", "SPlayer", "国内与开源播放器", ["splayer"]),
        new("tidal", "TIDAL", "海外、发烧友与自建库", ["tidal"]),
        new("amazon", "Amazon Music", "海外、发烧友与自建库", ["amazonmusic", "amazon.music"]),
        new("deezer", "Deezer", "海外、发烧友与自建库", ["deezer"]),
        new("qobuz", "Qobuz", "海外、发烧友与自建库", ["qobuz"]),
        new("plexamp", "Plexamp", "海外、发烧友与自建库", ["plexamp"]),
        new("cider", "Cider", "海外、发烧友与自建库", ["cider"]),
        new("soundcloud", "SoundCloud", "海外、发烧友与自建库", ["soundcloud"]),
        new("bandcamp", "Bandcamp", "海外、发烧友与自建库", ["bandcamp"]),
        new("foobar", "foobar2000", "海外、发烧友与自建库", ["foobar2000"]),
        new("audirvana", "Audirvana", "海外、发烧友与自建库", ["audirvana"]),
        new("roon", "Roon", "海外、发烧友与自建库", ["roon"]),
        new("vox", "VOX", "海外、发烧友与自建库", ["vox"]),
        new("feishin", "Feishin", "海外、发烧友与自建库", ["feishin"]),
        new("supersonic", "Supersonic", "海外、发烧友与自建库", ["supersonic"]),
        new("aimp", "AIMP", "海外、发烧友与自建库", ["aimp"]),
        new("musicbee", "MusicBee", "海外、发烧友与自建库", ["musicbee"]),
        new("vlc", "VLC", "视频与媒体（仅手动）", ["vlc"], true),
        new("potplayer", "PotPlayer", "视频与媒体（仅手动）", ["potplayer"], true),
        new("mpv", "mpv", "视频与媒体（仅手动）", ["mpv"], true),
        new("bilibili", "Bilibili 桌面端", "视频与媒体（仅手动）", ["bilibili", "哔哩"], true)
    ];
    private static readonly string[] Blacklist = ["zoom", "msteams", "microsoftteams", "microsoft.teams", "wemeetapp", "wechat", "weixin", "discord", "slack", "obs"];
    public static bool IsBrowser(string id) => new[] { "msedge", "chrome", "firefox", "brave", "arc.exe", "arc_", "thebrowsercompany.arc" }.Any(s => id.Contains(s, StringComparison.OrdinalIgnoreCase));
    public static PlayerProfile? Identify(string id) => Players.FirstOrDefault(p => p.Tokens.Any(t => id.Contains(t, StringComparison.OrdinalIgnoreCase)));
    public static bool IsBlacklisted(string id) => Blacklist.Any(b => id.Contains(b, StringComparison.OrdinalIgnoreCase));
    public static bool Allows(string id, string title, string selection)
    {
        if (IsBlacklisted(id)) return false;
        var profile = Identify(id);
        if (selection == "all") return true;
        if (selection != "auto") return profile?.Id == selection || IsBrowser(id) && MediaMetadataSanitizer.WebPlatform(title) == selection;
        if (profile is { ManualOnly: false }) return true;
        return IsBrowser(id) && MediaMetadataSanitizer.WebPlatform(title) is { } web && web != "bilibili";
    }
}

public static class MediaMetadataSanitizer
{
    private static readonly (string Suffix, string Platform)[] Sites =
    [
        ("YouTube Music", "youtube"), ("Spotify", "spotify"), ("Apple Music", "apple"),
        ("网易云音乐", "netease"), ("QQ音乐", "qq"), ("QQ 音乐", "qq"),
        ("SoundCloud", "soundcloud"), ("Bandcamp", "bandcamp"), ("Bilibili", "bilibili"), ("哔哩哔哩", "bilibili")
    ];

    private static readonly string[] VideoNoisePatterns =
    [
        @"\s*[\(\[【（［]\s*(?:Official\s+)?(?:Music\s+)?(?:Video|MV|M/V|Audio|Lyric\s+Video|Lyrics?|Visualizer|Visual|HD|4K|original\s+ver\.?)\s*[\)\]】）］]",
        @"\s*[\(\[【（［]\s*(?:(?:官方|華納|华纳|高畫質|高画质|HD|Official)\s*)*(?:MV|完整版|高清|高畫質|纯享版|純享版|歌词版|歌詞版|动态歌词|動態歌詞)\s*[\)\]】）］]",
        @"\s*[\(\[【（［][^()\[\]【】（）［］]*(?:官方完整版|高畫質|官方MV|动态歌词|動態歌詞|純享版|纯享版)[^()\[\]【】（）［］]*[\)\]】）］]",
        @"\s*[\(\[]\s*(?:from\s+[^)\]]+|Spider-Man:[^)\]]+)\s*[\)\]]",
        @"\s+(?:Official\s+Music\s+Video|Official\s+Video|Official\s+MV|Official\s+Audio|MUSIC\s+VIDEO|M/V|MV|Official)\s*$"
    ];

    private static readonly string[] ChannelArtistKeywords =
    [
        "vevo", "labels", "smtown", "jyp entertainment", "yg entertainment",
        "records", "binmusic", "jvr music", "warner music", "sony music",
        "universal music", "1thek", "youtube channel", "official channel",
        "滚石唱片", "滾石唱片", "杰威尔音乐", "杰威爾音樂", "相信音樂", "相信音乐",
        "華納音樂", "华纳音乐", "福茂唱片", "海蝶音乐", "海蝶音樂"
    ];

    public static string? WebPlatform(string title) => Sites.FirstOrDefault(s =>
        Regex.IsMatch(title, @"(?:\s*[-–—|·]\s*|^|\s+on\s+)" + Regex.Escape(s.Suffix) + @"\s*$", RegexOptions.IgnoreCase)).Platform;

    public static Track Clean(Track track, bool splitGeneric = false)
    {
        var title = track.Title.Trim();
        var artist = track.Artist.Trim();
        var web = WebPlatform(title);
        var youtube = track.IsMusicVideo || track.Platform == "youtube" || web == "youtube";

        foreach (var site in Sites)
            title = Regex.Replace(title, @"\s*(?:[-–—|·]|\bon)\s*" + Regex.Escape(site.Suffix) + @"\s*$", "", RegexOptions.IgnoreCase);

        if (youtube)
        {
            for (var i = 0; i < 2; i++)
            {
                foreach (var pattern in VideoNoisePatterns)
                    title = Regex.Replace(title, pattern, "", RegexOptions.IgnoreCase);
            }
            title = Regex.Replace(title, @"\s*[-–—|·]\s*(?:official\s+)?(?:youtube\s+music|youtube)\s*$", "", RegexOptions.IgnoreCase).Trim();
        }
        else
        {
            title = Regex.Replace(title, @"\s*[\(\[（](?:official\s*(?:music\s*)?(?:video|audio|lyric\s*video)|lyrics?|官方(?:音乐)?(?:视频|音频)|高清|\d{3,4}p|4k)[\)\]）]", "", RegexOptions.IgnoreCase);
        }

        artist = Regex.Replace(artist, @"\s*-\s*Topic\s*$", "", RegexOptions.IgnoreCase).Trim();
        if (youtube)
        {
            if (artist.EndsWith("VEVO", StringComparison.OrdinalIgnoreCase) && artist.Length > 4)
                artist = artist[..^4].Trim();
            else if (artist.EndsWith(" official", StringComparison.OrdinalIgnoreCase) && artist.Length > 9)
                artist = artist[..^9].Trim();
            if (ChannelArtistKeywords.Any(k => artist.Contains(k, StringComparison.OrdinalIgnoreCase)))
                artist = "";
        }

        var matchingArtist = youtube ? CleanYouTubeArtist(artist) : artist;
        var expectedArtists = TrackMatcher.ArtistGroup(matchingArtist);
        bool MatchesExpectedArtist(string lhs)
        {
            if (expectedArtists.Count == 0) return false;
            var candidateArtists = TrackMatcher.ArtistGroup(youtube ? CleanYouTubeArtist(lhs) : lhs);
            return candidateArtists.Count > 0 && expectedArtists.SetEquals(candidateArtists);
        }

        var extracted = false;
        if (youtube)
        {
            // 1. Prefer verified "Artist - Title" split first so titles containing "-" stay intact!
            if (expectedArtists.Count > 0 && SplitArtistTitle(title, MatchesExpectedArtist, allowMultiPart: true) is { } matchedSplit)
            {
                artist = matchedSplit.Artist;
                title = matchedSplit.Title;
                extracted = true;
            }

            // 2. Bracketed "Artist【Title】..." or "Artist「Title」..." only when artist matches or channel-like
            if (!extracted)
            {
                var bracket = Regex.Match(title, @"^(.+?)\s*(?:【([^】]+)】|「([^」]+)」)(.*)$");
                if (bracket.Success)
                {
                    var lhs = bracket.Groups[1].Value.Trim(' ', '-', '–', '—', '|');
                    var inner = (bracket.Groups[2].Success ? bracket.Groups[2].Value : bracket.Groups[3].Value).Trim();
                    var trailing = bracket.Groups[4].Value.Trim();
                    if (lhs.Length > 0 && inner.Length > 0 && (MatchesExpectedArtist(lhs) || expectedArtists.Count == 0))
                    {
                        artist = lhs;
                        title = inner;
                        var withMatch = Regex.Match(trailing, @"^with\s+([^()\[\]【】]+)", RegexOptions.IgnoreCase);
                        if (withMatch.Success)
                        {
                            var guest = CleanYouTubeArtist(withMatch.Groups[1].Value);
                            if (guest.Length > 0) artist = $"{artist}, {guest}";
                            trailing = trailing[withMatch.Length..].Trim();
                        }
                        if (trailing.Length > 0) title = $"{title} {trailing}";
                        extracted = true;
                    }
                }
            }

            // 3. Quoted "Artist 'Title'" only when artist matches or channel-like
            if (!extracted)
            {
                var quoted = Regex.Match(title, @"^(.+?)\s*(?:-\s*)?(?:'([^']{2,})'|""([^""]{2,})"")\s*$");
                if (quoted.Success)
                {
                    var lhs = quoted.Groups[1].Value.Trim(' ', '-', '–', '—', '|');
                    var inner = (quoted.Groups[2].Success ? quoted.Groups[2].Value : quoted.Groups[3].Value).Trim();
                    if (lhs.Length > 0 && inner.Length > 0 && (MatchesExpectedArtist(lhs) || expectedArtists.Count == 0))
                    {
                        artist = lhs;
                        title = inner;
                        extracted = true;
                    }
                }
            }

            // 4. Channel/unknown artist fallback: split strictly 2-part "Artist - Title"
            if (!extracted && expectedArtists.Count == 0 && SplitArtistTitle(title, _ => true, allowMultiPart: false) is { } channelSplit)
            {
                artist = channelSplit.Artist;
                title = channelSplit.Title;
                extracted = true;
            }

            title = title.Trim('\'', '"', '“', '”', '‘', '’', ' ');
            foreach (var pattern in VideoNoisePatterns)
                title = Regex.Replace(title, pattern, "", RegexOptions.IgnoreCase);

            artist = string.Join(", ", artist.Split(',').Select(CleanYouTubeArtist).Where(s => s.Length > 0));
            if (TrackMatcher.ParseTitle(title).Versions.Count == 0)
                title = CleanYouTubeTitle(title);
        }
        else if (SplitArtistTitle(title, lhs => MatchesExpectedArtist(lhs) || (splitGeneric && string.IsNullOrWhiteSpace(artist)), allowMultiPart: expectedArtists.Count > 0) is { } genericSplit)
        {
            artist = genericSplit.Artist;
            title = genericSplit.Title;
        }
        var collaborators = TrackMatcher.Collaborators(title);
        if (collaborators.Length > 0)
        {
            artist = string.Join(", ", new[] { artist }.Concat(collaborators).Where(a => a.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase));
            title = Regex.Replace(title, @"\s*(?:[\(\[（]\s*(?:feat\.?|ft\.?|featuring|with)|\s+(?:feat\.?|ft\.?|featuring))\s+[^\)\]）]+[\)\]）]?", "", RegexOptions.IgnoreCase).Trim();
        }
        return track with
        {
            Title = title.Trim(),
            Artist = artist.Trim(),
            Platform = web ?? track.Platform,
            IsMusicVideo = track.IsMusicVideo || web == "youtube"
        };
    }

    private static (string Artist, string Title)? SplitArtistTitle(string value, Func<string, bool> acceptsArtist, bool allowMultiPart)
    {
        foreach (var sep in new[] { " - ", " — ", " – ", " _ " })
        {
            var parts = value.Split(sep);
            if (parts.Length < 2) continue;
            if (!allowMultiPart && parts.Length != 2) continue;
            var lhs = parts[0].Trim();
            var rhs = string.Join(sep, parts.Skip(1)).Trim();
            if (lhs.Length > 0 && rhs.Length > 0 && acceptsArtist(lhs)) return (lhs, rhs);
        }
        return null;
    }

    private static string CleanYouTubeArtist(string raw)
    {
        var value = raw.Trim();
        value = Regex.Replace(value, @"\s*[\(（][^\(\)（）]+[\)）]\s*$", "").Trim();
        var hanLatin = Regex.Match(value, @"^([\u4e00-\u9fff·\s]{2,12})\s+[A-Za-z][A-Za-z0-9\s.'-]{1,24}$");
        if (hanLatin.Success) return hanLatin.Groups[1].Value.Trim();
        var latinKorean = Regex.Match(value, @"^([A-Za-z0-9\s.'-]{2,20})\s+[\uac00-\ud7a3\s]{2,}$");
        if (latinKorean.Success) return latinKorean.Groups[1].Value.Trim();
        return value;
    }

    private static string CleanYouTubeTitle(string raw)
    {
        var value = raw.Trim();
        var latinKorean = Regex.Match(value, @"^([A-Za-z0-9\s.'!?&-]+?)\s*\([\uac00-\ud7a3\s]+\)\s*$");
        if (latinKorean.Success) value = latinKorean.Groups[1].Value.Trim();
        var cjkEnglish = Regex.Match(value, @"^([\u4e00-\u9fff\u3040-\u30ff]{2,16})\s+[A-Za-z][A-Za-z0-9\s'’!?.,-]{2,}$");
        if (cjkEnglish.Success) value = cjkEnglish.Groups[1].Value.Trim();
        return value.Trim();
    }
}
