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
    public static string? WebPlatform(string title) => Sites.FirstOrDefault(s =>
        Regex.IsMatch(title, @"(?:\s*[-–—|·]\s*|^|\s+on\s+)" + Regex.Escape(s.Suffix) + @"\s*$", RegexOptions.IgnoreCase)).Platform;
    public static Track Clean(Track track, bool splitGeneric = false)
    {
        var title = track.Title.Trim(); var artist = track.Artist.Trim();
        var web = WebPlatform(title);
        var youtube = track.IsMusicVideo || track.Platform == "youtube" || web == "youtube";
        foreach (var site in Sites)
            title = Regex.Replace(title, @"\s*(?:[-–—|·]|\bon)\s*" + Regex.Escape(site.Suffix) + @"\s*$", "", RegexOptions.IgnoreCase);
        if (youtube)
        {
            for (var i = 0; i < 2; i++)
            {
                title = Regex.Replace(title, @"\s*[\(\[【（]\s*(?:official\s*)?(?:music\s*)?(?:video|mv|m/v|audio|lyric\s*video|lyrics?|visualizer|hd|4k|live\s*video|官方(?:音乐)?(?:视频|音频)|官方完整版|高画質|高画质|纯享版|純享版|歌词版|歌詞版)[^)\]】）]*[\)\]】）]", "", RegexOptions.IgnoreCase);
                title = Regex.Replace(title, @"\s+(?:official\s+(?:music\s+)?video|official\s+mv|official\s+audio|music\s+video|m/v|mv)\s*$", "", RegexOptions.IgnoreCase);
            }
            title = Regex.Replace(title, @"\s*[-–—|·]\s*(?:official\s+)?(?:youtube\s+music|youtube)\s*$", "", RegexOptions.IgnoreCase);
        }
        else
        {
            title = Regex.Replace(title, @"\s*[\(\[（](?:official\s*(?:music\s*)?(?:video|audio|lyric\s*video)|lyrics?|官方(?:音乐)?(?:视频|音频)|高清|\d{3,4}p|4k)[\)\]）]", "", RegexOptions.IgnoreCase);
        }
        artist = Regex.Replace(artist, @"\s*-\s*Topic\s*$", "", RegexOptions.IgnoreCase).Trim();
        if (youtube)
        {
            artist = Regex.Replace(artist, @"\s*(?:VEVO|official|官方)\s*$", "", RegexOptions.IgnoreCase).Trim();
            if (Regex.IsMatch(artist, @"(?:vevo|records|entertainment|唱片|音乐|official channel)", RegexOptions.IgnoreCase))
                artist = "";
        }
        if (title.StartsWith(artist + " - ", StringComparison.OrdinalIgnoreCase))
            title = title[(artist.Length + 3)..].Trim();
        if ((splitGeneric || youtube || string.IsNullOrWhiteSpace(artist)) && title.Split(" - ", 2) is [var left, var right])
        {
            if (string.IsNullOrWhiteSpace(artist) || youtube || TrackMatcher.ArtistKey(artist) == TrackMatcher.ArtistKey(left))
            { artist = left.Trim(); title = right.Trim(); }
        }
        var collaborators = TrackMatcher.Collaborators(title);
        if (collaborators.Length > 0)
        {
            artist = string.Join(", ", new[] { artist }.Concat(collaborators).Where(a => a.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase));
            title = Regex.Replace(title, @"\s*(?:[\(\[（]\s*(?:feat\.?|ft\.?|featuring|with)|\s+(?:feat\.?|ft\.?|featuring))\s+[^\)\]）]+[\)\]）]?", "", RegexOptions.IgnoreCase).Trim();
        }
        return track with { Title = title, Artist = artist, Platform = web ?? track.Platform,
            IsMusicVideo = track.IsMusicVideo || web == "youtube" };
    }
}
