using System.Net.Http;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using NotchMuse.Core;
using NotchMuse.Platform;
using NotchMuse.Sources;
using Forms = System.Windows.Forms;

namespace NotchMuse.App;
public partial class MainWindow : Window
{
    private readonly SmtcService media = new();
    private readonly HttpClient client = new(new HttpClientHandler { AutomaticDecompression = System.Net.DecompressionMethods.All }) { Timeout = TimeSpan.FromSeconds(12) };
    private readonly LyricsEngine engine;
    private CancellationTokenSource? lookup;
    private Track? lastTrack;
    private bool closed;
    private bool locked;
    private readonly Forms.NotifyIcon tray = new() { Icon = System.Drawing.SystemIcons.Application, Visible = true, Text = "NotchMuse" };
    private HwndSource? source;
    private const int HotkeyId = 0x4E4D;
    private const uint ModAlt = 0x0001;
    private const uint ModControl = 0x0002;
    private const uint WmHotkey = 0x0312;
    private const int GwlExstyle = -20;
    private const int WsExTransparent = 0x20;
    private const int WsExLayered = 0x80000;
    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    public MainWindow()
    {
        InitializeComponent(); engine = LyricsEngine.Create(client);
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("自由悬浮", null, (_, _) => Show());
        menu.Items.Add("顶部悬浮岛", null, (_, _) => MoveToTopIsland());
        menu.Items.Add("锁定穿透", null, (_, _) => ToggleLock());
        menu.Items.Add("打开主窗口", null, (_, _) => { Show(); Activate(); });
        menu.Items.Add("退出", null, (_, _) => Close());
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => { Show(); Activate(); };
    }
    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        var handle = new WindowInteropHelper(this).Handle;
        var dark = 1; DwmSetWindowAttribute(handle, 20, ref dark, sizeof(int));
        source = HwndSource.FromHwnd(handle); source?.AddHook(WindowMessage);
        RegisterHotKey(handle, HotkeyId, ModControl | ModAlt, (uint)System.Windows.Forms.Keys.L);
        media.Changed += OnMediaChanged; media.Error += OnMediaError;
        try { await media.StartAsync(); }
        catch (Exception ex) when (ex is COMException or InvalidOperationException) { StatusLabel.Text = "系统播控暂不可用：" + ex.Message; }
    }
    private void OnMediaError(string error) => Dispatcher.InvokeAsync(() => StatusLabel.Text = error);
    private void OnMediaChanged(PlaybackSnapshot? snapshot) => Dispatcher.InvokeAsync(() => UpdateTrack(snapshot));
    private async void UpdateTrack(PlaybackSnapshot? snapshot)
    {
        if (closed) return;
        TrackLabel.Text = snapshot is null ? "等待播放音乐…" : snapshot.Track.Title + " · " + snapshot.Track.Artist;
        if (snapshot?.Track == lastTrack) return;
        lastTrack = snapshot?.Track; lookup?.Cancel(); lookup?.Dispose(); lookup = new(); var ct = lookup.Token;
        LyricsLabel.Text = "";
        if (snapshot is null) { StatusLabel.Text = "等待音乐播放器连接"; return; }
        if (snapshot.Track.Duration <= 0) { StatusLabel.Text = "等待播放器提供歌曲时长…"; return; }
        StatusLabel.Text = "正在声波雷达里搜寻这首歌的词…";
        try
        {
            var result = await engine.FindAsync(snapshot.Track, ct);
            if (ct.IsCancellationRequested || closed) return;
            StatusLabel.Text = result.Decision.Winner is { } winner ? winner.Provider + " · " + result.Decision.Reason : "歌词跑丢了，正在黑胶纹路里打捞…";
            LyricsLabel.Text = result.Decision.Winner is { } c ? c.Document.Normalized.FirstOrDefault()?.Text ?? "歌词跑丢了…" : "歌词跑丢了…";
        }
        catch (OperationCanceledException) { }
    }
    private void OnDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    { if (!locked) DragMove(); }
    private void OnLockClick(object sender, RoutedEventArgs e) => ToggleLock();
    private void OnSettingsClick(object sender, RoutedEventArgs e) { Show(); Activate(); }
    private void OnHideClick(object sender, RoutedEventArgs e) => Hide();
    private void ToggleLock()
    {
        locked = !locked; LockButton.Content = locked ? "解锁" : "锁定";
        var handle = new WindowInteropHelper(this).Handle;
        var style = GetWindowLong(handle, GwlExstyle);
        style |= WsExLayered;
        if (locked) style |= WsExTransparent; else style &= ~WsExTransparent;
        SetWindowLong(handle, GwlExstyle, style);
        Capsule.BorderBrush = locked ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(0x55, 0xFF, 0xB1, 0x5A)) : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(0x33, 0xF5, 0xA6, 0x23));
    }
    private void MoveToTopIsland()
    {
        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = SystemParameters.WorkArea.Left + (SystemParameters.WorkArea.Width - Width) / 2;
        Top = SystemParameters.WorkArea.Top + 18;
        Show(); Activate();
    }
    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WmHotkey && wParam.ToInt32() == HotkeyId) { ToggleLock(); handled = true; }
        return IntPtr.Zero;
    }
    private void OnClosed(object? sender, EventArgs e)
    { closed = true; lookup?.Cancel(); lookup?.Dispose(); var handle = new WindowInteropHelper(this).Handle; UnregisterHotKey(handle, HotkeyId); source?.RemoveHook(WindowMessage); tray.Visible = false; tray.Dispose(); media.Changed -= OnMediaChanged; media.Error -= OnMediaError; media.Dispose(); client.Dispose(); }
}
