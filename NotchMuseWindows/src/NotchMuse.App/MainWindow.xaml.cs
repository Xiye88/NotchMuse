using Microsoft.Win32;
using NotchMuse.Core;
using NotchMuse.Platform;
using NotchMuse.Sources;
using System.Net;
using System.Net.Http;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Forms = System.Windows.Forms;

namespace NotchMuse.App;

public sealed record LyricView(string DisplayText, double Time);

public partial class MainWindow : Window
{
    private readonly SmtcService media = new();
    private readonly HttpClient client = new(new HttpClientHandler { AutomaticDecompression = DecompressionMethods.All }) { Timeout = TimeSpan.FromSeconds(12) };
    private readonly LyricsEngine engine;
    private readonly Forms.NotifyIcon tray = new() { Icon = CreateTrayIcon(), Visible = true, Text = "NotchMuse" };
    private readonly UpdateService updateService;
    private readonly DispatcherTimer frameTimer = new() { Interval = TimeSpan.FromMilliseconds(41) };
    private readonly DispatcherTimer fullscreenTimer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly DispatcherTimer noLyricsTimer = new() { Interval = TimeSpan.FromSeconds(2.2) };
    private readonly string[] noLyricsLines = MicroAnimationCatalog.Phrases.ToArray();
    private int noLyricsIndex;
    private CancellationTokenSource? lookup;
    private PlaybackSnapshot? snapshot;
    private LyricsCandidate? activeCandidate;
    private HwndSource? source;
    private bool closed;
    private bool locked;
    private bool draggingProgress;
    private bool english;
    private double timeOffset;
    private DisplayMode mode = DisplayMode.FreeFloat;
    private IntPtr windowHandle;
    private const int HotkeyId = 0x4E4D;
    private const uint ModAlt = 0x0001, ModControl = 0x0002, WmHotkey = 0x0312;
    private const int GwlExstyle = -20, WsExTransparent = 0x20, WsExLayered = 0x80000;
    private const int SwpNoSize = 0x0001, SwpNoZOrder = 0x0004, SwpShowWindow = 0x0040;
    private const uint HwndTop = 0;
    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] private static extern IntPtr FindWindow(string? className, string? windowName);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RectNative rect);
    [DllImport("user32.dll")] private static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    [StructLayout(LayoutKind.Sequential)] private readonly record struct RectNative(int Left, int Top, int Right, int Bottom);
    private enum DisplayMode { FreeFloat, TopIsland, Taskbar }

    private static System.Drawing.Icon CreateTrayIcon()
    {
        var executable = Environment.ProcessPath;
        return executable is not null
            ? System.Drawing.Icon.ExtractAssociatedIcon(executable) ?? System.Drawing.SystemIcons.Application
            : System.Drawing.SystemIcons.Application;
    }

    public MainWindow()
    {
        InitializeComponent();
        engine = LyricsEngine.Create(client);
        updateService = new UpdateService(client);
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("自由悬浮", null, (_, _) => SetMode(DisplayMode.FreeFloat));
        menu.Items.Add("顶部悬浮岛", null, (_, _) => SetMode(DisplayMode.TopIsland));
        menu.Items.Add("任务栏贴边", null, (_, _) => SetMode(DisplayMode.Taskbar));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("锁定穿透", null, (_, _) => ToggleLock());
        menu.Items.Add("时间偏移 −0.5s", null, (_, _) => ChangeOffset(-.5));
        menu.Items.Add("时间偏移重置", null, (_, _) => ChangeOffset(-timeOffset));
        menu.Items.Add("时间偏移 +0.5s", null, (_, _) => ChangeOffset(.5));
        menu.Items.Add("开机自启", null, (_, _) => ToggleStartup());
        menu.Items.Add("打开主窗口", null, (_, _) => { SetMode(DisplayMode.FreeFloat); Show(); Activate(); });
        menu.Items.Add("退出", null, (_, _) => Close());
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => { Show(); Activate(); };
        frameTimer.Tick += (_, _) => RefreshProgress();
        fullscreenTimer.Tick += (_, _) => HideForFullscreenIfNeeded();
        noLyricsTimer.Tick += (_, _) => StatusLabel.Text = noLyricsLines[noLyricsIndex++ % noLyricsLines.Length];
        SystemParameters.StaticPropertyChanged += (_, _) => Dispatcher.Invoke(ApplyTheme);
        SystemEvents.DisplaySettingsChanged += (_, _) => Dispatcher.Invoke(() => { if (!closed) PositionWindow(); });
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        windowHandle = new WindowInteropHelper(this).Handle;
        var dark = 1; DwmSetWindowAttribute(windowHandle, 20, ref dark, sizeof(int));
        source = HwndSource.FromHwnd(windowHandle); source?.AddHook(WindowMessage);
        RegisterHotKey(windowHandle, HotkeyId, ModControl | ModAlt, (uint)Forms.Keys.L);
        media.Changed += OnMediaChanged; media.Error += OnMediaError;
        ApplyTheme(); SetMode(mode); frameTimer.Start(); fullscreenTimer.Start();
        StartVisualMotion();
        _ = RefreshReleaseInfoAsync();
        try { await media.StartAsync(); } catch (Exception ex) when (ex is COMException or InvalidOperationException) { StatusLabel.Text = "系统播控暂不可用：" + ex.Message; }
    }

    private void ApplyTheme()
    {
        if (SystemParameters.HighContrast)
        {
            WorkspaceRoot.Background = System.Windows.Media.Brushes.Black;
            SidebarPanel.Background = System.Windows.Media.Brushes.Black;
            return;
        }

        var glass = SystemParameters.WindowGlassColor;
        var lightTaskbar = (glass.R * 0.299 + glass.G * 0.587 + glass.B * 0.114) > 168;
        WorkspaceRoot.Background = new System.Windows.Media.SolidColorBrush(lightTaskbar ? System.Windows.Media.Color.FromRgb(247, 246, 242) : System.Windows.Media.Color.FromRgb(16, 16, 19));
        SidebarPanel.Background = new System.Windows.Media.SolidColorBrush(lightTaskbar ? System.Windows.Media.Color.FromRgb(235, 233, 228) : System.Windows.Media.Color.FromRgb(23, 23, 27));
    }
    private void OnMediaError(string error) => Dispatcher.InvokeAsync(() => StatusLabel.Text = error);
    private void OnMediaChanged(PlaybackSnapshot? value) => Dispatcher.InvokeAsync(() => UpdateTrack(value));
    private async void UpdateTrack(PlaybackSnapshot? value)
    {
        if (closed) return;
        snapshot = value;
        TrackLabel.Text = value is null ? "等待播放音乐…" : value.Track.Title + " · " + value.Track.Artist;
        SidebarTrack.Text = value is null ? "等待播放音乐…" : value.Track.Title;
        PlayButton.Content = value?.Playing == true ? "暂停" : "播放";
        if (value is null) { activeCandidate = null; LyricsItems.ItemsSource = null; BeginNoLyricsMotion(); return; }
        lookup?.Cancel(); lookup?.Dispose(); lookup = new(); var ct = lookup.Token;
        StatusLabel.Text = "正在寻找歌词…";
        try
        {
            var result = await engine.FindAsync(value.Track, ct);
            if (ct.IsCancellationRequested || closed) return;
            var winner = result.Decision.Winner;
            activeCandidate = winner;
            if (winner is null) BeginNoLyricsMotion();
            else
            {
                noLyricsTimer.Stop();
                StatusLabel.Text = winner.Provider + " · " + result.Decision.Reason;
            }
            RenderLyrics();
            AnimateLyricArrival();
        }
        catch (OperationCanceledException) { }
    }

    private void RefreshProgress()
    {
        if (snapshot is null) return;
        var duration = snapshot.Track.Duration;
        if (duration <= 0 || draggingProgress) return;
        ProgressSlider.Maximum = duration; ProgressSlider.Value = Math.Clamp(snapshot.Position + timeOffset, 0, duration);
    }
    private async void OnLyricClick(object sender, RoutedEventArgs e) { if (sender is FrameworkElement { Tag: double time }) await media.SeekAsync(time + timeOffset); }
    private async void OnPlayClick(object sender, RoutedEventArgs e) { await media.ToggleAsync(); }
    private void OnProgressGrab(object sender, System.Windows.Input.MouseButtonEventArgs e) => draggingProgress = true;
    private async void OnProgressRelease(object sender, System.Windows.Input.MouseButtonEventArgs e) { draggingProgress = false; await media.SeekAsync(ProgressSlider.Value - timeOffset); }
    private void OnProgressChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
    private void OnAccentClick(object sender, RoutedEventArgs e) { if (sender is System.Windows.Controls.Button b) { Resources["AccentBrush"] = b.Background; } }
    private void OnChineseClick(object sender, RoutedEventArgs e) { english = false; ApplyLanguage(); }
    private void OnEnglishClick(object sender, RoutedEventArgs e) { english = true; ApplyLanguage(); }
    private void ApplyLanguage()
    {
        LyricsNavButton.Content = english ? "Lyrics" : "歌词";
        DisplayNavButton.Content = english ? "Display" : "显示";
        AppearanceNavButton.Content = english ? "Appearance" : "外观";
        GeneralNavButton.Content = english ? "General" : "通用";
        CheckUpdateButton.Content = english ? "Check for updates" : "检查更新";
        RenderLyrics();
    }
    private void OnBilingualChanged(object sender, RoutedEventArgs e) => RenderLyrics();
    private void RenderLyrics()
    {
        LyricsItems.ItemsSource = activeCandidate?.Document.Normalized.Select(line =>
        {
            var text = string.IsNullOrWhiteSpace(line.Text) ? "♪" : line.Text;
            if (BilingualLyricsCheck.IsChecked == true && !string.IsNullOrWhiteSpace(line.Translation))
                text += Environment.NewLine + line.Translation;
            return new LyricView(text, line.Start);
        }).ToArray();
    }
    private async void OnCheckUpdateClick(object sender, RoutedEventArgs e)
    {
        CheckUpdateButton.IsEnabled = false;
        try
        {
            var latest = await updateService.GetLatestAsync(CancellationToken.None);
            CheckUpdateButton.Content = latest is not null && UpdateService.IsNewer("0.9.0", latest)
                ? (english ? $"Update available {latest.TagName}" : $"发现新版本 {latest.TagName}")
                : (english ? "Already up to date" : "已是最新版本");
        }
        catch (HttpRequestException) { CheckUpdateButton.Content = english ? "Update check unavailable" : "暂时无法检查更新"; }
        finally { CheckUpdateButton.IsEnabled = true; }
    }
    private async Task RefreshReleaseInfoAsync()
    {
        try
        {
            var latest = await updateService.GetLatestAsync(CancellationToken.None);
            if (latest is null || string.IsNullOrWhiteSpace(latest.Body)) return;
            var notice = latest.Body.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).FirstOrDefault(line => !line.StartsWith("#", StringComparison.Ordinal));
            if (string.IsNullOrWhiteSpace(notice)) return;
            await Dispatcher.InvokeAsync(() =>
            {
                AnnouncementText.Text = notice.Trim();
                AnnouncementCapsule.Visibility = Visibility.Visible;
            });
        }
        catch (HttpRequestException) { }
        catch (JsonException) { }
    }
    private void OnShareClick(object sender, RoutedEventArgs e)
    {
        ShareLinesList.Items.Clear();
        if (LyricsItems.ItemsSource is IEnumerable<LyricView> lines)
        {
            foreach (var line in lines.Take(6))
            {
                ShareLinesList.Items.Add(line);
                ShareLinesList.SelectedItems.Add(line);
            }
        }
        ShareStatusLabel.Text = "";
        SharePopup.IsOpen = true;
    }
    private async void OnCopyShareClick(object sender, RoutedEventArgs e)
    {
        var png = RenderSelectedShareCard();
        System.Windows.Clipboard.SetImage(ShareCardRenderer.Decode(png));
        ShareStatusLabel.Text = "已复制 ✓";
        await Task.Delay(1200);
        if (!closed) ShareStatusLabel.Text = "";
    }
    private void OnSaveShareClick(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.SaveFileDialog { Filter = "PNG 图片|*.png", FileName = "NotchMuse-lyrics.png" };
        if (dialog.ShowDialog(this) != true) return;
        File.WriteAllBytes(dialog.FileName, RenderSelectedShareCard());
        ShareStatusLabel.Text = "已保存 ✓";
    }
    private byte[] RenderSelectedShareCard()
    {
        var lines = ShareLinesList.SelectedItems.Cast<LyricView>().Take(6).Select(line => line.DisplayText).ToArray();
        if (lines.Length == 0) lines = ["♪"];
        var theme = ShareThemeCombo.SelectedIndex switch
        {
            1 => ShareCardTheme.WarmAlabaster,
            2 => ShareCardTheme.SodaMist,
            _ => ShareCardTheme.VinylNight
        };
        return ShareCardRenderer.RenderPng(snapshot?.Track.Title ?? "NotchMuse", snapshot?.Track.Artist ?? "Lyrics", lines, theme);
    }
    private void OnAppearanceClick(object sender, RoutedEventArgs e) => OnNavigate(new System.Windows.Controls.Button { Tag = "Appearance" }, e);
    private void OnSettingsClick(object sender, RoutedEventArgs e) => OnNavigate(new System.Windows.Controls.Button { Tag = "General" }, e);
    private void OnSidebarToggle(object sender, RoutedEventArgs e)
    {
        SidebarColumn.Width = SidebarColumn.Width.Value > 0 ? new GridLength(0) : new GridLength(224);
    }
    private void OnNavigate(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button b) return;
        var tag = b.Tag?.ToString() ?? "Lyrics";
        var isLyrics = tag == "Lyrics"; LyricsPage.Visibility = isLyrics ? Visibility.Visible : Visibility.Collapsed; SettingsPage.Visibility = isLyrics ? Visibility.Collapsed : Visibility.Visible;
        DisplaySettingsPage.Visibility = tag == "Display" ? Visibility.Visible : Visibility.Collapsed;
        AppearanceSettingsPage.Visibility = tag == "Appearance" ? Visibility.Visible : Visibility.Collapsed;
        GeneralSettingsPage.Visibility = tag == "General" ? Visibility.Visible : Visibility.Collapsed;
        PageTitle.Text = tag switch { "Display" => "显示", "Appearance" => "外观", "General" => "通用", _ => "歌词" };
    }
    private void OnDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (locked || e.ButtonState != System.Windows.Input.MouseButtonState.Pressed) return;
        CenterGuide.Visibility = Visibility.Visible;
        try { DragMove(); } finally { CenterGuide.Visibility = Visibility.Collapsed; }
        if (!System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.LeftAlt) && !System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.RightAlt))
        {
            var work = SystemParameters.WorkArea;
            var center = work.Left + (work.Width - Width) / 2;
            if (Math.Abs(Left - center) <= 10) Left = center;
            Left = Math.Clamp(Left, work.Left, work.Right - Width);
            Top = Math.Clamp(Top, work.Top, work.Bottom - Height);
        }
    }
    private void OnLockClick(object sender, RoutedEventArgs e) => ToggleLock();
    private void ToggleLock() { locked = !locked; LockButton.Content = locked ? "解锁" : "锁定"; var style = GetWindowLong(windowHandle, GwlExstyle) | WsExLayered; style = locked ? style | WsExTransparent : style & ~WsExTransparent; SetWindowLong(windowHandle, GwlExstyle, style); }
    private void OnFloatClick(object sender, RoutedEventArgs e) => SetMode(DisplayMode.FreeFloat);
    private void OnHideClick(object sender, RoutedEventArgs e) => Hide();
    private void OnStateChanged(object? sender, EventArgs e) { if (WindowState == WindowState.Minimized) Hide(); }
    private void SetMode(DisplayMode next)
    {
        mode = next; ModeCombo.SelectedIndex = (int)next; Show(); Activate();
        if (next == DisplayMode.FreeFloat) { SidebarColumn.Width = new GridLength(224); Width = 1120; Height = 720; WindowStyle = WindowStyle.None; PositionWindow(); }
        else if (next == DisplayMode.TopIsland) { SidebarColumn.Width = new GridLength(0); Width = 760; Height = 180; PositionWindow(); }
        else { SidebarColumn.Width = new GridLength(0); Width = 760; Height = 108; PositionWindow(); }
    }
    private void OnModeChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e) { if (ModeCombo.SelectedItem is System.Windows.Controls.ComboBoxItem item && Enum.TryParse<DisplayMode>(item.Tag?.ToString(), out var next) && IsLoaded) SetMode(next); }
    private void StartVisualMotion()
    {
        var sweep = new DoubleAnimation
        {
            From = 0,
            To = 500,
            Duration = TimeSpan.FromSeconds(2.4),
            RepeatBehavior = RepeatBehavior.Forever
        };
        SweepLine.RenderTransform = new TranslateTransform();
        ((TranslateTransform)SweepLine.RenderTransform).BeginAnimation(TranslateTransform.YProperty, sweep);
        var rotation = new DoubleAnimation
        {
            From = 0,
            To = 360,
            Duration = TimeSpan.FromSeconds(18),
            RepeatBehavior = RepeatBehavior.Forever
        };
        VinylRotation.BeginAnimation(RotateTransform.AngleProperty, rotation);
    }
    private void AnimateLyricArrival()
    {
        var transform = new TranslateTransform(0, 6);
        LyricsPage.RenderTransform = transform;
        LyricsPage.BeginAnimation(OpacityProperty, new DoubleAnimation(0.6, 1, TimeSpan.FromSeconds(0.20)));
        transform.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(6, 0, TimeSpan.FromSeconds(0.20)));
    }
    private void PositionWindow()
    {
        WindowStartupLocation = WindowStartupLocation.Manual;
        var work = SystemParameters.WorkArea;
        if (mode == DisplayMode.Taskbar)
        {
            var trayWindow = FindWindow("Shell_TrayWnd", null);
            if (trayWindow != IntPtr.Zero && GetWindowRect(trayWindow, out var rect))
            {
                var scale = GetDpiForWindow(windowHandle) / 96.0;
                Left = rect.Left / scale + 12;
                Top = rect.Top / scale - Height - 6;
            }
            else { Left = work.Left + 12; Top = work.Bottom - Height - 6; }
        }
        else if (mode == DisplayMode.TopIsland) { Left = work.Left + (work.Width - Width) / 2; Top = work.Top + 18; }
        else { Left = work.Left + (work.Width - Width) / 2; Top = work.Top + (work.Height - Height) / 2; }
    }
    private void HideForFullscreenIfNeeded()
    {
        if (mode == DisplayMode.FreeFloat) return;
        var foreground = GetForegroundWindow(); if (foreground == IntPtr.Zero || foreground == windowHandle) return;
        if (!GetWindowRect(foreground, out var rect)) return;
        var work = SystemParameters.WorkArea;
        var fullscreen = rect.Left <= work.Left && rect.Top <= work.Top && rect.Right >= work.Right && rect.Bottom >= work.Bottom;
        if (fullscreen) Hide();
        else if (!IsVisible) { Show(); PositionWindow(); }
    }
    private void BeginNoLyricsMotion()
    {
        noLyricsIndex = 0;
        StatusLabel.Text = noLyricsLines[0];
        noLyricsTimer.Start();
    }
    private void ChangeOffset(double delta) { timeOffset = Math.Clamp(timeOffset + delta, -10, 10); }
    private void OnOffsetMinus(object sender, RoutedEventArgs e) => ChangeOffset(-.5);
    private void OnOffsetReset(object sender, RoutedEventArgs e) => ChangeOffset(-timeOffset);
    private void OnOffsetPlus(object sender, RoutedEventArgs e) => ChangeOffset(.5);
    private void OnStartupChanged(object sender, RoutedEventArgs e) => SetStartup(StartupCheck.IsChecked == true);
    private void ToggleStartup() { SetStartup(!IsStartupEnabled()); StartupCheck.IsChecked = IsStartupEnabled(); }
    private static bool IsStartupEnabled() => Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")?.GetValue("NotchMuse") is not null;
    private static void SetStartup(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"); if (enabled) key?.SetValue("NotchMuse", Environment.ProcessPath ?? ""); else key?.DeleteValue("NotchMuse", false);
    }
    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled) { if (message == WmHotkey && wParam.ToInt32() == HotkeyId) { ToggleLock(); handled = true; } return IntPtr.Zero; }
    private void OnClosed(object? sender, EventArgs e)
    {
        closed = true; lookup?.Cancel(); lookup?.Dispose(); frameTimer.Stop(); fullscreenTimer.Stop(); noLyricsTimer.Stop(); UnregisterHotKey(windowHandle, HotkeyId); source?.RemoveHook(WindowMessage); tray.Visible = false; tray.Dispose(); media.Changed -= OnMediaChanged; media.Error -= OnMediaError; media.Dispose(); client.Dispose(); SystemEvents.DisplaySettingsChanged -= (_, _) => { };
    }
}





