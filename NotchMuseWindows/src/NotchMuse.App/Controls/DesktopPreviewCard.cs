using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace NotchMuse.App.Controls;

/// <summary>
/// High-fidelity vector-drawn miniature Windows 11 desktop preview card.
/// Serves as the primary visual mode switcher on the Display page (zero duplicate ComboBox!).
/// </summary>
public sealed class DesktopPreviewCard : Border
{
    private readonly Border screenFrame = new();
    private readonly Canvas scene = new() { Width = 216, Height = 112, ClipToBounds = true };
    private readonly TextBlock titleLabel = new() { FontSize = 13, FontWeight = FontWeights.SemiBold };
    private readonly TextBlock captionLabel = new() { FontSize = 11, TextTrimming = TextTrimming.CharacterEllipsis };
    private readonly Border activeBadge = new() { CornerRadius = new CornerRadius(5), Padding = new Thickness(6, 1.5, 6, 1.5) };
    private readonly TextBlock activeBadgeText = new() { FontSize = 9.5, FontWeight = FontWeights.SemiBold };

    private bool isSelected;
    private bool isDark;
    private bool isEnglish;
    private string sampleLyric = "♪ 晚风轻轻吹过黑胶纹路";

    public LyricsDisplayMode Mode { get; }
    public event Action<LyricsDisplayMode>? ModeSelected;

    public DesktopPreviewCard(LyricsDisplayMode mode)
    {
        Mode = mode;
        CornerRadius = new CornerRadius(12);
        BorderThickness = new Thickness(1);
        Padding = new Thickness(10);
        Cursor = System.Windows.Input.Cursors.Hand;

        var layout = new StackPanel();

        screenFrame.CornerRadius = new CornerRadius(8);
        screenFrame.BorderThickness = new Thickness(0.8);
        screenFrame.ClipToBounds = true;
        screenFrame.Child = new Viewbox { Stretch = Stretch.Uniform, Child = scene };
        layout.Children.Add(screenFrame);

        var footer = new Grid { Margin = new Thickness(2, 9, 2, 0) };
        footer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        footer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        titleLabel.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");
        Grid.SetRow(titleLabel, 0);
        footer.Children.Add(titleLabel);

        activeBadge.HorizontalAlignment = System.Windows.HorizontalAlignment.Right;
        activeBadge.VerticalAlignment = VerticalAlignment.Center;
        activeBadge.SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
        activeBadgeText.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
        activeBadge.Child = activeBadgeText;
        Grid.SetRow(activeBadge, 0);
        footer.Children.Add(activeBadge);

        captionLabel.Margin = new Thickness(0, 3, 0, 0);
        captionLabel.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
        Grid.SetRow(captionLabel, 1);
        footer.Children.Add(captionLabel);

        layout.Children.Add(footer);
        Child = layout;

        MouseEnter += (_, _) => ApplyChrome();
        MouseLeave += (_, _) => ApplyChrome();
        MouseLeftButtonUp += (_, e) =>
        {
            e.Handled = true;
            ModeSelected?.Invoke(Mode);
        };

        Refresh(false, false, false, null);
    }

    public void Refresh(bool selected, bool dark, bool english, string? lyricPreview)
    {
        isSelected = selected;
        isDark = dark;
        isEnglish = english;
        if (!string.IsNullOrWhiteSpace(lyricPreview))
            sampleLyric = "♪ " + lyricPreview.Trim();
        else
            sampleLyric = english ? "♪ Softly glowing across the screen" : "♪ 晚风轻轻吹过黑胶纹路";

        (titleLabel.Text, captionLabel.Text) = (Mode, english) switch
        {
            (LyricsDisplayMode.Taskbar, false) => ("任务栏左下角", "精准嵌入 Win11 居中任务栏左侧空白区"),
            (LyricsDisplayMode.TopIsland, false) => ("顶部悬浮岛", "贴合屏幕顶部中央的毛玻璃灵动胶囊"),
            (LyricsDisplayMode.FreeFloat, false) => ("桌面自由悬浮", "随心拖动 + 居中磁吸参考线 + 一键穿透"),
            (LyricsDisplayMode.Taskbar, true) => ("Taskbar Bottom-Left", "Nested cleanly in Win11 centered taskbar gap"),
            (LyricsDisplayMode.TopIsland, true) => ("Top Floating Island", "Frosted capsule anchored to top screen edge"),
            _ => ("Desktop Free Float", "Draggable pill with magnetic center snap")
        };

        activeBadgeText.Text = english ? "Active" : "当前";
        activeBadge.Visibility = selected ? Visibility.Visible : Visibility.Collapsed;

        ApplyChrome();
        DrawMiniatureDesktop();
    }

    private void ApplyChrome()
    {
        if (isSelected)
        {
            SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
            SetResourceReference(Border.BorderBrushProperty, "AccentBrush");
            BorderThickness = new Thickness(1.5);
        }
        else if (IsMouseOver)
        {
            SetResourceReference(Border.BackgroundProperty, "CardHoverBrush");
            SetResourceReference(Border.BorderBrushProperty, "AccentBorderBrush");
            BorderThickness = new Thickness(1);
        }
        else
        {
            SetResourceReference(Border.BackgroundProperty, "CardBrush");
            SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");
            BorderThickness = new Thickness(1);
        }

        screenFrame.BorderBrush = new SolidColorBrush(isDark
            ? System.Windows.Media.Color.FromArgb(30, 255, 255, 255)
            : System.Windows.Media.Color.FromArgb(24, 0, 0, 0));
    }

    private void DrawMiniatureDesktop()
    {
        scene.Children.Clear();

        // 1. Soft Win11-style architectural wallpaper gradient
        var bg = new System.Windows.Shapes.Rectangle
        {
            Width = 216,
            Height = 112,
            Fill = new LinearGradientBrush(
                isDark ? System.Windows.Media.Color.FromRgb(28, 30, 38) : System.Windows.Media.Color.FromRgb(235, 232, 224),
                isDark ? System.Windows.Media.Color.FromRgb(18, 19, 24) : System.Windows.Media.Color.FromRgb(219, 216, 208),
                45)
        };
        scene.Children.Add(bg);

        // Ambient warm bloom
        var bloom = new Ellipse
        {
            Width = 140,
            Height = 90,
            Fill = new RadialGradientBrush(
                System.Windows.Media.Color.FromArgb(isDark ? (byte)42 : (byte)36, 224, 109, 27),
                System.Windows.Media.Color.FromArgb(0, 224, 109, 27))
        };
        Canvas.SetLeft(bloom, 38);
        Canvas.SetTop(bloom, 12);
        scene.Children.Add(bloom);

        // Subtle miniature workspace app window in background
        var miniApp = new Border
        {
            Width = 132,
            Height = 62,
            CornerRadius = new CornerRadius(5),
            Background = new SolidColorBrush(isDark
                ? System.Windows.Media.Color.FromArgb(190, 32, 33, 40)
                : System.Windows.Media.Color.FromArgb(215, 252, 251, 248)),
            BorderBrush = new SolidColorBrush(isDark
                ? System.Windows.Media.Color.FromArgb(28, 255, 255, 255)
                : System.Windows.Media.Color.FromArgb(24, 0, 0, 0)),
            BorderThickness = new Thickness(0.7)
        };
        var appLines = new StackPanel { Margin = new Thickness(9, 10, 9, 6) };
        appLines.Children.Add(new Border { Height = 4, Width = 54, HorizontalAlignment = System.Windows.HorizontalAlignment.Left, CornerRadius = new CornerRadius(2), Background = new SolidColorBrush(isDark ? System.Windows.Media.Color.FromArgb(46, 255, 255, 255) : System.Windows.Media.Color.FromArgb(30, 0, 0, 0)) });
        appLines.Children.Add(new Border { Height = 3, Width = 92, Margin = new Thickness(0, 6, 0, 0), HorizontalAlignment = System.Windows.HorizontalAlignment.Left, CornerRadius = new CornerRadius(1.5), Background = new SolidColorBrush(isDark ? System.Windows.Media.Color.FromArgb(26, 255, 255, 255) : System.Windows.Media.Color.FromArgb(18, 0, 0, 0)) });
        appLines.Children.Add(new Border { Height = 3, Width = 76, Margin = new Thickness(0, 5, 0, 0), HorizontalAlignment = System.Windows.HorizontalAlignment.Left, CornerRadius = new CornerRadius(1.5), Background = new SolidColorBrush(isDark ? System.Windows.Media.Color.FromArgb(22, 255, 255, 255) : System.Windows.Media.Color.FromArgb(16, 0, 0, 0)) });
        miniApp.Child = appLines;
        Canvas.SetLeft(miniApp, 42);
        Canvas.SetTop(miniApp, 22);
        scene.Children.Add(miniApp);

        // 2. Authentic Windows 11 Centered Taskbar Strip at bottom (height 18)
        var taskbar = new Border
        {
            Width = 216,
            Height = 18,
            Background = new SolidColorBrush(isDark
                ? System.Windows.Media.Color.FromArgb(232, 24, 24, 29)
                : System.Windows.Media.Color.FromArgb(235, 246, 245, 241)),
            BorderBrush = new SolidColorBrush(isDark
                ? System.Windows.Media.Color.FromArgb(26, 255, 255, 255)
                : System.Windows.Media.Color.FromArgb(24, 0, 0, 0)),
            BorderThickness = new Thickness(0, 0.7, 0, 0)
        };
        Canvas.SetLeft(taskbar, 0);
        Canvas.SetTop(taskbar, 94);
        scene.Children.Add(taskbar);

        // Centered Win11 Start + pinned icons
        var centerIcons = new StackPanel { Orientation = System.Windows.Controls.Orientation.Horizontal };
        var iconColors = new[]
        {
            System.Windows.Media.Color.FromRgb(56, 152, 245), // Start blue
            isDark ? System.Windows.Media.Color.FromRgb(120, 122, 134) : System.Windows.Media.Color.FromRgb(145, 143, 136),
            isDark ? System.Windows.Media.Color.FromRgb(120, 122, 134) : System.Windows.Media.Color.FromRgb(145, 143, 136),
            isDark ? System.Windows.Media.Color.FromRgb(120, 122, 134) : System.Windows.Media.Color.FromRgb(145, 143, 136),
            isDark ? System.Windows.Media.Color.FromRgb(120, 122, 134) : System.Windows.Media.Color.FromRgb(145, 143, 136)
        };
        foreach (var col in iconColors)
        {
            centerIcons.Children.Add(new Border
            {
                Width = 6,
                Height = 6,
                CornerRadius = new CornerRadius(1.5),
                Margin = new Thickness(1.8, 0, 1.8, 0),
                Background = new SolidColorBrush(col)
            });
        }
        Canvas.SetLeft(centerIcons, 84);
        Canvas.SetTop(centerIcons, 100);
        scene.Children.Add(centerIcons);

        // Right system tray stub
        var trayStub = new Border
        {
            Width = 22,
            Height = 4,
            CornerRadius = new CornerRadius(2),
            Background = new SolidColorBrush(isDark ? System.Windows.Media.Color.FromArgb(65, 255, 255, 255) : System.Windows.Media.Color.FromArgb(55, 0, 0, 0))
        };
        Canvas.SetLeft(trayStub, 186);
        Canvas.SetTop(trayStub, 101);
        scene.Children.Add(trayStub);

        // 3. Mode-Specific Luminous Lyrics Overlay
        var accent = isDark ? System.Windows.Media.Color.FromRgb(255, 138, 54) : System.Windows.Media.Color.FromRgb(224, 109, 27);

        if (Mode == LyricsDisplayMode.Taskbar)
        {
            // Glowing warm amber lyrics nested cleanly in Win11 bottom-left blank zone!
            var pill = new Border
            {
                Width = 74,
                Height = 12,
                CornerRadius = new CornerRadius(4),
                Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(isDark ? (byte)55 : (byte)42, accent.R, accent.G, accent.B)),
                BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(170, accent.R, accent.G, accent.B)),
                BorderThickness = new Thickness(0.7),
                Padding = new Thickness(4, 0, 4, 0)
            };
            pill.Child = new TextBlock
            {
                Text = sampleLyric,
                FontSize = 6.2,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(accent),
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            Canvas.SetLeft(pill, 5);
            Canvas.SetTop(pill, 97);
            scene.Children.Add(pill);
        }
        else if (Mode == LyricsDisplayMode.TopIsland)
        {
            var island = new Border
            {
                Width = 114,
                Height = 16,
                CornerRadius = new CornerRadius(0, 0, 8, 8),
                Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(242, 20, 20, 24)),
                BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(145, accent.R, accent.G, accent.B)),
                BorderThickness = new Thickness(0.8, 0, 0.8, 0.8),
                Padding = new Thickness(7, 0, 7, 0)
            };
            island.Child = new TextBlock
            {
                Text = sampleLyric,
                FontSize = 6.8,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 152, 74)),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            Canvas.SetLeft(island, 51);
            Canvas.SetTop(island, 0);
            scene.Children.Add(island);
        }
        else
        {
            // Delicate vertical magnetic center snap guide
            var guide = new Line
            {
                X1 = 108,
                Y1 = 8,
                X2 = 108,
                Y2 = 90,
                Stroke = new SolidColorBrush(System.Windows.Media.Color.FromArgb(135, accent.R, accent.G, accent.B)),
                StrokeThickness = 0.8,
                StrokeDashArray = new DoubleCollection { 2.5, 2.5 }
            };
            scene.Children.Add(guide);

            var floatPill = new Border
            {
                Width = 122,
                Height = 20,
                CornerRadius = new CornerRadius(10),
                Background = new SolidColorBrush(isDark
                    ? System.Windows.Media.Color.FromArgb(236, 26, 26, 32)
                    : System.Windows.Media.Color.FromArgb(240, 255, 254, 250)),
                BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(155, accent.R, accent.G, accent.B)),
                BorderThickness = new Thickness(0.9),
                Padding = new Thickness(8, 0, 8, 0)
            };
            floatPill.Child = new TextBlock
            {
                Text = sampleLyric,
                FontSize = 7.2,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(accent),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            Canvas.SetLeft(floatPill, 47);
            Canvas.SetTop(floatPill, 43);
            scene.Children.Add(floatPill);
        }
    }
}
