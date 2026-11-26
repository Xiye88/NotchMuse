using Microsoft.Win32;
using NotchMuse.Core;
using NotchMuse.Platform;
using NotchMuse.Sources;
using System.Net;
using System.Net.Http;
using System.Runtime.InteropServices;
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
    private readonly Forms.NotifyIcon tray = new() { Icon = System.Drawing.SystemIcons.Application, Visible = true, Text = "NotchMuse" };
    private readonly DispatcherTimer frameTimer = new() { Interval = TimeSpan.FromMilliseconds(41) };
    private readonly DispatcherTimer fullscreenTimer = new() { Interval = TimeSpan.FromSeconds(2) };
    private CancellationTokenSource? lookup;
    private PlaybackSnapshot? snapshot;
    private HwndSource? source;
    private bool closed;
    private bool locked;
    private bool draggingProgress;
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
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    [StructLayout(LayoutKind.Sequential)] private readonly record struct RectNative(int Left, int Top, int Right, int Bottom);
    private enum DisplayMode { FreeFloat, TopIsland, Taskbar }

    public MainWindow()
    {
        InitializeComponent();
        engine = LyricsEngine.Create(client);
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
        try { await media.StartAsync(); } catch (Exception ex) when (ex is COMException or InvalidOperationException) { StatusLabel.Text = "系统播控暂不可用：" + ex.Message; }
    }

    private void ApplyTheme() => WorkspaceRoot.Background = SystemParameters.HighContrast ? System.Windows.Media.Brushes.Black : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(16, 16, 19));
    private void OnMediaError(string error) => Dispatcher.InvokeAsync(() => StatusLabel.Text = error);
    private void OnMediaChanged(PlaybackSnapshot? value) => Dispatcher.InvokeAsync(() => UpdateTrack(value));
    private async void UpdateTrack(PlaybackSnapshot? value)
    {
        if (closed) return;
        snapshot = value;
        TrackLabel.Text = value is null ? "等待播放音乐…" : value.Track.Title + " · " + value.Track.Artist;
        SidebarTrack.Text = value is null ? "等待播放音乐…" : value.Track.Title;
        PlayButton.Content = value?.Playing == true ? "暂停" : "播放";
        if (value is null) { LyricsItems.ItemsSource = null; StatusLabel.Text = "歌词跑丢了…"; return; }
        lookup?.Cancel(); lookup?.Dispose(); lookup = new(); var ct = lookup.Token;
        StatusLabel.Text = "正在寻找歌词…";
        try
        {
            var result = await engine.FindAsync(value.Track, ct);
            if (ct.IsCancellationRequested || closed) return;
            var winner = result.Decision.Winner;
            StatusLabel.Text = winner is null ? "歌词跑丢了…" : winner.Provider + " · " + result.Decision.Reason;
            LyricsItems.ItemsSource = winner?.Document.Normalized.Select(l => new LyricView(string.IsNullOrWhiteSpace(l.Text) ? "♪" : l.Text, l.Start)).ToArray();
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
            if (trayWindow != IntPtr.Zero && GetWindowRect(trayWindow, out var rect)) { Left = rect.Left + 12; Top = rect.Top - Height - 6; }
            else { Left = work.Left + 12; Top = work.Bottom - Height - 6; }
        }
        else if (mode == DisplayMode.TopIsland) { Left = work.Left + (work.Width - Width) / 2; Top = work.Top + 18; }
        else { Left = work.Left + (work.Width - Width) / 2; Top = work.Top + (work.Height - Height) / 2; }
    }
    private void HideForFullscreenIfNeeded()
    {
        if (mode == DisplayMode.FreeFloat || !IsVisible) return;
        var foreground = GetForegroundWindow(); if (foreground == IntPtr.Zero || foreground == windowHandle) return;
        if (!GetWindowRect(foreground, out var rect)) return;
        var work = SystemParameters.WorkArea;
        var fullscreen = rect.Left <= work.Left && rect.Top <= work.Top && rect.Right >= work.Right && rect.Bottom >= work.Bottom;
        if (fullscreen) Hide(); else if (!IsVisible) { Show(); PositionWindow(); }
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
        closed = true; lookup?.Cancel(); lookup?.Dispose(); frameTimer.Stop(); fullscreenTimer.Stop(); UnregisterHotKey(windowHandle, HotkeyId); source?.RemoveHook(WindowMessage); tray.Visible = false; tray.Dispose(); media.Changed -= OnMediaChanged; media.Error -= OnMediaError; media.Dispose(); client.Dispose(); SystemEvents.DisplaySettingsChanged -= (_, _) => { };
    }
}




