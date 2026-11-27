using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using NotchMuse.App.Themes;
using Forms = System.Windows.Forms;

namespace NotchMuse.App.Overlays;

public partial class FloatingLyricsWindow : Window
{
    private const int GwlExStyle = -20;
    private const int WsExTransparent = 0x00000020;
    private const int WsExToolWindow = 0x00000080;
    private const int WsExNoActivate = 0x08000000;

    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);

    private IntPtr handle;
    private LyricsDisplayMode mode = LyricsDisplayMode.FreeFloat;
    private bool locked;
    private double sweepProgress;

    public event Action? LockToggled;
    public event Action? CycleModeRequested;
    public event Action? OpenAppearanceRequested;
    public event Action? OpenSettingsRequested;
    public event Action? HideRequested;
    public event Action<double, double>? PositionCommitted;

    public FloatingLyricsWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            ApplyWindowStyles();
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    public void ConfigureMode(LyricsDisplayMode nextMode, AppSettings settings)
    {
        mode = nextMode;
        locked = settings.OverlayLocked;
        ApplyWindowStyles();
        ApplyAppearance(settings);
        PositionOnScreen(settings);
    }

    public void SetLocked(bool value)
    {
        locked = value;
        ApplyWindowStyles();
        if (locked) HoverToolbar.Visibility = Visibility.Collapsed;
    }

    public void ApplyLanguage(bool english)
    {
        LockMiniBtn.Content = locked ? (english ? "Unlock" : "解锁") : (english ? "Lock" : "锁定");
        ModeMiniBtn.Content = english ? "Taskbar" : "任务栏";
        ThemeMiniBtn.Content = english ? "Style" : "配色";
        SettingsMiniBtn.Content = english ? "Settings" : "设置";
        HideMiniBtn.Content = english ? "Hide" : "隐藏";
    }

    public void ApplyAppearance(AppSettings settings)
    {
        var dark = ThemeManager.IsDarkActive || mode == LyricsDisplayMode.TopIsland;
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;

        var fontSize = mode == LyricsDisplayMode.TopIsland
            ? Math.Clamp(settings.FontSize * 0.78, 13, 20)
            : Math.Clamp(settings.FontSize, 14, 34);
        BaseLyricText.FontSize = fontSize;
        SweepLyricText.FontSize = fontSize;
        SubLyricText.FontSize = Math.Clamp(fontSize * 0.58, 10.5, 16);

        if (settings.BackgroundCapsuleEnabled || mode == LyricsDisplayMode.TopIsland)
        {
            LyricCapsule.CornerRadius = mode == LyricsDisplayMode.TopIsland
                ? new CornerRadius(0, 0, 16, 16)
                : new CornerRadius(18);
            LyricCapsule.Padding = mode == LyricsDisplayMode.TopIsland
                ? new Thickness(20, 7, 20, 8)
                : new Thickness(24, 11, 24, 11);
            LyricCapsule.Background = new SolidColorBrush(dark
                ? System.Windows.Media.Color.FromArgb(234, 21, 21, 26)
                : System.Windows.Media.Color.FromArgb(238, 250, 249, 246));
            LyricCapsule.BorderBrush = new SolidColorBrush(dark
                ? System.Windows.Media.Color.FromArgb(38, 255, 255, 255)
                : System.Windows.Media.Color.FromArgb(28, 0, 0, 0));
            LyricCapsule.BorderThickness = mode == LyricsDisplayMode.TopIsland
                ? new Thickness(1, 0, 1, 1)
                : new Thickness(1);
        }
        else
        {
            LyricCapsule.Background = System.Windows.Media.Brushes.Transparent;
            LyricCapsule.BorderBrush = System.Windows.Media.Brushes.Transparent;
            LyricCapsule.BorderThickness = new Thickness(0);
        }

        BaseLyricText.Foreground = new SolidColorBrush(dark
            ? System.Windows.Media.Color.FromArgb(118, 243, 242, 239)
            : System.Windows.Media.Color.FromArgb(128, 26, 26, 28));
        SubLyricText.Foreground = new SolidColorBrush(dark
            ? System.Windows.Media.Color.FromRgb(166, 166, 174)
            : System.Windows.Media.Color.FromRgb(110, 109, 104));

        Opacity = Math.Clamp(settings.LyricOpacity, 0.3, 1.0);
        ApplyLanguage(settings.EnglishLanguage);
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual)
    {
        var clean = string.IsNullOrWhiteSpace(primary) ? "♪" : primary.Trim();
        BaseLyricText.Text = clean;
        SweepLyricText.Text = clean;

        if (showBilingual && !string.IsNullOrWhiteSpace(translation))
        {
            SubLyricText.Text = translation.Trim();
            SubLyricText.Visibility = Visibility.Visible;
        }
        else
        {
            SubLyricText.Visibility = Visibility.Collapsed;
        }

        sweepProgress = Math.Clamp(progress, 0, 1);
        UpdateSweepClip();
    }

    public void ShowHoverToolbarForPreview(bool show)
    {
        HoverToolbar.Visibility = show && mode == LyricsDisplayMode.FreeFloat ? Visibility.Visible : Visibility.Collapsed;
    }

    public void PositionOnScreen(AppSettings settings)
    {
        var area = ResolveScreenWorkArea(settings.DisplayScreen);
        if (mode == LyricsDisplayMode.TopIsland)
        {
            OverlayStack.VerticalAlignment = VerticalAlignment.Top;
            Width = 540;
            Height = 76;
            Left = area.Left + (area.Width - Width) / 2;
            Top = area.Top;
            HoverToolbar.Visibility = Visibility.Collapsed;
            return;
        }

        OverlayStack.VerticalAlignment = VerticalAlignment.Center;
        Width = 680;
        Height = 128;
        if (settings.FloatingLeft.HasValue && settings.FloatingTop.HasValue)
        {
            Left = Math.Clamp(settings.FloatingLeft.Value, area.Left, Math.Max(area.Left, area.Right - Width));
            Top = Math.Clamp(settings.FloatingTop.Value, area.Top, Math.Max(area.Top, area.Bottom - Height));
        }
        else
        {
            Left = area.Left + (area.Width - Width) / 2;
            Top = area.Bottom - Height - 42;
        }
    }

    private static Rect ResolveScreenWorkArea(string deviceName)
    {
        var screen = Forms.Screen.AllScreens.FirstOrDefault(s =>
            string.Equals(s.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) ?? Forms.Screen.PrimaryScreen;
        if (screen is null) return SystemParameters.WorkArea;
        var dpiScale = VisualTreeHelper.GetDpi(System.Windows.Application.Current.MainWindow ?? new Window()).DpiScaleX;
        if (dpiScale <= 0) dpiScale = 1.0;
        var wa = screen.WorkingArea;
        return new Rect(wa.Left / dpiScale, wa.Top / dpiScale, wa.Width / dpiScale, wa.Height / dpiScale);
    }

    private void ApplyWindowStyles()
    {
        if (handle == IntPtr.Zero) return;
        var style = GetWindowLong(handle, GwlExStyle) | WsExToolWindow | WsExNoActivate;
        style = locked ? (style | WsExTransparent) : (style & ~WsExTransparent);
        SetWindowLong(handle, GwlExStyle, style);
    }

    private void UpdateSweepClip()
    {
        var width = SweepHost.ActualWidth;
        var height = SweepHost.ActualHeight;
        if (width <= 0)
        {
            SweepHost.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
            width = SweepHost.DesiredSize.Width;
            height = SweepHost.DesiredSize.Height;
        }
        SweepClip.Rect = new Rect(0, 0, Math.Max(0, width * sweepProgress), Math.Max(48, height + 8));
    }

    private void OnOverlayMouseEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (mode == LyricsDisplayMode.FreeFloat && !locked)
            HoverToolbar.Visibility = Visibility.Visible;
    }

    private void OnOverlayMouseLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        HoverToolbar.Visibility = Visibility.Collapsed;
    }

    private void OnCapsuleDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (locked || mode != LyricsDisplayMode.FreeFloat || e.LeftButton != System.Windows.Input.MouseButtonState.Pressed) return;
        SnapGuide.Visibility = Visibility.Visible;
        try { DragMove(); }
        finally { SnapGuide.Visibility = Visibility.Collapsed; }

        var work = SystemParameters.WorkArea;
        var center = work.Left + (work.Width - Width) / 2;
        if (Math.Abs(Left - center) <= 12) Left = center;
        Left = Math.Clamp(Left, work.Left, work.Right - Width);
        Top = Math.Clamp(Top, work.Top, work.Bottom - Height);
        PositionCommitted?.Invoke(Left, Top);
    }

    private void OnLockClick(object sender, RoutedEventArgs e) => LockToggled?.Invoke();
    private void OnCycleModeClick(object sender, RoutedEventArgs e) => CycleModeRequested?.Invoke();
    private void OnOpenAppearanceClick(object sender, RoutedEventArgs e) => OpenAppearanceRequested?.Invoke();
    private void OnOpenSettingsClick(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke();
    private void OnHideClick(object sender, RoutedEventArgs e) => HideRequested?.Invoke();
}
