using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using NotchMuse.App.Themes;

namespace NotchMuse.App.Overlays;

public partial class TaskbarLyricsWindow : Window
{
    private const uint SwpNoSize = 0x0001;
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoActivate = 0x0010;
    private static readonly IntPtr HwndTopmost = new(-1);

    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

    private bool isLightTaskbar = true;
    private bool doubleLineMode = true;
    private double sweepProgress;
    private double targetSurfaceOpacity = 1.0;
    private string rawPrimaryText = "NotchMuse";
    private string? rawTranslationText;
    private string? rawNextLineText;
    private bool showBilingualActive;
    private bool locked;
    private bool clickThroughDodged;
    private IntPtr handle;
    private HwndSource? hwndSource;
    private readonly DispatcherTimer lockedHoverTimer = new() { Interval = TimeSpan.FromMilliseconds(55) };

    public TaskbarSlot? CurrentSlot { get; private set; }
    public bool IsClickThroughDodged => clickThroughDodged;
    public event Action? OpenMainRequested;

    public TaskbarLyricsWindow()
    {
        InitializeComponent();
        lockedHoverTimer.Tick += OnLockedHoverTick;
        SourceInitialized += OnSourceInitialized;
        IsVisibleChanged += (_, _) =>
        {
            if (IsVisible)
            {
                ApplyWindowStyles();
                UpdateLockedHoverMonitor();
            }
            else
            {
                lockedHoverTimer.Stop();
                SetClickThroughDodge(false);
            }
        };
        Closed += (_, _) =>
        {
            lockedHoverTimer.Stop();
            hwndSource?.RemoveHook(WndProc);
            hwndSource = null;
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        handle = new WindowInteropHelper(this).Handle;
        if (handle != IntPtr.Zero && hwndSource is null)
        {
            hwndSource = HwndSource.FromHwnd(handle);
            hwndSource?.AddHook(WndProc);
        }
        ApplyWindowStyles();
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        var clickThrough = WindowClickThroughHelper.HandleClickThroughMessage(msg, locked, ref handled);
        if (handled) return clickThrough;

        if (msg == WindowClickThroughHelper.WmMouseActivate)
        {
            handled = true;
            return WindowClickThroughHelper.MaNoActivate;
        }
        return IntPtr.Zero;
    }

    private static readonly SolidColorBrush UnlockedHitBrush = new(System.Windows.Media.Color.FromArgb(6, 0, 0, 0));

    public void SetLocked(bool value)
    {
        locked = value;
        RootSurface.IsHitTestVisible = !locked;
        RootSurface.Background = locked ? System.Windows.Media.Brushes.Transparent : UnlockedHitBrush;
        ApplyWindowStyles();
        UpdateLockedHoverMonitor();
    }

    private void UpdateLockedHoverMonitor()
    {
        if (locked && IsVisible)
        {
            if (!lockedHoverTimer.IsEnabled) lockedHoverTimer.Start();
        }
        else
        {
            lockedHoverTimer.Stop();
            SetClickThroughDodge(false);
        }
    }

    private void OnLockedHoverTick(object? sender, EventArgs e)
    {
        if (!locked || !IsVisible)
        {
            lockedHoverTimer.Stop();
            SetClickThroughDodge(false);
            return;
        }
        if (!WindowClickThroughHelper.GetCursorPos(out var pt)) return;
        var currentHandle = handle != IntPtr.Zero ? handle : new WindowInteropHelper(this).Handle;
        if (currentHandle == IntPtr.Zero || !WindowClickThroughHelper.GetWindowRect(currentHandle, out var rect)) return;
        var inside = pt.X >= rect.Left - 4 && pt.X <= rect.Right + 4 && pt.Y >= rect.Top - 2 && pt.Y <= rect.Bottom + 2;
        SetClickThroughDodge(inside);
    }

    private void SetClickThroughDodge(bool dodge)
    {
        if (clickThroughDodged == dodge) return;
        clickThroughDodged = dodge;
        var target = dodge ? 0.0 : targetSurfaceOpacity;
        if (InteractionMotion.AnimationsAllowed)
        {
            var anim = new DoubleAnimation(target, TimeSpan.FromMilliseconds(dodge ? 100 : 160))
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
            RootSurface.BeginAnimation(OpacityProperty, anim);
        }
        else
        {
            RootSurface.BeginAnimation(OpacityProperty, null);
            RootSurface.Opacity = target;
        }
    }

    private void ApplyWindowStyles()
    {
        var currentHandle = handle != IntPtr.Zero ? handle : new WindowInteropHelper(this).Handle;
        if (currentHandle == IntPtr.Zero) return;
        handle = currentHandle;
        WindowClickThroughHelper.ApplyClickThrough(handle, locked);
    }

    public void Reposition()
    {
        var slot = TaskbarLocator.Locate();
        CurrentSlot = slot;
        Left = slot.Left;
        Top = slot.Top;
        Width = slot.Width;
        Height = slot.Height;
        ApplyTaskbarTheme(slot.IsLightTaskbar);
        EnsureTopmostAboveTaskbar();
    }

    public void EnsureTopmostAboveTaskbar()
    {
        if (handle == IntPtr.Zero || !IsVisible) return;
        SetWindowPos(handle, HwndTopmost, 0, 0, 0, 0, SwpNoMove | SwpNoSize | SwpNoActivate);
    }

    public void ApplyTaskbarTheme(bool lightTaskbar)
    {
        isLightTaskbar = lightTaskbar;
        var primary = lightTaskbar
            ? System.Windows.Media.Color.FromRgb(28, 28, 32)
            : System.Windows.Media.Color.FromRgb(243, 242, 239);
        var secondary = lightTaskbar
            ? System.Windows.Media.Color.FromRgb(102, 100, 94)
            : System.Windows.Media.Color.FromRgb(166, 166, 174);

        BaseLyricText.Foreground = new SolidColorBrush(System.Windows.Media.Color.FromArgb(170, primary.R, primary.G, primary.B));
        SubLyricText.Foreground = new SolidColorBrush(secondary);
    }

    public void UpdateAppearance(AppSettings settings)
    {
        doubleLineMode = settings.FloatingDoubleLine;
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;
        NoteGlyph.Foreground = accentBrush;
        var accentColor = ThemeManager.ParseColor(settings.AccentHex, System.Windows.Media.Color.FromRgb(224, 109, 27));
        NotePill.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(isLightTaskbar ? (byte)32 : (byte)42, accentColor.R, accentColor.G, accentColor.B));

        // Scale nicely inside 48px taskbar height (compact 2-line fit when Double-Line is enabled)
        var primarySize = doubleLineMode
            ? Math.Clamp(settings.FontSize * 0.56, 11.5, 13.5)
            : Math.Clamp(settings.FontSize * 0.64, 12.5, 16.0);
        BaseLyricText.FontSize = primarySize;
        SweepLyricText.FontSize = primarySize;
        SubLyricText.FontSize = Math.Clamp(primarySize - 2.6, 9.5, 10.8);
        targetSurfaceOpacity = Math.Clamp(settings.LyricOpacity, 0.35, 1.0);
        if (!clickThroughDodged)
        {
            RootSurface.BeginAnimation(OpacityProperty, null);
            RootSurface.Opacity = targetSurfaceOpacity;
        }
        ApplySecondaryLine();
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual, string? nextLine = null)
    {
        rawPrimaryText = string.IsNullOrWhiteSpace(primary) ? "NotchMuse" : primary.Trim();
        rawTranslationText = string.IsNullOrWhiteSpace(translation) ? null : translation.Trim();
        rawNextLineText = string.IsNullOrWhiteSpace(nextLine) ? null : nextLine.Trim();
        showBilingualActive = showBilingual;

        if (BaseLyricText.Text != rawPrimaryText)
        {
            BaseLyricText.Text = rawPrimaryText;
            SweepLyricText.Text = rawPrimaryText;
        }

        ApplySecondaryLine();
        sweepProgress = Math.Clamp(progress, 0, 1);
        UpdateSweepClip();
    }

    private void ApplySecondaryLine()
    {
        if (doubleLineMode)
        {
            var second = (showBilingualActive && !string.IsNullOrWhiteSpace(rawTranslationText))
                ? rawTranslationText
                : rawNextLineText;
            if (!string.IsNullOrWhiteSpace(second))
            {
                SubLyricText.Text = second;
                SubLyricText.Visibility = Visibility.Visible;
            }
            else
            {
                SubLyricText.Visibility = Visibility.Collapsed;
            }
        }
        else if (showBilingualActive && !string.IsNullOrWhiteSpace(rawTranslationText))
        {
            SubLyricText.Text = rawTranslationText;
            SubLyricText.Visibility = Visibility.Visible;
        }
        else
        {
            SubLyricText.Visibility = Visibility.Collapsed;
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
        SweepClip.Rect = new Rect(0, 0, Math.Max(0, width * sweepProgress), Math.Max(28, height + 6));
    }

    private void OnSurfaceEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (locked) return;
        RootSurface.Background = new SolidColorBrush(isLightTaskbar
            ? System.Windows.Media.Color.FromArgb(20, 0, 0, 0)
            : System.Windows.Media.Color.FromArgb(24, 255, 255, 255));
    }

    private void OnSurfaceLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        RootSurface.Background = locked ? System.Windows.Media.Brushes.Transparent : UnlockedHitBrush;
    }

    private void OnSurfaceClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (locked) return;
        OpenMainRequested?.Invoke();
    }
}
