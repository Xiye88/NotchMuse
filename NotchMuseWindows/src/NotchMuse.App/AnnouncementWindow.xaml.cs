using System.Diagnostics;
using System.Net.Http;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace NotchMuse.App;

public partial class AnnouncementWindow : Window
{
    private const string CurrentVersion = "0.9.0";
    private readonly bool english;
    private readonly UpdateService? updateService;
    private AnnouncementInfo announcement;
    private ReleaseInfo? availableUpdate;

    public AnnouncementWindow(
        AnnouncementInfo announcement,
        ReleaseInfo? availableUpdate,
        bool isEnglish,
        UpdateService? updateService = null)
    {
        InitializeComponent();
        english = isEnglish;
        this.announcement = announcement;
        this.availableUpdate = availableUpdate;
        this.updateService = updateService;
        RenderContent();
    }

    private void RenderContent()
    {
        if (availableUpdate is not null)
        {
            Title = english ? $"NotchMuse {availableUpdate.TagName} Available" : $"发现新版本 {availableUpdate.TagName}";
            TitleText.Text = english ? "New Version Available" : "发现新版本";
            VersionBadgeText.Text = availableUpdate.TagName;
            SubtitleText.Text = english
                ? $"Current v{CurrentVersion} → Latest {availableUpdate.TagName}"
                : $"当前版本 v{CurrentVersion} → 最新版本 {availableUpdate.TagName}";
            SummaryText.Text = !string.IsNullOrWhiteSpace(availableUpdate.Name)
                ? availableUpdate.Name
                : (english ? $"NotchMuse {availableUpdate.TagName} is ready to install." : $"NotchMuse {availableUpdate.TagName} 已发布，建议立即升级体验最新修复与优化。");
            HighlightsHeading.Text = english ? "Release Notes" : "新版本更新内容";

            var lines = ParseReleaseBodyLines(availableUpdate.Body);
            RenderBulletItems(lines.Count > 0
                ? lines
                : (english ? announcement.HighlightsEn : announcement.HighlightsZh) ?? []);

            DownloadUpdateButton.Content = english ? $"Download {availableUpdate.TagName}" : $"下载新版 {availableUpdate.TagName}";
            DownloadUpdateButton.Visibility = Visibility.Visible;
        }
        else
        {
            Title = english ? "NotchMuse Latest Updates" : "NotchMuse 最新版本进展";
            TitleText.Text = english ? announcement.TitleEn : announcement.TitleZh;
            VersionBadgeText.Text = string.IsNullOrWhiteSpace(announcement.Id) ? $"v{CurrentVersion}" : announcement.Id;
            SubtitleText.Text = english
                ? $"Installed v{CurrentVersion} · Up to date"
                : $"当前已安装 v{CurrentVersion} · 已是最新版本";
            SummaryText.Text = (english ? announcement.SummaryEn : announcement.SummaryZh)
                ?? (english ? UpdateService.FallbackAnnouncement.SummaryEn! : UpdateService.FallbackAnnouncement.SummaryZh!);
            HighlightsHeading.Text = english ? "What's New in This Release" : "本版核心亮点";

            var bullets = (english ? announcement.HighlightsEn : announcement.HighlightsZh)
                ?? (english ? UpdateService.FallbackAnnouncement.HighlightsEn! : UpdateService.FallbackAnnouncement.HighlightsZh!);
            RenderBulletItems(bullets);

            DownloadUpdateButton.Visibility = Visibility.Collapsed;
        }

        CheckNowButton.Content = english ? "Check for Updates" : "立即检查更新";
        ConfirmButton.Content = english ? "Got It" : "我知道了";
    }

    private void RenderBulletItems(IReadOnlyList<string> items)
    {
        HighlightsHost.Children.Clear();
        foreach (var item in items)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 9) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(16) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var dot = new Border
            {
                Width = 6,
                Height = 6,
                CornerRadius = new CornerRadius(3),
                Margin = new Thickness(2, 6, 0, 0),
                VerticalAlignment = VerticalAlignment.Top,
                HorizontalAlignment = System.Windows.HorizontalAlignment.Left
            };
            dot.SetResourceReference(Border.BackgroundProperty, "AccentBrush");

            var tb = new TextBlock
            {
                Text = item,
                FontSize = 12.5,
                LineHeight = 18.5,
                TextWrapping = TextWrapping.Wrap
            };
            tb.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");
            Grid.SetColumn(tb, 1);

            row.Children.Add(dot);
            row.Children.Add(tb);
            HighlightsHost.Children.Add(row);
        }
    }

    private static List<string> ParseReleaseBodyLines(string? body)
    {
        var result = new List<string>();
        if (string.IsNullOrWhiteSpace(body)) return result;
        foreach (var raw in body.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            var line = raw.Trim().TrimStart('-', '*', '•', '#').Trim();
            if (line.Length < 4) continue;
            result.Add(line);
            if (result.Count >= 8) break;
        }
        return result;
    }

    private async void OnCheckNowClick(object sender, RoutedEventArgs e)
    {
        if (updateService is null)
        {
            CheckStatusText.Text = english ? "Up to date" : "已是最新版本";
            return;
        }

        CheckNowButton.IsEnabled = false;
        CheckStatusText.Text = english ? "Checking…" : "正在检查…";
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(8));
            announcement = await updateService.GetAnnouncementAsync(cts.Token);
            var latest = await updateService.GetLatestAsync(cts.Token);
            if (latest is not null && UpdateService.IsNewer(CurrentVersion, latest))
            {
                availableUpdate = latest;
                CheckStatusText.Text = english ? $"Found {latest.TagName}" : $"发现新版 {latest.TagName}";
            }
            else
            {
                CheckStatusText.Text = english ? "Already up to date" : "当前已是最新版";
            }
            RenderContent();
        }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or OperationCanceledException or InvalidOperationException)
        {
            CheckStatusText.Text = english ? "Check unavailable" : "暂时无法连接更新服务";
        }
        finally
        {
            CheckNowButton.IsEnabled = true;
        }
    }

    private void OnDownloadUpdateClick(object sender, RoutedEventArgs e)
    {
        var target = availableUpdate?.DownloadUrl ?? availableUpdate?.HtmlUrl ?? announcement.Url;
        if (string.IsNullOrWhiteSpace(target)) return;
        try { Process.Start(new ProcessStartInfo(target) { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception) { }
    }

    private void OnTitleDrag(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed) DragMove();
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Close();
}
