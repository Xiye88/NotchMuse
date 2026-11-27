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
    private static readonly Lazy<BitmapSource?> CachedAppLogo = new(TryLoadAppLogo);

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
            var (background, foreground, muted, accent, hairline) = Colors(theme);
            drawing.DrawRectangle(background, null, new Rect(0, 0, width, height));

            // Subtle ambient editorial accent glow in top-left behind album cover (NO giant disc!)
            var accentColor = accent is SolidColorBrush scb ? scb.Color : System.Windows.Media.Color.FromRgb(255, 138, 54);
            var softGlow = new RadialGradientBrush(
                System.Windows.Media.Color.FromArgb(26, accentColor.R, accentColor.G, accentColor.B),
                System.Windows.Media.Color.FromArgb(0, accentColor.R, accentColor.G, accentColor.B));
            drawing.DrawEllipse(softGlow, null, new System.Windows.Point(130, 120), 240, 180);

            // Header Left: 112x112 (@2x equivalent of 56x56) rounded album cover or clean minimal note tile
            var coverRect = new Rect(76, 68, 112, 112);
            var coverClip = new RectangleGeometry(coverRect, 20, 20);
            var artwork = TryDecodeArtwork(artworkBytes);
            if (artwork is not null)
            {
                drawing.PushClip(coverClip);
                drawing.DrawImage(artwork, coverRect);
                drawing.Pop();
                drawing.DrawRoundedRectangle(null, new System.Windows.Media.Pen(hairline, 1.4), coverRect, 20, 20);
            }
            else
            {
                var tileBg = new LinearGradientBrush(
                    System.Windows.Media.Color.FromArgb(46, accentColor.R, accentColor.G, accentColor.B),
                    System.Windows.Media.Color.FromArgb(18, accentColor.R, accentColor.G, accentColor.B),
                    45);
                drawing.DrawRoundedRectangle(tileBg, new System.Windows.Media.Pen(accent, 1.4), coverRect, 20, 20);
                var noteText = Text("♪", 46, accent, FontWeights.Bold, 80);
                drawing.DrawText(noteText, new System.Windows.Point(coverRect.X + (coverRect.Width - noteText.Width) / 2, coverRect.Y + 24));
            }

            // Header Right: Full-width Bold Track Title + "Artist · 《Album》" (zero obstruction on right!)
            var cleanArtist = string.IsNullOrWhiteSpace(artist) ? "NotchMuse" : artist.Trim();
            var subtitle = string.IsNullOrWhiteSpace(album)
                ? cleanArtist
                : $"{cleanArtist} · 《{album.Trim()}》";

            drawing.DrawText(Text(title, 38, foreground, FontWeights.Bold, width - 280), new System.Windows.Point(214, 78));
            drawing.DrawText(Text(subtitle, 22, muted, FontWeights.Medium, width - 280), new System.Windows.Point(214, 134));

            // Subtle decorative quotation bar before lyrics
            drawing.DrawRoundedRectangle(accent, null, new Rect(76, 224, 36, 4), 2, 2);

            // Lyric lines body (clean editorial spacing)
            var y = 252.0;
            var displayLines = lines.Take(6).ToArray();
            var lineStep = displayLines.Length <= 4 ? 76.0 : 68.0;
            foreach (var line in displayLines)
            {
                drawing.DrawText(Text(line, 33, foreground, FontWeights.SemiBold, width - 152), new System.Windows.Point(76, y));
                y += lineStep;
            }

            // Crisp studio divider
            drawing.DrawLine(new System.Windows.Media.Pen(hairline, 1.2),
                new System.Windows.Point(76, height - 96), new System.Windows.Point(width - 76, height - 96));

            // Bottom-Left: Minimal studio caption
            drawing.DrawText(Text("LYRICS CARD", 15, muted, FontWeights.SemiBold, 300), new System.Windows.Point(76, height - 66));

            // Bottom-Right: Compact refined NotchMuse mini logo + wordmark
            var wordmark = Text("NotchMuse", 20, foreground, FontWeights.Bold, 220);
            var wordmarkX = width - 76 - wordmark.Width;
            var footerCenterY = height - 54.0;
            drawing.DrawText(wordmark, new System.Windows.Point(wordmarkX, footerCenterY - wordmark.Height / 2));

            var logoSize = 30.0;
            var logoRect = new Rect(wordmarkX - logoSize - 11, footerCenterY - logoSize / 2, logoSize, logoSize);
            var logo = CachedAppLogo.Value;
            if (logo is not null)
            {
                drawing.PushClip(new RectangleGeometry(logoRect, 7, 7));
                drawing.DrawImage(logo, logoRect);
                drawing.Pop();
                drawing.DrawRoundedRectangle(null, new System.Windows.Media.Pen(hairline, 1.0), logoRect, 7, 7);
            }
            else
            {
                drawing.DrawRoundedRectangle(accent, null, logoRect, 8, 8);
                var miniNote = Text("♪", 17, System.Windows.Media.Brushes.White, FontWeights.Bold, 30);
                drawing.DrawText(miniNote, new System.Windows.Point(logoRect.X + (logoSize - miniNote.Width) / 2, logoRect.Y + 3));
            }
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

    private static BitmapSource? TryLoadAppLogo()
    {
        try
        {
            var uri = new Uri("pack://application:,,,/NotchMuse.App;component/NotchMuse.ico", UriKind.Absolute);
            var info = System.Windows.Application.GetResourceStream(uri);
            if (info?.Stream is null) return null;
            using var s = info.Stream;
            var decoder = new IconBitmapDecoder(s, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
            var best = decoder.Frames.OrderByDescending(f => f.PixelWidth).FirstOrDefault();
            best?.Freeze();
            return best;
        }
        catch (IOException) { return null; }
        catch (InvalidOperationException) { return null; }
        catch (NotSupportedException) { return null; }
        catch (ArgumentException) { return null; }
        catch (UriFormatException) { return null; }
    }

    private static BitmapSource? TryDecodeArtwork(byte[]? bytes)
    {
        if (bytes is null || bytes.Length == 0) return null;
        try { return Decode(bytes); }
        catch (NotSupportedException) { return null; }
        catch (InvalidOperationException) { return null; }
        catch (ArgumentException) { return null; }
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

    private static (MediaBrush Background, MediaBrush Foreground, MediaBrush Muted, MediaBrush Accent, MediaBrush Hairline) Colors(ShareCardTheme theme) => theme switch
    {
        ShareCardTheme.WarmAlabaster => (
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(245, 242, 234)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(28, 28, 30)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(110, 108, 102)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(224, 109, 27)),
            new SolidColorBrush(System.Windows.Media.Color.FromArgb(44, 28, 28, 30))),
        ShareCardTheme.SodaMist => (
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(212, 232, 228)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 52, 54)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(74, 112, 112)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(32, 146, 132)),
            new SolidColorBrush(System.Windows.Media.Color.FromArgb(44, 24, 52, 54))),
        _ => (
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(22, 22, 26)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(246, 244, 238)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(158, 156, 150)),
            new SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 138, 54)),
            new SolidColorBrush(System.Windows.Media.Color.FromArgb(42, 255, 255, 255)))
    };
}
