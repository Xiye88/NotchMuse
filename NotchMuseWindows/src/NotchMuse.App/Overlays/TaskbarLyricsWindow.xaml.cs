using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using NotchMuse.App.Themes;

namespace NotchMuse.App.Overlays;

public partial class TaskbarLyricsWindow : Window
{
    private const int GwlExStyle = -20;
    private const int WsExTransparent = 0x00000020;
    private const int WsExToolWindow = 0x00000080;
    private const int WsExNoActivate = 0x08000000;
    private const uint SwpNoSize = 0x0001;
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoActivate = 0x0010;
    private static readonly IntPtr HwndTopmost = new(-1);

    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

    private bool isLightTaskbar = true;
    private double sweepProgress;
    private bool locked;
    private IntPtr handle;

    public TaskbarSlot? CurrentSlot { get; private set; }
    public event Action? OpenMainRequested;

    public TaskbarLyricsWindow()
    {
        InitializeComponent();
        SourceInitialized += OnSourceInitialized;
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        handle = new WindowInteropHelper(this).Handle;
        ApplyWindowStyles();
    }

    public void SetLocked(bool value)
    {
        locked = value;
        ApplyWindowStyles();
    }

    private void ApplyWindowStyles()
    {
        if (handle == IntPtr.Zero) return;
        var style = GetWindowLong(handle, GwlExStyle) | WsExToolWindow | WsExNoActivate;
        style = locked ? (style | WsExTransparent) : (style & ~WsExTransparent);
        SetWindowLong(handle, GwlExStyle, style);
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
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;
        NoteGlyph.Foreground = accentBrush;
        var accentColor = ThemeManager.ParseColor(settings.AccentHex, System.Windows.Media.Color.FromRgb(224, 109, 27));
        NotePill.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(isLightTaskbar ? (byte)32 : (byte)42, accentColor.R, accentColor.G, accentColor.B));

        // Scale nicely inside 48px taskbar height
        var primarySize = Math.Clamp(settings.FontSize * 0.62, 12.0, 16.0);
        BaseLyricText.FontSize = primarySize;
        SweepLyricText.FontSize = primarySize;
        SubLyricText.FontSize = Math.Clamp(primarySize - 3.0, 9.5, 11.5);
        RootSurface.Opacity = Math.Clamp(settings.LyricOpacity, 0.35, 1.0);
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual)
    {
        var clean = string.IsNullOrWhiteSpace(primary) ? "NotchMuse" : primary.Trim();
        if (BaseLyricText.Text != clean)
        {
            BaseLyricText.Text = clean;
            SweepLyricText.Text = clean;
        }

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
        RootSurface.Background = new SolidColorBrush(isLightTaskbar
            ? System.Windows.Media.Color.FromArgb(20, 0, 0, 0)
            : System.Windows.Media.Color.FromArgb(24, 255, 255, 255));
    }

    private void OnSurfaceLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        RootSurface.Background = System.Windows.Media.Brushes.Transparent;
    }

    private void OnSurfaceClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        OpenMainRequested?.Invoke();
    }
}
