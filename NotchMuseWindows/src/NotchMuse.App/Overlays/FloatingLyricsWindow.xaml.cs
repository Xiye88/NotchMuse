using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Threading;
using NotchMuse.App.Themes;
using Forms = System.Windows.Forms;

namespace NotchMuse.App.Overlays;

public partial class FloatingLyricsWindow : Window
{
    private const double MagneticSnapThresholdDip = 10.0;
    private const double TopEdgeFlipThresholdDip = 72.0;

    public static readonly (string NameZh, string NameEn, string Hex)[] QuickSolidPalette =
    [
        ("纯白", "Pure White", "#FFFFFF"),
        ("暖琥珀", "Warm Amber", "#FF8A36"),
        ("天青蓝", "Sky Cyan", "#38BDF8"),
        ("翡翠绿", "Emerald", "#34D399"),
        ("樱花粉", "Sakura Pink", "#F472B6"),
        ("柔紫", "Soft Violet", "#A78BFA"),
        ("墨黑", "Ink Black", "#1C1C20")
    ];

    public static readonly (string NameZh, string NameEn, string StartHex, string EndHex)[] QuickGradientPalette =
    [
        ("暖日落橙粉", "Warm Sunset", "#FF8A36", "#FF4D8D"),
        ("极光青紫", "Aurora Violet", "#38BDF8", "#A855F7"),
        ("薄荷晴空", "Mint Sky", "#34D399", "#0EA5E9")
    ];

    private readonly DispatcherTimer microTooltipTimer = new() { Interval = TimeSpan.FromMilliseconds(90) };
    private readonly DispatcherTimer dragPollTimer = new() { Interval = TimeSpan.FromMilliseconds(8) }; // ~120Hz silky Win32 drag without CaptureMouse or modal loop traps!
    private readonly DispatcherTimer lockedHoverTimer = new() { Interval = TimeSpan.FromMilliseconds(55) };
    private readonly FloatingUnlockPillWindow unlockPill = new();

    private IntPtr handle;
    private HwndSource? hwndSource;
    private LyricsDisplayMode mode = LyricsDisplayMode.FreeFloat;
    private AppSettings? activeSettings;
    private bool locked;
    private bool clickThroughDodged;
    private bool hovered;
    private bool dragging;
    private NativePoint dragStartCursorPx;
    private NativeWindowRect dragStartRectPx;
    private bool dragMoved;
    private bool verticalLayout;
    private bool doubleLineMode = true;
    private bool isTransparentCapsule;
    private bool toolbarFlippedBelow;
    private double sweepProgress;
    private string rawPrimaryText = "等待播放音乐…";
    private string? rawNextLineText;
    private string? rawTranslationText;
    private bool showBilingualActive;
    private System.Windows.Controls.Button? pendingTooltipButton;
    private System.Windows.Media.Brush idleBackgroundBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(209, 62, 62, 68));
    private System.Windows.Media.Brush idleBorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(46, 255, 255, 255));
    private Thickness idleBorderThickness = new(0.75);

    public event Action? LockToggled;
    public event Action<bool>? OrientationToggled;
    public event Action<string, string?>? QuickColorSelected;
    public event Action? OpenMainRequested;
    public event Action? OpenSettingsRequested;
    public event Action? HideRequested;
    public event Action<double, double>? PositionCommitted;

    public FloatingLyricsWindow()
    {
        InitializeComponent();
        BuildQuickColorDots();
        microTooltipTimer.Tick += OnMicroTooltipTimerTick;
        dragPollTimer.Tick += OnDragPollTick;
        lockedHoverTimer.Tick += OnLockedHoverTick;
        unlockPill.UnlockRequested += () => LockToggled?.Invoke();
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            if (handle != IntPtr.Zero && hwndSource is null)
            {
                hwndSource = HwndSource.FromHwnd(handle);
                hwndSource?.AddHook(WndProc);
            }
            ApplyClickThroughStyle();
        };
        IsVisibleChanged += (_, _) =>
        {
            if (IsVisible)
            {
                ApplyClickThroughStyle();
                UpdateLockedHoverMonitor();
            }
            else
            {
                if (dragging) FinishDirectDrag(commit: false);
                HideUnlockPill();
                lockedHoverTimer.Stop();
            }
        };
        Closed += (_, _) =>
        {
            dragPollTimer.Stop();
            microTooltipTimer.Stop();
            lockedHoverTimer.Stop();
            unlockPill.Close();
            hwndSource?.RemoveHook(WndProc);
            hwndSource = null;
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
        VerticalSweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    private const int WmLButtonDown = 0x0201;

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        // 1. Click-through guard alongside WS_EX_TRANSPARENT (covers FreeFloat & TopIsland)
        var clickThrough = WindowClickThroughHelper.HandleClickThroughMessage(msg, locked, ref handled);
        if (handled) return clickThrough;

        // 2. Keep overlay non-activating while clicking/hovering/dragging so games & browsers never lose focus
        if (msg == WindowClickThroughHelper.WmMouseActivate)
        {
            handled = true;
            return WindowClickThroughHelper.MaNoActivate;
        }

        // 3. Raw Win32 WM_LBUTTONDOWN backup: guarantees dragging starts even on WS_EX_NOACTIVATE layered windows
        //    if the click lands inside LyricCapsule (never intercepting HoverToolbar buttons!).
        if (msg == WmLButtonDown && !locked && mode == LyricsDisplayMode.FreeFloat && !dragging && IsCursorInsideCapsule())
        {
            StartDirectDrag();
        }

        return IntPtr.Zero;
    }

    private bool IsCursorInsideCapsule()
    {
        if (!LyricCapsule.IsLoaded || PresentationSource.FromVisual(LyricCapsule) is null) return false;
        if (!WindowClickThroughHelper.GetCursorPos(out var pt)) return false;
        var origin = LyricCapsule.PointToScreen(new System.Windows.Point(0, 0));
        var dpi = Math.Max(1.0, VisualTreeHelper.GetDpi(this).DpiScaleX);
        var w = Math.Max(40, LyricCapsule.ActualWidth) * dpi;
        var h = Math.Max(24, LyricCapsule.ActualHeight) * dpi;
        return pt.X >= origin.X && pt.X <= origin.X + w && pt.Y >= origin.Y && pt.Y <= origin.Y + h;
    }

    public IntPtr WindowHandle => handle;
    public bool IsToolbarFlippedBelow => toolbarFlippedBelow;
    public bool IsQuickColorPopoverOpen => QuickColorPopover.Visibility == Visibility.Visible;
    public bool IsClickThroughDodged => clickThroughDodged;

    private void BuildQuickColorDots()
    {
        QuickColorDotsHost.Children.Clear();
        var en = activeSettings?.EnglishLanguage == true;
        var isGradient = activeSettings?.ColorMode == LyricColorMode.Gradient;

        // 7 Solid Dots
        foreach (var item in QuickSolidPalette)
        {
            var color = ThemeManager.ParseColor(item.Hex, Colors.White);
            var btn = new System.Windows.Controls.Button
            {
                Style = (Style)FindResource("FloatingColorDot"),
                Background = new SolidColorBrush(color),
                ToolTip = en ? item.NameEn : item.NameZh,
                Tag = !isGradient && activeSettings is not null && string.Equals(activeSettings.AccentHex, item.Hex, StringComparison.OrdinalIgnoreCase)
                    ? "Selected"
                    : null
            };
            var hex = item.Hex;
            btn.Click += (_, _) =>
            {
                InteractionMotion.Rebound(btn, 0.94);
                InteractionSoundEngine.Play(InteractionSoundCue.Tick);
                QuickColorSelected?.Invoke(hex, null);
                BuildQuickColorDots();
            };
            QuickColorDotsHost.Children.Add(btn);
        }

        // Subtle vertical divider
        QuickColorDotsHost.Children.Add(new Border
        {
            Width = 1,
            Height = 14,
            Margin = new Thickness(5, 0, 5, 0),
            Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(56, 255, 255, 255)),
            VerticalAlignment = VerticalAlignment.Center
        });

        // 3 Curated Gradient Dots (Mac Build 100 parity!)
        foreach (var g in QuickGradientPalette)
        {
            var brush = new LinearGradientBrush(
                ThemeManager.ParseColor(g.StartHex, Colors.DarkOrange),
                ThemeManager.ParseColor(g.EndHex, Colors.DeepPink),
                new System.Windows.Point(0, 0),
                new System.Windows.Point(1, 1));
            var btn = new System.Windows.Controls.Button
            {
                Style = (Style)FindResource("FloatingColorDot"),
                Background = brush,
                ToolTip = en ? g.NameEn : g.NameZh,
                Tag = isGradient && activeSettings is not null &&
                      string.Equals(activeSettings.AccentHex, g.StartHex, StringComparison.OrdinalIgnoreCase) &&
                      string.Equals(activeSettings.GradientEndHex, g.EndHex, StringComparison.OrdinalIgnoreCase)
                    ? "Selected"
                    : null
            };
            var sHex = g.StartHex;
            var eHex = g.EndHex;
            btn.Click += (_, _) =>
            {
                InteractionMotion.Rebound(btn, 0.94);
                InteractionSoundEngine.Play(InteractionSoundCue.Tick);
                QuickColorSelected?.Invoke(sHex, eHex);
                BuildQuickColorDots();
            };
            QuickColorDotsHost.Children.Add(btn);
        }
    }

    public void ConfigureMode(LyricsDisplayMode nextMode, AppSettings settings)
    {
        mode = nextMode;
        activeSettings = settings;
        locked = settings.OverlayLocked;
        LyricCapsule.IsHitTestVisible = !locked;
        HoverToolbarHost.IsHitTestVisible = false;
        HoverToolbarHost.Opacity = 0;
        HoverToolbarHost.Visibility = mode == LyricsDisplayMode.FreeFloat ? Visibility.Visible : Visibility.Collapsed;
        verticalLayout = mode == LyricsDisplayMode.FreeFloat && settings.FloatingVerticalLayout;
        doubleLineMode = settings.FloatingDoubleLine;
        ApplyClickThroughStyle();
        UpdateLockedHoverMonitor();
        ApplyAppearance(settings);
        PositionOnScreen(settings);
        UpdateToolbarPlacement();
    }

    public void SetLocked(bool value)
    {
        locked = value;
        if (locked)
        {
            FinishDirectDrag(commit: false);
            hovered = false;
            HideMicroTooltip();
            QuickColorPopover.Visibility = Visibility.Collapsed;
            SetHoverToolbarVisible(false);
        }
        LyricCapsule.IsHitTestVisible = !locked;
        if (locked) HoverToolbarHost.IsHitTestVisible = false;
        ApplyClickThroughStyle();
        UpdateLockedHoverMonitor();
        if (activeSettings is not null) ApplyAppearance(activeSettings);
        UpdateHoverChrome();
    }

    private void SetHoverToolbarVisible(bool visible)
    {
        if (mode != LyricsDisplayMode.FreeFloat)
        {
            HoverToolbarHost.Visibility = Visibility.Collapsed;
            HoverToolbarHost.Opacity = 0;
            HoverToolbarHost.IsHitTestVisible = false;
            return;
        }
        HoverToolbarHost.Visibility = Visibility.Visible;
        HoverToolbarHost.Opacity = visible ? 1.0 : 0.0;
        HoverToolbarHost.IsHitTestVisible = visible && !locked;
    }

    private static readonly Geometry UnlockedIconGeometry = Geometry.Parse("M 4.5,7 V 5.1 A 3.5,3.5 0 0 1 11.2,4.1 M 3.2,7 H 12.8 A 1.2,1.2 0 0 1 14,8.2 V 13.3 A 1.2,1.2 0 0 1 12.8,14.5 H 3.2 A 1.2,1.2 0 0 1 2,13.3 V 8.2 A 1.2,1.2 0 0 1 3.2,7 Z");
    private static readonly Geometry LockedIconGeometry = Geometry.Parse("M 4.5,7 V 5.2 A 3.5,3.5 0 0 1 11.5,5.2 V 7 M 3.2,7 H 12.8 A 1.2,1.2 0 0 1 14,8.2 V 13.3 A 1.2,1.2 0 0 1 12.8,14.5 H 3.2 A 1.2,1.2 0 0 1 2,13.3 V 8.2 A 1.2,1.2 0 0 1 3.2,7 Z");
    private static readonly Geometry SwitchToVerticalGeometry = Geometry.Parse("M 4.5,2.5 V 13.5 M 9.5,2.5 V 13.5 M 13,5.5 V 10.5");
    private static readonly Geometry SwitchToHorizontalGeometry = Geometry.Parse("M 2.5,4.5 H 13.5 M 2.5,9.5 H 13.5 M 5.5,13 H 10.5");

    public void ApplyLanguage(bool english)
    {
        LockIconPath.Data = locked ? LockedIconGeometry : UnlockedIconGeometry;
        OrientationIconPath.Data = verticalLayout ? SwitchToHorizontalGeometry : SwitchToVerticalGeometry;
        unlockPill.ApplyLanguage(english);
        BuildQuickColorDots();
    }

    private void UpdateLockedHoverMonitor()
    {
        // Active for BOTH FreeFloat AND TopIsland whenever click-through lock is ON so hovering auto-hides the lyric capsule!
        if (locked && IsVisible)
        {
            if (!lockedHoverTimer.IsEnabled) lockedHoverTimer.Start();
        }
        else
        {
            lockedHoverTimer.Stop();
            HideUnlockPill();
            SetClickThroughDodge(false);
        }
    }

    private void SetClickThroughDodge(bool dodge)
    {
        if (clickThroughDodged == dodge) return;
        clickThroughDodged = dodge;
        var targetOpacity = dodge ? 0.0 : 1.0;
        if (InteractionMotion.AnimationsAllowed)
        {
            var anim = new DoubleAnimation(targetOpacity, TimeSpan.FromMilliseconds(dodge ? 110 : 170))
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };
            LyricCapsule.BeginAnimation(OpacityProperty, anim);
        }
        else
        {
            LyricCapsule.BeginAnimation(OpacityProperty, null);
            LyricCapsule.Opacity = targetOpacity;
        }
    }

    private void HideUnlockPill()
    {
        if (unlockPill.IsVisible) unlockPill.Hide();
    }

    private void OnLockedHoverTick(object? sender, EventArgs e)
    {
        if (!locked || !IsVisible)
        {
            lockedHoverTimer.Stop();
            HideUnlockPill();
            SetClickThroughDodge(false);
            return;
        }
        if (!WindowClickThroughHelper.GetCursorPos(out var pt)) return;

        var dpi = Math.Max(1.0, VisualTreeHelper.GetDpi(this).DpiScaleX);
        var cursorDip = new System.Windows.Point(pt.X / dpi, pt.Y / dpi);

        var capW = Math.Max(120, LyricCapsule.ActualWidth);
        var capH = Math.Max(42, LyricCapsule.ActualHeight);
        var capOrigin = LyricCapsule.IsLoaded && PresentationSource.FromVisual(LyricCapsule) is not null
            ? LyricCapsule.PointToScreen(new System.Windows.Point(0, 0))
            : new System.Windows.Point(Left * dpi, Top * dpi);
        var capRect = new Rect(capOrigin.X / dpi, capOrigin.Y / dpi, capW, capH);
        var dodgeRect = new Rect(capRect.Left - 10, capRect.Top - 10, capRect.Width + 20, capRect.Height + 20);

        if (mode == LyricsDisplayMode.FreeFloat)
        {
            var work = ResolveScreenWorkArea(activeSettings?.DisplayScreen ?? "Primary");
            var pillAbove = capRect.Top - 36 >= work.Top;
            var pillLeft = capRect.Left + (capRect.Width - unlockPill.Width) / 2;
            var pillTop = pillAbove ? capRect.Top - unlockPill.Height - 2 : capRect.Bottom + 2;

            var pillZone = new Rect(pillLeft - 8, pillTop - 6, unlockPill.Width + 16, unlockPill.Height + 12);
            var nearCapsuleOrPill = dodgeRect.Contains(cursorDip) || pillZone.Contains(cursorDip);

            // Auto-hide the lyric capsule on hover while locked so underlying content is 100% visible & clickable!
            SetClickThroughDodge(nearCapsuleOrPill);

            if (nearCapsuleOrPill)
            {
                if (!unlockPill.IsVisible || Math.Abs(unlockPill.Left - pillLeft) > 2 || Math.Abs(unlockPill.Top - pillTop) > 2)
                    unlockPill.ShowAt(pillLeft, pillTop);
            }
            else
            {
                HideUnlockPill();
            }
        }
        else
        {
            // TopIsland locked click-through: auto-hide cleanly when cursor moves near top lyrics, zero obstruction!
            HideUnlockPill();
            SetClickThroughDodge(dodgeRect.Contains(cursorDip));
        }
    }

    private string GetMicroTooltipForButton(System.Windows.Controls.Button btn)
    {
        var en = activeSettings?.EnglishLanguage == true;
        if (btn == LockMiniBtn) return locked ? (en ? "Unlock & Drag (Ctrl+Alt+L)" : "解锁并恢复拖动 (Ctrl+Alt+L)") : (en ? "Lock & Auto-Dodge Click-Through (Ctrl+Alt+L)" : "锁定穿透 · 悬停自动隐藏 (Ctrl+Alt+L)");
        if (btn == OrientationMiniBtn) return verticalLayout ? (en ? "Switch to Horizontal Lyrics" : "切换为横排歌词") : (en ? "Switch to Vertical Lyrics" : "切换为竖排歌词");
        if (btn == ColorMiniBtn) return en ? "Quick Solid & Gradient Colors" : "快捷配色（7 纯色 + 3 渐变）";
        if (btn == OpenMainMiniBtn) return en ? "Open NotchMuse Window" : "打开主窗口";
        if (btn == SettingsMiniBtn) return en ? "Open Settings" : "打开设置";
        if (btn == HideMiniBtn) return en ? "Hide Desktop Lyrics" : "隐藏桌面歌词";
        return "";
    }

    public void ApplyAppearance(AppSettings settings)
    {
        activeSettings = settings;
        verticalLayout = mode == LyricsDisplayMode.FreeFloat && settings.FloatingVerticalLayout;
        doubleLineMode = settings.FloatingDoubleLine;

        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        SweepLyricText.Foreground = accentBrush;
        VerticalSweepText.Foreground = accentBrush;

        var fontSize = mode == LyricsDisplayMode.TopIsland
            ? Math.Clamp(settings.FontSize * 0.78, 13, 20)
            : Math.Clamp(settings.FontSize, 14, 34);
        BaseLyricText.FontSize = fontSize;
        SweepLyricText.FontSize = fontSize;
        OutlineLyricText.FontSize = fontSize;
        SubLyricText.FontSize = Math.Clamp(fontSize * 0.62, 11, 17);

        var vertFontSize = Math.Clamp(fontSize * 0.92, 15, 26);
        VerticalBaseText.FontSize = vertFontSize;
        VerticalSweepText.FontSize = vertFontSize;
        VerticalOutlineText.FontSize = vertFontSize;
        VerticalNextText.FontSize = Math.Clamp(vertFontSize * 0.82, 13, 22);

        isTransparentCapsule = !settings.BackgroundCapsuleEnabled || settings.CapsulePreset == CapsuleBackgroundPreset.Transparent;
        var preset = settings.CapsulePreset;
        var bgOpacity = Math.Clamp(settings.CapsuleBackgroundOpacity, 0.30, 1.0);

        LyricCapsule.CornerRadius = mode == LyricsDisplayMode.TopIsland
            ? new CornerRadius(0, 0, 16, 16)
            : new CornerRadius(14);

        // Tight 20px horizontal margin so hover frame hugs the rendered lyric width closely!
        LyricCapsule.Padding = mode == LyricsDisplayMode.TopIsland
            ? new Thickness(20, 8, 20, 9)
            : verticalLayout
                ? new Thickness(16, 18, 16, 18)
                : new Thickness(20, 10, 20, 10);

        if (isTransparentCapsule)
        {
            // Alpha = 6 (imperceptible visually, remains >= 1 even at minimum LyricOpacity 0.30 so DWM ALWAYS hit-tests!)
            idleBackgroundBrush = new SolidColorBrush(locked
                ? System.Windows.Media.Color.FromArgb(0, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(6, 0, 0, 0));
            idleBorderBrush = System.Windows.Media.Brushes.Transparent;
            idleBorderThickness = new Thickness(0.75);
            CapsuleShadow.Opacity = 0;

            OutlineLyricText.Visibility = Visibility.Visible;
            VerticalOutlineText.Visibility = Visibility.Visible;
            var brightInk = new SolidColorBrush(System.Windows.Media.Color.FromArgb(232, 248, 247, 244));
            var subInk = new SolidColorBrush(System.Windows.Media.Color.FromArgb(210, 236, 235, 230));
            BaseLyricText.Foreground = brightInk;
            VerticalBaseText.Foreground = brightInk;
            SubLyricText.Foreground = subInk;
            VerticalNextText.Foreground = subInk;

            var halo = new DropShadowEffect { Color = Colors.Black, BlurRadius = 5, ShadowDepth = 0, Opacity = 0.88 };
            SubLyricText.Effect = halo;
            VerticalNextText.Effect = halo;
            SweepLyricText.Effect = new DropShadowEffect { Color = Colors.Black, BlurRadius = 4, ShadowDepth = 0, Opacity = 0.68 };
            VerticalSweepText.Effect = SweepLyricText.Effect;
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
                ? System.Windows.Media.Color.FromArgb(30, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(38, 255, 255, 255));
            idleBorderThickness = mode == LyricsDisplayMode.TopIsland
                ? new Thickness(0.75, 0, 0.75, 0.75)
                : new Thickness(0.75);
            CapsuleShadow.Opacity = isLightCapsule ? 0.18 : 0.30;

            OutlineLyricText.Visibility = Visibility.Collapsed;
            VerticalOutlineText.Visibility = Visibility.Collapsed;
            var baseInk = new SolidColorBrush(isLightCapsule
                ? System.Windows.Media.Color.FromArgb(148, 26, 26, 28)
                : System.Windows.Media.Color.FromArgb(148, 245, 244, 240));
            var secondaryInk = new SolidColorBrush(isLightCapsule
                ? System.Windows.Media.Color.FromRgb(94, 92, 86)
                : System.Windows.Media.Color.FromRgb(186, 185, 190));

            BaseLyricText.Foreground = baseInk;
            VerticalBaseText.Foreground = baseInk;
            SubLyricText.Foreground = secondaryInk;
            VerticalNextText.Foreground = secondaryInk;
            SubLyricText.Effect = null;
            VerticalNextText.Effect = null;
            SweepLyricText.Effect = null;
            VerticalSweepText.Effect = null;
        }

        LyricCapsule.Cursor = (mode == LyricsDisplayMode.FreeFloat && !locked)
            ? System.Windows.Input.Cursors.SizeAll
            : System.Windows.Input.Cursors.Arrow;

        Opacity = Math.Clamp(settings.LyricOpacity, 0.3, 1.0);
        ApplyLanguage(settings.EnglishLanguage);
        ApplyOrientationTextFormatting();
        UpdateHoverChrome();
    }

    public void UpdateLyric(string primary, string? translation, double progress, bool showBilingual, string? nextLine = null)
    {
        rawPrimaryText = string.IsNullOrWhiteSpace(primary) ? "♪" : primary.Trim();
        rawNextLineText = string.IsNullOrWhiteSpace(nextLine) ? null : nextLine.Trim();
        rawTranslationText = string.IsNullOrWhiteSpace(translation) ? null : translation.Trim();
        showBilingualActive = showBilingual;
        sweepProgress = Math.Clamp(progress, 0, 1);

        ApplyOrientationTextFormatting();
        UpdateSweepClip();
    }

    private void ApplyOrientationTextFormatting()
    {
        if (verticalLayout && mode == LyricsDisplayMode.FreeFloat)
        {
            HorizontalLyricsHost.Visibility = Visibility.Collapsed;
            VerticalLyricsHost.Visibility = Visibility.Visible;
            // Strictly forbid any horizontal secondary text below vertical lyrics!
            SubLyricText.Visibility = Visibility.Collapsed;

            var stackedPrimary = StackVerticalChars(rawPrimaryText);
            VerticalBaseText.Text = stackedPrimary;
            VerticalSweepText.Text = stackedPrimary;
            VerticalOutlineText.Text = stackedPrimary;
            var lh = VerticalBaseText.FontSize * 1.15;
            VerticalBaseText.LineHeight = lh;
            VerticalSweepText.LineHeight = lh;
            VerticalOutlineText.LineHeight = lh;

            var secondaryText = showBilingualActive && !string.IsNullOrWhiteSpace(rawTranslationText)
                ? rawTranslationText
                : rawNextLineText;

            if (doubleLineMode && !string.IsNullOrWhiteSpace(secondaryText))
            {
                VerticalNextText.Text = StackVerticalChars(secondaryText);
                VerticalNextText.LineHeight = VerticalNextText.FontSize * 1.15;
                VerticalNextText.Visibility = Visibility.Visible;
            }
            else
            {
                VerticalNextText.Visibility = Visibility.Collapsed;
            }
        }
        else
        {
            VerticalLyricsHost.Visibility = Visibility.Collapsed;
            HorizontalLyricsHost.Visibility = Visibility.Visible;

            BaseLyricText.Text = rawPrimaryText;
            SweepLyricText.Text = rawPrimaryText;
            OutlineLyricText.Text = rawPrimaryText;

            // Horizontal Double-Line works across BOTH FreeFloat AND TopIsland!
            // Bilingual translation takes priority if present, otherwise soft next-line preview!
            if (doubleLineMode)
            {
                var secondLine = (showBilingualActive && !string.IsNullOrWhiteSpace(rawTranslationText))
                    ? rawTranslationText
                    : rawNextLineText;
                if (!string.IsNullOrWhiteSpace(secondLine))
                {
                    SubLyricText.Text = secondLine;
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
    }

    private static string StackVerticalChars(string text) =>
        string.Join(Environment.NewLine, text.Where(c => !char.IsControl(c)).Take(16).Select(c => c.ToString()));

    public void ShowHoverToolbarForPreview(bool show, bool openQuickColors = false, bool forceBelow = false, string? previewMicroTooltip = null)
    {
        hovered = show && mode == LyricsDisplayMode.FreeFloat && !locked;
        SetHoverToolbarVisible(hovered);
        QuickColorPopover.Visibility = (hovered && openQuickColors) ? Visibility.Visible : Visibility.Collapsed;
        ApplyToolbarFlip(forceBelow);
        UpdateHoverChrome();

        if (!string.IsNullOrWhiteSpace(previewMicroTooltip) && hovered)
        {
            MicroTooltipText.Text = previewMicroTooltip;
            MicroTooltipText.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
            var lw = MicroTooltipText.DesiredSize.Width;
            var tw = Math.Max(220, lw + 16);
            MicroTooltipTrack.Width = tw;
            MicroTooltipText.Opacity = 1.0;
            Canvas.SetLeft(MicroTooltipText, Math.Max(0, (tw - lw) / 2));
            Canvas.SetTop(MicroTooltipText, 1);
        }
        else
        {
            HideMicroTooltip();
        }
    }

    public void PositionOnScreen(AppSettings settings)
    {
        var area = ResolveScreenWorkArea(settings.DisplayScreen);
        if (mode == LyricsDisplayMode.TopIsland)
        {
            OverlayGrid.VerticalAlignment = VerticalAlignment.Top;
            Width = 560;
            Height = settings.FloatingDoubleLine ? 84 : 74;
            Left = area.Left + (area.Width - Width) / 2;
            Top = area.Top;
            SetHoverToolbarVisible(false);
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
            Height = 196;
        }

        var insets = ComputeCapsuleInsetsDip();
        var edgeDip = 4.0;
        var minLeft = area.Left + edgeDip - insets.Left;
        var maxLeft = Math.Max(minLeft, area.Right - (Width - insets.Right) - edgeDip);
        var minTop = area.Top + edgeDip - insets.Top;
        var maxTop = Math.Max(minTop, area.Bottom - (Height - insets.Bottom) - edgeDip);

        if (settings.FloatingLeft.HasValue && settings.FloatingTop.HasValue)
        {
            Left = Math.Clamp(settings.FloatingLeft.Value, minLeft, maxLeft);
            Top = Math.Clamp(settings.FloatingTop.Value, minTop, maxTop);
        }
        else
        {
            Left = area.Left + (area.Width - Width) / 2;
            Top = Math.Clamp(area.Bottom - (Height - insets.Bottom) - 18, minTop, maxTop);
        }

        UpdateToolbarPlacement();
    }

    private (double Left, double Top, double Right, double Bottom) ComputeCapsuleInsetsDip()
    {
        if (LyricCapsule.IsLoaded && LyricCapsule.ActualWidth >= 40 && LyricCapsule.ActualHeight >= 24 &&
            PresentationSource.FromVisual(LyricCapsule) is not null)
        {
            var topLeft = LyricCapsule.TranslatePoint(new System.Windows.Point(0, 0), this);
            var inL = Math.Clamp(topLeft.X, 0, Math.Max(0, Width - 40));
            var inT = Math.Clamp(topLeft.Y, 0, Math.Max(0, Height - 24));
            var inR = Math.Clamp(Width - (topLeft.X + LyricCapsule.ActualWidth), 0, Math.Max(0, Width - inL - 40));
            var inB = Math.Clamp(Height - (topLeft.Y + LyricCapsule.ActualHeight), 0, Math.Max(0, Height - inT - 24));
            return (inL, inT, inR, inB);
        }

        // Sensible pre-layout fallback matching centered capsule proportions
        var estW = verticalLayout ? 112.0 : 320.0;
        var estH = verticalLayout ? 320.0 : (doubleLineMode ? 70.0 : 48.0);
        var hPad = Math.Max(0, (Width - estW) / 2.0);
        var vPad = Math.Max(0, (Height - estH) / 2.0);
        return (hPad, vPad, hPad, vPad);
    }

    private NativeWindowInsets ComputeCapsuleInsetsPixels(double dpi)
    {
        var dip = ComputeCapsuleInsetsDip();
        return new NativeWindowInsets(
            (int)Math.Round(dip.Left * dpi),
            (int)Math.Round(dip.Top * dpi),
            (int)Math.Round(dip.Right * dpi),
            (int)Math.Round(dip.Bottom * dpi));
    }

    /// <summary>
    /// Computes whether the floating hover toolbar should flip below the lyric capsule
    /// (true ONLY when the visible capsule top is near the top screen edge; otherwise anchored 4px above).
    /// </summary>
    public static bool ShouldFlipToolbarBelow(double capsuleTopDip, double workAreaTopDip) =>
        capsuleTopDip - workAreaTopDip < TopEdgeFlipThresholdDip;

    private void UpdateToolbarPlacement()
    {
        if (mode != LyricsDisplayMode.FreeFloat) return;
        var area = ResolveScreenWorkArea(activeSettings?.DisplayScreen ?? "Primary");
        var insets = ComputeCapsuleInsetsDip();
        var visibleCapsuleTop = Top + insets.Top;
        ApplyToolbarFlip(ShouldFlipToolbarBelow(visibleCapsuleTop, area.Top));
    }

    private void ApplyToolbarFlip(bool flipBelow)
    {
        toolbarFlippedBelow = flipBelow;
        HoverToolbarStack.Children.Clear();
        if (flipBelow)
        {
            Grid.SetRow(HoverToolbarHost, 2);
            HoverToolbarHost.Padding = new Thickness(6, 4, 6, 0);
            QuickColorPopover.Margin = new Thickness(0, 4, 0, 0);
            MicroTooltipTrack.Margin = new Thickness(0, 2, 0, 0);
            HoverToolbarStack.Children.Add(HoverToolbar);
            HoverToolbarStack.Children.Add(QuickColorPopover);
            HoverToolbarStack.Children.Add(MicroTooltipTrack);
        }
        else
        {
            Grid.SetRow(HoverToolbarHost, 0);
            HoverToolbarHost.Padding = new Thickness(6, 0, 6, 4);
            QuickColorPopover.Margin = new Thickness(0, 0, 0, 4);
            MicroTooltipTrack.Margin = new Thickness(0, 0, 0, 2);
            HoverToolbarStack.Children.Add(MicroTooltipTrack);
            HoverToolbarStack.Children.Add(QuickColorPopover);
            HoverToolbarStack.Children.Add(HoverToolbar);
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

    private NativeWindowRect ResolveScreenWorkAreaPixels(string deviceName)
    {
        var screen = Forms.Screen.AllScreens.FirstOrDefault(s =>
            string.Equals(s.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) ?? Forms.Screen.PrimaryScreen;
        if (screen is null)
        {
            var wa = SystemParameters.WorkArea;
            var dpi = Math.Max(1.0, VisualTreeHelper.GetDpi(this).DpiScaleX);
            return new NativeWindowRect
            {
                Left = (int)Math.Round(wa.Left * dpi),
                Top = (int)Math.Round(wa.Top * dpi),
                Right = (int)Math.Round(wa.Right * dpi),
                Bottom = (int)Math.Round(wa.Bottom * dpi)
            };
        }
        var area = screen.WorkingArea;
        return new NativeWindowRect { Left = area.Left, Top = area.Top, Right = area.Right, Bottom = area.Bottom };
    }

    private void ApplyClickThroughStyle()
    {
        var currentHandle = handle != IntPtr.Zero ? handle : new WindowInteropHelper(this).Handle;
        if (currentHandle == IntPtr.Zero) return;
        handle = currentHandle;
        WindowClickThroughHelper.ApplyClickThrough(handle, locked);
    }

    private void UpdateHoverChrome()
    {
        var showHover = (hovered || dragging) && mode == LyricsDisplayMode.FreeFloat && !locked;
        if (showHover)
        {
            if (isTransparentCapsule)
            {
                // Soft airy luminous translucent mist (alpha ~0.19) + ultra-fine 0.75px soft border (Mac Build 103 parity!)
                LyricCapsule.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(48, 255, 255, 255));
                LyricCapsule.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(72, 255, 255, 255));
                LyricCapsule.BorderThickness = new Thickness(0.75);
            }
            else
            {
                // Subtle 0.75px soft warm amber halo rim instead of harsh solid line
                LyricCapsule.Background = idleBackgroundBrush;
                LyricCapsule.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(148, 255, 138, 54));
                LyricCapsule.BorderThickness = new Thickness(0.75);
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
        if (verticalLayout && mode == LyricsDisplayMode.FreeFloat)
        {
            var vw = VerticalSweepHost.ActualWidth;
            var vh = VerticalSweepHost.ActualHeight;
            if (vw <= 0 || vh <= 0)
            {
                VerticalSweepHost.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
                vw = VerticalSweepHost.DesiredSize.Width;
                vh = VerticalSweepHost.DesiredSize.Height;
            }
            VerticalSweepClip.Rect = new Rect(0, 0, Math.Max(40, vw + 8), Math.Max(0, vh * sweepProgress));
        }
        else
        {
            var width = SweepHost.ActualWidth;
            var height = SweepHost.ActualHeight;
            if (width <= 0 || height <= 0)
            {
                SweepHost.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
                width = SweepHost.DesiredSize.Width;
                height = SweepHost.DesiredSize.Height;
            }
            SweepClip.Rect = new Rect(0, 0, Math.Max(0, width * sweepProgress), Math.Max(48, height + 8));
        }
    }

    // Restrained Dock 1.08x micro-magnify + 150ms borderless dark-ink micro-tooltip directly above button!
    private void OnToolbarButtonEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button btn) return;
        InteractionMotion.Magnify(btn, 1.08);
        pendingTooltipButton = btn;
        microTooltipTimer.Stop();
        microTooltipTimer.Start();
    }

    private void OnToolbarButtonLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn)
            InteractionMotion.Magnify(btn, 1.0);
        if (pendingTooltipButton == sender) pendingTooltipButton = null;
        HideMicroTooltip();
    }

    private void OnMicroTooltipTimerTick(object? sender, EventArgs e)
    {
        microTooltipTimer.Stop();
        if (pendingTooltipButton is null || !hovered) return;

        var label = GetMicroTooltipForButton(pendingTooltipButton);
        if (string.IsNullOrWhiteSpace(label)) return;

        MicroTooltipText.Text = label;
        MicroTooltipText.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
        var labelWidth = MicroTooltipText.DesiredSize.Width;
        var barWidth = Math.Max(180, HoverToolbar.ActualWidth);
        var trackWidth = Math.Max(barWidth, labelWidth + 12);
        MicroTooltipTrack.Width = trackWidth;

        // Center directly above/below the hovered icon & clamp cleanly inside the track
        var btnCenter = pendingTooltipButton.TranslatePoint(new System.Windows.Point(pendingTooltipButton.ActualWidth / 2, 0), HoverToolbar);
        var barOffset = (trackWidth - barWidth) / 2.0;
        var desiredX = Math.Clamp(barOffset + btnCenter.X - labelWidth / 2, 0, Math.Max(0, trackWidth - labelWidth));

        Canvas.SetLeft(MicroTooltipText, desiredX);
        Canvas.SetTop(MicroTooltipText, 1);

        if (InteractionMotion.AnimationsAllowed)
            MicroTooltipText.BeginAnimation(OpacityProperty, new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(110)));
        else
            MicroTooltipText.Opacity = 1.0;
    }

    private void HideMicroTooltip()
    {
        microTooltipTimer.Stop();
        if (InteractionMotion.AnimationsAllowed)
            MicroTooltipText.BeginAnimation(OpacityProperty, new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(90)));
        else
            MicroTooltipText.Opacity = 0.0;
    }

    private void OnOverlayMouseEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (mode != LyricsDisplayMode.FreeFloat || locked) return;
        hovered = true;
        UpdateToolbarPlacement();
        SetHoverToolbarVisible(true);
        UpdateHoverChrome();
    }

    private void OnOverlayMouseLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (dragging) return;
        hovered = false;
        HideMicroTooltip();
        QuickColorPopover.Visibility = Visibility.Collapsed;
        SetHoverToolbarVisible(false);
        UpdateHoverChrome();
    }

    private void OnCapsuleMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (locked || mode != LyricsDisplayMode.FreeFloat || e.LeftButton != MouseButtonState.Pressed) return;
        StartDirectDrag();
        e.Handled = true;
    }

    private void StartDirectDrag()
    {
        if (dragging || locked || mode != LyricsDisplayMode.FreeFloat) return;
        var currentHandle = handle != IntPtr.Zero ? handle : new WindowInteropHelper(this).Handle;
        if (currentHandle == IntPtr.Zero) return;
        handle = currentHandle;

        if (!WindowClickThroughHelper.GetCursorPos(out dragStartCursorPx)) return;
        if (!WindowClickThroughHelper.GetWindowRect(handle, out dragStartRectPx)) return;

        dragging = true;
        dragMoved = false;
        HideMicroTooltip();
        QuickColorPopover.Visibility = Visibility.Collapsed;
        UpdateHoverChrome();
        dragPollTimer.Start();
    }

    private void OnDragPollTick(object? sender, EventArgs e)
    {
        if (!dragging || locked || mode != LyricsDisplayMode.FreeFloat || handle == IntPtr.Zero)
        {
            FinishDirectDrag(commit: false);
            return;
        }

        var buttonStillHeld = WindowClickThroughHelper.IsLeftMouseButtonDown() || Mouse.LeftButton == MouseButtonState.Pressed;
        if (!buttonStillHeld)
        {
            FinishDirectDrag(commit: dragMoved);
            return;
        }

        if (!WindowClickThroughHelper.GetCursorPos(out var nowPx)) return;
        var dx = nowPx.X - dragStartCursorPx.X;
        var dy = nowPx.Y - dragStartCursorPx.Y;
        if (Math.Abs(dx) < 1 && Math.Abs(dy) < 1) return;
        dragMoved = true;

        var proposed = new NativeWindowRect
        {
            Left = dragStartRectPx.Left + dx,
            Top = dragStartRectPx.Top + dy,
            Right = dragStartRectPx.Right + dx,
            Bottom = dragStartRectPx.Bottom + dy
        };

        var screen = Forms.Screen.FromPoint(new System.Drawing.Point(nowPx.X, nowPx.Y))
            ?? Forms.Screen.PrimaryScreen;
        var workPx = screen is not null
            ? new NativeWindowRect { Left = screen.WorkingArea.Left, Top = screen.WorkingArea.Top, Right = screen.WorkingArea.Right, Bottom = screen.WorkingArea.Bottom }
            : ResolveScreenWorkAreaPixels(activeSettings?.DisplayScreen ?? "Primary");

        var dpi = Math.Max(1.0, VisualTreeHelper.GetDpi(this).DpiScaleX);
        var snapPx = (int)Math.Round(MagneticSnapThresholdDip * dpi);
        var insetPx = (int)Math.Round(4.0 * dpi);
        var altBypass = WindowClickThroughHelper.IsAltKeyDown();
        var capsuleInsetsPx = ComputeCapsuleInsetsPixels(dpi);

        var snapped = WindowClickThroughHelper.SnapFreeWindowRect(proposed, workPx, snapPx, insetPx, altBypass, capsuleInsetsPx);
        WindowClickThroughHelper.MoveWindowPixelsNoActivate(handle, snapped.Rect.Left, snapped.Rect.Top);
        Left = snapped.Rect.Left / dpi;
        Top = snapped.Rect.Top / dpi;
        SnapGuide.Visibility = snapped.SnappedCenterX ? Visibility.Visible : Visibility.Collapsed;
        UpdateToolbarPlacement();
    }

    private void FinishDirectDrag(bool commit)
    {
        dragPollTimer.Stop();
        var wasDragging = dragging;
        dragging = false;
        dragMoved = false;
        SnapGuide.Visibility = Visibility.Collapsed;
        if (!wasDragging) return;

        UpdateToolbarPlacement();
        if (commit && !locked) PositionCommitted?.Invoke(Left, Top);
        if (!IsMouseOver)
        {
            hovered = false;
            HideMicroTooltip();
            QuickColorPopover.Visibility = Visibility.Collapsed;
            SetHoverToolbarVisible(false);
        }
        UpdateHoverChrome();
    }

    private void OnLockClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        LockToggled?.Invoke();
    }

    private void OnOrientationClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        verticalLayout = !verticalLayout;
        OrientationToggled?.Invoke(verticalLayout);
    }

    private void OnToggleQuickColorClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        QuickColorPopover.Visibility = QuickColorPopover.Visibility == Visibility.Visible
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    private void OnOpenMainClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        OpenMainRequested?.Invoke();
    }

    private void OnOpenSettingsClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        OpenSettingsRequested?.Invoke();
    }

    private void OnHideClick(object sender, RoutedEventArgs e)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        HideRequested?.Invoke();
    }
}
