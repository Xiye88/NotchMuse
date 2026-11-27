using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
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
    private const double TopEdgeFlipThresholdDip = 72.0;

    private static readonly (string NameZh, string NameEn, string Hex)[] QuickPalette =
    [
        ("纯白", "Pure White", "#FFFFFF"),
        ("暖琥珀", "Warm Amber", "#FF8A36"),
        ("天青蓝", "Sky Cyan", "#38BDF8"),
        ("翡翠绿", "Emerald", "#34D399"),
        ("樱花粉", "Sakura Pink", "#F472B6"),
        ("柔紫", "Soft Violet", "#A78BFA"),
        ("墨黑", "Ink Black", "#1C1C20")
    ];

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
    private bool verticalLayout;
    private bool isTransparentCapsule;
    private bool toolbarFlippedBelow;
    private double sweepProgress;
    private string rawPrimaryText = "等待播放音乐…";
    private string? rawTranslationText;
    private bool showBilingualActive;
    private NativePoint dragStartCursorPx;
    private double dragStartLeft;
    private double dragStartTop;
    private double dragDpiScale = 1.0;
    private System.Windows.Media.Brush idleBackgroundBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(209, 62, 62, 68));
    private System.Windows.Media.Brush idleBorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(46, 255, 255, 255));
    private Thickness idleBorderThickness = new(1);

    public event Action? LockToggled;
    public event Action<bool>? OrientationToggled;
    public event Action<string>? QuickColorSelected;
    public event Action? OpenMainRequested;
    public event Action? OpenSettingsRequested;
    public event Action? HideRequested;
    public event Action<double, double>? PositionCommitted;

    public FloatingLyricsWindow()
    {
        InitializeComponent();
        BuildQuickColorDots();
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            ApplyClickThroughStyle();
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    public IntPtr WindowHandle => handle;
    public bool IsToolbarFlippedBelow => toolbarFlippedBelow;
    public bool IsQuickColorPopoverOpen => QuickColorPopover.Visibility == Visibility.Visible;

    private void BuildQuickColorDots()
    {
        QuickColorDotsHost.Children.Clear();
        var en = activeSettings?.EnglishLanguage == true;
        foreach (var item in QuickPalette)
        {
            var color = ThemeManager.ParseColor(item.Hex, Colors.White);
            var btn = new System.Windows.Controls.Button
            {
                Style = (Style)FindResource("FloatingColorDot"),
                Background = new SolidColorBrush(color),
                ToolTip = en ? item.NameEn : item.NameZh,
                Tag = activeSettings is not null && string.Equals(activeSettings.AccentHex, item.Hex, StringComparison.OrdinalIgnoreCase)
                    ? "Selected"
                    : null
            };
            var hex = item.Hex;
            btn.Click += (_, _) =>
            {
                QuickColorSelected?.Invoke(hex);
                HighlightSelectedQuickColor(hex);
            };
            QuickColorDotsHost.Children.Add(btn);
        }
    }

    private void HighlightSelectedQuickColor(string activeHex)
    {
        for (var i = 0; i < QuickColorDotsHost.Children.Count && i < QuickPalette.Length; i++)
        {
            if (QuickColorDotsHost.Children[i] is System.Windows.Controls.Button btn)
            {
                btn.Tag = string.Equals(QuickPalette[i].Hex, activeHex, StringComparison.OrdinalIgnoreCase)
                    ? "Selected"
                    : null;
            }
        }
    }

    public void ConfigureMode(LyricsDisplayMode nextMode, AppSettings settings)
    {
        mode = nextMode;
        activeSettings = settings;
        locked = settings.OverlayLocked;
        verticalLayout = mode == LyricsDisplayMode.FreeFloat && settings.FloatingVerticalLayout;
        ApplyClickThroughStyle();
        ApplyAppearance(settings);
        PositionOnScreen(settings);
        UpdateToolbarPlacement();
    }

    public void SetLocked(bool value)
    {
        locked = value;
        if (locked)
        {
            EndDrag(commit: false);
            hovered = false;
            QuickColorPopover.Visibility = Visibility.Collapsed;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
        }
        ApplyClickThroughStyle();
        if (activeSettings is not null) ApplyAppearance(activeSettings);
        UpdateHoverChrome();
    }

    public void ApplyLanguage(bool english)
    {
        LockMiniBtn.Content = locked ? (english ? "Unlock" : "解锁") : (english ? "Lock" : "锁定");
        LockMiniBtn.ToolTip = english ? "Lock & enable mouse click-through (Ctrl+Alt+L)" : "锁定歌词并开启鼠标穿透 (Ctrl+Alt+L)";

        OrientationMiniBtn.Content = verticalLayout ? (english ? "Horiz" : "横排") : (english ? "Vert" : "竖排");
        OrientationMiniBtn.ToolTip = english ? "Switch Horizontal / Vertical lyric layout" : "切换横排 / 竖排歌词布局";

        ColorMiniBtn.Content = english ? "Colors" : "配色";
        ColorMiniBtn.ToolTip = english ? "Quick 7-color lyric palette" : "快捷切换 7 款主流歌词配色";

        OpenMainMiniBtn.Content = english ? "Home" : "主窗口";
        OpenMainMiniBtn.ToolTip = english ? "Show & focus NotchMuse main window" : "一键召唤并置前 NotchMuse 主界面";

        SettingsMiniBtn.Content = english ? "Settings" : "设置";
        SettingsMiniBtn.ToolTip = english ? "Open NotchMuse settings" : "打开外观与通用设置";

        HideMiniBtn.Content = english ? "Hide" : "隐藏";
        HideMiniBtn.ToolTip = english ? "Hide floating lyrics (restore from tray)" : "隐藏桌面悬浮歌词（可从托盘恢复）";

        BuildQuickColorDots();
    }

    public void ApplyAppearance(AppSettings settings)
    {
        activeSettings = settings;
        verticalLayout = mode == LyricsDisplayMode.FreeFloat && settings.FloatingVerticalLayout;
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;

        var fontSize = mode == LyricsDisplayMode.TopIsland
            ? Math.Clamp(settings.FontSize * 0.78, 13, 20)
            : Math.Clamp(settings.FontSize, 14, 34);
        BaseLyricText.FontSize = fontSize;
        SweepLyricText.FontSize = fontSize;
        OutlineLyricText.FontSize = fontSize;
        SubLyricText.FontSize = Math.Clamp(fontSize * 0.58, 10.5, 16);

        isTransparentCapsule = !settings.BackgroundCapsuleEnabled || settings.CapsulePreset == CapsuleBackgroundPreset.Transparent;
        var preset = settings.CapsulePreset;
        var bgOpacity = Math.Clamp(settings.CapsuleBackgroundOpacity, 0.30, 1.0);

        LyricCapsule.CornerRadius = mode == LyricsDisplayMode.TopIsland
            ? new CornerRadius(0, 0, 16, 16)
            : new CornerRadius(16);
        LyricCapsule.Padding = mode == LyricsDisplayMode.TopIsland
            ? new Thickness(22, 8, 22, 9)
            : verticalLayout
                ? new Thickness(16, 20, 16, 20)
                : new Thickness(26, 12, 26, 12);

        if (isTransparentCapsule)
        {
            // Idle transparent hit layer (#01000000 when unlocked) ensures 100% Win32 HitTest;
            // hover dynamically elevates this to a soft translucent gray grab-surface!
            idleBackgroundBrush = new SolidColorBrush(locked
                ? System.Windows.Media.Color.FromArgb(0, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(1, 0, 0, 0));
            idleBorderBrush = System.Windows.Media.Brushes.Transparent;
            idleBorderThickness = new Thickness(1);
            CapsuleShadow.Opacity = 0;

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

            idleBackgroundBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(alphaByte, baseRgb.R, baseRgb.G, baseRgb.B));
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
        HighlightSelectedQuickColor(settings.AccentHex);
        ApplyOrientationTextFormatting();
        UpdateHoverChrome();
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual)
    {
        rawPrimaryText = string.IsNullOrWhiteSpace(primary) ? "♪" : primary.Trim();
        rawTranslationText = translation?.Trim();
        showBilingualActive = showBilingual;
        sweepProgress = Math.Clamp(progress, 0, 1);

        ApplyOrientationTextFormatting();
        UpdateSweepClip();
    }

    private void ApplyOrientationTextFormatting()
    {
        if (verticalLayout && mode == LyricsDisplayMode.FreeFloat)
        {
            var chars = rawPrimaryText.Take(16).Select(c => c.ToString());
            var stacked = string.Join(Environment.NewLine, chars);
            BaseLyricText.Text = stacked;
            SweepLyricText.Text = stacked;
            OutlineLyricText.Text = stacked;
            BaseLyricText.LineHeight = BaseLyricText.FontSize * 1.18;
            SweepLyricText.LineHeight = SweepLyricText.FontSize * 1.18;
            OutlineLyricText.LineHeight = OutlineLyricText.FontSize * 1.18;
            SubLyricText.Visibility = Visibility.Collapsed;
        }
        else
        {
            BaseLyricText.Text = rawPrimaryText;
            SweepLyricText.Text = rawPrimaryText;
            OutlineLyricText.Text = rawPrimaryText;
            BaseLyricText.LineHeight = double.NaN;
            SweepLyricText.LineHeight = double.NaN;
            OutlineLyricText.LineHeight = double.NaN;

            if (showBilingualActive && !string.IsNullOrWhiteSpace(rawTranslationText))
            {
                SubLyricText.Text = rawTranslationText;
                SubLyricText.Visibility = Visibility.Visible;
            }
            else
            {
                SubLyricText.Visibility = Visibility.Collapsed;
            }
        }
    }

    public void ShowHoverToolbarForPreview(bool show, bool openQuickColors = false, bool forceBelow = false)
    {
        hovered = show && mode == LyricsDisplayMode.FreeFloat && !locked;
        HoverToolbarHost.Visibility = hovered ? Visibility.Visible : Visibility.Collapsed;
        QuickColorPopover.Visibility = (hovered && openQuickColors) ? Visibility.Visible : Visibility.Collapsed;
        ApplyToolbarFlip(forceBelow);
        UpdateHoverChrome();
    }

    public void PositionOnScreen(AppSettings settings)
    {
        var area = ResolveScreenWorkArea(settings.DisplayScreen);
        if (mode == LyricsDisplayMode.TopIsland)
        {
            OverlayGrid.VerticalAlignment = VerticalAlignment.Top;
            Width = 540;
            Height = 76;
            Left = area.Left + (area.Width - Width) / 2;
            Top = area.Top;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
            QuickColorPopover.Visibility = Visibility.Collapsed;
            return;
        }

        OverlayGrid.VerticalAlignment = VerticalAlignment.Center;
        if (verticalLayout)
        {
            Width = 340;
            Height = 520;
        }
        else
        {
            Width = 700;
            Height = 176;
        }

        if (settings.FloatingLeft.HasValue && settings.FloatingTop.HasValue)
        {
            Left = Math.Clamp(settings.FloatingLeft.Value, area.Left, Math.Max(area.Left, area.Right - Width));
            Top = Math.Clamp(settings.FloatingTop.Value, area.Top, Math.Max(area.Top, area.Bottom - Height));
        }
        else
        {
            Left = area.Left + (area.Width - Width) / 2;
            Top = area.Bottom - Height - 28;
        }

        UpdateToolbarPlacement();
    }

    /// <summary>
    /// Computes whether the floating hover toolbar should flip below the lyric capsule
    /// (true ONLY when near the top screen edge; otherwise always anchored above the lyrics).
    /// </summary>
    public static bool ShouldFlipToolbarBelow(double windowTopDip, double workAreaTopDip) =>
        windowTopDip - workAreaTopDip < TopEdgeFlipThresholdDip;

    private void UpdateToolbarPlacement()
    {
        if (mode != LyricsDisplayMode.FreeFloat) return;
        var area = ResolveScreenWorkArea(activeSettings?.DisplayScreen ?? "Primary");
        ApplyToolbarFlip(ShouldFlipToolbarBelow(Top, area.Top));
    }

    private void ApplyToolbarFlip(bool flipBelow)
    {
        toolbarFlippedBelow = flipBelow;
        if (flipBelow)
        {
            Grid.SetRow(HoverToolbarHost, 2);
            HoverToolbarHost.Padding = new Thickness(8, 7, 8, 0);
        }
        else
        {
            Grid.SetRow(HoverToolbarHost, 0);
            HoverToolbarHost.Padding = new Thickness(8, 0, 8, 7);
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
        var showHover = (hovered || dragging) && mode == LyricsDisplayMode.FreeFloat && !locked;
        if (showHover)
        {
            if (isTransparentCapsule)
            {
                // Transparent mode hover: soft translucent gray grab-backdrop + subtle border (zero blue focus ring!)
                LyricCapsule.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(148, 36, 36, 42));
                LyricCapsule.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(115, 255, 255, 255));
                LyricCapsule.BorderThickness = new Thickness(1);
            }
            else
            {
                LyricCapsule.Background = idleBackgroundBrush;
                LyricCapsule.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(215, 255, 138, 54));
                LyricCapsule.BorderThickness = new Thickness(1);
            }
        }
        else
        {
            LyricCapsule.Background = idleBackgroundBrush;
            LyricCapsule.BorderBrush = idleBorderBrush;
            LyricCapsule.BorderThickness = idleBorderThickness;
        }
    }

    private void UpdateSweepClip()
    {
        var width = SweepHost.ActualWidth;
        var height = SweepHost.ActualHeight;
        if (width <= 0 || height <= 0)
        {
            SweepHost.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
            width = SweepHost.DesiredSize.Width;
            height = SweepHost.DesiredSize.Height;
        }

        if (verticalLayout && mode == LyricsDisplayMode.FreeFloat)
        {
            SweepClip.Rect = new Rect(0, 0, Math.Max(40, width + 8), Math.Max(0, height * sweepProgress));
        }
        else
        {
            SweepClip.Rect = new Rect(0, 0, Math.Max(0, width * sweepProgress), Math.Max(48, height + 8));
        }
    }

    private void OnOverlayMouseEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (mode != LyricsDisplayMode.FreeFloat || locked) return;
        hovered = true;
        UpdateToolbarPlacement();
        HoverToolbarHost.Visibility = Visibility.Visible;
        UpdateHoverChrome();
    }

    private void OnOverlayMouseLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (dragging) return;
        hovered = false;
        QuickColorPopover.Visibility = Visibility.Collapsed;
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
        QuickColorPopover.Visibility = Visibility.Collapsed;
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

        // Allow dragging all the way down so the capsule itself can kiss the taskbar top edge!
        Left = Math.Clamp(nextLeft, work.Left, Math.Max(work.Left, work.Right - Width));
        Top = Math.Clamp(nextTop, work.Top, Math.Max(work.Top, work.Bottom - Height + 24));
        UpdateToolbarPlacement();
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
            QuickColorPopover.Visibility = Visibility.Collapsed;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
        }
        UpdateHoverChrome();
    }

    private void OnLockClick(object sender, RoutedEventArgs e) => LockToggled?.Invoke();

    private void OnOrientationClick(object sender, RoutedEventArgs e)
    {
        verticalLayout = !verticalLayout;
        OrientationToggled?.Invoke(verticalLayout);
    }

    private void OnToggleQuickColorClick(object sender, RoutedEventArgs e)
    {
        QuickColorPopover.Visibility = QuickColorPopover.Visibility == Visibility.Visible
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    private void OnOpenMainClick(object sender, RoutedEventArgs e) => OpenMainRequested?.Invoke();
    private void OnOpenSettingsClick(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke();
    private void OnHideClick(object sender, RoutedEventArgs e) => HideRequested?.Invoke();
}
