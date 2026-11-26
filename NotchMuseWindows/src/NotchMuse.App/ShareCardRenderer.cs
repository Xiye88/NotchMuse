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
            drawing.DrawEllipse(accent, null, new System.Windows.Point(width - 120, 120), 130, 130);
            drawing.DrawEllipse(new SolidColorBrush(System.Windows.Media.Color.FromArgb(80, 255, 255, 255)), null, new System.Windows.Point(width - 120, 120), 88, 88);
            drawing.DrawText(Text(title, 42, foreground, FontWeights.SemiBold), new System.Windows.Point(72, 72));
            drawing.DrawText(Text(artist, 22, muted, FontWeights.Normal), new System.Windows.Point(74, 132));
            var y = 250.0;
            foreach (var line in lines.Take(6))
            {
                drawing.DrawText(Text(line, 32, foreground, FontWeights.Medium), new System.Windows.Point(74, y));
                y += 68;
            }
            drawing.DrawText(Text("♪ NotchMuse", 18, muted, FontWeights.Normal), new System.Windows.Point(74, height - 64));
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

    private static FormattedText Text(string value, double size, MediaBrush brush, FontWeight weight) =>
        new(value, System.Globalization.CultureInfo.CurrentUICulture, System.Windows.FlowDirection.LeftToRight,
            new Typeface(new System.Windows.Media.FontFamily("Segoe UI"), FontStyles.Normal, weight, FontStretches.Normal), size, brush, 1.0);

    private static (MediaBrush Background, MediaBrush Foreground, MediaBrush Muted, MediaBrush Accent) Colors(ShareCardTheme theme) => theme switch
    {
        ShareCardTheme.WarmAlabaster => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(240, 233, 218)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(49, 42, 35)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(119, 104, 88)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(220, 164, 98))),
        ShareCardTheme.SodaMist => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(207, 229, 225)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(27, 58, 59)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(80, 117, 116)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(91, 168, 159))),
        _ => (new SolidColorBrush(System.Windows.Media.Color.FromRgb(24, 24, 29)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(248, 245, 237)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(174, 169, 158)), new SolidColorBrush(System.Windows.Media.Color.FromRgb(247, 180, 93)))
    };
}
