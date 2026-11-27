using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using NotchMuse.App.Overlays;
using NotchMuse.App.Themes;

namespace NotchMuse.App;

/// <summary>
/// Renders pixel-accurate WPF screenshots of all 4 main pages (Light + Dark)
/// plus the Windows 11 Taskbar Bottom-Left overlay and Floating/Island overlays
/// for mandatory visual inspection.
/// </summary>
public static class AuditSnapshotRunner
{
    public static async Task RunAsync(string outputDir)
    {
        Directory.CreateDirectory(outputDir);

        var main = new MainWindow(isAuditMode: true)
        {
            Width = 1080,
            Height = 700,
            WindowStartupLocation = WindowStartupLocation.Manual,
            Left = -3000,
            Top = -3000,
            ShowInTaskbar = false
        };

        main.Show();
        await FlushRenderAsync();
        main.LoadAuditDemoSession();
        await FlushRenderAsync();

        // 1-4: Light Braun Warm Alabaster (Lyrics, Display, Appearance, General)
        main.SetThemeMode(AppThemeMode.Light);
        main.SelectDisplayMode(LyricsDisplayMode.Taskbar);

        main.NavigateTo("Lyrics");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "01_light_lyrics.png"), 1080, 700);

        main.NavigateTo("Display");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "02_light_display.png"), 1080, 700);

        main.NavigateTo("Appearance");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "03_light_appearance.png"), 1080, 700);

        main.NavigateTo("General");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "04_light_general.png"), 1080, 700);

        // 5-6: Dark Vinyl Hi-Fi (Lyrics + Display)
        main.SetThemeMode(AppThemeMode.Dark);

        main.NavigateTo("Lyrics");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "05_dark_lyrics.png"), 1080, 700);

        main.NavigateTo("Display");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "06_dark_display.png"), 1080, 700);

        // 7: Real Win11 Centered Taskbar Bottom-Left Lyrics Showcase (Light + Dark Win11 taskbars)
        RenderTaskbarShowcase(main.CurrentSettings, Path.Combine(outputDir, "07_win11_taskbar_lyrics.png"));

        // 8: Desktop Free-Floating Lyrics (with hover mini-toolbar) + Top Island Showcase
        RenderDesktopOverlaysShowcase(main.CurrentSettings, Path.Combine(outputDir, "08_desktop_overlays.png"));

        main.Close();
    }

    private static async Task FlushRenderAsync()
    {
        await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Render);
        await Task.Delay(80);
        await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Render);
    }

    private static void SaveVisualPng(FrameworkElement element, string filePath, int width, int height)
    {
        element.Measure(new System.Windows.Size(width, height));
        element.Arrange(new Rect(0, 0, width, height));
        element.UpdateLayout();

        var rtb = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        rtb.Render(element);
        WritePng(rtb, filePath);
    }

    private static void RenderTaskbarShowcase(AppSettings settings, string filePath)
    {
        var canvas = new StackPanel
        {
            Width = 1280,
            Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(234, 232, 226))
        };

        // Light Win11 Desktop bottom edge + centered taskbar with bottom-left lyrics
        canvas.Children.Add(BuildWin11TaskbarStrip(settings, lightTaskbar: true, "Windows 11 浅色居中任务栏 · 左下角空白区歌词实景（BetterLyrics 布局）"));

        // Dark Win11 Desktop bottom edge + centered taskbar with bottom-left lyrics
        canvas.Children.Add(BuildWin11TaskbarStrip(settings, lightTaskbar: false, "Windows 11 深色居中任务栏 · 左下角空白区歌词实景（自动深色文字适配）"));

        SaveVisualPng(canvas, filePath, 1280, 340);
    }

    private static FrameworkElement BuildWin11TaskbarStrip(AppSettings settings, bool lightTaskbar, string label)
    {
        var host = new Grid { Height = 170 };
        // Realistic desktop wallpaper lower section
        host.Background = new LinearGradientBrush(
            lightTaskbar ? System.Windows.Media.Color.FromRgb(218, 224, 232) : System.Windows.Media.Color.FromRgb(24, 28, 38),
            lightTaskbar ? System.Windows.Media.Color.FromRgb(236, 232, 224) : System.Windows.Media.Color.FromRgb(16, 18, 24),
            20);

        var caption = new TextBlock
        {
            Text = label,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(lightTaskbar ? System.Windows.Media.Color.FromRgb(42, 42, 46) : System.Windows.Media.Color.FromRgb(230, 228, 224)),
            Margin = new Thickness(20, 18, 20, 0),
            VerticalAlignment = VerticalAlignment.Top
        };
        host.Children.Add(caption);

        // 48px authentic Win11 centered taskbar
        var taskbar = new Border
        {
            Height = 48,
            VerticalAlignment = VerticalAlignment.Bottom,
            Background = new SolidColorBrush(lightTaskbar
                ? System.Windows.Media.Color.FromArgb(242, 243, 243, 243)
                : System.Windows.Media.Color.FromArgb(245, 28, 28, 32)),
            BorderBrush = new SolidColorBrush(lightTaskbar
                ? System.Windows.Media.Color.FromArgb(28, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(28, 255, 255, 255)),
            BorderThickness = new Thickness(0, 1, 0, 0)
        };

        var tbGrid = new Grid();

        // Bottom-left real TaskbarLyricsWindow content nested in TaskbarLocator computed slot!
        var slot = TaskbarLocator.ComputeSlot(0, 0, 1280, 48, isCentered: true, widgetsVisible: false, isLightTaskbar: lightTaskbar, null, 480, 1120);
        var overlay = new TaskbarLyricsWindow();
        overlay.ApplyTaskbarTheme(lightTaskbar);
        overlay.UpdateAppearance(settings);
        overlay.UpdateLyric("请你打开电视看看", "Please turn on the TV and take a look", 0.64, true);

        var overlayContent = (UIElement)overlay.Content;
        overlay.Content = null;
        var slotHost = new Border
        {
            Width = slot.Width,
            Height = 48,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Left,
            Margin = new Thickness(slot.Left, 0, 0, 0),
            Child = overlayContent
        };
        tbGrid.Children.Add(slotHost);

        // Centered Win11 Start + Pinned Icons
        var centerIcons = new StackPanel
        {
            Orientation = System.Windows.Controls.Orientation.Horizontal,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var startIcon = new Border
        {
            Width = 26,
            Height = 26,
            CornerRadius = new CornerRadius(5),
            Margin = new Thickness(6, 0, 6, 0),
            Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(0, 120, 212))
        };
        centerIcons.Children.Add(startIcon);
        for (var i = 0; i < 6; i++)
        {
            centerIcons.Children.Add(new Border
            {
                Width = 24,
                Height = 24,
                CornerRadius = new CornerRadius(6),
                Margin = new Thickness(6, 0, 6, 0),
                Background = new SolidColorBrush(lightTaskbar
                    ? System.Windows.Media.Color.FromArgb(38, 0, 0, 0)
                    : System.Windows.Media.Color.FromArgb(40, 255, 255, 255))
            });
        }
        tbGrid.Children.Add(centerIcons);

        // Right System Tray & Clock
        var clock = new StackPanel
        {
            HorizontalAlignment = System.Windows.HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 16, 0)
        };
        var ink = new SolidColorBrush(lightTaskbar ? System.Windows.Media.Color.FromRgb(28, 28, 32) : System.Windows.Media.Color.FromRgb(240, 240, 242));
        clock.Children.Add(new TextBlock { Text = "10:12", FontSize = 11.5, FontWeight = FontWeights.Medium, Foreground = ink, HorizontalAlignment = System.Windows.HorizontalAlignment.Right });
        clock.Children.Add(new TextBlock { Text = "2026/11/27", FontSize = 10.5, Foreground = ink, Opacity = 0.78, HorizontalAlignment = System.Windows.HorizontalAlignment.Right });
        tbGrid.Children.Add(clock);

        taskbar.Child = tbGrid;
        host.Children.Add(taskbar);
        return host;
    }

    private static void RenderDesktopOverlaysShowcase(AppSettings settings, string filePath)
    {
        var canvas = new Grid
        {
            Width = 1040,
            Height = 520,
            Background = new LinearGradientBrush(
                System.Windows.Media.Color.FromRgb(42, 49, 64),
                System.Windows.Media.Color.FromRgb(22, 24, 32),
                35)
        };

        // 1. Top Island Overlay (Soft Gray #3E3E44 @ 82%)
        var islandSettings = new AppSettings { AccentHex = settings.AccentHex, CapsulePreset = CapsuleBackgroundPreset.SoftGray, CapsuleBackgroundOpacity = 0.82, FontSize = 22 };
        var island = new FloatingLyricsWindow();
        island.ConfigureMode(LyricsDisplayMode.TopIsland, islandSettings);
        island.UpdateLyric("请你打开电视看看", "Please turn on the TV and take a look", 0.58, true);
        var islandVisual = (UIElement)island.Content;
        island.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 540,
            Height = 76,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top,
            Child = islandVisual
        });

        // 2. Free-Floating Frosted Paper (#F8F6F1 @ 88%) with hover warm amber glow border + 5-button toolbar
        var paperSettings = new AppSettings { AccentHex = "#E06D1B", CapsulePreset = CapsuleBackgroundPreset.FrostedPaper, CapsuleBackgroundOpacity = 0.88, FontSize = 22 };
        var paperFloat = new FloatingLyricsWindow();
        paperFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, paperSettings);
        paperFloat.ShowHoverToolbarForPreview(true);
        paperFloat.UpdateLyric("多少人为生命在努力勇敢的走下去", "So many keep walking bravely for life", 0.66, true);
        var paperVisual = (UIElement)paperFloat.Content;
        paperFloat.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 680,
            Height = 140,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 118, 0, 0),
            Child = paperVisual
        });

        // 3. Free-Floating Slate Blue (#1E293B @ 82%) + Transparent dual-layer shadow comparison row
        var bottomRow = new UniformGrid
        {
            Columns = 2,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(24, 0, 24, 34)
        };

        var slateSettings = new AppSettings { AccentHex = "#38BDF8", CapsulePreset = CapsuleBackgroundPreset.SlateBlue, CapsuleBackgroundOpacity = 0.82, FontSize = 19 };
        var slateFloat = new FloatingLyricsWindow();
        slateFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, slateSettings);
        slateFloat.UpdateLyric("深海雾蓝 · 晚风轻轻吹过", "Slate Blue capsule @ 82%", 0.72, true);
        var slateVisual = (UIElement)slateFloat.Content;
        slateFloat.Content = null;
        bottomRow.Children.Add(new Border { Height = 110, Child = slateVisual });

        var transSettings = new AppSettings { AccentHex = "#FF8A36", CapsulePreset = CapsuleBackgroundPreset.Transparent, FontSize = 19 };
        var transFloat = new FloatingLyricsWindow();
        transFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, transSettings);
        transFloat.UpdateLyric("极简无背景 · 双层阴影高对比", "Transparent mode with adaptive text halo", 0.64, true);
        var transVisual = (UIElement)transFloat.Content;
        transFloat.Content = null;
        bottomRow.Children.Add(new Border { Height = 110, Child = transVisual });

        canvas.Children.Add(bottomRow);

        SaveVisualPng(canvas, filePath, 1040, 520);
    }

    private static void WritePng(BitmapSource source, string filePath)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(source));
        using var fs = File.Create(filePath);
        encoder.Save(fs);
    }
}
