using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Animation;
using NotchMuse.App.Themes;

namespace NotchMuse.App;

public partial class ShareCardWindow : Window
{
    private readonly string trackTitle;
    private readonly string trackArtist;
    private readonly string? trackAlbum;
    private readonly byte[]? artworkBytes;
    private readonly bool english;
    private readonly List<(System.Windows.Controls.CheckBox Check, string Line)> lineItems = [];
    private byte[] currentPng = [];
    private bool updatingPreview;
    private CancellationTokenSource? toastCts;

    public ShareCardWindow(
        string title,
        string artist,
        IReadOnlyList<string> candidateLines,
        bool isEnglish,
        string? album = null,
        byte[]? artwork = null)
    {
        trackTitle = string.IsNullOrWhiteSpace(title) ? "NotchMuse" : title;
        trackArtist = string.IsNullOrWhiteSpace(artist) ? "Vinyl Studio Hi-Fi" : artist;
        trackAlbum = string.IsNullOrWhiteSpace(album) ? null : album.Trim();
        artworkBytes = artwork;
        english = isEnglish;

        InitializeComponent();
        SourceInitialized += (_, _) => ThemeManager.ApplyWindowChrome(this, ThemeManager.IsDarkActive);

        ApplyLanguage();
        TrackBadge.Text = trackAlbum is null
            ? $"· {trackTitle} — {trackArtist}"
            : $"· {trackTitle} — {trackArtist} · 《{trackAlbum}》";

        var cleanLines = candidateLines.Where(l => !string.IsNullOrWhiteSpace(l)).Take(12).ToArray();
        if (cleanLines.Length == 0)
        {
            cleanLines = [isEnglish ? "Softly glowing across your desktop" : "晚风轻轻吹过黑胶纹路"];
        }

        LinesCheckHost.Children.Clear();
        lineItems.Clear();
        for (var i = 0; i < cleanLines.Length; i++)
        {
            var line = cleanLines[i];
            var row = new Border
            {
                CornerRadius = new CornerRadius(7),
                Padding = new Thickness(8, 6, 8, 6),
                Margin = new Thickness(0, 1, 0, 1),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            var cb = new System.Windows.Controls.CheckBox
            {
                IsChecked = i < Math.Min(4, cleanLines.Length),
                Content = new TextBlock
                {
                    Text = line,
                    FontSize = 12,
                    TextTrimming = TextTrimming.CharacterEllipsis,
                    MaxWidth = 220
                }
            };
            cb.Checked += OnLineSelectionChanged;
            cb.Unchecked += OnLineSelectionChanged;
            row.Child = cb;
            lineItems.Add((cb, line));
            LinesCheckHost.Children.Add(row);
        }

        RefreshPreview();
    }

    private void ApplyLanguage()
    {
        Title = english ? "Share Lyrics Card" : "分享歌词卡片";
        HeaderTitle.Text = english ? "Share Lyrics Card" : "生成歌词分享卡";
        PreviewHint.Text = english ? "Live Card Preview (1200 × 800 PNG)" : "实时卡片预览（1200 × 800 PNG）";
        TemplateLabel.Text = english ? "Card Template" : "卡片风格模板";
        ThemeVinylRadio.Content = english ? "Vinyl Night" : "黑胶暗夜";
        ThemeAlabasterRadio.Content = english ? "Alabaster" : "暖雪花石";
        ThemeSodaRadio.Content = english ? "Soda Mist" : "汽水雾青";
        LinesLabel.Text = english ? "Select 1–6 Lyric Lines" : "勾选 1–6 句歌词";
        CopyBtn.Content = english ? "Copy Image to Clipboard" : "复制图片到剪贴板";
        SaveBtn.Content = english ? "Save PNG…" : "保存为 PNG…";
    }

    private ShareCardTheme SelectedTheme =>
        ThemeAlabasterRadio.IsChecked == true
            ? ShareCardTheme.WarmAlabaster
            : ThemeSodaRadio.IsChecked == true
                ? ShareCardTheme.SodaMist
                : ShareCardTheme.VinylNight;

    private string[] SelectedLines =>
        lineItems.Where(x => x.Check.IsChecked == true).Select(x => x.Line).Take(6).ToArray();

    private void OnLineSelectionChanged(object sender, RoutedEventArgs e)
    {
        if (updatingPreview) return;
        var checkedItems = lineItems.Where(x => x.Check.IsChecked == true).ToArray();
        if (checkedItems.Length > 6 && sender is System.Windows.Controls.CheckBox cb)
        {
            updatingPreview = true;
            cb.IsChecked = false;
            updatingPreview = false;
            StatusFeedback.Text = english ? "Select up to 6 lines" : "最多选择 6 句歌词";
            return;
        }
        StatusFeedback.Text = "";
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        RefreshPreview();
    }

    private void OnTemplateChanged(object sender, RoutedEventArgs e)
    {
        if (!IsInitialized) return;
        InteractionSoundEngine.Play(InteractionSoundCue.Step);
        RefreshPreview();
    }

    public void RefreshPreview()
    {
        var lines = SelectedLines;
        if (lines.Length == 0) lines = ["♪"];
        currentPng = ShareCardRenderer.RenderPng(trackTitle, trackArtist, trackAlbum, lines, SelectedTheme, artworkBytes);
        PreviewImage.Source = ShareCardRenderer.Decode(currentPng);
        SelectedCountHint.Text = english
            ? $"{SelectedLines.Length} of 6 lines selected"
            : $"已选择 {SelectedLines.Length} / 6 句歌词";
    }

    private void OnCopyClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CopyBtn, 0.94);
        if (currentPng.Length == 0) RefreshPreview();
        System.Windows.Clipboard.SetImage(ShareCardRenderer.Decode(currentPng));
        ShowCompletionToast(english ? "Copied image to clipboard" : "已复制高清卡片到剪贴板");
    }

    private void OnSaveClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(SaveBtn, 0.94);
        if (currentPng.Length == 0) RefreshPreview();
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Filter = "PNG Image|*.png",
            FileName = $"NotchMuse-{SanitizeFileName(trackTitle)}.png"
        };
        if (dialog.ShowDialog(this) != true) return;
        File.WriteAllBytes(dialog.FileName, currentPng);
        ShowCompletionToast(english ? "Saved PNG card" : "已保存高清 PNG 分享卡");
    }

    private async void ShowCompletionToast(string message)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Landed);
        toastCts?.Cancel();
        toastCts?.Dispose();
        toastCts = new CancellationTokenSource();
        var token = toastCts.Token;

        CompletionToastText.Text = "✓  " + message;
        if (InteractionMotion.AnimationsAllowed)
            CompletionToast.BeginAnimation(OpacityProperty, new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(120)));
        else
            CompletionToast.Opacity = 1.0;

        try
        {
            await Task.Delay(1800, token);
            if (!IsLoaded) return;
            if (InteractionMotion.AnimationsAllowed)
                CompletionToast.BeginAnimation(OpacityProperty, new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(180)));
            else
                CompletionToast.Opacity = 0.0;
        }
        catch (OperationCanceledException) { }
    }

    private static string SanitizeFileName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var cleaned = new string(name.Where(c => !invalid.Contains(c)).ToArray()).Trim();
        return string.IsNullOrEmpty(cleaned) ? "lyrics" : cleaned;
    }

    private void OnTitleDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed) DragMove();
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();
}
