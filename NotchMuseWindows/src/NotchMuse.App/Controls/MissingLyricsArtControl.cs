using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace NotchMuse.App.Controls;

/// <summary>
/// Six playful, gentle vector micro-animations matching Mac Preview Build 97
/// when a song has no synced lyrics or when waiting for playback.
/// </summary>
public sealed class MissingLyricsArtControl : StackPanel
{
    private readonly Canvas stage = new() { Width = 148, Height = 96, HorizontalAlignment = System.Windows.HorizontalAlignment.Center };
    private readonly TextBlock caption = new()
    {
        FontSize = 13.5,
        FontWeight = FontWeights.Medium,
        TextAlignment = TextAlignment.Center,
        TextWrapping = TextWrapping.Wrap,
        MaxWidth = 340,
        Margin = new Thickness(0, 12, 0, 0)
    };
    private readonly System.Windows.Controls.Button retryButton = new()
    {
        Padding = new Thickness(16, 7, 16, 7),
        Margin = new Thickness(0, 14, 0, 0),
        HorizontalAlignment = System.Windows.HorizontalAlignment.Center
    };

    private MissingLyricsAnimationStyle style = MissingLyricsAnimationStyle.VinylSeek;
    private bool idleMode = true;
    private bool english;

    public event Action? RetryClicked;

    public MissingLyricsArtControl()
    {
        HorizontalAlignment = System.Windows.HorizontalAlignment.Center;
        VerticalAlignment = VerticalAlignment.Center;

        caption.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
        retryButton.Click += (_, _) => RetryClicked?.Invoke();

        Children.Add(stage);
        Children.Add(caption);
        Children.Add(retryButton);

        Rebuild();
    }

    public void Configure(MissingLyricsAnimationStyle nextStyle, bool isIdle, bool isEnglish)
    {
        var styleChanged = style != nextStyle;
        style = nextStyle;
        idleMode = isIdle;
        english = isEnglish;

        caption.Text = isIdle
            ? (isEnglish ? "Waiting for music…" : "等待播放音乐…")
            : GetCaption(style, isEnglish);
        retryButton.Content = isEnglish ? "Retry Match" : "重试匹配";
        retryButton.Visibility = isIdle ? Visibility.Collapsed : Visibility.Visible;

        if (styleChanged || stage.Children.Count == 0)
        {
            Rebuild();
        }
    }

    public static string GetDisplayName(MissingLyricsAnimationStyle s, bool isEnglish) => (s, isEnglish) switch
    {
        (MissingLyricsAnimationStyle.VinylSeek, false) => "黑胶寻轨（默认）",
        (MissingLyricsAnimationStyle.CassetteB, false) => "复古磁带",
        (MissingLyricsAnimationStyle.RunawayNotes, false) => "小音符逃跑",
        (MissingLyricsAnimationStyle.RadarPulse, false) => "声波雷达",
        (MissingLyricsAnimationStyle.FloatingCloud, false) => "云端漂浮",
        (MissingLyricsAnimationStyle.EqualizerBounce, false) => "律动音柱",
        (MissingLyricsAnimationStyle.VinylSeek, true) => "Vinyl Seek (Default)",
        (MissingLyricsAnimationStyle.CassetteB, true) => "Cassette Side B",
        (MissingLyricsAnimationStyle.RunawayNotes, true) => "Runaway Notes",
        (MissingLyricsAnimationStyle.RadarPulse, true) => "Sound Radar",
        (MissingLyricsAnimationStyle.FloatingCloud, true) => "Drifting Cloud",
        _ => "Rhythm Bars"
    };

    public static string GetCaption(MissingLyricsAnimationStyle s, bool isEnglish) => (s, isEnglish) switch
    {
        (MissingLyricsAnimationStyle.VinylSeek, false) => "唱针没找到这首歌的词，正在黑胶纹路里打捞…",
        (MissingLyricsAnimationStyle.CassetteB, false) => "歌词走失在磁带 B 面，正在帮你倒带找回…",
        (MissingLyricsAnimationStyle.RunawayNotes, false) => "歌词溜走了，这首大概是纯音乐？",
        (MissingLyricsAnimationStyle.RadarPulse, false) => "正在声波雷达里搜寻这首歌的词…",
        (MissingLyricsAnimationStyle.FloatingCloud, false) => "歌词飘在云端，先听听旋律吧~",
        (MissingLyricsAnimationStyle.EqualizerBounce, false) => "纯享旋律时刻，歌词休假去了~",
        (MissingLyricsAnimationStyle.VinylSeek, true) => "Tonearm couldn't find lyrics in the grooves…",
        (MissingLyricsAnimationStyle.CassetteB, true) => "Lyrics wandered off to Cassette Side B…",
        (MissingLyricsAnimationStyle.RunawayNotes, true) => "Lyrics ran away — maybe an instrumental?",
        (MissingLyricsAnimationStyle.RadarPulse, true) => "Scanning the sound radar for lyrics…",
        (MissingLyricsAnimationStyle.FloatingCloud, true) => "Lyrics are drifting in the clouds — enjoy the melody~",
        _ => "Pure melody time — lyrics are on vacation~"
    };

    private void Rebuild()
    {
        stage.Children.Clear();

        switch (style)
        {
            case MissingLyricsAnimationStyle.VinylSeek:
                BuildVinylSeek();
                break;
            case MissingLyricsAnimationStyle.CassetteB:
                BuildCassette();
                break;
            case MissingLyricsAnimationStyle.RunawayNotes:
                BuildRunawayNotes();
                break;
            case MissingLyricsAnimationStyle.RadarPulse:
                BuildRadarPulse();
                break;
            case MissingLyricsAnimationStyle.FloatingCloud:
                BuildFloatingCloud();
                break;
            case MissingLyricsAnimationStyle.EqualizerBounce:
                BuildEqualizerBounce();
                break;
        }
    }

    private void BuildVinylSeek()
    {
        var disc = new Canvas { Width = 66, Height = 66, RenderTransformOrigin = new System.Windows.Point(0.5, 0.5) };
        var rot = new RotateTransform();
        disc.RenderTransform = rot;
        Canvas.SetLeft(disc, 36);
        Canvas.SetTop(disc, 16);

        disc.Children.Add(new Ellipse { Width = 66, Height = 66, Fill = new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), Stroke = new SolidColorBrush(System.Windows.Media.Color.FromArgb(45, 255, 255, 255)), StrokeThickness = 1 });
        foreach (var inset in new[] { 7.0, 14.0, 20.0 })
        {
            var g = new Ellipse { Width = 66 - inset * 2, Height = 66 - inset * 2, Stroke = new SolidColorBrush(System.Windows.Media.Color.FromArgb(30, 255, 255, 255)), StrokeThickness = 0.7 };
            Canvas.SetLeft(g, inset);
            Canvas.SetTop(g, inset);
            disc.Children.Add(g);
        }
        var center = new Ellipse { Width = 20, Height = 20 };
        center.SetResourceReference(Shape.FillProperty, "AccentBrush");
        Canvas.SetLeft(center, 23);
        Canvas.SetTop(center, 23);
        disc.Children.Add(center);
        var hole = new Ellipse { Width = 6, Height = 6, Fill = new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)) };
        Canvas.SetLeft(hole, 30);
        Canvas.SetTop(hole, 30);
        disc.Children.Add(hole);
        stage.Children.Add(disc);

        var arm = new Path
        {
            Data = Geometry.Parse("M 106,18 L 96,46 L 84,54"),
            StrokeThickness = 2.2,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            StrokeLineJoin = PenLineJoin.Round
        };
        arm.SetResourceReference(Shape.StrokeProperty, "TextSecondaryBrush");
        stage.Children.Add(arm);

        var note = new TextBlock { Text = "♪", FontSize = 16, FontWeight = FontWeights.SemiBold };
        note.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
        Canvas.SetLeft(note, 114);
        Canvas.SetTop(note, 14);
        stage.Children.Add(note);

        rot.BeginAnimation(RotateTransform.AngleProperty, new DoubleAnimation(0, 360, TimeSpan.FromSeconds(10)) { RepeatBehavior = RepeatBehavior.Forever });
    }

    private void BuildCassette()
    {
        var body = new Border { Width = 96, Height = 58, CornerRadius = new CornerRadius(9), BorderThickness = new Thickness(1.4) };
        body.SetResourceReference(Border.BackgroundProperty, "CardBrush");
        body.SetResourceReference(Border.BorderBrushProperty, "TextSecondaryBrush");
        Canvas.SetLeft(body, 26);
        Canvas.SetTop(body, 20);
        stage.Children.Add(body);

        var window = new Border { Width = 72, Height = 22, CornerRadius = new CornerRadius(4) };
        window.SetResourceReference(Border.BackgroundProperty, "ControlBrush");
        Canvas.SetLeft(window, 38);
        Canvas.SetTop(window, 36);
        stage.Children.Add(window);

        foreach (var x in new[] { 48.0, 86.0 })
        {
            var reel = new Ellipse { Width = 14, Height = 14, StrokeThickness = 1.8 };
            reel.SetResourceReference(Shape.StrokeProperty, "AccentBrush");
            Canvas.SetLeft(reel, x);
            Canvas.SetTop(reel, 40);
            stage.Children.Add(reel);
        }
    }

    private void BuildRunawayNotes()
    {
        var offsets = new[] { (30.0, 44.0, "♪", 22.0), (66.0, 28.0, "♫", 26.0), (104.0, 40.0, "♪", 19.0) };
        for (var i = 0; i < offsets.Length; i++)
        {
            var (x, y, glyph, size) = offsets[i];
            var tb = new TextBlock { Text = glyph, FontSize = size, FontWeight = FontWeights.SemiBold };
            tb.SetResourceReference(TextBlock.ForegroundProperty, i == 1 ? "AccentBrush" : "TextSecondaryBrush");
            var tt = new TranslateTransform();
            tb.RenderTransform = tt;
            Canvas.SetLeft(tb, x);
            Canvas.SetTop(tb, y);
            stage.Children.Add(tb);
            tt.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(0, -10, TimeSpan.FromMilliseconds(950 + i * 240))
            {
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever
            });
        }
    }

    private void BuildRadarPulse()
    {
        foreach (var size in new[] { 72.0, 48.0, 24.0 })
        {
            var ring = new Ellipse { Width = size, Height = size, StrokeThickness = 1.3, Opacity = size == 24 ? 0.9 : 0.38 };
            ring.SetResourceReference(Shape.StrokeProperty, "AccentBrush");
            Canvas.SetLeft(ring, 74 - size / 2);
            Canvas.SetTop(ring, 48 - size / 2);
            stage.Children.Add(ring);
        }
        var dot = new Ellipse { Width = 8, Height = 8 };
        dot.SetResourceReference(Shape.FillProperty, "AccentBrush");
        Canvas.SetLeft(dot, 70);
        Canvas.SetTop(dot, 44);
        stage.Children.Add(dot);
    }

    private void BuildFloatingCloud()
    {
        var cloud = new Path
        {
            Data = Geometry.Parse("M 42,60 H 104 A 14,14 0 0 0 100,34 A 20,20 0 0 0 62,28 A 15,15 0 0 0 42,60 Z"),
            StrokeThickness = 1.4
        };
        cloud.SetResourceReference(Shape.FillProperty, "CardBrush");
        cloud.SetResourceReference(Shape.StrokeProperty, "TextSecondaryBrush");
        stage.Children.Add(cloud);

        var note = new TextBlock { Text = "♪", FontSize = 18, FontWeight = FontWeights.SemiBold };
        note.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
        Canvas.SetLeft(note, 94);
        Canvas.SetTop(note, 18);
        stage.Children.Add(note);
    }

    private void BuildEqualizerBounce()
    {
        var heights = new[] { 22.0, 42.0, 56.0, 36.0, 26.0 };
        for (var i = 0; i < heights.Length; i++)
        {
            var bar = new Border { Width = 9, Height = heights[i], CornerRadius = new CornerRadius(4.5) };
            bar.SetResourceReference(Border.BackgroundProperty, i is 1 or 2 or 3 ? "AccentBrush" : "TextSecondaryBrush");
            Canvas.SetLeft(bar, 42 + i * 14);
            Canvas.SetTop(bar, 76 - heights[i]);
            stage.Children.Add(bar);
        }
    }
}
