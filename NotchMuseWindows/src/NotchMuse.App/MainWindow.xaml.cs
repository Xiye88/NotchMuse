using Microsoft.Win32;
using NotchMuse.App.Controls;
using NotchMuse.App.Overlays;
using NotchMuse.App.Themes;
using NotchMuse.Core;
using NotchMuse.Platform;
using NotchMuse.Sources;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Forms = System.Windows.Forms;

namespace NotchMuse.App;

public sealed record LyricView(string DisplayText, double Time);

public partial class MainWindow : Window
{
    private const int HotkeyId = 0x4E4D;
    private const uint ModAlt = 0x0001;
    private const uint ModControl = 0x0002;
    private const uint WmHotkey = 0x0312;

    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out NativeRect rect);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder className, int maxCount);

    [StructLayout(LayoutKind.Sequential)]
    private readonly record struct NativeRect(int Left, int Top, int Right, int Bottom);

    private readonly AppSettings settings = AppSettings.Load();
    private readonly SmtcService media = new();
    private readonly HttpClient client = new(new HttpClientHandler { AutomaticDecompression = DecompressionMethods.All }) { Timeout = TimeSpan.FromSeconds(12) };
    private readonly LyricsEngine engine;
    private readonly UpdateService updateService;
    private readonly Forms.NotifyIcon tray;
    private readonly TaskbarLyricsWindow taskbarOverlay = new();
    private readonly FloatingLyricsWindow floatingOverlay = new();
    private readonly DispatcherTimer frameTimer = new() { Interval = TimeSpan.FromMilliseconds(33) };
    private readonly DispatcherTimer fullscreenTimer = new() { Interval = TimeSpan.FromMilliseconds(1500) };
    private readonly DispatcherTimer appearanceSyncTimer = new() { Interval = TimeSpan.FromMilliseconds(55) };
    private readonly DispatcherTimer updateCheckTimer = new() { Interval = TimeSpan.FromHours(6) };

    private readonly List<DesktopPreviewCard> previewCards = [];
    private readonly List<SweepLyricLineControl> lyricLineControls = [];
    private readonly Dictionary<AppearanceStylePreset, Border> presetCardMap = [];
    private readonly Dictionary<CapsuleBackgroundPreset, Border> capsuleChipMap = [];

    private readonly CancellationTokenSource windowCts = new();
    private CancellationTokenSource? lookupCts;
    private PlaybackSnapshot? snapshot;
    private LyricsCandidate? activeCandidate;
    private IReadOnlyList<LyricLine> normalizedLines = [];
    private int activeLineIndex = -1;
    private string activePage = "Lyrics";
    private string latestReleaseUrl = "https://github.com/Xiye88/NotchMuse/releases";
    private AnnouncementInfo activeAnnouncement = UpdateService.FallbackAnnouncement;
    private ReleaseInfo? availableUpdate;
    private double lastMatchedTrackDuration;
    private HwndSource? hwndSource;
    private IntPtr windowHandle;
    private bool initializing = true;
    private bool closed;
    private bool forceExit;
    private bool trayMinimizeHintShown;
    private bool draggingProgress;
    private string dragTrackKey = "";
    private int seekGeneration;
    private double optimisticSeekPosition;
    private DateTimeOffset optimisticSeekStartedAt = DateTimeOffset.MinValue;
    private DateTimeOffset optimisticSeekHoldUntil = DateTimeOffset.MinValue;
    private DateTimeOffset lastSliderTickAt = DateTimeOffset.MinValue;
    private string lastSliderStepKey = "";
    private bool sidebarCollapsed;
    private bool overlaysEnabled = true;
    private bool auditMode;
    private double auditPositionOverride = -1;
    private double currentLineSweepProgress;

    private static readonly (string NameZh, string NameEn, string Hex, string EndHex)[] SolidSwatches =
    [
        ("暖琥珀", "Warm Amber", "#E06D1B", "#FF2E88"),
        ("纯净墨", "Pure Ink", "#2A2A2E", "#5A5A64"),
        ("晴空蓝", "Sky Blue", "#3B82F6", "#A855F7"),
        ("黑胶紫", "Vinyl Violet", "#8B5CF6", "#EC4899"),
        ("森林青", "Emerald", "#22A96B", "#0EA5E9"),
        ("落日红", "Sunset Coral", "#E25D6B", "#8B5CF6"),
        ("流沙金", "Studio Gold", "#C9A24B", "#F97316"),
        ("雾海蓝", "Ocean Teal", "#0EA5A4", "#3B82F6")
    ];

    private static readonly (string NameZh, string NameEn, string StartHex, string EndHex)[] GradientSwatches =
    [
        ("日落霓虹", "Sunset Neon", "#FF7B2C", "#FF2E88"),
        ("极光青紫", "Aurora Violet", "#38BDF8", "#A855F7"),
        ("海盐薄荷", "Mint Ocean", "#10B981", "#2563EB"),
        ("微醺莓果", "Berry Dusk", "#F43F5E", "#7C3AED"),
        ("森林晴空", "Forest Sky", "#22C55E", "#06B6D4"),
        ("流金晚霞", "Molten Gold", "#FACC15", "#EA580C")
    ];

    public sealed record StylePresetSpec(
        AppearanceStylePreset Preset,
        string TitleZh,
        string TitleEn,
        string SubZh,
        string SubEn,
        string SampleText,
        string AccentHex,
        string EndHex,
        double FontSize,
        double Opacity,
        bool CapsuleEnabled,
        CapsuleBackgroundPreset CapsulePreset,
        LyricColorMode ColorMode,
        string StageBgHex1,
        string StageBgHex2,
        string MiniCapsuleHex,
        bool MiniLightCapsule);

    public static readonly StylePresetSpec[] StylePresetSpecs =
    [
        new(AppearanceStylePreset.Warm, "暖胶琥珀", "Warm Vinyl", "经典黑胶 · 雾灰底", "Classic Amber", "晚风轻吹过", "#FF8A36", "#FF2E88", 22, 1.0, true, CapsuleBackgroundPreset.SoftGray, LyricColorMode.Solid, "#2A2622", "#3E352E", "#D63E3E44", false),
        new(AppearanceStylePreset.Minimal, "雪花极简", "Alabaster", "浅色奶白 · 晴空蓝", "Frosted Light", "故事的小黄花", "#2563EB", "#60A5FA", 20, 0.96, true, CapsuleBackgroundPreset.FrostedPaper, LyricColorMode.Solid, "#D9DDE4", "#ECE9E1", "#EBF8F6F1", true),
        new(AppearanceStylePreset.SunsetGlow, "日落微醺", "Sunset Glow", "橙粉霓虹 · 暗黑胶", "Neon Sunset", "多少人为生命", "#FF7B2C", "#FF2E88", 23, 1.0, true, CapsuleBackgroundPreset.ObsidianDark, LyricColorMode.Gradient, "#2E1C2B", "#492435", "#DC18181C", false),
        new(AppearanceStylePreset.Soft, "极光幻境", "Aurora", "青紫渐变 · 深海蓝", "Aurora Glow", "请你打开电视", "#38BDF8", "#A855F7", 23, 0.98, true, CapsuleBackgroundPreset.SlateBlue, LyricColorMode.Gradient, "#162036", "#2B2246", "#D91E293B", false),
        new(AppearanceStylePreset.MintSoda, "汽水薄荷", "Mint Soda", "薄荷晴空 · 通透渐变", "Mint Breeze", "珍惜一切拥有", "#10B981", "#06B6D4", 22, 0.96, true, CapsuleBackgroundPreset.SlateBlue, LyricColorMode.Gradient, "#142B2D", "#1E3A4A", "#D61B2E35", false),
        new(AppearanceStylePreset.SakuraMist, "樱花绯雾", "Sakura Mist", "樱粉柔紫 · 磨砂白", "Sakura Light", "跌倒了别害怕", "#EC4899", "#8B5CF6", 21, 0.96, true, CapsuleBackgroundPreset.FrostedPaper, LyricColorMode.Gradient, "#EAD8E4", "#F2E6EE", "#ECF8F6F1", true),
        new(AppearanceStylePreset.ObsidianGold, "黑胶流金", "Studio Gold", "熔金渐变 · 曜石黑", "Liquid Gold", "我们是不是该", "#FACC15", "#F97316", 24, 1.0, true, CapsuleBackgroundPreset.ObsidianDark, LyricColorMode.Gradient, "#1E1B16", "#332A1C", "#E018181C", false),
        new(AppearanceStylePreset.Pure, "纯享无框", "Pure Glass", "零背景框 · 纯白大字", "No Backdrop", "微风拂过耳畔", "#FFFFFF", "#38BDF8", 26, 1.0, false, CapsuleBackgroundPreset.Transparent, LyricColorMode.Solid, "#2B374B", "#495C78", "#24FFFFFF", false)
    ];

    public MainWindow(bool isAuditMode = false)
    {
        auditMode = isAuditMode;
        engine = LyricsEngine.Create(client);
        updateService = new UpdateService(client);
        tray = new Forms.NotifyIcon { Icon = CreateTrayIcon(), Visible = !isAuditMode, Text = "NotchMuse" };

        InitializeComponent();
        InteractionSoundEngine.Enabled = settings.InteractionSoundsEnabled;
        BuildDynamicControls();
        WireOverlays();
        SetupTrayMenu();
        SyncControlsFromSettings();

        frameTimer.Tick += (_, _) => OnAnimationTick();
        fullscreenTimer.Tick += (_, _) => CheckFullscreenAndTaskbarZOrder();
        appearanceSyncTimer.Tick += (_, _) =>
        {
            appearanceSyncTimer.Stop();
            taskbarOverlay.UpdateAppearance(settings);
            floatingOverlay.ApplyAppearance(settings);
        };
        updateCheckTimer.Tick += async (_, _) =>
        {
            if (settings.AutoUpdateEnabled) await RefreshReleaseInfoAsync(checkUpdates: true);
        };
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        Closing += OnWindowClosing;
        MissingLyricsArt.RetryClicked += () => { if (snapshot is not null) UpdateTrack(snapshot); };

        initializing = false;
    }

    private static System.Drawing.Icon CreateTrayIcon()
    {
        var executable = Environment.ProcessPath;
        return executable is not null
            ? System.Drawing.Icon.ExtractAssociatedIcon(executable) ?? System.Drawing.SystemIcons.Application
            : System.Drawing.SystemIcons.Application;
    }

    private void BuildDynamicControls()
    {
        // 1. Three Win11 Desktop Preview Cards on Display Page
        DesktopPreviewCardsHost.Children.Clear();
        previewCards.Clear();
        foreach (var mode in new[] { LyricsDisplayMode.Taskbar, LyricsDisplayMode.TopIsland, LyricsDisplayMode.FreeFloat })
        {
            var card = new DesktopPreviewCard(mode) { Margin = new Thickness(4, 0, 4, 0), RenderTransformOrigin = new System.Windows.Point(0.5, 0.5) };
            card.ModeSelected += nextMode =>
            {
                InteractionMotion.Rebound(card, 0.97);
                InteractionSoundEngine.Play(InteractionSoundCue.Tick);
                SelectDisplayMode(nextMode);
            };
            previewCards.Add(card);
            DesktopPreviewCardsHost.Children.Add(card);
        }

        // 2. Display Screen Monitor List
        RefreshDisplayMonitors();

        // 3. Five-Group Player Dropdown & Default Launch Player on General Page
        PopulatePlayerCombo();
        PopulateDefaultLaunchPlayerCombo();

        // 4. Stop Behavior Dropdown
        StopBehaviorCombo.Items.Clear();
        StopBehaviorCombo.Items.Add(new ComboBoxItem { Tag = PlayerStopBehavior.Hide, Content = "隐藏歌词并等待" });
        StopBehaviorCombo.Items.Add(new ComboBoxItem { Tag = PlayerStopBehavior.Keep, Content = "保留最后一句并暂停" });

        // 5. Missing Lyrics 6-Style Dropdown
        PopulateMissingAnimationCombo();

        // 6. Appearance Swatches, Capsule Background Presets & 4 Typographic Style Preset Cards
        RebuildAppearanceSwatches();
        BuildCapsulePresetChips();
        BuildStylePresetCards();
    }

    private void WireOverlays()
    {
        taskbarOverlay.OpenMainRequested += BringMainToFront;
        floatingOverlay.LockToggled += ToggleOverlayLock;
        floatingOverlay.OrientationToggled += vertical =>
        {
            settings.FloatingVerticalLayout = vertical;
            settings.Save();
            floatingOverlay.ConfigureMode(LyricsDisplayMode.FreeFloat, settings);
        };
        floatingOverlay.QuickColorSelected += (startHex, endHex) =>
        {
            initializing = true;
            if (!string.IsNullOrWhiteSpace(endHex))
            {
                settings.ColorMode = LyricColorMode.Gradient;
                SolidColorRadio.IsChecked = false;
                GradientColorRadio.IsChecked = true;
                settings.GradientEndHex = endHex;
            }
            else
            {
                settings.ColorMode = LyricColorMode.Solid;
                SolidColorRadio.IsChecked = true;
                GradientColorRadio.IsChecked = false;
            }
            initializing = false;
            SelectAccentColors(startHex, settings.GradientEndHex);
        };
        floatingOverlay.OpenMainRequested += BringMainToFront;
        floatingOverlay.OpenSettingsRequested += () => { BringMainToFront(); NavigateTo("General"); };
        floatingOverlay.HideRequested += () => { overlaysEnabled = false; RefreshOverlayVisibility(); };
        floatingOverlay.PositionCommitted += (left, top) =>
        {
            settings.FloatingLeft = left;
            settings.FloatingTop = top;
            settings.Save();
        };
    }

    private void SetupTrayMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("任务栏左下角", null, (_, _) => Dispatcher.Invoke(() => { overlaysEnabled = true; SelectDisplayMode(LyricsDisplayMode.Taskbar); }));
        menu.Items.Add("顶部悬浮岛", null, (_, _) => Dispatcher.Invoke(() => { overlaysEnabled = true; SelectDisplayMode(LyricsDisplayMode.TopIsland); }));
        menu.Items.Add("桌面自由悬浮", null, (_, _) => Dispatcher.Invoke(() => { overlaysEnabled = true; SelectDisplayMode(LyricsDisplayMode.FreeFloat); }));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("锁定 / 解锁鼠标穿透 (Ctrl+Alt+L)", null, (_, _) => Dispatcher.Invoke(ToggleOverlayLock));
        menu.Items.Add("时间偏移 −0.5s", null, (_, _) => Dispatcher.Invoke(() => ChangeOffset(-0.5)));
        menu.Items.Add("时间偏移重置", null, (_, _) => Dispatcher.Invoke(() => ChangeOffset(-settings.TimeOffsetSeconds)));
        menu.Items.Add("时间偏移 +0.5s", null, (_, _) => Dispatcher.Invoke(() => ChangeOffset(0.5)));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("打开主窗口", null, (_, _) => Dispatcher.Invoke(BringMainToFront));
        menu.Items.Add("退出 NotchMuse", null, (_, _) => Dispatcher.Invoke(() => { forceExit = true; Close(); }));
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => Dispatcher.Invoke(BringMainToFront);
        tray.MouseClick += (_, e) =>
        {
            if (e.Button == Forms.MouseButtons.Left) Dispatcher.Invoke(BringMainToFront);
        };
    }

    private void BringMainToFront()
    {
        if (!IsVisible) Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        // Brief Topmost pulse reliably raises the window above browsers/players when summoned from a WS_EX_NOACTIVATE overlay
        Topmost = true;
        Activate();
        Topmost = false;
        Focus();
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        windowHandle = new WindowInteropHelper(this).Handle;
        ThemeManager.ApplyAppTheme(settings.ThemeMode, this);

        if (!auditMode)
        {
            hwndSource = HwndSource.FromHwnd(windowHandle);
            hwndSource?.AddHook(WindowMessageHook);
            RegisterHotKey(windowHandle, HotkeyId, ModControl | ModAlt, (uint)Forms.Keys.L);
        }

        ApplyLanguage();
        UpdateNavVisuals();
        RefreshPreviewCards();
        ApplyAppearanceToAllViews();

        if (!auditMode)
        {
            media.Changed += OnMediaChanged;
            media.Error += OnMediaError;
            frameTimer.Start();
            fullscreenTimer.Start();
            if (settings.AutoUpdateEnabled) updateCheckTimer.Start();
            RefreshOverlayVisibility();
            _ = RefreshReleaseInfoAsync(checkUpdates: settings.AutoUpdateEnabled);
            try
            {
                await media.SelectAsync(settings.PlayerSelection);
                await media.StartAsync();
            }
            catch (Exception ex) when (ex is COMException or InvalidOperationException)
            {
                DockSourceTag.Text = ex.Message;
            }
        }
    }

    private void SyncControlsFromSettings()
    {
        ThemeSystemRadio.IsChecked = settings.ThemeMode == AppThemeMode.System;
        ThemeLightRadio.IsChecked = settings.ThemeMode == AppThemeMode.Light;
        ThemeDarkRadio.IsChecked = settings.ThemeMode == AppThemeMode.Dark;

        SolidColorRadio.IsChecked = settings.ColorMode == LyricColorMode.Solid;
        GradientColorRadio.IsChecked = settings.ColorMode == LyricColorMode.Gradient;
        CustomSolidHexBox.Text = settings.AccentHex;
        UpdateCustomLyricColorControls();

        FontSizeSlider.Value = settings.FontSize;
        AnimSpeedSlider.Value = settings.AnimationSpeed;
        OpacitySlider.Value = settings.LyricOpacity;
        ShowCapsuleBgToggle.IsChecked = settings.BackgroundCapsuleEnabled && settings.CapsulePreset != CapsuleBackgroundPreset.Transparent;
        CapsuleOpacitySlider.Value = settings.CapsuleBackgroundOpacity;
        CustomCapsuleHexBox.Text = settings.CapsuleCustomHex;
        UpdateCustomCapsuleControls();

        LangZhRadio.IsChecked = !settings.EnglishLanguage;
        LangEnRadio.IsChecked = settings.EnglishLanguage;
        BilingualToggle.IsChecked = settings.BilingualEnabled;
        InteractionSoundsToggle.IsChecked = settings.InteractionSoundsEnabled;
        AutoUpdateToggle.IsChecked = settings.AutoUpdateEnabled;
        CloseToTrayToggle.IsChecked = settings.MinimizeToTrayOnClose;
        FloatingSingleLineRadio.IsChecked = !settings.FloatingDoubleLine;
        FloatingDoubleLineRadio.IsChecked = settings.FloatingDoubleLine;
        OverlayLockToggle.IsChecked = settings.OverlayLocked;

        var startup = IsStartupEnabled();
        DisplayStartupToggle.IsChecked = startup;
        GeneralStartupToggle.IsChecked = startup;

        SelectComboItemByTag(StopBehaviorCombo, settings.StopBehavior);
        SelectComboItemByTag(MissingAnimCombo, settings.MissingLyricsStyle);
        SelectComboItemByTag(PlayerSourceCombo, settings.PlayerSelection);
        SelectComboItemByTag(DefaultLaunchPlayerCombo, settings.DefaultLaunchPlayer);
        SelectComboItemByTag(DisplayScreenCombo, settings.DisplayScreen);

        UpdateOffsetReadout();
        UpdateAppearanceReadouts();
        HighlightSelectedPresetCard();
    }

    private static void SelectComboItemByTag(System.Windows.Controls.ComboBox combo, object? tag)
    {
        for (var i = 0; i < combo.Items.Count; i++)
        {
            if (combo.Items[i] is ComboBoxItem item && item.IsEnabled && Equals(item.Tag, tag))
            {
                combo.SelectedIndex = i;
                return;
            }
        }
        if (combo.Items.Count > 0 && combo.SelectedIndex < 0)
            combo.SelectedIndex = 0;
    }

    private void PopulatePlayerCombo()
    {
        PlayerSourceCombo.Items.Clear();
        var en = settings.EnglishLanguage;
        PlayerSourceCombo.Items.Add(new ComboBoxItem { Content = en ? "Automatic Detection" : "自动识别模式", IsEnabled = false });
        PlayerSourceCombo.Items.Add(new ComboBoxItem { Tag = "auto", Content = en ? "Auto (36+ Music Players & Web)" : "自动识别（36+ 音乐播放器与网页端）" });
        PlayerSourceCombo.Items.Add(new ComboBoxItem { Tag = "all", Content = en ? "All System Media Sessions" : "全部系统媒体会话" });

        foreach (var group in PlayerCatalog.Players.GroupBy(p => p.Group))
        {
            var groupLabel = en ? TranslatePlayerGroup(group.Key) : group.Key;
            PlayerSourceCombo.Items.Add(new ComboBoxItem { Content = groupLabel, IsEnabled = false });
            foreach (var player in group)
            {
                PlayerSourceCombo.Items.Add(new ComboBoxItem { Tag = player.Id, Content = player.Label });
            }
        }
        SelectComboItemByTag(PlayerSourceCombo, settings.PlayerSelection);
    }

    private static string TranslatePlayerGroup(string group) => group switch
    {
        "主流播放器" => "Mainstream Players",
        "国内与开源播放器" => "Regional & Open-Source",
        "海外、发烧友与自建库" => "Audiophile & Self-Hosted",
        _ => "Video & Media (Manual)"
    };

    private void PopulateDefaultLaunchPlayerCombo()
    {
        DefaultLaunchPlayerCombo.Items.Clear();
        var en = settings.EnglishLanguage;
        foreach (var p in DefaultPlayerLauncher.DetectAll())
        {
            var baseLabel = en ? p.LabelEn : p.LabelZh;
            var badge = p.IsInstalled ? (en ? " (Installed)" : "（已安装）") : "";
            DefaultLaunchPlayerCombo.Items.Add(new ComboBoxItem { Tag = p.Id, Content = baseLabel + badge });
        }
        SelectComboItemByTag(DefaultLaunchPlayerCombo, settings.DefaultLaunchPlayer);
    }

    private void PopulateMissingAnimationCombo()
    {
        MissingAnimCombo.Items.Clear();
        foreach (var style in Enum.GetValues<MissingLyricsAnimationStyle>())
        {
            MissingAnimCombo.Items.Add(new ComboBoxItem
            {
                Tag = style,
                Content = MissingLyricsArtControl.GetDisplayName(style, settings.EnglishLanguage)
            });
        }
        SelectComboItemByTag(MissingAnimCombo, settings.MissingLyricsStyle);
    }

    private void RefreshDisplayMonitors()
    {
        DisplayScreenCombo.Items.Clear();
        var en = settings.EnglishLanguage;
        DisplayScreenCombo.Items.Add(new ComboBoxItem { Tag = "Primary", Content = en ? "Primary Display (Default)" : "主显示器（默认）" });
        var idx = 1;
        foreach (var screen in Forms.Screen.AllScreens)
        {
            var suffix = screen.Primary ? (en ? " · Primary" : " · 主屏") : "";
            DisplayScreenCombo.Items.Add(new ComboBoxItem
            {
                Tag = screen.DeviceName,
                Content = $"{(en ? "Display" : "显示器")} {idx++} ({screen.Bounds.Width}×{screen.Bounds.Height}){suffix}"
            });
        }
        SelectComboItemByTag(DisplayScreenCombo, settings.DisplayScreen);
    }

    private void RebuildAppearanceSwatches()
    {
        AppearanceSwatchesPanel.Children.Clear();
        if (settings.ColorMode == LyricColorMode.Solid)
        {
            foreach (var swatch in SolidSwatches)
            {
                var btn = new System.Windows.Controls.Button
                {
                    Style = (Style)FindResource("ColorDotButton"),
                    Width = 28,
                    Height = 28,
                    Margin = new Thickness(0, 0, 10, 6),
                    Background = new SolidColorBrush(ThemeManager.ParseColor(swatch.Hex, Colors.DarkOrange)),
                    ToolTip = settings.EnglishLanguage ? swatch.NameEn : swatch.NameZh,
                    Tag = string.Equals(settings.AccentHex, swatch.Hex, StringComparison.OrdinalIgnoreCase) ? "Selected" : null
                };
                var hex = swatch.Hex;
                var endHex = swatch.EndHex;
                btn.Click += (_, _) => SelectAccentColors(hex, endHex);
                AppearanceSwatchesPanel.Children.Add(btn);
            }
        }
        else
        {
            foreach (var g in GradientSwatches)
            {
                var brush = new LinearGradientBrush(
                    ThemeManager.ParseColor(g.StartHex, Colors.DarkOrange),
                    ThemeManager.ParseColor(g.EndHex, Colors.Gold),
                    new System.Windows.Point(0, 0.5),
                    new System.Windows.Point(1, 0.5));
                var btn = new System.Windows.Controls.Button
                {
                    Style = (Style)FindResource("ColorDotButton"),
                    Width = 34,
                    Height = 28,
                    Margin = new Thickness(0, 0, 10, 6),
                    Background = brush,
                    ToolTip = settings.EnglishLanguage ? g.NameEn : g.NameZh,
                    Tag = string.Equals(settings.AccentHex, g.StartHex, StringComparison.OrdinalIgnoreCase) &&
                          string.Equals(settings.GradientEndHex, g.EndHex, StringComparison.OrdinalIgnoreCase)
                        ? "Selected"
                        : null
                };
                var sHex = g.StartHex;
                var eHex = g.EndHex;
                btn.Click += (_, _) => SelectAccentColors(sHex, eHex);
                AppearanceSwatchesPanel.Children.Add(btn);
            }
        }
    }

    private void BuildCapsulePresetChips()
    {
        CapsulePresetPanel.Children.Clear();
        capsuleChipMap.Clear();

        var en = settings.EnglishLanguage;
        var items = new (CapsuleBackgroundPreset Preset, string NameZh, string NameEn, string Hex)[]
        {
            (CapsuleBackgroundPreset.SoftGray, "柔和雾灰", "Soft Gray", "#3E3E44"),
            (CapsuleBackgroundPreset.FrostedPaper, "磨砂奶白", "Frosted Paper", "#F8F6F1"),
            (CapsuleBackgroundPreset.ObsidianDark, "经典黑胶", "Obsidian Dark", "#18181C"),
            (CapsuleBackgroundPreset.SlateBlue, "深海雾蓝", "Slate Blue", "#1E293B"),
            (CapsuleBackgroundPreset.Transparent, "极简无背景", "Transparent", ""),
            (CapsuleBackgroundPreset.Custom, "自定义", "Custom", settings.CapsuleCustomHex)
        };

        foreach (var item in items)
        {
            var chip = new Border
            {
                CornerRadius = new CornerRadius(9),
                BorderThickness = new Thickness(1),
                Padding = new Thickness(10, 6, 12, 6),
                Margin = new Thickness(0, 0, 8, 8),
                Cursor = System.Windows.Input.Cursors.Hand
            };

            var row = new StackPanel { Orientation = System.Windows.Controls.Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

            UIElement swatch;
            if (item.Preset == CapsuleBackgroundPreset.Transparent)
            {
                // Clean diagonal slash circle indicating pure transparent mode
                var grid = new Grid { Width = 15, Height = 15, Margin = new Thickness(0, 0, 7, 0) };
                var ring = new System.Windows.Shapes.Ellipse { Width = 15, Height = 15, StrokeThickness = 1.2 };
                ring.SetResourceReference(System.Windows.Shapes.Shape.StrokeProperty, "TextSecondaryBrush");
                var slash = new System.Windows.Shapes.Line { X1 = 3, Y1 = 12, X2 = 12, Y2 = 3, StrokeThickness = 1.2 };
                slash.SetResourceReference(System.Windows.Shapes.Shape.StrokeProperty, "AccentBrush");
                grid.Children.Add(ring);
                grid.Children.Add(slash);
                swatch = grid;
            }
            else
            {
                swatch = new Border
                {
                    Width = 15,
                    Height = 15,
                    CornerRadius = new CornerRadius(7.5),
                    Margin = new Thickness(0, 0, 7, 0),
                    Background = new SolidColorBrush(ThemeManager.ParseColor(item.Hex, System.Windows.Media.Color.FromRgb(62, 62, 68))),
                    BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(65, 128, 128, 128)),
                    BorderThickness = new Thickness(0.8)
                };
            }

            var label = new TextBlock
            {
                Text = en ? item.NameEn : item.NameZh,
                FontSize = 12,
                FontWeight = FontWeights.Medium,
                VerticalAlignment = VerticalAlignment.Center
            };
            label.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");

            row.Children.Add(swatch);
            row.Children.Add(label);
            chip.Child = row;

            var captured = item.Preset;
            chip.MouseLeftButtonUp += (_, _) => SelectCapsulePreset(captured);
            capsuleChipMap[item.Preset] = chip;
            CapsulePresetPanel.Children.Add(chip);
        }

        HighlightSelectedCapsuleChip();
    }

    private void SelectCapsulePreset(CapsuleBackgroundPreset preset)
    {
        initializing = true;
        settings.CapsulePreset = preset;
        settings.BackgroundCapsuleEnabled = preset != CapsuleBackgroundPreset.Transparent;
        ShowCapsuleBgToggle.IsChecked = settings.BackgroundCapsuleEnabled;
        if (preset != CapsuleBackgroundPreset.Transparent && preset != CapsuleBackgroundPreset.Custom)
        {
            settings.CapsuleBackgroundOpacity = AppSettings.GetCapsulePresetDefaults(preset).DefaultOpacity;
            CapsuleOpacitySlider.Value = settings.CapsuleBackgroundOpacity;
        }
        UpdateCustomCapsuleControls();
        initializing = false;

        settings.Save();
        HighlightSelectedCapsuleChip();
        ApplyAppearanceToAllViews();
    }

    private void OnShowCapsuleBgToggleChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        var enabled = ShowCapsuleBgToggle.IsChecked == true;
        initializing = true;
        settings.BackgroundCapsuleEnabled = enabled;
        if (enabled && settings.CapsulePreset == CapsuleBackgroundPreset.Transparent)
        {
            settings.CapsulePreset = CapsuleBackgroundPreset.SoftGray;
            settings.CapsuleBackgroundOpacity = AppSettings.GetCapsulePresetDefaults(CapsuleBackgroundPreset.SoftGray).DefaultOpacity;
            CapsuleOpacitySlider.Value = settings.CapsuleBackgroundOpacity;
        }
        UpdateCustomCapsuleControls();
        initializing = false;

        settings.Save();
        HighlightSelectedCapsuleChip();
        ApplyAppearanceToAllViews();
    }

    private void HighlightSelectedCapsuleChip()
    {
        foreach (var (preset, chip) in capsuleChipMap)
        {
            if (preset == settings.CapsulePreset)
            {
                chip.SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
                chip.SetResourceReference(Border.BorderBrushProperty, "AccentBrush");
                chip.BorderThickness = new Thickness(1.5);
            }
            else
            {
                chip.SetResourceReference(Border.BackgroundProperty, "CardBrush");
                chip.SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");
                chip.BorderThickness = new Thickness(1);
            }
        }
    }

    private void UpdateCustomCapsuleControls()
    {
        var bgEnabled = settings.BackgroundCapsuleEnabled && settings.CapsulePreset != CapsuleBackgroundPreset.Transparent;
        CapsuleStyleControls.IsEnabled = bgEnabled;
        CapsuleStyleControls.Opacity = bgEnabled ? 1.0 : 0.42;

        CustomCapsuleBar.Visibility = bgEnabled && settings.CapsulePreset == CapsuleBackgroundPreset.Custom
            ? Visibility.Visible
            : Visibility.Collapsed;
        CustomCapsuleSwatch.Background = new SolidColorBrush(
            ThemeManager.ParseColor(settings.CapsuleCustomHex, System.Windows.Media.Color.FromRgb(62, 62, 68)));
        CapsuleOpacityRow.IsEnabled = bgEnabled;
        CapsuleOpacityRow.Opacity = bgEnabled ? 1.0 : 0.42;
        CapsuleOpacityValueText.Text = !bgEnabled
            ? "0%"
            : $"{Math.Round(settings.CapsuleBackgroundOpacity * 100):0}%";
    }

    private void BuildStylePresetCards()
    {
        StylePresetsHost.Children.Clear();
        presetCardMap.Clear();

        var en = settings.EnglishLanguage;
        foreach (var spec in StylePresetSpecs)
        {
            var card = new Border
            {
                CornerRadius = new CornerRadius(12),
                BorderThickness = new Thickness(1),
                Padding = new Thickness(7, 7, 7, 9),
                Margin = new Thickness(4, 0, 4, 8),
                Cursor = System.Windows.Input.Cursors.Hand,
                RenderTransformOrigin = new System.Windows.Point(0.5, 0.5)
            };
            card.SetResourceReference(Border.BackgroundProperty, "CardBrush");
            card.SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");

            var stack = new StackPanel();

            // Miniature live lyric stage preview (shows exact backdrop + capsule + solid/gradient lyric brush!)
            var stageBg = new LinearGradientBrush(
                ThemeManager.ParseColor(spec.StageBgHex1, System.Windows.Media.Color.FromRgb(36, 38, 46)),
                ThemeManager.ParseColor(spec.StageBgHex2, System.Windows.Media.Color.FromRgb(56, 60, 74)),
                new System.Windows.Point(0, 0),
                new System.Windows.Point(1, 1));

            var stage = new Border
            {
                Height = 52,
                CornerRadius = new CornerRadius(8),
                Background = stageBg,
                Padding = new Thickness(6),
                Margin = new Thickness(0, 0, 0, 8),
                ClipToBounds = true
            };

            System.Windows.Media.Brush sampleBrush = spec.ColorMode == LyricColorMode.Gradient
                ? new LinearGradientBrush(
                    ThemeManager.ParseColor(spec.AccentHex, Colors.Orange),
                    ThemeManager.ParseColor(spec.EndHex, Colors.DeepPink),
                    new System.Windows.Point(0, 0.5),
                    new System.Windows.Point(1, 0.5))
                : new SolidColorBrush(ThemeManager.ParseColor(spec.AccentHex, Colors.Orange));

            var miniCapsule = new Border
            {
                CornerRadius = new CornerRadius(7),
                Padding = new Thickness(8, 3.5, 8, 3.5),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Background = spec.CapsuleEnabled
                    ? new SolidColorBrush(ThemeManager.ParseColor(spec.MiniCapsuleHex, System.Windows.Media.Color.FromArgb(210, 40, 40, 46)))
                    : System.Windows.Media.Brushes.Transparent,
                BorderBrush = spec.CapsuleEnabled
                    ? new SolidColorBrush(spec.MiniLightCapsule ? System.Windows.Media.Color.FromArgb(35, 0, 0, 0) : System.Windows.Media.Color.FromArgb(46, 255, 255, 255))
                    : new SolidColorBrush(System.Windows.Media.Color.FromArgb(60, 255, 255, 255)),
                BorderThickness = new Thickness(spec.CapsuleEnabled ? 0.75 : 0.6)
            };

            var miniStack = new StackPanel { HorizontalAlignment = System.Windows.HorizontalAlignment.Center };
            miniStack.Children.Add(new TextBlock
            {
                Style = null,
                Text = spec.SampleText,
                FontFamily = (System.Windows.Media.FontFamily)FindResource("StudioDisplayFont"),
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Foreground = sampleBrush,
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center
            });
            miniStack.Children.Add(new TextBlock
            {
                Style = null,
                Text = "♪ NotchMuse",
                FontFamily = (System.Windows.Media.FontFamily)FindResource("StudioFont"),
                FontSize = 8,
                Foreground = new SolidColorBrush(spec.MiniLightCapsule ? System.Windows.Media.Color.FromArgb(150, 40, 40, 44) : System.Windows.Media.Color.FromArgb(160, 240, 240, 244)),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
                Margin = new Thickness(0, 1, 0, 0)
            });
            miniCapsule.Child = miniStack;
            stage.Child = miniCapsule;

            // Title row + Solid/Gradient mini tag
            var headerRow = new Grid { Margin = new Thickness(2, 0, 2, 0) };
            var nameTb = new TextBlock
            {
                Text = en ? spec.TitleEn : spec.TitleZh,
                FontSize = 12.5,
                FontWeight = FontWeights.SemiBold,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            nameTb.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");

            var modeBadge = new Border
            {
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(4, 1, 4, 1),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            modeBadge.SetResourceReference(Border.BackgroundProperty, "ControlBrush");
            var modeTag = new TextBlock
            {
                Text = spec.ColorMode == LyricColorMode.Gradient ? (en ? "Grad" : "渐变") : (en ? "Solid" : "纯色"),
                FontSize = 9,
                FontWeight = FontWeights.Medium
            };
            modeTag.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
            modeBadge.Child = modeTag;

            headerRow.Children.Add(nameTb);
            headerRow.Children.Add(modeBadge);

            var descTb = new TextBlock
            {
                Text = en ? spec.SubEn : spec.SubZh,
                FontSize = 10.5,
                Margin = new Thickness(2, 2.5, 2, 0),
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            descTb.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");

            stack.Children.Add(stage);
            stack.Children.Add(headerRow);
            stack.Children.Add(descTb);
            card.Child = stack;

            var captured = spec;
            card.MouseLeftButtonUp += (_, _) =>
            {
                InteractionMotion.Rebound(card, 0.97);
                InteractionSoundEngine.Play(InteractionSoundCue.Step);
                ApplyStylePreset(captured);
            };
            presetCardMap[spec.Preset] = card;
            StylePresetsHost.Children.Add(card);
        }

        HighlightSelectedPresetCard();
    }

    private void ApplyStylePreset(StylePresetSpec spec)
    {
        initializing = true;
        settings.StylePreset = spec.Preset;
        settings.ColorMode = spec.ColorMode;
        settings.AccentHex = spec.AccentHex;
        settings.GradientEndHex = spec.EndHex;
        settings.FontSize = spec.FontSize;
        settings.LyricOpacity = spec.Opacity;
        settings.BackgroundCapsuleEnabled = spec.CapsuleEnabled;
        settings.CapsulePreset = spec.CapsulePreset;
        if (settings.CapsulePreset != CapsuleBackgroundPreset.Transparent)
            settings.CapsuleBackgroundOpacity = AppSettings.GetCapsulePresetDefaults(settings.CapsulePreset).DefaultOpacity;
        SyncControlsFromSettings();
        initializing = false;

        settings.Save();
        RebuildAppearanceSwatches();
        HighlightSelectedCapsuleChip();
        HighlightSelectedPresetCard();
        ApplyAppearanceToAllViews();
    }

    private void HighlightSelectedPresetCard()
    {
        foreach (var (preset, border) in presetCardMap)
        {
            if (preset == settings.StylePreset)
            {
                border.SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
                border.SetResourceReference(Border.BorderBrushProperty, "AccentBrush");
                border.BorderThickness = new Thickness(1.6);
            }
            else
            {
                border.SetResourceReference(Border.BackgroundProperty, "CardBrush");
                border.SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");
                border.BorderThickness = new Thickness(1);
            }
        }
    }

    private void SelectAccentColors(string startHex, string endHex)
    {
        settings.AccentHex = startHex;
        settings.GradientEndHex = endHex;
        initializing = true;
        CustomSolidHexBox.Text = startHex;
        initializing = false;
        settings.Save();
        RebuildAppearanceSwatches();
        UpdateCustomLyricColorControls();
        ApplyAppearanceToAllViews();
    }

    private void UpdateCustomLyricColorControls()
    {
        var isGradient = settings.ColorMode == LyricColorMode.Gradient;
        CustomSolidColorBar.Visibility = isGradient ? Visibility.Collapsed : Visibility.Visible;
        CustomGradientColorBar.Visibility = isGradient ? Visibility.Visible : Visibility.Collapsed;

        var startColor = ThemeManager.ParseColor(settings.AccentHex, System.Windows.Media.Color.FromRgb(224, 109, 27));
        var endColor = ThemeManager.ParseColor(settings.GradientEndHex, System.Windows.Media.Color.FromRgb(255, 46, 136));
        CustomSolidSwatch.Background = new SolidColorBrush(startColor);
        CustomGradStartSwatch.Background = new SolidColorBrush(startColor);
        CustomGradEndSwatch.Background = new SolidColorBrush(endColor);
        CustomGradPreviewPill.Background = new LinearGradientBrush(startColor, endColor, new System.Windows.Point(0, 0.5), new System.Windows.Point(1, 0.5));
    }

    private void UpdateAppearanceLivePreview()
    {
        NavAppearanceColorRing.Fill = ThemeManager.CreateLyricAccentBrush(settings);
    }

    private void ApplyAppearanceToAllViews()
    {
        UpdateCustomLyricColorControls();
        UpdateAppearanceReadouts();
        UpdateAppearanceLivePreview();
        RefreshLyricLineHighlights(forceAll: true);
        taskbarOverlay.UpdateAppearance(settings);
        floatingOverlay.ApplyAppearance(settings);
    }

    private void UpdateAppearanceReadouts()
    {
        FontSizeValueText.Text = $"{Math.Round(settings.FontSize):0} px";
        AnimSpeedValueText.Text = $"{settings.AnimationSpeed:0.0}×";
        OpacityValueText.Text = $"{Math.Round(settings.LyricOpacity * 100):0}%";
        UpdateCustomCapsuleControls();
    }

    private void UpdateOffsetReadout()
    {
        var sign = settings.TimeOffsetSeconds > 0 ? "+" : "";
        var label = settings.EnglishLanguage ? "Reset" : "重置";
        OffsetResetBtn.Content = Math.Abs(settings.TimeOffsetSeconds) < 0.01
            ? (settings.EnglishLanguage ? "0.0s Reset" : "0.0s 重置")
            : $"{sign}{settings.TimeOffsetSeconds:0.0}s {label}";
    }

    // =========================================================================
    // NAVIGATION & SIDEBAR
    // =========================================================================
    public void NavigateTo(string page)
    {
        activePage = page;
        LyricsPage.Visibility = page == "Lyrics" ? Visibility.Visible : Visibility.Collapsed;
        DisplayPage.Visibility = page == "Display" ? Visibility.Visible : Visibility.Collapsed;
        AppearancePage.Visibility = page == "Appearance" ? Visibility.Visible : Visibility.Collapsed;
        GeneralPage.Visibility = page == "General" ? Visibility.Visible : Visibility.Collapsed;
        UpdateNavVisuals();
    }

    private void UpdateNavVisuals()
    {
        var rows = new (string Page, Border Row, Border Led, TextBlock Label)[]
        {
            ("Lyrics", NavLyricsRow, NavLyricsLed, NavLyricsLabel),
            ("Display", NavDisplayRow, NavDisplayLed, NavDisplayLabel),
            ("Appearance", NavAppearanceRow, NavAppearanceLed, NavAppearanceLabel),
            ("General", NavGeneralRow, NavGeneralLed, NavGeneralLabel)
        };

        foreach (var (page, row, led, label) in rows)
        {
            var selected = page == activePage;
            if (selected)
            {
                row.SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
                led.SetResourceReference(Border.BackgroundProperty, "AccentBrush");
                label.FontWeight = FontWeights.SemiBold;
            }
            else
            {
                row.Background = System.Windows.Media.Brushes.Transparent;
                led.Background = System.Windows.Media.Brushes.Transparent;
                label.FontWeight = FontWeights.Medium;
            }
        }

        NavDisplayModeTag.Text = (settings.DisplayMode, settings.EnglishLanguage) switch
        {
            (LyricsDisplayMode.Taskbar, false) => "任务栏",
            (LyricsDisplayMode.TopIsland, false) => "悬浮岛",
            (LyricsDisplayMode.FreeFloat, false) => "自由",
            (LyricsDisplayMode.Taskbar, true) => "Taskbar",
            (LyricsDisplayMode.TopIsland, true) => "Island",
            _ => "Float"
        };

        if (activePage == "Display")
        {
            NavDisplayPill.SetResourceReference(Border.BackgroundProperty, "CardBrush");
            NavDisplayModeTag.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
        }
        else
        {
            NavDisplayPill.SetResourceReference(Border.BackgroundProperty, "ControlBrush");
            NavDisplayModeTag.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
        }
    }

    private void OnNavRowClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (sender is Border { Tag: string page } row)
        {
            InteractionMotion.Rebound(row, 0.97);
            InteractionSoundEngine.Play(InteractionSoundCue.Tick);
            NavigateTo(page);
        }
    }

    private void OnNavRowEnter(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (sender is Border { Tag: string page } row && page != activePage)
            row.SetResourceReference(Border.BackgroundProperty, "HoverRowBrush");
    }

    private void OnNavRowLeave(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (sender is Border { Tag: string page } row && page != activePage)
            row.Background = System.Windows.Media.Brushes.Transparent;
    }

    private void OnSidebarToggle(object sender, RoutedEventArgs e)
    {
        sidebarCollapsed = !sidebarCollapsed;
        SidebarColumn.Width = sidebarCollapsed ? new GridLength(0) : new GridLength(224);
        SplitterColumn.Width = sidebarCollapsed ? new GridLength(0) : new GridLength(1);
        ExpandSidebarBtn.Visibility = sidebarCollapsed ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnSidebarSplitterDragCompleted(object sender, System.Windows.Controls.Primitives.DragCompletedEventArgs e)
    {
        if (SidebarColumn.Width.Value < 110)
        {
            sidebarCollapsed = true;
            SidebarColumn.Width = new GridLength(0);
            SplitterColumn.Width = new GridLength(0);
            ExpandSidebarBtn.Visibility = Visibility.Visible;
        }
        else if (SidebarColumn.Width.Value < 190)
        {
            SidebarColumn.Width = new GridLength(224);
        }
    }

    // =========================================================================
    // DISPLAY MODES & OVERLAYS (BetterLyrics-style Win11 Taskbar + Island + Float)
    // =========================================================================
    public void SelectDisplayMode(LyricsDisplayMode nextMode)
    {
        settings.DisplayMode = nextMode;
        settings.Save();
        UpdateNavVisuals();
        RefreshPreviewCards();
        RefreshOverlayVisibility();
        PushCurrentLyricToOverlays();
        if (nextMode == LyricsDisplayMode.FreeFloat && settings.OverlayLocked)
        {
            DisplayStatusLine.Text = settings.EnglishLanguage
                ? "Click-through lock is ON · Hover desktop lyrics and click 🔒 (or press Ctrl+Alt+L) to unlock dragging"
                : "当前已开启鼠标穿透锁定 · 悬停桌面歌词点 🔒（或关闭下方锁定开关 / 按 Ctrl+Alt+L）即可拖动";
        }
    }

    private void RefreshPreviewCards()
    {
        var dark = ThemeManager.IsDarkActive;
        var sample = activeLineIndex >= 0 && activeLineIndex < normalizedLines.Count
            ? normalizedLines[activeLineIndex].Text
            : null;
        foreach (var card in previewCards)
        {
            card.Refresh(card.Mode == settings.DisplayMode, dark, settings.EnglishLanguage, sample);
        }
    }

    public static bool ShouldKeepFrontAfterModeSwitch(bool isVisible, WindowState state) =>
        isVisible && state != WindowState.Minimized;

    private void RefreshOverlayVisibility()
    {
        if (auditMode || closed) return;
        var keepMainFront = ShouldKeepFrontAfterModeSwitch(IsVisible, WindowState);

        if (!overlaysEnabled)
        {
            if (taskbarOverlay.IsVisible) taskbarOverlay.Hide();
            if (floatingOverlay.IsVisible) floatingOverlay.Hide();
            return;
        }

        if (settings.DisplayMode == LyricsDisplayMode.Taskbar)
        {
            if (floatingOverlay.IsVisible) floatingOverlay.Hide();
            taskbarOverlay.Reposition();
            taskbarOverlay.UpdateAppearance(settings);
            taskbarOverlay.SetLocked(settings.OverlayLocked);
            WindowClickThroughHelper.ShowTopmostNoActivate(taskbarOverlay, settings.OverlayLocked);
            taskbarOverlay.EnsureTopmostAboveTaskbar();
        }
        else
        {
            if (taskbarOverlay.IsVisible) taskbarOverlay.Hide();
            floatingOverlay.ConfigureMode(settings.DisplayMode, settings);
            WindowClickThroughHelper.ShowTopmostNoActivate(floatingOverlay, settings.OverlayLocked);
        }

        if (keepMainFront)
        {
            Activate();
        }
    }

    private void CheckFullscreenAndTaskbarZOrder()
    {
        if (closed || auditMode || !overlaysEnabled) return;

        var fg = GetForegroundWindow();
        var isFullscreen = false;
        if (fg != IntPtr.Zero && fg != windowHandle && fg != floatingOverlay.WindowHandle && GetWindowRect(fg, out var rect))
        {
            var cls = new System.Text.StringBuilder(64);
            _ = GetClassName(fg, cls, cls.Capacity);
            var className = cls.ToString();
            var isDesktopShell = string.Equals(className, "Progman", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(className, "WorkerW", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(className, "Shell_TrayWnd", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(className, "Shell_SecondaryTrayWnd", StringComparison.OrdinalIgnoreCase);

            var primary = Forms.Screen.PrimaryScreen?.Bounds;
            if (!isDesktopShell && primary is not null)
            {
                isFullscreen = rect.Left <= primary.Value.Left &&
                               rect.Top <= primary.Value.Top &&
                               rect.Right >= primary.Value.Right &&
                               rect.Bottom >= primary.Value.Bottom;
            }
        }

        if (isFullscreen)
        {
            if (taskbarOverlay.IsVisible) taskbarOverlay.Hide();
            if (floatingOverlay.IsVisible) floatingOverlay.Hide();
        }
        else
        {
            if (settings.DisplayMode == LyricsDisplayMode.Taskbar)
            {
                if (!taskbarOverlay.IsVisible) taskbarOverlay.Show();
                taskbarOverlay.EnsureTopmostAboveTaskbar();
            }
            else if (!floatingOverlay.IsVisible)
            {
                floatingOverlay.Show();
            }
        }
    }

    // =========================================================================
    // MEDIA PLAYBACK, LYRICS SYNC & TRUE TEXT-CLIP SWEEP ENGINE
    // =========================================================================
    private void OnMediaError(string error) => Dispatcher.InvokeAsync(() => DockSourceTag.Text = error);
    private void OnMediaChanged(PlaybackSnapshot? value) => Dispatcher.InvokeAsync(() => UpdateTrack(value));

    private async void UpdateTrack(PlaybackSnapshot? value)
    {
        if (closed) return;
        var previousKey = snapshot is null ? "" : $"{snapshot.Track.Title}|{snapshot.Track.Artist}";
        snapshot = value;
        if (value is not null && DateTimeOffset.UtcNow < optimisticSeekHoldUntil &&
            Math.Abs(value.Position - optimisticSeekPosition) < 2.2)
        {
            optimisticSeekHoldUntil = DateTimeOffset.MinValue;
        }
        UpdateTrackChrome(value);

        if (value is null)
        {
            if (settings.StopBehavior == PlayerStopBehavior.Hide)
            {
                activeCandidate = null;
                normalizedLines = [];
                RebuildLyricsLines();
            }
            return;
        }

        var nextKey = $"{value.Track.Title}|{value.Track.Artist}";
        var hasValidDuration = double.IsFinite(value.Track.Duration) && value.Track.Duration > 1.0;
        if (nextKey == previousKey && (activeCandidate is not null || (lastMatchedTrackDuration > 1.0 && hasValidDuration))) return;
        if (!hasValidDuration)
        {
            // SMTC often emits MediaPropertiesChanged with Duration=0 right before TimelinePropertiesChanged arrives.
            // Wait briefly for the real duration instead of wasting a rejected lookup!
            DockSourceTag.Text = settings.EnglishLanguage ? "Syncing timeline…" : "等待播放时长…";
            return;
        }
        lastMatchedTrackDuration = value.Track.Duration;

        lookupCts?.Cancel();
        lookupCts?.Dispose();
        lookupCts = new CancellationTokenSource();
        var ct = lookupCts.Token;

        DockSourceTag.Text = settings.EnglishLanguage ? "Matching lyrics…" : "正在匹配歌词…";
        try
        {
            var result = await engine.FindAsync(value.Track, ct);
            if (ct.IsCancellationRequested || closed) return;

            activeCandidate = result.Decision.Winner;
            normalizedLines = activeCandidate?.Document.Normalized ?? [];
            activeLineIndex = -1;

            if (activeCandidate is not null)
            {
                DockSourceTag.Text = $"{activeCandidate.Provider}";
                DisplayStatusLine.Text = $"{ResolvePlayerLabel(value)} · {value.Track.Title} — {value.Track.Artist} · {(settings.EnglishLanguage ? "Lyrics synced" : "歌词已同步")}";
            }
            else
            {
                DockSourceTag.Text = "";
                DisplayStatusLine.Text = $"{ResolvePlayerLabel(value)} · {value.Track.Title} — {value.Track.Artist} · {(settings.EnglishLanguage ? "Instrumental / No synced lyrics" : "暂无同步歌词")}";
            }

            RebuildLyricsLines();
            RefreshPreviewCards();
        }
        catch (OperationCanceledException) { }
    }

    private void UpdateTrackChrome(PlaybackSnapshot? value)
    {
        var en = settings.EnglishLanguage;
        var isPlaying = value?.Playing == true;
        var hasTrack = value is not null;

        var playerLabel = value is null ? "" : ResolvePlayerLabel(value);
        var subtitle = value is null
            ? "NotchMuse Hi-Fi"
            : string.IsNullOrWhiteSpace(value.Track.Artist) ? playerLabel : $"{value.Track.Artist} · {playerLabel}";

        VinylDeck.UpdateState(value?.Track.Title, subtitle, isPlaying, en, value?.ArtworkBytes);
        DockTrackTitle.Text = hasTrack
            ? (string.IsNullOrWhiteSpace(value!.Track.Artist) ? value.Track.Title : $"{value.Track.Title} — {value.Track.Artist}")
            : (en ? "Waiting for music…" : "等待播放音乐…");

        // Update Play/Pause crisp vector glyph
        PlayPauseGlyph.Data = Geometry.Parse(isPlaying
            ? "M 2.5,2 H 5.5 V 13 H 2.5 Z M 8.5,2 H 11.5 V 13 H 8.5 Z"
            : "M 3,2 L 12,7.5 L 3,13 Z");

        NavGeneralStatusDot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, hasTrack ? "StatusGreenBrush" : "StatusIdleBrush");
        DisplayStatusDot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, hasTrack ? "StatusGreenBrush" : "StatusIdleBrush");

        if (!hasTrack)
        {
            DockTimeText.Text = "00:00 / 00:00";
            DisplayStatusLine.Text = en
                ? "Waiting for a music player · Click any desktop card below to switch modes"
                : "等待播放器连接 · 点击下方桌面预览卡即可切换显示模式";
            taskbarOverlay.UpdateLyric(en ? "Waiting for music…" : "等待播放音乐…", null, 0, false);
            floatingOverlay.UpdateLyric(en ? "Waiting for music…" : "等待播放音乐…", null, 0, false);
        }
    }

    private static string ResolvePlayerLabel(PlaybackSnapshot snap)
    {
        var profile = PlayerCatalog.Identify(snap.AppId);
        if (profile is not null) return profile.Label;
        if (!string.IsNullOrWhiteSpace(snap.Track.Platform) && snap.Track.Platform != "unknown")
            return snap.Track.Platform;
        return "System Media";
    }

    private void RebuildLyricsLines()
    {
        LyricsLinesHost.Children.Clear();
        lyricLineControls.Clear();

        if (normalizedLines.Count == 0)
        {
            LyricsScrollViewer.Visibility = Visibility.Collapsed;
            MissingLyricsArt.Visibility = Visibility.Visible;
            MissingLyricsArt.Configure(settings.MissingLyricsStyle, snapshot is null, settings.EnglishLanguage);
            return;
        }

        MissingLyricsArt.Visibility = Visibility.Collapsed;
        LyricsScrollViewer.Visibility = Visibility.Visible;

        foreach (var line in normalizedLines)
        {
            var row = new SweepLyricLineControl(line.Start, line.Text, line.Translation, settings.BilingualEnabled);
            row.SeekRequested += async target =>
            {
                InteractionMotion.Rebound(row, 0.94);
                InteractionSoundEngine.Play(InteractionSoundCue.Step);
                await media.SeekAsync(Math.Max(0, target - settings.TimeOffsetSeconds));
            };
            lyricLineControls.Add(row);
            LyricsLinesHost.Children.Add(row);
        }

        activeLineIndex = -1;
        RefreshLyricLineHighlights(forceAll: true);
    }

    private void OnAnimationTick()
    {
        VinylDeck.StepEq(0.033 * settings.AnimationSpeed);
        if (snapshot is null) return;

        var nowPos = ComputeCurrentPositionSeconds();
        var duration = Math.Max(0, snapshot.Track.Duration);
        if (!draggingProgress && duration > 0)
        {
            ProgressSlider.Maximum = duration;
            ProgressSlider.Value = Math.Clamp(nowPos, 0, duration);
        }
        DockTimeText.Text = $"{FormatMmSs(nowPos)} / {FormatMmSs(duration)}";

        if (normalizedLines.Count == 0) return;

        var effectiveTime = nowPos + settings.TimeOffsetSeconds;
        var nextIndex = FindActiveLineIndex(effectiveTime);
        var lineProgress = ComputeLineSweepProgress(nextIndex, effectiveTime);
        currentLineSweepProgress = lineProgress;

        if (nextIndex != activeLineIndex)
        {
            activeLineIndex = nextIndex;
            RefreshLyricLineHighlights(forceAll: false, currentProgress: lineProgress);
            ScrollActiveLineToCenter();
            RefreshPreviewCards();
        }
        else if (activeLineIndex >= 0 && activeLineIndex < lyricLineControls.Count)
        {
            lyricLineControls[activeLineIndex].UpdateSweepProgress(lineProgress);
        }

        PushCurrentLyricToOverlays();
    }

    private void PushCurrentLyricToOverlays()
    {
        if (activeLineIndex < 0 || activeLineIndex >= normalizedLines.Count) return;
        var current = normalizedLines[activeLineIndex];
        var nextText = activeLineIndex + 1 < normalizedLines.Count ? normalizedLines[activeLineIndex + 1].Text : null;
        taskbarOverlay.UpdateLyric(current.Text, current.Translation, currentLineSweepProgress, settings.BilingualEnabled, nextText);
        floatingOverlay.UpdateLyric(current.Text, current.Translation, currentLineSweepProgress, settings.BilingualEnabled, nextText);
    }

    private double ComputeCurrentPositionSeconds()
    {
        if (auditPositionOverride >= 0) return auditPositionOverride;
        if (snapshot is null) return 0;
        var now = DateTimeOffset.UtcNow;
        if (now < optimisticSeekHoldUntil)
        {
            var holdElapsed = snapshot.Playing ? (now - optimisticSeekStartedAt).TotalSeconds * snapshot.Rate : 0;
            var holdPos = optimisticSeekPosition + holdElapsed;
            return snapshot.Track.Duration > 0 ? Math.Clamp(holdPos, 0, snapshot.Track.Duration) : Math.Max(0, holdPos);
        }
        var elapsed = snapshot.Playing ? (now - snapshot.CapturedAt).TotalSeconds * snapshot.Rate : 0;
        var pos = snapshot.Position + elapsed;
        return snapshot.Track.Duration > 0 ? Math.Clamp(pos, 0, snapshot.Track.Duration) : Math.Max(0, pos);
    }

    public static double ComputeSeekTargetFromPoint(double clickX, double trackWidth, double duration)
    {
        if (trackWidth <= 0 || duration <= 0) return 0;
        return Math.Clamp(clickX / trackWidth, 0, 1) * duration;
    }

    private int FindActiveLineIndex(double time)
    {
        var found = 0;
        for (var i = 0; i < normalizedLines.Count; i++)
        {
            if (normalizedLines[i].Start <= time) found = i;
            else break;
        }
        return found;
    }

    private double ComputeLineSweepProgress(int index, double time)
    {
        if (index < 0 || index >= normalizedLines.Count) return 0;
        var line = normalizedLines[index];
        var start = line.Start;
        var end = line.End ?? (index + 1 < normalizedLines.Count ? normalizedLines[index + 1].Start : start + 4.0);
        if (end <= start + 0.15) end = start + 3.2;

        // Word-level precision when timed words are present
        if (line.Words is { Count: > 0 } words)
        {
            var totalChars = Math.Max(1, words.Sum(w => w.Text.Length));
            double sweptChars = 0;
            foreach (var w in words)
            {
                if (time >= w.End) sweptChars += w.Text.Length;
                else if (time > w.Start && w.End > w.Start)
                {
                    sweptChars += w.Text.Length * ((time - w.Start) / (w.End - w.Start));
                    break;
                }
                else break;
            }
            return Math.Clamp(sweptChars / totalChars, 0, 1);
        }

        return Math.Clamp((time - start) / (end - start), 0, 1);
    }

    private void RefreshLyricLineHighlights(bool forceAll, double? currentProgress = null)
    {
        if (currentProgress.HasValue) currentLineSweepProgress = currentProgress.Value;
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        var targetIndex = activeLineIndex < 0 ? 0 : activeLineIndex;
        for (var i = 0; i < lyricLineControls.Count; i++)
        {
            var distance = Math.Abs(i - targetIndex);
            var prog = distance == 0 ? currentLineSweepProgress : (i < targetIndex ? 1.0 : 0.0);
            if (forceAll || distance <= 4)
            {
                lyricLineControls[i].ApplyVisualState(distance, prog, settings.FontSize, accentBrush, settings.LyricOpacity, animate: !auditMode && !forceAll);
            }
        }
    }

    private void ScrollActiveLineToCenter()
    {
        if (activeLineIndex < 0 || activeLineIndex >= lyricLineControls.Count) return;
        var target = lyricLineControls[activeLineIndex];
        if (!target.IsLoaded || LyricsScrollViewer.ViewportHeight <= 0) return;
        var point = target.TranslatePoint(new System.Windows.Point(0, target.ActualHeight / 2), LyricsLinesHost);
        var desiredOffset = Math.Max(0, point.Y - LyricsScrollViewer.ViewportHeight / 2 + 150);
        LyricsScrollViewer.ScrollToVerticalOffset(desiredOffset);
    }

    private static string FormatMmSs(double seconds)
    {
        var clamped = Math.Max(0, seconds);
        var ts = TimeSpan.FromSeconds(clamped);
        return string.Format(CultureInfo.InvariantCulture, "{0:00}:{1:00}", (int)ts.TotalMinutes, ts.Seconds);
    }

    // =========================================================================
    // LOCALIZATION (Full UI zh-CN <-> English)
    // =========================================================================
    private void ApplyLanguage()
    {
        var en = settings.EnglishLanguage;
        NavLyricsLabel.Text = en ? "Lyrics" : "歌词";
        NavDisplayLabel.Text = en ? "Display" : "显示";
        NavAppearanceLabel.Text = en ? "Appearance" : "外观";
        NavGeneralLabel.Text = en ? "General" : "通用";

        DisplayHeaderTitle.Text = en ? "Display" : "显示";
        DisplayPreviewLabel.Text = en ? "LIVE DESKTOP PREVIEW · CLICK TO SWITCH MODE" : "实时预览 · 点击卡片切换模式";
        FloatingLinesLabel.Text = en ? "Desktop Lyric Lines" : "桌面歌词行数";
        FloatingLinesDesc.Text = en ? "Double-line default highlights current line with upcoming next line or translation across Taskbar, Island & Float" : "默认双行显示（当前句高亮 + 柔和预告下一句或译文），同步作用于任务栏、悬浮岛与自由悬浮";
        FloatingSingleLineRadio.Content = en ? "Single" : "单行";
        FloatingDoubleLineRadio.Content = en ? "Double" : "双行";
        DisplayOffsetLabel.Text = en ? "Lyrics Time Offset" : "歌词时间偏移";
        DisplayOffsetDesc.Text = en ? "Fine-tune lyric timing ahead or behind across all views" : "微调歌词提前或延后，实时作用于所有视图";
        DisplayScreenLabel.Text = en ? "Display Monitor" : "显示屏幕";
        DisplayScreenDesc.Text = en ? "Choose which monitor hosts Top Island and Free Float" : "选择顶部悬浮岛与桌面自由悬浮所在显示器";
        DisplayStartupLabel.Text = en ? "Launch at Login" : "开机自启";
        DisplayStartupDesc.Text = en ? "Start quietly in the system tray when Windows boots" : "登录 Windows 时自动静默启动歌词服务";
        DisplayLockLabel.Text = en ? "Lock Desktop Overlay (Click-Through)" : "锁定桌面歌词（鼠标穿透）";
        DisplayLockDesc.Text = en ? "Auto-hides on hover and passes clicks straight through while locked" : "锁定后鼠标移近歌词自动隐藏避让并穿透点击，不遮挡后方按钮与窗口";

        AppearanceHeaderTitle.Text = en ? "Appearance" : "外观";
        ColorModeLabel.Text = en ? "Lyrics Color" : "歌词颜色";
        ColorModeDesc.Text = en ? "Solid or dual-hue gradient sweep with custom color palette" : "支持纯色与双色渐变扫光，并可自由调色盘选色";
        SolidColorRadio.Content = en ? "Solid" : "纯色";
        GradientColorRadio.Content = en ? "Gradient" : "渐变";
        CustomSolidLabel.Text = en ? "Custom Solid" : "自定义纯色";
        PickCustomSolidBtn.Content = en ? "Palette…" : "调色盘…";
        CustomGradLabel.Text = en ? "Custom Gradient" : "自定义渐变";
        PickGradStartBtn.Content = en ? "Start…" : "起点色…";
        PickGradEndBtn.Content = en ? "End…" : "终点色…";
        FontSizeLabel.Text = en ? "Font Size" : "字体大小";
        AnimSpeedLabel.Text = en ? "Animation Speed" : "动画速度";
        OpacityLabel.Text = en ? "Lyrics Opacity" : "歌词不透明度";
        BgCapsuleLabel.Text = en ? "Show Floating Capsule Background" : "显示悬浮胶囊背景";
        BgCapsuleDesc.Text = en ? "Turn off for pure transparent lyrics with high-contrast adaptive text halo" : "关闭后自由悬浮与顶部悬浮岛立即切为纯透明文字 + 双层高对比描边阴影";
        CapsuleOpacityLabel.Text = en ? "Background Opacity" : "背景不透明度";
        PickCustomColorBtn.Content = en ? "Palette…" : "调色盘…";
        QuickPresetsLabel.Text = en ? "QUICK STYLE PRESETS" : "风格快捷预设";

        GeneralHeaderTitle.Text = en ? "General" : "通用";
        PlayerSourceLabel.Text = en ? "Music Player" : "音乐播放器";
        PlayerSourceDesc.Text = en ? "Auto-detects 36+ desktop players and browser sessions" : "自动覆盖 36+ 主流及开源播放器与浏览器网页端";
        DefaultLaunchLabel.Text = en ? "Default Launch Player" : "默认启动播放器";
        DefaultLaunchDesc.Text = en ? "Opens your preferred player when Play is pressed with no active session" : "当前无活跃播放会话时，点击播放按钮自动拉起指定播放器";
        StopBehaviorLabel.Text = en ? "When Playback Stops" : "播放停止行为";
        StopBehaviorDesc.Text = en ? "Choose how lyrics behave when your player closes" : "当播放器退出或清空队列时的歌词显示策略";
        GeneralStartupLabel.Text = en ? "Launch at Login" : "开机自启";
        GeneralStartupDesc.Text = en ? "Start with Windows in low-memory tray mode" : "随 Windows 自动启动，保持低内存常驻托盘";
        CloseToTrayLabel.Text = en ? "Minimize to Tray on Close" : "关闭时最小化到托盘";
        CloseToTrayDesc.Text = en ? "Keep lyrics running in the bottom-right tray when closed; turn off to exit directly" : "开启后点关闭缩到右下角托盘图标继续显示歌词；关闭后直接退出程序";
        ThemeModeLabel.Text = en ? "Theme Mode" : "外观模式";
        ThemeModeDesc.Text = en ? "Light uses Braun Warm Alabaster, Dark uses Vinyl Hi-Fi" : "浅色采用 Braun 暖雪花石，深色采用黑胶 Hi-Fi 暗灰";
        ThemeSystemRadio.Content = en ? "System" : "跟随系统";
        ThemeLightRadio.Content = en ? "Light" : "浅色";
        ThemeDarkRadio.Content = en ? "Dark" : "深色";
        MissingAnimLabel.Text = en ? "No-Lyrics Micro-Animation" : "未找到歌词微动画";
        MissingAnimDesc.Text = en ? "Gentle vector illustration for instrumentals or unmatched tracks" : "纯音乐或暂无同步歌词时展示的轻巧动态插画";
        LanguageLabel.Text = en ? "Language" : "界面语言";
        LanguageDesc.Text = en ? "Applies immediately across the entire interface" : "切换全界面语言，实时生效无需重启";
        BilingualLabel.Text = en ? "Bilingual Lyrics" : "双语歌词";
        BilingualDesc.Text = en ? "Show translated lines underneath original lyrics when available" : "当歌词源包含中文翻译时，在原文下方优雅显示译文";
        InteractionSoundsLabel.Text = en ? "Interaction Micro-Sounds" : "交互微音效";
        InteractionSoundsDesc.Text = en ? "Zero-asset synthesized tactile sounds with 0% idle CPU" : "零外部素材纯内存合成微触感音效，闲置 0% CPU";
        DesktopShortcutLabel.Text = en ? "Desktop Shortcut" : "桌面快捷方式";
        DesktopShortcutDesc.Text = en ? "Installer includes a desktop shortcut option; portable users can create one here" : "安装包最后一步支持勾选创建，便携版也可在此一键创建桌面图标";
        CreateShortcutButton.Content = en ? "Create Desktop Shortcut" : "创建桌面快捷方式";
        AutoUpdateLabel.Text = en ? "Automatic Updates (Recommended)" : "自动更新（推荐开启）";
        AutoUpdateDesc.Text = en ? "Checks on launch & every 6h and alerts you in the bottom-left banner" : "启动与运行期间自动检测新版，发现更新后在左下角即时提醒下载";
        VersionTitleLabel.Text = en ? "Version" : "版本信息";
        VersionValueLabel.Text = en ? "Version v0.9.0" : "当前版本：v0.9.0";
        CheckUpdateButton.Content = availableUpdate is not null
            ? (en ? $"Download {availableUpdate.TagName}" : $"下载新版 {availableUpdate.TagName}")
            : (en ? "Check for Updates" : "检查更新");
        UpdateBottomLeftAnnouncementText();

        initializing = true;
        PopulatePlayerCombo();
        PopulateDefaultLaunchPlayerCombo();
        PopulateMissingAnimationCombo();
        RefreshDisplayMonitors();
        if (StopBehaviorCombo.Items.Count >= 2)
        {
            ((ComboBoxItem)StopBehaviorCombo.Items[0]).Content = en ? "Hide Lyrics and Wait" : "隐藏歌词并等待";
            ((ComboBoxItem)StopBehaviorCombo.Items[1]).Content = en ? "Keep Last Lyrics and Pause" : "保留最后一句并暂停";
        }
        initializing = false;

        BuildCapsulePresetChips();
        BuildStylePresetCards();
        UpdateNavVisuals();
        UpdateOffsetReadout();
        UpdateTrackChrome(snapshot);
        RefreshPreviewCards();
        MissingLyricsArt.Configure(settings.MissingLyricsStyle, snapshot is null, en);
        floatingOverlay.ApplyLanguage(en);
    }

    // =========================================================================
    // UI EVENT HANDLERS
    // =========================================================================
    private void OnTitleDrag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2) { OnMaximizeRestoreClick(sender, e); return; }
        if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed) DragMove();
    }

    private void OnMinimizeClick(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void OnMaximizeRestoreClick(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    public static bool ShouldMinimizeToTrayOnClose(bool minimizeToTraySetting, bool isAuditMode, bool isForceExit) =>
        !isAuditMode && !isForceExit && minimizeToTraySetting;

    private void MinimizeToSystemTray()
    {
        Hide();
        if (!trayMinimizeHintShown && !auditMode)
        {
            trayMinimizeHintShown = true;
            var en = settings.EnglishLanguage;
            tray.ShowBalloonTip(
                2200,
                "NotchMuse",
                en ? "Minimized to system tray. Click the tray icon to reopen." : "已缩小到右下角托盘继续运行，点击托盘图标可随时恢复主窗口",
                Forms.ToolTipIcon.None);
        }
    }

    private void OnCloseToTrayClick(object sender, RoutedEventArgs e)
    {
        if (ShouldMinimizeToTrayOnClose(settings.MinimizeToTrayOnClose, auditMode, forceExit))
        {
            MinimizeToSystemTray();
        }
        else
        {
            forceExit = true;
            Close();
        }
    }

    private void OnWindowClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (ShouldMinimizeToTrayOnClose(settings.MinimizeToTrayOnClose, auditMode, forceExit))
        {
            e.Cancel = true;
            MinimizeToSystemTray();
        }
    }

    private void OnCloseToTrayToggleChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.MinimizeToTrayOnClose = CloseToTrayToggle.IsChecked == true;
        settings.Save();
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
    }

    private void OnStateChanged(object? sender, EventArgs e) { }

    private void OnQuickThemeToggle(object sender, RoutedEventArgs e)
    {
        var next = ThemeManager.IsDarkActive ? AppThemeMode.Light : AppThemeMode.Dark;
        SetThemeMode(next);
    }

    public void SetThemeMode(AppThemeMode mode)
    {
        settings.ThemeMode = mode;
        settings.Save();
        initializing = true;
        ThemeSystemRadio.IsChecked = mode == AppThemeMode.System;
        ThemeLightRadio.IsChecked = mode == AppThemeMode.Light;
        ThemeDarkRadio.IsChecked = mode == AppThemeMode.Dark;
        initializing = false;

        ThemeManager.ApplyAppTheme(mode, this);
        UpdateThemeToggleIcon();
        RefreshPreviewCards();
        ApplyAppearanceToAllViews();
    }

    private void UpdateThemeToggleIcon()
    {
        // Sun icon when Dark (click to go Light), Moon crescent when Light (click to go Dark)
        ThemeToggleIconPath.Data = Geometry.Parse(ThemeManager.IsDarkActive
            ? "M 8,2.2 V 3.6 M 8,12.4 V 13.8 M 2.2,8 H 3.6 M 12.4,8 H 13.8 M 3.9,3.9 L 4.9,4.9 M 11.1,11.1 L 12.1,12.1 M 12.1,3.9 L 11.1,4.9 M 4.9,11.1 L 3.9,12.1 M 10.6,8 A 2.6,2.6 0 1 1 5.4,8 A 2.6,2.6 0 1 1 10.6,8 Z"
            : "M 12.5,9.6 A 5.2,5.2 0 1 1 6.4,3.5 A 4.2,4.2 0 0 0 12.5,9.6 Z");
    }

    private void OnThemeRadioChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        var mode = ThemeDarkRadio.IsChecked == true
            ? AppThemeMode.Dark
            : ThemeLightRadio.IsChecked == true
                ? AppThemeMode.Light
                : AppThemeMode.System;
        SetThemeMode(mode);
    }

    private void OnSponsorClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(SponsorIconBtn, 0.92);
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        var dialog = new SupportWindow(settings.EnglishLanguage, client) { Owner = this };
        dialog.ShowDialog();
    }

    private void OnGitHubClick(object sender, RoutedEventArgs e) => OpenExternalUrl("https://github.com/Xiye88/NotchMuse");

    private void OnAnnouncementClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        InteractionMotion.Rebound(AnnouncementCapsule, 0.96);
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        AnnouncementUnreadDot.Visibility = Visibility.Collapsed;
        var dialog = new AnnouncementWindow(activeAnnouncement, availableUpdate, settings.EnglishLanguage, updateService)
        {
            Owner = this
        };
        dialog.ShowDialog();
    }

    private static void OpenExternalUrl(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception) { }
    }

    private async void OnPlayClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(PlayPauseButton, 0.94);
        InteractionSoundEngine.Play(InteractionSoundCue.Latch);
        if (snapshot is null)
        {
            // Strictly obey DefaultLaunchPlayer: "none" stays completely silent without waking other players!
            if (string.IsNullOrWhiteSpace(settings.DefaultLaunchPlayer) ||
                string.Equals(settings.DefaultLaunchPlayer, "none", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
            if (DefaultPlayerLauncher.TryLaunch(settings.DefaultLaunchPlayer, out var playerLabel, settings.EnglishLanguage))
            {
                DockSourceTag.Text = settings.EnglishLanguage ? $"Launching {playerLabel}…" : $"正在启动 {playerLabel}…";
            }
            return;
        }
        await media.ToggleAsync();
    }

    private async void OnPreviousClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(PrevTrackButton, 0.94);
        InteractionSoundEngine.Play(InteractionSoundCue.Latch);
        if (snapshot is not null) await media.PreviousAsync();
    }

    private async void OnNextClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(NextTrackButton, 0.94);
        InteractionSoundEngine.Play(InteractionSoundCue.Latch);
        if (snapshot is not null) await media.NextAsync();
    }

    private void OnProgressMouseDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        var duration = ProgressSlider.Maximum;
        if (duration <= 0) return;
        dragTrackKey = snapshot is null ? "" : $"{snapshot.Track.Title}|{snapshot.Track.Artist}";
        var target = ComputeSeekTargetFromPoint(e.GetPosition(ProgressSlider).X, ProgressSlider.ActualWidth, duration);
        ProgressSlider.Value = target;
        DockTimeText.Text = $"{FormatMmSs(target)} / {FormatMmSs(duration)}";
        if (ProgressSlider.CaptureMouse())
        {
            draggingProgress = true;
        }
        else
        {
            _ = CommitProgressSeekAsync(target);
        }
        e.Handled = true;
    }

    private void OnProgressMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (!draggingProgress || e.LeftButton != System.Windows.Input.MouseButtonState.Pressed) return;
        var duration = ProgressSlider.Maximum;
        if (duration <= 0) return;
        var target = ComputeSeekTargetFromPoint(e.GetPosition(ProgressSlider).X, ProgressSlider.ActualWidth, duration);
        ProgressSlider.Value = target;
        DockTimeText.Text = $"{FormatMmSs(target)} / {FormatMmSs(duration)}";
        e.Handled = true;
    }

    private async void OnProgressMouseUp(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (!draggingProgress) return;
        var duration = ProgressSlider.Maximum;
        var target = ComputeSeekTargetFromPoint(e.GetPosition(ProgressSlider).X, ProgressSlider.ActualWidth, duration);
        draggingProgress = false;
        if (ProgressSlider.IsMouseCaptured) ProgressSlider.ReleaseMouseCapture();
        e.Handled = true;

        var currentKey = snapshot is null ? "" : $"{snapshot.Track.Title}|{snapshot.Track.Artist}";
        if (currentKey != dragTrackKey) return;
        await CommitProgressSeekAsync(target);
    }

    private void OnProgressLostCapture(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (!draggingProgress) return;
        draggingProgress = false;
        // Involuntary capture loss: restore displayed position cleanly without firing an unintended seek
        if (snapshot is not null && snapshot.Track.Duration > 0)
        {
            var pos = ComputeCurrentPositionSeconds();
            ProgressSlider.Value = Math.Clamp(pos, 0, snapshot.Track.Duration);
            DockTimeText.Text = $"{FormatMmSs(pos)} / {FormatMmSs(snapshot.Track.Duration)}";
        }
    }

    private async Task CommitProgressSeekAsync(double targetSeconds)
    {
        var duration = snapshot?.Track.Duration ?? ProgressSlider.Maximum;
        var clamped = duration > 0 ? Math.Clamp(targetSeconds, 0, duration) : Math.Max(0, targetSeconds);
        ProgressSlider.Value = clamped;
        DockTimeText.Text = $"{FormatMmSs(clamped)} / {FormatMmSs(duration)}";

        var myGen = Interlocked.Increment(ref seekGeneration);
        optimisticSeekPosition = clamped;
        optimisticSeekStartedAt = DateTimeOffset.UtcNow;
        optimisticSeekHoldUntil = optimisticSeekStartedAt.AddMilliseconds(1100);

        InteractionSoundEngine.Play(InteractionSoundCue.Step);
        if (normalizedLines.Count > 0)
        {
            var eff = clamped + settings.TimeOffsetSeconds;
            activeLineIndex = FindActiveLineIndex(eff);
            var prog = ComputeLineSweepProgress(activeLineIndex, eff);
            RefreshLyricLineHighlights(forceAll: false, currentProgress: prog);
            ScrollActiveLineToCenter();
        }

        try
        {
            await media.SeekAsync(clamped);
        }
        catch (Exception ex) when (ex is COMException or InvalidOperationException)
        {
            if (seekGeneration == myGen)
            {
                optimisticSeekHoldUntil = DateTimeOffset.MinValue;
            }
        }
    }

    private void OnQuickColorDotClick(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button { Background: SolidColorBrush scb } btn)
        {
            InteractionMotion.Rebound(btn, 0.94);
            InteractionSoundEngine.Play(InteractionSoundCue.Step);
            var c = scb.Color;
            var hex = $"#{c.R:X2}{c.G:X2}{c.B:X2}";
            SelectAccentColors(hex, settings.GradientEndHex);
        }
    }

    private void OnColorModeChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        var nextMode = GradientColorRadio.IsChecked == true ? LyricColorMode.Gradient : LyricColorMode.Solid;
        settings.ColorMode = nextMode;

        // Auto-upgrade near-identical colors when entering Gradient mode so Gradient is immediately dramatic & unmistakable!
        if (nextMode == LyricColorMode.Gradient && ThemeManager.HasLowColorContrast(settings.AccentHex, settings.GradientEndHex))
        {
            settings.AccentHex = GradientSwatches[0].StartHex;
            settings.GradientEndHex = GradientSwatches[0].EndHex;
            initializing = true;
            CustomSolidHexBox.Text = settings.AccentHex;
            initializing = false;
        }

        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        settings.Save();
        RebuildAppearanceSwatches();
        ApplyAppearanceToAllViews();
    }

    private void SetColorModeRadiosSynced(LyricColorMode mode)
    {
        initializing = true;
        settings.ColorMode = mode;
        SolidColorRadio.IsChecked = mode == LyricColorMode.Solid;
        GradientColorRadio.IsChecked = mode == LyricColorMode.Gradient;
        initializing = false;
    }

    private void OnCustomSolidHexChanged(object sender, TextChangedEventArgs e)
    {
        if (initializing) return;
        if (ThemeManager.TryParseRgbHex(CustomSolidHexBox.Text, out var parsed))
        {
            SetColorModeRadiosSynced(LyricColorMode.Solid);
            settings.AccentHex = $"#{parsed.R:X2}{parsed.G:X2}{parsed.B:X2}";
            settings.Save();
            RebuildAppearanceSwatches();
            ApplyAppearanceToAllViews();
        }
    }

    private void OnPickCustomSolidColor(object sender, RoutedEventArgs e)
    {
        var current = ThemeManager.ParseColor(settings.AccentHex, System.Windows.Media.Color.FromRgb(224, 109, 27));
        if (!TryPickColorFromDialog(current, out var hex)) return;
        SetColorModeRadiosSynced(LyricColorMode.Solid);
        InteractionSoundEngine.Play(InteractionSoundCue.Step);
        SelectAccentColors(hex, settings.GradientEndHex);
    }

    private void OnPickGradientStartColor(object sender, RoutedEventArgs e)
    {
        var current = ThemeManager.ParseColor(settings.AccentHex, System.Windows.Media.Color.FromRgb(255, 123, 44));
        if (!TryPickColorFromDialog(current, out var hex)) return;
        SetColorModeRadiosSynced(LyricColorMode.Gradient);
        InteractionSoundEngine.Play(InteractionSoundCue.Step);
        SelectAccentColors(hex, settings.GradientEndHex);
    }

    private void OnPickGradientEndColor(object sender, RoutedEventArgs e)
    {
        var current = ThemeManager.ParseColor(settings.GradientEndHex, System.Windows.Media.Color.FromRgb(255, 46, 136));
        if (!TryPickColorFromDialog(current, out var hex)) return;
        SetColorModeRadiosSynced(LyricColorMode.Gradient);
        InteractionSoundEngine.Play(InteractionSoundCue.Step);
        SelectAccentColors(settings.AccentHex, hex);
    }

    private static bool TryPickColorFromDialog(System.Windows.Media.Color current, out string hex)
    {
        using var dialog = new Forms.ColorDialog
        {
            FullOpen = true,
            Color = System.Drawing.Color.FromArgb(current.R, current.G, current.B)
        };
        if (dialog.ShowDialog() != Forms.DialogResult.OK)
        {
            hex = "";
            return false;
        }
        var c = dialog.Color;
        hex = $"#{c.R:X2}{c.G:X2}{c.B:X2}";
        return true;
    }

    private void OnAppearanceSliderChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (initializing) return;
        // Zero disk I/O & zero full stage reflow during drag -> butter-smooth 60fps Bencho interaction!
        settings.FontSize = Math.Round(FontSizeSlider.Value);
        settings.AnimationSpeed = Math.Round(AnimSpeedSlider.Value, 1);
        settings.LyricOpacity = Math.Round(OpacitySlider.Value, 2);

        UpdateAppearanceReadouts();
        UpdateAppearanceLivePreview();
        PlayThrottledSliderTick($"{settings.FontSize:0}|{settings.AnimationSpeed:0.0}|{Math.Round(settings.LyricOpacity * 20):0}");
        appearanceSyncTimer.Stop();
        appearanceSyncTimer.Start();
    }

    private void OnCapsuleOpacityChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (initializing) return;
        settings.CapsuleBackgroundOpacity = Math.Round(CapsuleOpacitySlider.Value, 2);
        UpdateCustomCapsuleControls();
        UpdateAppearanceLivePreview();
        PlayThrottledSliderTick($"cap|{Math.Round(settings.CapsuleBackgroundOpacity * 20):0}");
        appearanceSyncTimer.Stop();
        appearanceSyncTimer.Start();
    }

    private void OnAppearanceSliderDragCompleted(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (initializing) return;
        appearanceSyncTimer.Stop();
        settings.Save();
        ApplyAppearanceToAllViews();
    }

    private void PlayThrottledSliderTick(string stepKey)
    {
        if (stepKey == lastSliderStepKey) return;
        var now = DateTimeOffset.UtcNow;
        if ((now - lastSliderTickAt).TotalMilliseconds < 70) return;
        lastSliderStepKey = stepKey;
        lastSliderTickAt = now;
        InteractionSoundEngine.Play(InteractionSoundCue.Dial);
    }

    private void OnCustomCapsuleHexChanged(object sender, TextChangedEventArgs e)
    {
        if (initializing) return;
        if (ThemeManager.TryParseRgbHex(CustomCapsuleHexBox.Text, out var parsed))
        {
            settings.CapsuleCustomHex = $"#{parsed.R:X2}{parsed.G:X2}{parsed.B:X2}";
            settings.CapsulePreset = CapsuleBackgroundPreset.Custom;
            settings.BackgroundCapsuleEnabled = true;
            settings.Save();
            BuildCapsulePresetChips();
            ApplyAppearanceToAllViews();
        }
    }

    private void OnPickCustomCapsuleColor(object sender, RoutedEventArgs e)
    {
        var current = ThemeManager.ParseColor(settings.CapsuleCustomHex, System.Windows.Media.Color.FromRgb(62, 62, 68));
        using var dialog = new Forms.ColorDialog
        {
            FullOpen = true,
            Color = System.Drawing.Color.FromArgb(current.R, current.G, current.B)
        };
        if (dialog.ShowDialog() != Forms.DialogResult.OK) return;

        var c = dialog.Color;
        var hex = $"#{c.R:X2}{c.G:X2}{c.B:X2}";
        initializing = true;
        settings.CapsuleCustomHex = hex;
        settings.CapsulePreset = CapsuleBackgroundPreset.Custom;
        settings.BackgroundCapsuleEnabled = true;
        CustomCapsuleHexBox.Text = hex;
        initializing = false;

        settings.Save();
        BuildCapsulePresetChips();
        ApplyAppearanceToAllViews();
    }

    private void ChangeOffset(double delta)
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Dial);
        settings.TimeOffsetSeconds = Math.Round(Math.Clamp(settings.TimeOffsetSeconds + delta, -10, 10), 1);
        settings.Save();
        UpdateOffsetReadout();
    }

    private void OnFloatingLinesModeChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.FloatingDoubleLine = FloatingDoubleLineRadio.IsChecked == true;
        settings.Save();
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        taskbarOverlay.UpdateAppearance(settings);
        floatingOverlay.ApplyAppearance(settings);
        floatingOverlay.PositionOnScreen(settings);
        PushCurrentLyricToOverlays();
    }

    private void OnAutoUpdateChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.AutoUpdateEnabled = AutoUpdateToggle.IsChecked == true;
        settings.Save();
        InteractionSoundEngine.Play(InteractionSoundCue.Tick);
        if (settings.AutoUpdateEnabled)
        {
            updateCheckTimer.Start();
            _ = RefreshReleaseInfoAsync(checkUpdates: true);
        }
        else
        {
            updateCheckTimer.Stop();
        }
    }

    private void OnInteractionSoundsChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        var next = InteractionSoundsToggle.IsChecked == true;
        settings.InteractionSoundsEnabled = next;
        settings.Save();
        InteractionSoundEngine.SetEnabledWithFeedback(next);
    }

    private void OnOffsetMinus(object sender, RoutedEventArgs e) => ChangeOffset(-0.5);
    private void OnOffsetReset(object sender, RoutedEventArgs e) => ChangeOffset(-settings.TimeOffsetSeconds);
    private void OnOffsetPlus(object sender, RoutedEventArgs e) => ChangeOffset(0.5);

    private void OnDisplayScreenChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || DisplayScreenCombo.SelectedItem is not ComboBoxItem { Tag: string dev }) return;
        settings.DisplayScreen = dev;
        settings.Save();
        RefreshOverlayVisibility();
    }

    private void OnOverlayLockChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.OverlayLocked = OverlayLockToggle.IsChecked == true;
        settings.Save();
        ApplyOverlayLockState();
    }

    private void ToggleOverlayLock()
    {
        settings.OverlayLocked = !settings.OverlayLocked;
        settings.Save();
        initializing = true;
        OverlayLockToggle.IsChecked = settings.OverlayLocked;
        initializing = false;
        ApplyOverlayLockState();
    }

    private void ApplyOverlayLockState()
    {
        InteractionSoundEngine.Play(InteractionSoundCue.Latch);
        taskbarOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.ApplyLanguage(settings.EnglishLanguage);
        var en = settings.EnglishLanguage;
        DisplayStatusLine.Text = settings.OverlayLocked
            ? (en ? "Click-through LOCKED across all modes · Press Ctrl+Alt+L to unlock" : "鼠标穿透已开启（全部显示模式生效）· 按 Ctrl+Alt+L 解锁")
            : (en ? "Desktop lyrics UNLOCKED · Drag freely in Free Float mode" : "鼠标穿透已解锁 · 自由悬浮模式下可直接拖动歌词");
    }

    private void OnStartupToggleChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        var enabled = sender == DisplayStartupToggle
            ? DisplayStartupToggle.IsChecked == true
            : GeneralStartupToggle.IsChecked == true;
        SetStartup(enabled);
        initializing = true;
        DisplayStartupToggle.IsChecked = enabled;
        GeneralStartupToggle.IsChecked = enabled;
        initializing = false;
    }

    private static bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        return key?.GetValue("NotchMuse") is not null;
    }

    private static void SetStartup(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        var exePath = Environment.ProcessPath;
        if (enabled && !string.IsNullOrWhiteSpace(exePath))
            key?.SetValue("NotchMuse", $"\"{exePath}\"");
        else
            key?.DeleteValue("NotchMuse", false);
    }

    private async void OnPlayerSourceChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || PlayerSourceCombo.SelectedItem is not ComboBoxItem { Tag: string selection }) return;
        settings.PlayerSelection = selection;
        settings.Save();
        if (!auditMode) await media.SelectAsync(selection);
    }

    private void OnDefaultLaunchPlayerChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || DefaultLaunchPlayerCombo.SelectedItem is not ComboBoxItem { Tag: string playerId }) return;
        settings.DefaultLaunchPlayer = playerId;
        settings.Save();
    }

    private void OnStopBehaviorChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || StopBehaviorCombo.SelectedItem is not ComboBoxItem { Tag: PlayerStopBehavior behavior }) return;
        settings.StopBehavior = behavior;
        settings.Save();
    }

    private void OnMissingAnimChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || MissingAnimCombo.SelectedItem is not ComboBoxItem { Tag: MissingLyricsAnimationStyle style }) return;
        settings.MissingLyricsStyle = style;
        settings.Save();
        MissingLyricsArt.Configure(style, snapshot is null, settings.EnglishLanguage);
    }

    private void OnLanguageRadioChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.EnglishLanguage = LangEnRadio.IsChecked == true;
        settings.Save();
        ApplyLanguage();
    }

    private void OnBilingualChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.BilingualEnabled = BilingualToggle.IsChecked == true;
        settings.Save();
        foreach (var ctrl in lyricLineControls) ctrl.SetShowBilingual(settings.BilingualEnabled);
    }

    private void OnCreateDesktopShortcutClick(object sender, RoutedEventArgs e)
    {
        InteractionMotion.Rebound(CreateShortcutButton, 0.94);
        var exePath = Environment.ProcessPath;
        var desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        if (string.IsNullOrWhiteSpace(exePath) || string.IsNullOrWhiteSpace(desktopDir) || !Directory.Exists(desktopDir))
        {
            CreateShortcutButton.Content = settings.EnglishLanguage ? "Unavailable" : "路径不可用";
            return;
        }
        var lnkPath = Path.Combine(desktopDir, "NotchMuse.lnk");
        try
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType is null) return;
            dynamic shell = Activator.CreateInstance(shellType)!;
            dynamic shortcut = shell.CreateShortcut(lnkPath);
            shortcut.TargetPath = exePath;
            shortcut.WorkingDirectory = Path.GetDirectoryName(exePath) ?? "";
            shortcut.IconLocation = exePath + ",0";
            shortcut.Description = "NotchMuse — Windows Desktop Lyrics";
            shortcut.Save();
            InteractionSoundEngine.Play(InteractionSoundCue.Landed);
            CreateShortcutButton.Content = settings.EnglishLanguage ? "Created ✓" : "已创建桌面快捷方式 ✓";
        }
        catch (Exception ex) when (ex is COMException or UnauthorizedAccessException or Microsoft.CSharp.RuntimeBinder.RuntimeBinderException or IOException)
        {
            CreateShortcutButton.Content = settings.EnglishLanguage ? "Creation failed" : "创建失败";
        }
    }

    private async void OnCheckUpdateClick(object sender, RoutedEventArgs e)
    {
        if (availableUpdate is not null)
        {
            OpenExternalUrl(availableUpdate.DownloadUrl ?? availableUpdate.HtmlUrl);
            return;
        }

        CheckUpdateButton.IsEnabled = false;
        try
        {
            var latest = await updateService.GetLatestAsync(windowCts.Token);
            if (closed || !IsLoaded) return;
            if (latest is not null && UpdateService.IsNewer("0.9.0", latest))
            {
                availableUpdate = latest;
                latestReleaseUrl = string.IsNullOrWhiteSpace(latest.HtmlUrl) ? latestReleaseUrl : latest.HtmlUrl;
                AnnouncementText.Text = settings.EnglishLanguage
                    ? $"✨ Update {latest.TagName} Available"
                    : $"✨ 发现新版 {latest.TagName} · 点击更新";
                AnnouncementCapsule.Visibility = Visibility.Visible;
                CheckUpdateButton.Content = settings.EnglishLanguage ? $"Download {latest.TagName}" : $"下载新版 {latest.TagName}";
            }
            else
            {
                CheckUpdateButton.Content = settings.EnglishLanguage ? "Up to date" : "已是最新版本";
            }
        }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or OperationCanceledException or InvalidOperationException)
        {
            if (!closed && IsLoaded)
                CheckUpdateButton.Content = settings.EnglishLanguage ? "Check unavailable" : "暂时无法检查更新";
        }
        finally
        {
            if (!closed && IsLoaded)
                CheckUpdateButton.IsEnabled = true;
        }
    }

    private void UpdateBottomLeftAnnouncementText()
    {
        var en = settings.EnglishLanguage;
        if (availableUpdate is not null)
        {
            AnnouncementText.Text = en
                ? $"✨ Update {availableUpdate.TagName} Available"
                : $"✨ 发现新版 {availableUpdate.TagName} · 点击更新";
            AnnouncementUnreadDot.Visibility = Visibility.Visible;
        }
        else
        {
            AnnouncementText.Text = en ? activeAnnouncement.TitleEn : activeAnnouncement.TitleZh;
        }
        AnnouncementCapsule.Visibility = Visibility.Visible;
    }

    private async Task RefreshReleaseInfoAsync(bool checkUpdates = true)
    {
        // 1. Always fetch Mac-parity announcement feed (falls back cleanly to built-in v0.9.0 banner)
        var announcement = await updateService.GetAnnouncementAsync(windowCts.Token);
        if (!closed && IsLoaded)
        {
            await Dispatcher.InvokeAsync(() =>
            {
                if (closed || !IsLoaded) return;
                activeAnnouncement = announcement;
                UpdateBottomLeftAnnouncementText();
            });
        }

        if (!checkUpdates) return;

        // 2. Check GitHub Releases latest for automatic update alert
        try
        {
            var latest = await updateService.GetLatestAsync(windowCts.Token);
            if (closed || latest is null || string.IsNullOrWhiteSpace(latest.TagName)) return;
            latestReleaseUrl = string.IsNullOrWhiteSpace(latest.HtmlUrl) ? latestReleaseUrl : latest.HtmlUrl;
            var hasNewer = UpdateService.IsNewer("0.9.0", latest);
            await Dispatcher.InvokeAsync(() =>
            {
                if (closed || !IsLoaded) return;
                if (hasNewer)
                {
                    availableUpdate = latest;
                    CheckUpdateButton.Content = settings.EnglishLanguage ? $"Download {latest.TagName}" : $"下载新版 {latest.TagName}";
                    UpdateBottomLeftAnnouncementText();
                }
            });
        }
        catch (Exception ex) when (ex is HttpRequestException or JsonException or OperationCanceledException or InvalidOperationException) { }
    }

    // =========================================================================
    // LIVE-PREVIEW SHARE CARD WINDOW
    // =========================================================================
    private void OnShareClick(object sender, RoutedEventArgs e)
    {
        var start = Math.Max(0, activeLineIndex - 1);
        var slice = normalizedLines.Skip(start).Take(10).Select(l => l.Text).ToArray();
        if (slice.Length == 0)
        {
            slice = [settings.EnglishLanguage ? "Softly glowing across your desktop" : "晚风轻轻吹过黑胶纹路"];
        }

        var dialog = new ShareCardWindow(
            snapshot?.Track.Title ?? "NotchMuse",
            snapshot?.Track.Artist ?? "Vinyl Studio Hi-Fi",
            slice,
            settings.EnglishLanguage,
            album: snapshot?.Track.Album,
            artwork: snapshot?.ArtworkBytes)
        {
            Owner = this
        };
        dialog.ShowDialog();
    }

    // =========================================================================
    // VISUAL AUDIT MODE SUPPORT (Real WPF Layout & Render Inspection)
    // =========================================================================
    internal void LoadAuditDemoSession(byte[]? demoArtwork = null)
    {
        var demoTrack = new Track("稻香 (Vinyl Studio Session)", "周杰伦", "魔杰座", 223, Platform: "spotify");
        snapshot = new PlaybackSnapshot("Spotify.exe", demoTrack, Playing: true, Position: 46.8, CapturedAt: DateTimeOffset.UtcNow, Rate: 1.0, ArtworkBytes: demoArtwork);
        auditPositionOverride = 46.8;

        var demoLines = new List<LyricLine>
        {
            new(24.0, "对这个世界如果你有太多的抱怨", 30.0, Translation: "If you have too many complaints about this world"),
            new(30.5, "跌倒了就不敢继续往前走", 36.0, Translation: "Afraid to keep walking after you fall"),
            new(36.5, "为什么人要这么的脆弱堕落", 42.0, Translation: "Why do we become so fragile and lost"),
            new(42.5, "请你打开电视看看", 49.0, Translation: "Please turn on the TV and take a look"),
            new(49.5, "多少人为生命在努力勇敢的走下去", 56.5, Translation: "So many keep walking bravely for life"),
            new(57.0, "我们是不是该知足", 62.5, Translation: "Shouldn't we learn to be grateful"),
            new(63.0, "珍惜一切就算没有拥有", 70.0, Translation: "Cherish everything even if we don't own it")
        };

        normalizedLines = demoLines;
        activeCandidate = new LyricsCandidate("NetEase", "netease", "demo", demoTrack.Title, demoTrack.Artist, demoTrack.Album, demoTrack.Duration, new LyricDocument(demoLines));
        UpdateTrackChrome(snapshot);
        VinylDeck.SetStaticVisualFrame(38, 8.5, 12.2, 6.4);
        DockSourceTag.Text = "NetEase · 逐行同步";
        DisplayStatusLine.Text = "Spotify · 稻香 (Vinyl Studio Session) — 周杰伦 · 歌词已同步";
        AnnouncementText.Text = "✨ v0.9.0 新公告";
        AnnouncementCapsule.Visibility = Visibility.Visible;

        RebuildLyricsLines();
        activeLineIndex = 3;
        RefreshLyricLineHighlights(forceAll: true, currentProgress: 0.62);
        ProgressSlider.Maximum = 223;
        ProgressSlider.Value = 46.8;
        DockTimeText.Text = "00:46 / 03:43";
        RefreshPreviewCards();
        ScrollActiveLineToCenter();
    }

    internal void PrepareAppearanceAuditShowcase()
    {
        initializing = true;
        settings.ColorMode = LyricColorMode.Gradient;
        settings.AccentHex = "#FF7B2C";
        settings.GradientEndHex = "#FF2E88";
        settings.CapsulePreset = CapsuleBackgroundPreset.Custom;
        settings.CapsuleCustomHex = "#3E3E44";
        settings.BackgroundCapsuleEnabled = true;
        SyncControlsFromSettings();
        initializing = false;
        RebuildAppearanceSwatches();
        HighlightSelectedCapsuleChip();
        HighlightSelectedPresetCard();
        ApplyAppearanceToAllViews();
    }

    internal TaskbarLyricsWindow TaskbarOverlay => taskbarOverlay;
    internal FloatingLyricsWindow FloatingOverlay => floatingOverlay;
    internal AppSettings CurrentSettings => settings;

    private void OnDisplaySettingsChanged(object? sender, EventArgs e)
    {
        Dispatcher.InvokeAsync(() =>
        {
            if (closed) return;
            RefreshDisplayMonitors();
            RefreshOverlayVisibility();
        });
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        Dispatcher.InvokeAsync(() =>
        {
            if (closed) return;
            if (settings.ThemeMode == AppThemeMode.System)
            {
                ThemeManager.ApplyAppTheme(settings.ThemeMode, this);
                UpdateThemeToggleIcon();
                RefreshPreviewCards();
            }
            if (settings.DisplayMode == LyricsDisplayMode.Taskbar)
            {
                taskbarOverlay.Reposition();
                taskbarOverlay.UpdateAppearance(settings);
            }
        });
    }

    private IntPtr WindowMessageHook(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WmHotkey && wParam.ToInt32() == HotkeyId)
        {
            ToggleOverlayLock();
            handled = true;
        }
        return IntPtr.Zero;
    }

    private void OnClosed(object? sender, EventArgs e)
    {
        closed = true;
        if (appearanceSyncTimer.IsEnabled)
        {
            appearanceSyncTimer.Stop();
            settings.Save();
        }
        windowCts.Cancel();
        windowCts.Dispose();
        lookupCts?.Cancel();
        lookupCts?.Dispose();
        frameTimer.Stop();
        fullscreenTimer.Stop();
        appearanceSyncTimer.Stop();
        updateCheckTimer.Stop();
        if (!auditMode && windowHandle != IntPtr.Zero)
        {
            UnregisterHotKey(windowHandle, HotkeyId);
            hwndSource?.RemoveHook(WindowMessageHook);
        }
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        tray.Visible = false;
        tray.Dispose();
        media.Changed -= OnMediaChanged;
        media.Error -= OnMediaError;
        media.Dispose();
        client.Dispose();
        taskbarOverlay.Close();
        floatingOverlay.Close();
    }
}
