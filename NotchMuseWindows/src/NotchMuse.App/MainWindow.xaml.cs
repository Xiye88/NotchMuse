using System.Net.Http;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Interop;
using NotchMuse.Core;
using NotchMuse.Platform;
using NotchMuse.Sources;

namespace NotchMuse.App;
public partial class MainWindow : Window
{
    private readonly SmtcService media = new();
    private readonly HttpClient client = new(new HttpClientHandler { AutomaticDecompression = System.Net.DecompressionMethods.All }) { Timeout = TimeSpan.FromSeconds(12) };
    private readonly LyricsEngine engine;
    private CancellationTokenSource? lookup;
    private Track? lastTrack;
    private bool started;
    private bool closed;
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    public MainWindow()
    {
        InitializeComponent(); engine = LyricsEngine.Create(client);
        var profiles = new[] { new PlayerProfile("auto", "自动检测（推荐）", "顶部置顶", []), new PlayerProfile("all", "所有 Windows 系统播控应用", "顶部置顶", []) }.Concat(PlayerCatalog.Players);
        var view = new ListCollectionView(profiles.ToList()); view.GroupDescriptions.Add(new PropertyGroupDescription("Group"));
        SourcePicker.GroupStyle.Add(new GroupStyle { HeaderTemplate = (DataTemplate)System.Windows.Markup.XamlReader.Parse("<DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'><TextBlock Text='{Binding Name}' FontWeight='Bold' Margin='4,8,4,4'/></DataTemplate>") });
        SourcePicker.ItemsSource = view; SourcePicker.SelectedValue = "auto";
    }
    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        var dark = 1; DwmSetWindowAttribute(new WindowInteropHelper(this).Handle, 20, ref dark, sizeof(int));
        media.Changed += OnMediaChanged; media.Error += OnMediaError;
        try { await media.StartAsync(); started = true; }
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
            LyricsLabel.Text = result.Decision.Winner is { } c ? string.Join('\n', c.Document.Normalized.Select(l => l.Text)) :
                string.Join('\n', result.Sources.Select(s => s.Provider + ": " + s.Status + (s.Error is null ? "" : " · " + s.Error)));
        }
        catch (OperationCanceledException) { }
    }
    private async void OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    { if (started && SourcePicker.SelectedValue is string selection) await media.SelectAsync(selection); }
    private void OnClosed(object? sender, EventArgs e)
    { closed = true; lookup?.Cancel(); lookup?.Dispose(); media.Changed -= OnMediaChanged; media.Error -= OnMediaError; media.Dispose(); client.Dispose(); }
}
