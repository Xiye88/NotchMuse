using System.Diagnostics;
using System.IO;

namespace NotchMuse.App;

public sealed record LaunchablePlayer(string Id, string LabelZh, string LabelEn, string? DetectedExecutable, string? ProtocolUri)
{
    public bool IsInstalled => !string.IsNullOrWhiteSpace(DetectedExecutable);
}

/// <summary>
/// Detects locally installed Windows music players and launches the user's preferred player
/// when Play is pressed with no active SMTC media session (Mac Build 98 parity).
/// </summary>
public static class DefaultPlayerLauncher
{
    public static IReadOnlyList<LaunchablePlayer> DetectAll()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);

        return
        [
            new("none", "不自动启动", "Do not auto-launch", null, null),
            new("spotify", "Spotify", "Spotify",
                FirstExisting(
                    Path.Combine(appData, "Spotify", "Spotify.exe"),
                    Path.Combine(localAppData, "Microsoft", "WindowsApps", "Spotify.exe")),
                "spotify:"),
            new("netease", "网易云音乐", "NetEase Cloud Music",
                FirstExisting(
                    Path.Combine(pf86, "Netease", "CloudMusic", "cloudmusic.exe"),
                    Path.Combine(pf, "Netease", "CloudMusic", "cloudmusic.exe"),
                    @"D:\CloudMusic\cloudmusic.exe",
                    @"D:\Program Files\Netease\CloudMusic\cloudmusic.exe",
                    @"D:\Program Files (x86)\Netease\CloudMusic\cloudmusic.exe"),
                "orpheus:"),
            new("qq", "QQ 音乐", "QQ Music",
                FirstExisting(
                    Path.Combine(pf86, "Tencent", "QQMusic", "QQMusic.exe"),
                    Path.Combine(pf, "Tencent", "QQMusic", "QQMusic.exe"),
                    @"D:\Program Files (x86)\Tencent\QQMusic\QQMusic.exe",
                    @"D:\Program Files\Tencent\QQMusic\QQMusic.exe"),
                "qqmusic:"),
            new("soda", "汽水音乐", "Soda Music",
                FirstExisting(
                    Path.Combine(localAppData, "Programs", "SodaMusic", "SodaMusic.exe"),
                    Path.Combine(localAppData, "SodaMusic", "SodaMusic.exe"),
                    Path.Combine(pf, "SodaMusic", "SodaMusic.exe")),
                "sodamusic:"),
            new("kugou", "酷狗音乐", "Kugou Music",
                FirstExisting(
                    Path.Combine(pf86, "KuGou", "KGMusic", "KuGou.exe"),
                    Path.Combine(pf, "KuGou", "KGMusic", "KuGou.exe"),
                    @"D:\Program Files (x86)\KuGou\KGMusic\KuGou.exe"),
                "kugou:"),
            new("apple", "Apple Music", "Apple Music",
                FirstExisting(
                    Path.Combine(localAppData, "Microsoft", "WindowsApps", "AppleMusic.exe")),
                "applemusic:")
        ];
    }

    public static bool TryLaunch(string playerId, out string? launchedLabel, bool english)
    {
        launchedLabel = null;
        if (string.IsNullOrWhiteSpace(playerId) || playerId == "none") return false;

        var player = DetectAll().FirstOrDefault(p => string.Equals(p.Id, playerId, StringComparison.OrdinalIgnoreCase));
        if (player is null) return false;
        launchedLabel = english ? player.LabelEn : player.LabelZh;

        if (!string.IsNullOrWhiteSpace(player.DetectedExecutable) && File.Exists(player.DetectedExecutable))
        {
            try
            {
                Process.Start(new ProcessStartInfo(player.DetectedExecutable) { UseShellExecute = true });
                return true;
            }
            catch (System.ComponentModel.Win32Exception) { }
        }

        if (!string.IsNullOrWhiteSpace(player.ProtocolUri))
        {
            try
            {
                Process.Start(new ProcessStartInfo(player.ProtocolUri) { UseShellExecute = true });
                return true;
            }
            catch (System.ComponentModel.Win32Exception) { }
        }

        return false;
    }

    private static string? FirstExisting(params string[] candidates) =>
        candidates.FirstOrDefault(p => !string.IsNullOrWhiteSpace(p) && File.Exists(p));
}
