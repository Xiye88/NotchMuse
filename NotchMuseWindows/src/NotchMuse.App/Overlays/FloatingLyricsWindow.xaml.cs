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

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out NativePoint pt);

    [StructLayout(LayoutKind.Sequential)]
    private readonly record struct NativePoint(int X, int Y);

    private readonly DispatcherTimer microTooltipTimer = new() { Interval = TimeSpan.FromMilliseconds(150) };

    private IntPtr handle;
    private LyricsDisplayMode mode = LyricsDisplayMode.FreeFloat;
    private AppSettings? activeSettings;
    private bool locked;
    private bool hovered;
    private bool dragging;
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
    private NativePoint dragStartCursorPx;
    private double dragStartLeft;
    private double dragStartTop;
    private double dragDpiScale = 1.0;
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
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            ApplyClickThroughStyle();
        };
        SweepHost.SizeChanged += (_, _) => UpdateSweepClip();
        VerticalSweepHost.SizeChanged += (_, _) => UpdateSweepClip();
    }

    public IntPtr WindowHandle => handle;
    public bool IsToolbarFlippedBelow => toolbarFlippedBelow;
    public bool IsQuickColorPopoverOpen => QuickColorPopover.Visibility == Visibility.Visible;

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
        verticalLayout = mode == LyricsDisplayMode.FreeFloat && settings.FloatingVerticalLayout;
        doubleLineMode = settings.FloatingDoubleLine;
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
            HideMicroTooltip();
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
        OrientationMiniBtn.Content = verticalLayout ? (english ? "Horiz" : "横排") : (english ? "Vert" : "竖排");
        ColorMiniBtn.Content = english ? "Colors" : "配色";
        OpenMainMiniBtn.Content = english ? "Home" : "主窗口";
        SettingsMiniBtn.Content = english ? "Settings" : "设置";
        HideMiniBtn.Content = english ? "Hide" : "隐藏";
        BuildQuickColorDots();
    }

    private string GetMicroTooltipForButton(System.Windows.Controls.Button btn)
    {
        var en = activeSettings?.EnglishLanguage == true;
        if (btn == LockMiniBtn) return locked ? (en ? "Unlock click-through (Ctrl+Alt+L)" : "解锁并恢复拖动 (Ctrl+Alt+L)") : (en ? "Lock & click-through (Ctrl+Alt+L)" : "锁定穿透 (Ctrl+Alt+L)");
        if (btn == OrientationMiniBtn) return verticalLayout ? (en ? "Switch to horizontal layout" : "切换为横排歌词") : (en ? "Switch to vertical layout" : "切换为竖排歌词");
        if (btn == ColorMiniBtn) return en ? "Quick solid & gradient palette" : "7 纯色 + 3 渐变快捷配色";
        if (btn == OpenMainMiniBtn) return en ? "Summon NotchMuse main window" : "召唤并置前主窗口";
        if (btn == SettingsMiniBtn) return en ? "Open settings" : "打开设置";
        if (btn == HideMiniBtn) return en ? "Hide floating lyrics" : "隐藏悬浮歌词";
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
            idleBackgroundBrush = new SolidColorBrush(locked
                ? System.Windows.Media.Color.FromArgb(0, 0, 0, 0)
                : System.Windows.Media.Color.FromArgb(1, 0, 0, 0));
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

            // Horizontal Double-Line (default): bilingual translation takes priority if present, otherwise soft next-line preview!
            if (doubleLineMode && mode == LyricsDisplayMode.FreeFloat)
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
        HoverToolbarHost.Visibility = hovered ? Visibility.Visible : Visibility.Collapsed;
        QuickColorPopover.Visibility = (hovered && openQuickColors) ? Visibility.Visible : Visibility.Collapsed;
        ApplyToolbarFlip(forceBelow);
        UpdateHoverChrome();

        if (!string.IsNullOrWhiteSpace(previewMicroTooltip) && hovered)
        {
            MicroTooltipText.Text = previewMicroTooltip;
            MicroTooltipText.Opacity = 1.0;
            Canvas.SetLeft(MicroTooltipText, 92);
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
            Height = 198;
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
        var trackWidth = Math.Max(HoverToolbar.ActualWidth, 260);
        MicroTooltipTrack.Width = trackWidth;

        // Center directly above the hovered button & clamp strictly within [0 .. trackWidth - labelWidth]
        var btnCenter = pendingTooltipButton.TranslatePoint(new System.Windows.Point(pendingTooltipButton.ActualWidth / 2, 0), HoverToolbar);
        var desiredX = Math.Clamp(btnCenter.X - labelWidth / 2, 0, Math.Max(0, trackWidth - labelWidth));

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
        HoverToolbarHost.Visibility = Visibility.Visible;
        UpdateHoverChrome();
    }

    private void OnOverlayMouseLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (dragging) return;
        hovered = false;
        HideMicroTooltip();
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
        HideMicroTooltip();
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
            HideMicroTooltip();
            QuickColorPopover.Visibility = Visibility.Collapsed;
            HoverToolbarHost.Visibility = Visibility.Collapsed;
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
