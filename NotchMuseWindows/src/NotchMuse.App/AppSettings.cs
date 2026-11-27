using System.IO;
using System.Text.Json;

namespace NotchMuse.App;

public enum AppThemeMode
{
    System,
    Light,
    Dark
}

public enum LyricsDisplayMode
{
    Taskbar,
    TopIsland,
    FreeFloat
}

public enum LyricColorMode
{
    Solid,
    Gradient
}

public enum PlayerStopBehavior
{
    Hide,
    Keep
}

public enum MissingLyricsAnimationStyle
{
    VinylSeek,
    CassetteB,
    RunawayNotes,
    RadarPulse,
    FloatingCloud,
    EqualizerBounce
}

public enum AppearanceStylePreset
{
    Warm,
    Minimal,
    Soft,
    Pure
}

public sealed class AppSettings
{
    public AppThemeMode ThemeMode { get; set; } = AppThemeMode.Light;
    public LyricsDisplayMode DisplayMode { get; set; } = LyricsDisplayMode.Taskbar;
    public LyricColorMode ColorMode { get; set; } = LyricColorMode.Solid;
    public string AccentHex { get; set; } = "#E06D1B";
    public string GradientEndHex { get; set; } = "#FF9E44";
    public double FontSize { get; set; } = 22;
    public double AnimationSpeed { get; set; } = 1.0;
    public double LyricOpacity { get; set; } = 1.0;
    public bool BackgroundCapsuleEnabled { get; set; } = true;
    public AppearanceStylePreset StylePreset { get; set; } = AppearanceStylePreset.Warm;
    public string PlayerSelection { get; set; } = "auto";
    public PlayerStopBehavior StopBehavior { get; set; } = PlayerStopBehavior.Hide;
    public MissingLyricsAnimationStyle MissingLyricsStyle { get; set; } = MissingLyricsAnimationStyle.VinylSeek;
    public bool EnglishLanguage { get; set; }
    public bool BilingualEnabled { get; set; } = true;
    public double TimeOffsetSeconds { get; set; }
    public string DisplayScreen { get; set; } = "Primary";
    public bool OverlayLocked { get; set; }
    public double? FloatingLeft { get; set; }
    public double? FloatingTop { get; set; }

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private static string SettingsPath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NotchMuse", "settings.json");

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var parsed = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath));
                if (parsed is not null)
                {
                    parsed.FontSize = Math.Clamp(parsed.FontSize, 12, 40);
                    parsed.AnimationSpeed = Math.Clamp(parsed.AnimationSpeed, 0.5, 2.0);
                    parsed.LyricOpacity = Math.Clamp(parsed.LyricOpacity, 0.3, 1.0);
                    parsed.TimeOffsetSeconds = Math.Clamp(parsed.TimeOffsetSeconds, -10, 10);
                    return parsed;
                }
            }
        }
        catch (IOException) { }
        catch (JsonException) { }
        catch (UnauthorizedAccessException) { }

        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            var dir = Path.GetDirectoryName(SettingsPath);
            if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, JsonOptions));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
