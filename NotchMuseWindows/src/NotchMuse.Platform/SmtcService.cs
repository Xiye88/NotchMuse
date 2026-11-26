using NotchMuse.Core;
using Windows.Media.Control;

namespace NotchMuse.Platform;

public sealed record PlaybackSnapshot(string AppId, Track Track, bool Playing, double Position, DateTimeOffset CapturedAt, double Rate);
public sealed class SmtcService : IDisposable
{
    private GlobalSystemMediaTransportControlsSessionManager? manager;
    private GlobalSystemMediaTransportControlsSession? active;
    private readonly HashSet<GlobalSystemMediaTransportControlsSession> observed = [];
    private long generation;
    private bool disposed;
    public string Selection { get; private set; } = "auto";
    public PlaybackSnapshot? Current { get; private set; }
    public event Action<PlaybackSnapshot?>? Changed;
    public event Action<string>? Error;

    public async Task StartAsync()
    {
        manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
        manager.SessionsChanged += SessionsChanged; manager.CurrentSessionChanged += CurrentSessionChanged;
        RefreshSessions(); await RefreshAsync();
    }
    public async Task SelectAsync(string selection) { Selection = selection; await RefreshAsync(); }
    private void RefreshSessions()
    {
        if (manager is null) return;
        var sessions = manager.GetSessions().ToHashSet();
        foreach (var old in observed.Where(s => !sessions.Contains(s)).ToArray()) { Unsubscribe(old); observed.Remove(old); }
        foreach (var session in sessions.Where(s => !observed.Contains(s)))
        {
            observed.Add(session); session.MediaPropertiesChanged += MediaChanged;
            session.PlaybackInfoChanged += PlaybackChanged; session.TimelinePropertiesChanged += TimelineChanged;
        }
    }
    private async void SessionsChanged(GlobalSystemMediaTransportControlsSessionManager sender, SessionsChangedEventArgs args)
    { RefreshSessions(); await SafeRefresh(); }
    private async void CurrentSessionChanged(GlobalSystemMediaTransportControlsSessionManager sender, CurrentSessionChangedEventArgs args) => await SafeRefresh();
    private async void MediaChanged(GlobalSystemMediaTransportControlsSession sender, MediaPropertiesChangedEventArgs args) => await SafeRefresh();
    private async void PlaybackChanged(GlobalSystemMediaTransportControlsSession sender, PlaybackInfoChangedEventArgs args) => await SafeRefresh();
    private async void TimelineChanged(GlobalSystemMediaTransportControlsSession sender, TimelinePropertiesChangedEventArgs args) => await SafeRefresh();
    private async Task SafeRefresh()
    {
        try { await RefreshAsync(); }
        catch (Exception e) when (e is System.Runtime.InteropServices.COMException or InvalidOperationException) { Error?.Invoke(e.Message); }
    }
    private async Task RefreshAsync()
    {
        if (manager is null || disposed) return;
        var request = Interlocked.Increment(ref generation);
        var preferred = manager.GetCurrentSession();
        var ordered = manager.GetSessions().OrderByDescending(s => s.GetPlaybackInfo().PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing)
            .ThenByDescending(s => s == preferred).ToArray();
        foreach (var session in ordered)
        {
            if (PlayerCatalog.IsBlacklisted(session.SourceAppUserModelId)) continue;
            var props = await session.TryGetMediaPropertiesAsync();
            if (request != Interlocked.Read(ref generation) || disposed) return;
            if (!PlayerCatalog.Allows(session.SourceAppUserModelId, props.Title, Selection)) continue;
            var timeline = session.GetTimelineProperties(); var playback = session.GetPlaybackInfo();
            var profile = PlayerCatalog.Identify(session.SourceAppUserModelId);
            var track = MediaMetadataSanitizer.Clean(new(props.Title, props.Artist, props.AlbumTitle,
                (timeline.EndTime - timeline.StartTime).TotalSeconds, Platform: profile?.Id ?? "unknown"), Selection == "all");
            if (string.IsNullOrWhiteSpace(track.Title)) continue;
            active = session;
            Current = new(session.SourceAppUserModelId, track, playback.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing,
                (timeline.Position - timeline.StartTime).TotalSeconds, DateTimeOffset.UtcNow, playback.PlaybackRate ?? 1);
            Changed?.Invoke(Current); return;
        }
        active = null; Current = null; Changed?.Invoke(null);
    }
    public async Task<bool> SeekAsync(double seconds)
    {
        var session = active;
        if (session is null || !session.GetPlaybackInfo().Controls.IsPlaybackPositionEnabled || !double.IsFinite(seconds)) return false;
        try { return await session.TryChangePlaybackPositionAsync(session.GetTimelineProperties().StartTime.Ticks + TimeSpan.FromSeconds(Math.Max(0, seconds)).Ticks); }
        catch (System.Runtime.InteropServices.COMException) { return false; }
    }
    public async Task<bool> ToggleAsync() => active is not null && await active.TryTogglePlayPauseAsync();
    public async Task<bool> PreviousAsync() => active is not null && await active.TrySkipPreviousAsync();
    public async Task<bool> NextAsync() => active is not null && await active.TrySkipNextAsync();
    private void Unsubscribe(GlobalSystemMediaTransportControlsSession s)
    { s.MediaPropertiesChanged -= MediaChanged; s.PlaybackInfoChanged -= PlaybackChanged; s.TimelinePropertiesChanged -= TimelineChanged; }
    public void Dispose()
    {
        disposed = true; Interlocked.Increment(ref generation);
        if (manager is not null) { manager.SessionsChanged -= SessionsChanged; manager.CurrentSessionChanged -= CurrentSessionChanged; }
        foreach (var session in observed) Unsubscribe(session);
        observed.Clear(); active = null; manager = null;
    }
}
