using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace NotchMuse.App.Themes;

public static class ThemeManager
{
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmwaBorderColor = 34;
    private const int DwmcpRound = 2;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static bool IsDarkActive { get; private set; }

    public static bool IsSystemLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (key?.GetValue("AppsUseLightTheme") is int value) return value != 0;
        }
        catch (UnauthorizedAccessException) { }
        return true;
    }

    public static bool IsTaskbarLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (key?.GetValue("SystemUsesLightTheme") is int value) return value != 0;
        }
        catch (UnauthorizedAccessException) { }
        return true;
    }

    public static bool ResolveIsDark(AppThemeMode mode) => mode switch
    {
        AppThemeMode.Dark => true,
        AppThemeMode.Light => false,
        _ => !IsSystemLightTheme()
    };

    public static void ApplyAppTheme(AppThemeMode mode, Window? mainWindow = null)
    {
        var dark = ResolveIsDark(mode);
        IsDarkActive = dark;

        var app = System.Windows.Application.Current;
        if (app is not null)
        {
            var uri = new Uri(dark ? "Themes/DarkTokens.xaml" : "Themes/LightTokens.xaml", UriKind.Relative);
            var nextTokens = new ResourceDictionary { Source = uri };
            var merged = app.Resources.MergedDictionaries;
            for (var i = merged.Count - 1; i >= 0; i--)
            {
                var src = merged[i].Source?.OriginalString ?? "";
                if (src.Contains("LightTokens.xaml", StringComparison.OrdinalIgnoreCase) ||
                    src.Contains("DarkTokens.xaml", StringComparison.OrdinalIgnoreCase))
                {
                    merged.RemoveAt(i);
                }
            }
            merged.Insert(0, nextTokens);
        }

        if (mainWindow is not null)
        {
            ApplyWindowChrome(mainWindow, dark);
        }
    }

    public static void ApplyWindowChrome(Window window, bool dark)
    {
        var hwnd = new WindowInteropHelper(window).Handle;
        if (hwnd == IntPtr.Zero) return;

        var darkFlag = dark ? 1 : 0;
        _ = DwmSetWindowAttribute(hwnd, DwmwaUseImmersiveDarkMode, ref darkFlag, sizeof(int));

        var cornerPref = DwmcpRound;
        _ = DwmSetWindowAttribute(hwnd, DwmwaWindowCornerPreference, ref cornerPref, sizeof(int));

        // Subtle Win11 DWM border matching theme so there is ZERO harsh white ring
        var borderColorRef = dark ? 0x002B2B30 : 0x00D8D5CD; // COLORREF is 0x00BBGGRR
        _ = DwmSetWindowAttribute(hwnd, DwmwaBorderColor, ref borderColorRef, sizeof(int));
    }

    public static System.Windows.Media.Color ParseColor(string hex, System.Windows.Media.Color fallback)
    {
        try
        {
            if (System.Windows.Media.ColorConverter.ConvertFromString(hex) is System.Windows.Media.Color c)
                return c;
        }
        catch (FormatException) { }
        return fallback;
    }

    public static System.Windows.Media.Brush CreateLyricAccentBrush(AppSettings settings)
    {
        var start = ParseColor(settings.AccentHex, IsDarkActive
            ? System.Windows.Media.Color.FromRgb(255, 138, 54)
            : System.Windows.Media.Color.FromRgb(224, 109, 27));

        if (settings.ColorMode == LyricColorMode.Gradient)
        {
            var end = ParseColor(settings.GradientEndHex, System.Windows.Media.Color.FromRgb(255, 178, 102));
            return new LinearGradientBrush(start, end, new System.Windows.Point(0, 0.5), new System.Windows.Point(1, 0.5));
        }

        return new SolidColorBrush(start);
    }
}
