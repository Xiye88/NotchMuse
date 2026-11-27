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
    public const string TronAddress = "TCTrNcvTD3QE7opC61mKoTyUmRkKos6jan";
    public const string SupportersUrl = "https://raw.githubusercontent.com/Xiye88/NotchMuse/main/docs/support/supporters.json";

    private readonly bool english;
    private readonly HttpClient? httpClient;
    private readonly CancellationTokenSource windowCts = new();
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
            toastCts = null;
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
        HeaderTitle.Text = english ? "Buy the Author a Coffee" : "请作者喝杯咖啡";
        HeaderSubtitle.Text = english
            ? "NotchMuse is free and open-source · Your support keeps Windows & Mac releases moving forward"
            : "NotchMuse 永久免费开源 · 你的支持会让 Windows & Mac 双端持续变得更好";
        WeChatBadge.Text = english ? "WeChat Pay" : "微信赞赏";
        WeChatHint.Text = english ? "Scan with WeChat" : "打开微信扫一扫赞赏";
        WeChatSubHint.Text = english ? "Any amount is appreciated" : "随心打赏，不设门槛";
        CopyEvmBtn.Content = english ? "Copy EVM Address" : "复制 EVM 地址";
        CopyTronBtn.Content = english ? "Copy TRC-20 Address" : "复制 TRC-20 地址";
        ChainNoticeText.Text = english
            ? "Note: Send USDT only on the matching chain (EVM or TRC-20). Thank you for supporting NotchMuse!"
            : "提示：链上打赏请务必核对对应网络（EVM / TRC-20），仅支持 USDT 转账。感谢每一份温暖支持！";
        SupportersHeader.Text = english ? "Supporters Wall" : "鸣谢名单 · Supporters";
        GitHubStarBtn.Content = english ? "Star on GitHub ↗" : "GitHub Star 支持 ↗";
        SupportersStatusText.Text = english ? "Loading supporters…" : "正在加载鸣谢名单…";

        EvmAddressLabel.Text = $"{EvmAddress[..8]}…{EvmAddress[^6..]}";
        TronAddressLabel.Text = $"{TronAddress[..8]}…{TronAddress[^6..]}";
    }

    private void LoadQrCodes()
    {
        try
        {
            var bmp = new BitmapImage();
            bmp.BeginInit();
            bmp.UriSource = new Uri("pack://application:,,,/NotchMuse.App;component/WeChatSupport.jpg", UriKind.Absolute);
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.EndInit();
            bmp.Freeze();
            WeChatQrImage.Source = bmp;
        }
        catch (IOException) { }
        catch (UriFormatException) { }

        EvmQrImage.Source = QrCodeRenderer.RenderBitmap(EvmAddress, 180);
        TronQrImage.Source = QrCodeRenderer.RenderBitmap(TronAddress, 180);
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
        catch (HttpRequestException)
        {
            if (!windowCts.IsCancellationRequested)
                await Dispatcher.InvokeAsync(() => { if (IsLoaded) RenderSupporters([]); });
        }
        catch (JsonException)
        {
            if (!windowCts.IsCancellationRequested)
                await Dispatcher.InvokeAsync(() => { if (IsLoaded) RenderSupporters([]); });
        }
        catch (InvalidOperationException)
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
                ? "Become the first supporter listed here — your name will shine on both Windows & Mac!"
                : "期待你的名字出现在鸣谢名单中 · 你的支持将同步展示在 Windows 与 Mac 双端";
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

    private void OnCopyEvmClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CopyEvmBtn, 0.94);
        if (TryCopyClipboard(EvmAddress))
            ShowToast(english ? "Copied USDT (EVM) address" : "已复制 USDT (EVM) 地址");
        else
            ShowToast(english ? "Clipboard busy, please retry" : "剪贴板被占用，请重试");
    }

    private void OnCopyTronClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CopyTronBtn, 0.94);
        if (TryCopyClipboard(TronAddress))
            ShowToast(english ? "Copied USDT (TRC-20) address" : "已复制 USDT (TRC-20) 地址");
        else
            ShowToast(english ? "Clipboard busy, please retry" : "剪贴板被占用，请重试");
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
