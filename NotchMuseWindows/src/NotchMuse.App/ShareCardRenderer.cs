using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using MediaBrush = System.Windows.Media.Brush;

namespace NotchMuse.App;

public enum ShareCardTheme
{
    VinylNight,
    WarmAlabaster,
    SodaMist
}

public static class ShareCardRenderer
{
    public static byte[] RenderPng(string title, string artist, IReadOnlyList<string> lines, ShareCardTheme theme) =>
        RenderPng(title, artist, album: null, lines, theme, artworkBytes: null);

    public static byte[] RenderPng(
        string title,
        string artist,
        string? album,
        IReadOnlyList<string> lines,
        ShareCardTheme theme,
        byte[]? artworkBytes = null)
    {
        const int width = 1200;
        const int height = 800;
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            var (background, foreground, muted, accent) = Colors(theme);
            drawing.DrawRectangle(background, null, new Rect(0, 0, width, height));

            // Subtle ambient vinyl disc watermark in top-right corner
            var discCenter = new System.Windows.Point(width - 125, 130);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromArgb(30, 0, 0, 0)), null, discCenter, 128, 128);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), new System.Windows.Media.Pen(accent, 1.5), discCenter, 118, 118);
            var groovePen = new System.Windows.Media.Pen(new SolidColorBrush(System.Windows.Media.Color.FromArgb(38, 255, 255, 255)), 1.1);
            foreach (var r in new[] { 98.0, 80.0, 62.0 })
                drawing.DrawEllipse(null, groovePen, discCenter, r, r);
            drawing.DrawEllipse(accent, null, discCenter, 38, 38);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), null, discCenter, 10, 10);

            // Header Left: 112x112 (@2x equivalent of 56x56) rounded album cover or fallback mini vinyl badge
            var coverRect = new Rect(74, 64, 112, 112);
            var coverClip = new RectangleGeometry(coverRect, 18, 18);
            var artwork = TryDecodeArtwork(artworkBytes);
            if (artwork is not null)
            {
                drawing.PushClip(coverClip);
                drawing.DrawImage(artwork, coverRect);
                drawing.Pop();
                drawing.DrawRoundedRectangle(null, new System.Windows.Media.Pen(new SolidColorBrush(System.Windows.Media.Color.FromArgb(55, 255, 255, 255)), 1.5), coverRect, 18, 18);
            }
            else
            {
                drawing.DrawRoundedRectangle(new SolidColorBrush(System.Windows.Media.Color.FromRgb(28, 28, 34)),
                    new System.Windows.Media.Pen(accent, 1.5), coverRect, 18, 18);
                var miniCenter = new System.Windows.Point(coverRect.X + coverRect.Width / 2, coverRect.Y + coverRect.Height / 2);
                drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(18, 18, 22)), groovePen, miniCenter, 38, 38);
                drawing.DrawEllipse(null, groovePen, miniCenter, 28, 28);
                drawing.DrawEllipse(accent, null, miniCenter, 15, 15);
                drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(18, 18, 22)), null, miniCenter, 4.5, 4.5);
            }

            // Header Right: Bold Track Title + "Artist · 《Album》"
            var cleanArtist = string.IsNullOrWhiteSpace(artist) ? "NotchMuse" : artist.Trim();
            var subtitle = string.IsNullOrWhiteSpace(album)
                ? cleanArtist
                : $"{cleanArtist} · 《{album.Trim()}》";

            drawing.DrawText(Text(title, 38, foreground, FontWeights.Bold, width - 440), new System.Windows.Point(210, 74));
            drawing.DrawText(Text(subtitle, 22, muted, FontWeights.Medium, width - 440), new System.Windows.Point(210, 128));

            // Lyric lines body
            var y = 236.0;
            foreach (var line in lines.Take(6))
            {
                drawing.DrawText(Text(line, 33, foreground, FontWeights.SemiBold, width - 160), new System.Windows.Point(74, y));
                y += 72;
            }

            // Subtle divider & studio footer mark
            drawing.DrawLine(new System.Windows.Media.Pen(new SolidColorBrush(System.Windows.Media.Color.FromArgb(40, 140, 140, 140)), 1),
                new System.Windows.Point(74, height - 92), new System.Windows.Point(width - 74, height - 92));
            drawing.DrawText(Text("♪ NotchMuse · Vinyl Studio Hi-Fi", 19, muted, FontWeights.Medium, 600), new System.Windows.Point(74, height - 68));
        }

        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(visual);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new MemoryStream();
        encoder.Save(stream);
        return stream.ToArray();
    }

    public static BitmapSource Decode(byte[] png)
    {
        using var stream = new MemoryStream(png);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        bitmap.StreamSource = stream;
        bitmap.EndInit();
        bitmap.Freeze();
        return bitmap;
    }

    private static BitmapSource? TryDecodeArtwork(byte[]? bytes)
    {
        if (bytes is null || bytes.Length == 0) return null;
        try { return Decode(bytes); }
        catch (NotSupportedException) { return null; }
        catch (IOException) { return null; }
    }

    private static FormattedText Text(string value, double size, MediaBrush brush, FontWeight weight, double maxWidth = 1040) =>
        new(value, System.Globalization.CultureInfo.CurrentUICulture, System.Windows.FlowDirection.LeftToRight,
            new Typeface(new System.Windows.Media.FontFamily("Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI"), FontStyles.Normal, weight, FontStretches.Normal), size, brush, 1.0)
        {
            MaxTextWidth = maxWidth,
            MaxLineCount = 1,
            Trimming = TextTrimming.CharacterEllipsis
        };

    private static (MediaBrush Background, MediaBrush Foreground, MediaBrush Muted, MediaBrush Accent) Colors(ShareCardTheme theme) => theme switch
    {
        ShareCardTheme.WarmAlabaster => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(245, 242, 234)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(28, 28, 30)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(110, 108, 102)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(224, 109, 27))),
        ShareCardTheme.SodaMist => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(212, 232, 228)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 52, 54)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(74, 112, 112)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(42, 157, 143))),
        _ => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(22, 22, 26)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(246, 244, 238)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(166, 164, 158)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 138, 54)))
    };
}
