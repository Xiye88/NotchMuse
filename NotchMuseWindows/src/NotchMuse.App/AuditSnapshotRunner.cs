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
        var demoArtwork = RenderDemoAlbumArtworkPng();
        main.LoadAuditDemoSession(demoArtwork);
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
        main.PrepareAppearanceAuditShowcase();
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "03_light_appearance.png"), 1080, 920);

        main.NavigateTo("General");
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "04_light_general.png"), 1080, 920);

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

        // 8: Desktop Overlays Showcase rendered under LIGHT THEME (explicitly verifying hover toolbar light text contrast!)
        ThemeManager.ApplyAppTheme(AppThemeMode.Light);
        RenderDesktopOverlaysShowcase(main.CurrentSettings, Path.Combine(outputDir, "08_desktop_overlays.png"));

        // 9: Live-Preview Share Card Modal Window (with 56x56@2x Album Artwork + Album Header)
        var shareWin = new ShareCardWindow(
            "稻香 (Vinyl Studio Session)",
            "周杰伦",
            [
                "对这个世界如果你有太多的抱怨",
                "跌倒了就不敢继续往前走",
                "请你打开电视看看",
                "多少人为生命在努力勇敢的走下去",
                "我们是不是该知足",
                "珍惜一切就算没有拥有"
            ],
            isEnglish: false,
            album: "魔杰座",
            artwork: demoArtwork)
        {
            WindowStartupLocation = WindowStartupLocation.Manual,
            Left = -3000,
            Top = -3000
        };
        shareWin.Show();
        await FlushRenderAsync();
        SaveVisualPng(shareWin, Path.Combine(outputDir, "09_share_card_dialog.png"), 780, 490);
        shareWin.Close();

        // 10: Native Mac-Parity Support / Sponsor Modal Window (WeChat + QQ User Group 1137981671 + USDT EVM)
        var supportWin = new SupportWindow(isEnglish: false, client: null, skipNetwork: true)
        {
            WindowStartupLocation = WindowStartupLocation.Manual,
            Left = -3000,
            Top = -3000
        };
        supportWin.Show();
        await FlushRenderAsync();
        SaveVisualPng(supportWin, Path.Combine(outputDir, "10_support_window.png"), 780, 560);
        supportWin.Close();

        // 11: Minimum-Width (760px) Narrow Appearance Layout Check (zero clipping/misalignment!)
        main.SetThemeMode(AppThemeMode.Light);
        main.NavigateTo("Appearance");
        main.PrepareAppearanceAuditShowcase();
        main.Width = 760;
        main.Height = 680;
        await FlushRenderAsync();
        SaveVisualPng(main, Path.Combine(outputDir, "11_narrow_appearance.png"), 760, 680);

        main.Close();
    }

    private static byte[] RenderDemoAlbumArtworkPng()
    {
        const int s = 256;
        var dv = new DrawingVisual();
        using (var dc = dv.RenderOpen())
        {
            dc.DrawRectangle(
                new LinearGradientBrush(
                    System.Windows.Media.Color.FromRgb(236, 124, 52),
                    System.Windows.Media.Color.FromRgb(48, 44, 78),
                    new System.Windows.Point(0, 0),
                    new System.Windows.Point(1, 1)),
                null,
                new Rect(0, 0, s, s));
            dc.DrawEllipse(
                new RadialGradientBrush(
                    System.Windows.Media.Color.FromArgb(220, 255, 226, 168),
                    System.Windows.Media.Color.FromArgb(0, 255, 160, 80)),
                null,
                new System.Windows.Point(s * 0.68, s * 0.34),
                86, 86);
            dc.DrawGeometry(
                new SolidColorBrush(System.Windows.Media.Color.FromArgb(185, 22, 20, 34)),
                null,
                Geometry.Parse("M 0,192 Q 68,148 134,174 T 256,158 L 256,256 L 0,256 Z"));
            dc.DrawEllipse(
                null,
                new System.Windows.Media.Pen(new SolidColorBrush(System.Windows.Media.Color.FromArgb(95, 255, 255, 255)), 2.2),
                new System.Windows.Point(s * 0.5, s * 0.5),
                74, 74);
        }
        var rtb = new RenderTargetBitmap(s, s, 96, 96, PixelFormats.Pbgra32);
        rtb.Render(dv);
        var enc = new PngBitmapEncoder();
        enc.Frames.Add(BitmapFrame.Create(rtb));
        using var ms = new MemoryStream();
        enc.Save(ms);
        return ms.ToArray();
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
        var tbSettings = new AppSettings
        {
            AccentHex = settings.AccentHex,
            GradientEndHex = settings.GradientEndHex,
            ColorMode = settings.ColorMode,
            FontSize = settings.FontSize,
            FloatingDoubleLine = true,
            BilingualEnabled = !lightTaskbar
        };
        overlay.UpdateAppearance(tbSettings);
        overlay.UpdateLyric(
            "请你打开电视看看",
            lightTaskbar ? null : "Please turn on the TV and take a look",
            0.64,
            showBilingual: !lightTaskbar,
            nextLine: "多少人为生命在努力勇敢的走下去");

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
            Width = 1080,
            Height = 560,
            Background = new LinearGradientBrush(
                System.Windows.Media.Color.FromRgb(186, 198, 214),
                System.Windows.Media.Color.FromRgb(44, 52, 68),
                50)
        };

        // 1. Top Island Overlay (Soft Gray #3E3E44 @ 82%, Double-Line active!)
        var islandSettings = new AppSettings
        {
            AccentHex = settings.AccentHex,
            CapsulePreset = CapsuleBackgroundPreset.SoftGray,
            CapsuleBackgroundOpacity = 0.82,
            FloatingDoubleLine = true,
            FontSize = 21
        };
        var island = new FloatingLyricsWindow();
        island.ConfigureMode(LyricsDisplayMode.TopIsland, islandSettings);
        island.UpdateLyric("请你打开电视看看", null, 0.58, false, nextLine: "多少人为生命在努力勇敢的走下去");
        var islandVisual = (UIElement)island.Content;
        island.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 540,
            Height = 84,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top,
            Child = islandVisual
        });

        // 2. Transparent Double-Line Hover: Soft Airy Mist + Tight Lyric Width + Borderless Dark-Ink Micro-Tooltip + 7 Solid + 3 Gradient Dots!
        var transHoverSettings = new AppSettings
        {
            ColorMode = LyricColorMode.Gradient,
            AccentHex = "#FF8A36",
            GradientEndHex = "#FF4D8D",
            BackgroundCapsuleEnabled = false,
            CapsulePreset = CapsuleBackgroundPreset.Transparent,
            FloatingDoubleLine = true,
            FontSize = 22
        };
        var transHoverFloat = new FloatingLyricsWindow();
        transHoverFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, transHoverSettings);
        transHoverFloat.ShowHoverToolbarForPreview(show: true, openQuickColors: true, forceBelow: false, previewMicroTooltip: "7 纯色 + 3 渐变快捷配色");
        transHoverFloat.UpdateLyric("多少人为生命在努力勇敢的走下去", null, 0.66, false, nextLine: "我们是不是该知足 珍惜一切就算没有拥有");
        var transHoverVisual = (UIElement)transHoverFloat.Content;
        transHoverFloat.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 700,
            Height = 220,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(40, 102, 0, 0),
            Child = transHoverVisual
        });

        // 3. Right Side: Tight 2-Column Vertical Double-Line Lyrics (12px gap, ZERO horizontal bottom text!)
        var vertSettings = new AppSettings
        {
            ColorMode = LyricColorMode.Gradient,
            AccentHex = "#38BDF8",
            GradientEndHex = "#A855F7",
            CapsulePreset = CapsuleBackgroundPreset.SlateBlue,
            CapsuleBackgroundOpacity = 0.84,
            FloatingVerticalLayout = true,
            FloatingDoubleLine = true,
            FontSize = 20
        };
        var vertFloat = new FloatingLyricsWindow();
        vertFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, vertSettings);
        vertFloat.UpdateLyric("请你打开电视看看", null, 0.62, false, nextLine: "多少人为生命努力走下去");
        var vertVisual = (UIElement)vertFloat.Content;
        vertFloat.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 220,
            Height = 400,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 40, 56, 0),
            Child = vertVisual
        });

        // 4. Bottom Left: Frosted Paper Double-Line with Soft 0.75px Amber Hover Rim
        var paperSettings = new AppSettings { AccentHex = "#E06D1B", CapsulePreset = CapsuleBackgroundPreset.FrostedPaper, CapsuleBackgroundOpacity = 0.88, FloatingDoubleLine = true, FontSize = 19 };
        var paperFloat = new FloatingLyricsWindow();
        paperFloat.ConfigureMode(LyricsDisplayMode.FreeFloat, paperSettings);
        paperFloat.ShowHoverToolbarForPreview(show: true, openQuickColors: false, forceBelow: true);
        paperFloat.UpdateLyric("磨砂奶白 · 柔和百搭浅色桌面", null, 0.70, false, nextLine: "贴近屏幕顶部时工具栏自动下翻");
        var paperVisual = (UIElement)paperFloat.Content;
        paperFloat.Content = null;
        canvas.Children.Add(new Border
        {
            Width = 620,
            Height = 160,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(70, 0, 0, 26),
            Child = paperVisual
        });

        SaveVisualPng(canvas, filePath, 1080, 560);
    }

    private static void WritePng(BitmapSource source, string filePath)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(source));
        using var fs = File.Create(filePath);
        encoder.Save(fs);
    }
}
