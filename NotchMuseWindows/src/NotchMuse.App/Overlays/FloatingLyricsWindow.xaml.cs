using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;
using NotchMuse.App.Themes;
using Forms = System.Windows.Forms;

namespace NotchMuse.App.Overlays;

public partial class FloatingLyricsWindow : Window
{
    private const double MagneticSnapThresholdDip = 10.0;

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out NativePoint pt);

    [StructLayout(LayoutKind.Sequential)]
    private readonly record struct NativePoint(int X, int Y);

    private IntPtr handle;
    private LyricsDisplayMode mode = LyricsDisplayMode.FreeFloat;
    private AppSettings? activeSettings;
    private bool locked;
    private bool hovered;
    private bool dragging;
    private double sweepProgress;
    private NativePoint dragStartCursorPx;
    private double dragStartLeft;
    private double dragStartTop;
    private double dragDpiScale = 1.0;
    private System.Windows.Media.Brush idleBorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(46, 255, 255, 255));
    private Thickness idleBorderThickness = new(1);

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
            ApplyClickThroughStyle();
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    public IntPtr WindowHandle => handle;

    public void ConfigureMode(LyricsDisplayMode nextMode, AppSettings settings)
    {
        mode = nextMode;
        activeSettings = settings;
        locked = settings.OverlayLocked;
        ApplyClickThroughStyle();
        ApplyAppearance(settings);
        PositionOnScreen(settings);
    }

    public void SetLocked(bool value)
    {
        locked = value;
        if (locked)
        {
            EndDrag(commit: false);
            hovered = false;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
        }
        ApplyClickThroughStyle();
        if (activeSettings is not null) ApplyAppearance(activeSettings);
        UpdateHoverChrome();
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
        activeSettings = settings;
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;

        var fontSize = mode == LyricsDisplayMode.TopIsland
            ? Math.Clamp(settings.FontSize * 0.78, 13, 20)
            : Math.Clamp(settings.FontSize, 14, 34);
        BaseLyricText.FontSize = fontSize;
        SweepLyricText.FontSize = fontSize;
        OutlineLyricText.FontSize = fontSize;
        SubLyricText.FontSize = Math.Clamp(fontSize * 0.58, 10.5, 16);

        var preset = settings.CapsulePreset;
        if (mode == LyricsDisplayMode.TopIsland && preset == CapsuleBackgroundPreset.Transparent)
        {
            // Top Island always retains a sleek subtle pill so it anchors neatly to the screen edge
            preset = CapsuleBackgroundPreset.SoftGray;
        }

        var isTransparentMode = preset == CapsuleBackgroundPreset.Transparent;
        var bgOpacity = Math.Clamp(settings.CapsuleBackgroundOpacity, 0.30, 1.0);

        LyricCapsule.CornerRadius = mode == LyricsDisplayMode.TopIsland
            ? new CornerRadius(0, 0, 16, 16)
            : new CornerRadius(18);
        LyricCapsule.Padding = mode == LyricsDisplayMode.TopIsland
            ? new Thickness(22, 8, 22, 9)
            : new Thickness(24, 11, 24, 11);

        if (isTransparentMode)
        {
            // Critical Win32 HitTest guarantee: #01000000 is visually invisible yet 100% catches mouse hover/drag when unlocked!
            LyricCapsule.Background = new SolidColorBrush(locked
                ? System.Windows.Media.Color.FromArgb(0, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(1, 0, 0, 0));
            idleBorderBrush = System.Windows.Media.Brushes.Transparent;
            idleBorderThickness = new Thickness(1);
            CapsuleShadow.Opacity = 0;

            // Dual-layer crisp dark halo outline so transparent lyrics stay super legible on any wallpaper
            OutlineLyricText.Visibility = Visibility.Visible;
            BaseLyricText.Foreground = new SolidColorBrush(System.Windows.Media.Color.FromArgb(228, 248, 247, 244));
            SubLyricText.Foreground = new SolidColorBrush(System.Windows.Media.Color.FromArgb(236, 238, 236, 232));
            SubLyricText.Effect = new DropShadowEffect { Color = Colors.Black, BlurRadius = 5, ShadowDepth = 0, Opacity = 0.90 };
            SweepLyricText.Effect = new DropShadowEffect { Color = Colors.Black, BlurRadius = 4, ShadowDepth = 0, Opacity = 0.72 };
        }
        else
        {
            var baseHex = preset == CapsuleBackgroundPreset.Custom
                ? settings.CapsuleCustomHex
                : AppSettings.GetCapsulePresetDefaults(preset).Hex;
            var baseRgb = ThemeManager.ParseColor(baseHex, System.Windows.Media.Color.FromRgb(62, 62, 68));
            var alphaByte = (byte)Math.Clamp(Math.Round(bgOpacity * 255), 76, 255);
            var isLightCapsule = (baseRgb.R * 0.299 + baseRgb.G * 0.587 + baseRgb.B * 0.114) > 165;

            LyricCapsule.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(alphaByte, baseRgb.R, baseRgb.G, baseRgb.B));
            idleBorderBrush = new SolidColorBrush(isLightCapsule
                ? System.Windows.Media.Color.FromArgb(34, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(44, 255, 255, 255));
            idleBorderThickness = mode == LyricsDisplayMode.TopIsland
                ? new Thickness(1, 0, 1, 1)
                : new Thickness(1);
            CapsuleShadow.Opacity = isLightCapsule ? 0.20 : 0.34;

            OutlineLyricText.Visibility = Visibility.Collapsed;
            BaseLyricText.Foreground = new SolidColorBrush(isLightCapsule
                ? System.Windows.Media.Color.FromArgb(148, 26, 26, 28)
                : System.Windows.Media.Color.FromArgb(148, 245, 244, 240));
            SubLyricText.Foreground = new SolidColorBrush(isLightCapsule
                ? System.Windows.Media.Color.FromRgb(94, 92, 86)
                : System.Windows.Media.Color.FromRgb(186, 185, 190));
            SubLyricText.Effect = null;
            SweepLyricText.Effect = null;
        }

        LyricCapsule.Cursor = (mode == LyricsDisplayMode.FreeFloat && !locked)
            ? System.Windows.Input.Cursors.SizeAll
            : System.Windows.Input.Cursors.Arrow;

        Opacity = Math.Clamp(settings.LyricOpacity, 0.3, 1.0);
        ApplyLanguage(settings.EnglishLanguage);
        UpdateHoverChrome();
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual)
    {
        var clean = string.IsNullOrWhiteSpace(primary) ? "♪" : primary.Trim();
        BaseLyricText.Text = clean;
        SweepLyricText.Text = clean;
        OutlineLyricText.Text = clean;

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
        hovered = show && mode == LyricsDisplayMode.FreeFloat && !locked;
        HoverToolbarHost.Visibility = hovered ? Visibility.Visible : Visibility.Collapsed;
        UpdateHoverChrome();
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
            HoverToolbarHost.Visibility = Visibility.Collapsed;
            return;
        }

        OverlayStack.VerticalAlignment = VerticalAlignment.Center;
        Width = 680;
        Height = 132;
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

    private Rect ResolveScreenWorkArea(string deviceName)
    {
        var screen = Forms.Screen.AllScreens.FirstOrDefault(s =>
            string.Equals(s.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) ?? Forms.Screen.PrimaryScreen;
        if (screen is null) return SystemParameters.WorkArea;
        var dpiScale = VisualTreeHelper.GetDpi(this).DpiScaleX;
        if (dpiScale <= 0) dpiScale = 1.0;
        var wa = screen.WorkingArea;
        return new Rect(wa.Left / dpiScale, wa.Top / dpiScale, wa.Width / dpiScale, wa.Height / dpiScale);
    }

    private void ApplyClickThroughStyle()
    {
        if (handle == IntPtr.Zero) return;
        WindowClickThroughHelper.ApplyClickThrough(handle, locked);
    }

    private void UpdateHoverChrome()
    {
        var showGlow = (hovered || dragging) && mode == LyricsDisplayMode.FreeFloat && !locked;
        if (showGlow)
        {
            LyricCapsule.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(215, 255, 138, 54));
            LyricCapsule.BorderThickness = new Thickness(1);
        }
        else
        {
            LyricCapsule.BorderBrush = idleBorderBrush;
            LyricCapsule.BorderThickness = idleBorderThickness;
        }
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
        if (mode != LyricsDisplayMode.FreeFloat || locked) return;
        hovered = true;
        HoverToolbarHost.Visibility = Visibility.Visible;
        UpdateHoverChrome();
    }

    private void OnOverlayMouseLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (dragging) return;
        hovered = false;
        HoverToolbarHost.Visibility = Visibility.Collapsed;
        UpdateHoverChrome();
    }

    private void OnCapsuleMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (locked || mode != LyricsDisplayMode.FreeFloat || e.LeftButton != MouseButtonState.Pressed) return;
        if (!GetCursorPos(out dragStartCursorPx)) return;

        dragDpiScale = VisualTreeHelper.GetDpi(this).DpiScaleX;
        if (dragDpiScale <= 0) dragDpiScale = 1.0;

        dragStartLeft = Left;
        dragStartTop = Top;
        dragging = true;
        LyricCapsule.CaptureMouse();
        UpdateHoverChrome();
        e.Handled = true;
    }

    private void OnCapsuleMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (!dragging) return;
        if (e.LeftButton != MouseButtonState.Pressed)
        {
            EndDrag(commit: true);
            return;
        }
        if (!GetCursorPos(out var nowPx)) return;

        var dx = (nowPx.X - dragStartCursorPx.X) / dragDpiScale;
        var dy = (nowPx.Y - dragStartCursorPx.Y) / dragDpiScale;

        var work = ResolveScreenWorkArea(activeSettings?.DisplayScreen ?? "Primary");
        var nextLeft = dragStartLeft + dx;
        var nextTop = dragStartTop + dy;

        var altBypass = Keyboard.Modifiers.HasFlag(ModifierKeys.Alt);
        var centerLeft = work.Left + (work.Width - Width) / 2;
        if (!altBypass && Math.Abs(nextLeft - centerLeft) <= MagneticSnapThresholdDip)
        {
            nextLeft = centerLeft;
            SnapGuide.Visibility = Visibility.Visible;
        }
        else
        {
            SnapGuide.Visibility = Visibility.Collapsed;
        }

        Left = Math.Clamp(nextLeft, work.Left, Math.Max(work.Left, work.Right - Width));
        Top = Math.Clamp(nextTop, work.Top, Math.Max(work.Top, work.Bottom - Height));
        e.Handled = true;
    }

    private void OnCapsuleMouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!dragging) return;
        EndDrag(commit: true);
        e.Handled = true;
    }

    private void OnCapsuleLostCapture(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (!dragging) return;
        EndDrag(commit: true);
    }

    private void EndDrag(bool commit)
    {
        dragging = false;
        SnapGuide.Visibility = Visibility.Collapsed;
        if (LyricCapsule.IsMouseCaptured) LyricCapsule.ReleaseMouseCapture();
        if (commit) PositionCommitted?.Invoke(Left, Top);
        if (!IsMouseOver)
        {
            hovered = false;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
        }
        UpdateHoverChrome();
    }

    private void OnLockClick(object sender, RoutedEventArgs e) => LockToggled?.Invoke();
    private void OnCycleModeClick(object sender, RoutedEventArgs e) => CycleModeRequested?.Invoke();
    private void OnOpenAppearanceClick(object sender, RoutedEventArgs e) => OpenAppearanceRequested?.Invoke();
    private void OnOpenSettingsClick(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke();
    private void OnHideClick(object sender, RoutedEventArgs e) => HideRequested?.Invoke();
}
