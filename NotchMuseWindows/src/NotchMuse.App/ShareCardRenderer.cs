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
    public static byte[] RenderPng(string title, string artist, IReadOnlyList<string> lines, ShareCardTheme theme)
    {
        const int width = 1200;
        const int height = 800;
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            var (background, foreground, muted, accent) = Colors(theme);
            drawing.DrawRectangle(background, null, new Rect(0, 0, width, height));

            // Precision vinyl disc motif in top-right corner
            var discCenter = new System.Windows.Point(width - 135, 135);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromArgb(42, 0, 0, 0)), null, discCenter, 136, 136);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), new System.Windows.Media.Pen(accent, 1.8), discCenter, 126, 126);
            var groovePen = new System.Windows.Media.Pen(new SolidColorBrush(System.Windows.Media.Color.FromArgb(42, 255, 255, 255)), 1.2);
            foreach (var r in new[] { 104.0, 86.0, 68.0 })
                drawing.DrawEllipse(null, groovePen, discCenter, r, r);
            drawing.DrawEllipse(accent, null, discCenter, 44, 44);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), null, discCenter, 12, 12);

            // Subtle accent bar on left of track title
            drawing.DrawRoundedRectangle(accent, null, new Rect(72, 74, 6, 86), 3, 3);

            drawing.DrawText(Text(title, 40, foreground, FontWeights.Bold, width - 360), new System.Windows.Point(94, 72));
            drawing.DrawText(Text(artist, 22, muted, FontWeights.Medium, width - 360), new System.Windows.Point(94, 130));

            var y = 238.0;
            foreach (var line in lines.Take(6))
            {
                drawing.DrawText(Text(line, 33, foreground, FontWeights.SemiBold, width - 160), new System.Windows.Point(74, y));
                y += 72;
            }
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

    private static FormattedText Text(string value, double size, MediaBrush brush, FontWeight weight, double maxWidth = 1040)
    {
        var ft = new FormattedText(value, System.Globalization.CultureInfo.CurrentUICulture, System.Windows.FlowDirection.LeftToRight,
            new Typeface(new System.Windows.Media.FontFamily("Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI"), FontStyles.Normal, weight, FontStretches.Normal), size, brush, 1.0)
        {
            MaxTextWidth = maxWidth,
            MaxLineCount = 1,
            Trimming = TextTrimming.CharacterEllipsis
        };
        return ft;
    }

    private static (MediaBrush Background, MediaBrush Foreground, MediaBrush Muted, MediaBrush Accent) Colors(ShareCardTheme theme) => theme switch
    {
        ShareCardTheme.WarmAlabaster => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(240, 233, 218)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(49, 42, 35)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(119, 104, 88)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(220, 164, 98))),
        ShareCardTheme.SodaMist => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(207, 229, 225)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(27, 58, 59)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(80, 117, 116)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(91, 168, 159))),
        _ => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(248, 245, 237)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(174, 169, 158)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(247, 180, 93)))
    };
}
