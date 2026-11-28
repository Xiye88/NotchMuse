using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using NotchMuse.App.Themes;

namespace NotchMuse.App;

public partial class SupportWindow : Window
{
    public const string EvmAddress = "0x6c0275e975818e99d078ee2348576e2d9608f6d6";
    public const string QqGroupId = "1137981671";
    public const string QqGroupJoinUrl = "https://qm.qq.com/q/J6W0oSPtu0";
    public const string SupportersUrl = "https://raw.githubusercontent.com/Xiye88/NotchMuse/main/docs/support/supporters.json";

    private readonly bool english;
    private readonly HttpClient? httpClient;
    private readonly CancellationTokenSource windowCts = new();
    private readonly Dictionary<System.Windows.Controls.Button, CancellationTokenSource> copyResetTimers = [];
    private CancellationTokenSource? toastCts;

    public SupportWindow(bool isEnglish, HttpClient? client = null, bool skipNetwork = false)
    {
        english = isEnglish;
        httpClient = client;

        InitializeComponent();
        SourceInitialized += (_, _) => ThemeManager.ApplyWindowChrome(this, ThemeManager.IsDarkActive);
        Closed += (_, _) =>
        {
            windowCts.Cancel();
            windowCts.Dispose();
            toastCts?.Cancel();
            toastCts?.Dispose();
            foreach (var cts in copyResetTimers.Values)
            {
                cts.Cancel();
                cts.Dispose();
            }
            copyResetTimers.Clear();
        };

        ApplyLanguage();
        LoadQrCodes();

        if (skipNetwork)
        {
            RenderSupporters([("NotchMuse Community", isEnglish ? "Thank you for keeping open-source music alive!" : "感谢每一位支持开源项目的音乐同好")]);
        }
        else
        {
            _ = LoadSupportersAsync();
        }
    }

    private void ApplyLanguage()
    {
        Title = english ? "Support NotchMuse" : "支持 NotchMuse";
        HeaderTitle.Text = english ? "Support NotchMuse" : "支持 NotchMuse";
        HeaderSubtitle.Text = english
            ? "NotchMuse is a free passion project built with love. If it brightens your listening, feel free to buy me a coffee or join the user group."
            : "NotchMuse 是免费开源、为爱发电的独立项目。如果它陪你度过了好时光，欢迎请作者喝杯咖啡，或加入用户群交流反馈。";
        WeChatBadge.Text = english ? "WeChat Pay" : "微信支付";
        WeChatHint.Text = english ? "Scan with WeChat" : "打开微信扫一扫赞赏";
        WeChatSubHint.Text = english ? "Any amount is appreciated" : "随心打赏，不设门槛";
        QqGroupBadge.Text = english ? "QQ User Group" : "QQ 用户交流群";
        QqGroupHint.Text = english ? "Feedback · Updates · Chat" : "交流反馈 · 抢先体验";
        QqGroupIdLabel.Text = english ? $"Group {QqGroupId}" : $"群号 {QqGroupId}";
        CopyQqGroupBtn.Content = english ? "Copy Group ID" : "复制群号";
        EvmOnlyNotice.Text = english ? "EVM networks · USDT only" : "仅支持 EVM 网络 USDT";
        CopyEvmBtn.Content = english ? "Copy Address" : "复制地址";
        SupportersHeader.Text = english ? "Supporters Wall" : "鸣谢名单 · Supporters";
        GitHubStarBtn.Content = english ? "Star on GitHub ↗" : "GitHub Star 支持 ↗";
        SupportersStatusText.Text = english ? "Loading supporters…" : "正在加载鸣谢名单…";

        EvmAddressLabel.Text = $"{EvmAddress[..6]}…{EvmAddress[^4..]}";
    }

    private void LoadQrCodes()
    {
        WeChatQrImage.Source = TryLoadPackImage("pack://application:,,,/NotchMuse.App;component/WeChatSupport.jpg");
        QqGroupQrImage.Source = TryLoadPackImage("pack://application:,,,/NotchMuse.App;component/qq-group-qr.png")
            ?? QrCodeRenderer.RenderBitmap(QqGroupJoinUrl, 180);
        EvmQrImage.Source = QrCodeRenderer.RenderBitmap(EvmAddress, 180);
    }

    private static BitmapSource? TryLoadPackImage(string packUri)
    {
        try
        {
            var bmp = new BitmapImage();
            bmp.BeginInit();
            bmp.UriSource = new Uri(packUri, UriKind.Absolute);
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.EndInit();
            bmp.Freeze();
            return bmp;
        }
        catch (Exception ex) when (ex is IOException or UriFormatException or NotSupportedException or InvalidOperationException)
        {
            return null;
        }
    }

    private async Task LoadSupportersAsync()
    {
        try
        {
            var ct = windowCts.Token;
            using var fallbackClient = httpClient is null ? new HttpClient { Timeout = TimeSpan.FromSeconds(8) } : null;
            var activeClient = httpClient ?? fallbackClient!;
            var json = await activeClient.GetStringAsync(SupportersUrl, ct);
            using var doc = JsonDocument.Parse(json);
            var list = new List<(string Name, string? Note)>();

            var root = doc.RootElement;
            var array = root.ValueKind == JsonValueKind.Array
                ? root
                : root.ValueKind == JsonValueKind.Object && root.TryGetProperty("supporters", out var nested) && nested.ValueKind == JsonValueKind.Array
                    ? nested
                    : default;

            if (array.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in array.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String)
                    {
                        var s = item.GetString();
                        if (!string.IsNullOrWhiteSpace(s)) list.Add((s.Trim(), null));
                    }
                    else if (item.ValueKind == JsonValueKind.Object)
                    {
                        var name = item.TryGetProperty("name", out var n) && n.ValueKind == JsonValueKind.String ? n.GetString() : null;
                        var note = item.TryGetProperty("note", out var nt) && nt.ValueKind == JsonValueKind.String ? nt.GetString() : null;
                        if (!string.IsNullOrWhiteSpace(name)) list.Add((name.Trim(), note?.Trim()));
                    }
                }
            }

            if (ct.IsCancellationRequested) return;
            await Dispatcher.InvokeAsync(() => { if (IsLoaded) RenderSupporters(list); });
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or InvalidOperationException)
        {
            if (!windowCts.IsCancellationRequested)
                await Dispatcher.InvokeAsync(() => { if (IsLoaded) RenderSupporters([]); });
        }
    }

    private void RenderSupporters(IReadOnlyList<(string Name, string? Note)> supporters)
    {
        SupportersWrap.Children.Clear();
        if (supporters.Count == 0)
        {
            SupportersStatusText.Text = english
                ? "Thanks to everyone supporting NotchMuse — your name will shine on both Windows & Mac!"
                : "感谢每一位支持 NotchMuse 的朋友 · 鸣谢名单将同步展示在 Windows 与 Mac 双端";
            SupportersStatusText.Visibility = Visibility.Visible;
            return;
        }

        SupportersStatusText.Visibility = Visibility.Collapsed;
        foreach (var (name, note) in supporters.Take(24))
        {
            var chip = new Border
            {
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(9, 4, 9, 4),
                Margin = new Thickness(0, 0, 6, 6),
                BorderThickness = new Thickness(1)
            };
            chip.SetResourceReference(Border.BackgroundProperty, "CardBrush");
            chip.SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");

            var text = string.IsNullOrWhiteSpace(note) ? $"♥ {name}" : $"♥ {name} · {note}";
            var tb = new TextBlock { Text = text, FontSize = 11.5 };
            tb.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");
            chip.Child = tb;
            SupportersWrap.Children.Add(chip);
        }
    }

    private void OnCopyQqGroupClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CopyQqGroupBtn, 0.94);
        if (TryCopyClipboard(QqGroupId))
        {
            FlashButtonFeedback(CopyQqGroupBtn, english ? "Copied ✓" : "已复制 ✓", english ? "Copy Group ID" : "复制群号");
            ShowToast(english ? $"Copied QQ Group ID {QqGroupId}" : $"已复制 QQ 群号 {QqGroupId}");
        }
        else
        {
            ShowToast(english ? "Clipboard busy, please retry" : "剪贴板被占用，请重试");
        }
    }

    private void OnCopyEvmClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CopyEvmBtn, 0.94);
        if (TryCopyClipboard(EvmAddress))
        {
            FlashButtonFeedback(CopyEvmBtn, english ? "Copied ✓" : "已复制 ✓", english ? "Copy Address" : "复制地址");
            ShowToast(english ? "Copied USDT (EVM) address" : "已复制 USDT (EVM) 地址");
        }
        else
        {
            ShowToast(english ? "Clipboard busy, please retry" : "剪贴板被占用，请重试");
        }
    }

    private async void FlashButtonFeedback(System.Windows.Controls.Button button, string feedbackText, string originalText)
    {
        if (copyResetTimers.Remove(button, out var old))
        {
            old.Cancel();
            old.Dispose();
        }
        var cts = new CancellationTokenSource();
        copyResetTimers[button] = cts;
        var ct = cts.Token;

        button.Content = feedbackText;
        try
        {
            await Task.Delay(2000, ct);
            if (!ct.IsCancellationRequested && IsLoaded)
                button.Content = originalText;
        }
        catch (OperationCanceledException) { }
    }

    private static bool TryCopyClipboard(string text)
    {
        try
        {
            System.Windows.Clipboard.SetText(text);
            return true;
        }
        catch (System.Runtime.InteropServices.ExternalException)
        {
            return false;
        }
    }

    private void OnGitHubClick(object sender, RoutedEventArgs e)
    {
        try { Process.Start(new ProcessStartInfo("https://github.com/Xiye88/NotchMuse") { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception) { }
    }

    private async void ShowToast(string message)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Landed);
        toastCts?.Cancel();
        toastCts?.Dispose();
        toastCts = new CancellationTokenSource();
        var ct = toastCts.Token;

        CopyToastText.Text = "✓  " + message;
        CopyToast.BeginAnimation(OpacityProperty, null);
        if (InteractionMotion.AnimationsAllowed)
            CopyToast.BeginAnimation(OpacityProperty, new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(120)));
        else
            CopyToast.Opacity = 1.0;

        try
        {
            await Task.Delay(1700, ct);
            if (ct.IsCancellationRequested || !IsLoaded) return;
            CopyToast.BeginAnimation(OpacityProperty, null);
            if (InteractionMotion.AnimationsAllowed)
                CopyToast.BeginAnimation(OpacityProperty, new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(180)));
            else
                CopyToast.Opacity = 0.0;
        }
        catch (OperationCanceledException) { }
    }

    private void OnTitleDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed) DragMove();
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();
}
