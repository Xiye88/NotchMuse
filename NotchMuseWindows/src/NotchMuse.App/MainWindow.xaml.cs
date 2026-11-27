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

    private readonly List<DesktopPreviewCard> previewCards = [];
    private readonly List<SweepLyricLineControl> lyricLineControls = [];
    private readonly Dictionary<AppearanceStylePreset, Border> presetCardMap = [];
    private readonly Dictionary<CapsuleBackgroundPreset, Border> capsuleChipMap = [];

    private CancellationTokenSource? lookupCts;
    private PlaybackSnapshot? snapshot;
    private LyricsCandidate? activeCandidate;
    private IReadOnlyList<LyricLine> normalizedLines = [];
    private int activeLineIndex = -1;
    private string activePage = "Lyrics";
    private string latestReleaseUrl = "https://github.com/Xiye88/NotchMuse/releases";
    private HwndSource? hwndSource;
    private IntPtr windowHandle;
    private bool initializing = true;
    private bool closed;
    private bool draggingProgress;
    private bool sidebarCollapsed;
    private bool overlaysEnabled = true;
    private bool auditMode;
    private double auditPositionOverride = -1;
    private double currentLineSweepProgress;

    private static readonly (string NameZh, string NameEn, string Hex, string EndHex)[] SolidSwatches =
    [
        ("暖琥珀", "Warm Amber", "#E06D1B", "#FF9E44"),
        ("纯净墨", "Pure Ink", "#2A2A2E", "#5A5A64"),
        ("晴空蓝", "Sky Blue", "#3B82F6", "#60A5FA"),
        ("黑胶紫", "Vinyl Violet", "#8B5CF6", "#A78BFA"),
        ("森林青", "Emerald", "#22A96B", "#52D196"),
        ("落日红", "Sunset Coral", "#E25D6B", "#F59479"),
        ("流沙金", "Studio Gold", "#C9A24B", "#E8C97A"),
        ("雾海蓝", "Ocean Teal", "#0EA5A4", "#38BDF8")
    ];

    private static readonly (string NameZh, string NameEn, string StartHex, string EndHex)[] GradientSwatches =
    [
        ("琥珀日落", "Amber Sunset", "#E06D1B", "#F59E0B"),
        ("薄荷海风", "Mint Breeze", "#14B8A6", "#38BDF8"),
        ("晚霞紫粉", "Rose Dusk", "#EC4899", "#8B5CF6"),
        ("霓虹极光", "Aurora", "#22C55E", "#3B82F6"),
        ("蜜桃暖阳", "Peach Glow", "#F97316", "#EC4899"),
        ("曜石流金", "Liquid Gold", "#D97706", "#FDE047")
    ];

    public MainWindow(bool isAuditMode = false)
    {
        auditMode = isAuditMode;
        engine = LyricsEngine.Create(client);
        updateService = new UpdateService(client);
        tray = new Forms.NotifyIcon { Icon = CreateTrayIcon(), Visible = !isAuditMode, Text = "NotchMuse" };

        InitializeComponent();
        BuildDynamicControls();
        WireOverlays();
        SetupTrayMenu();
        SyncControlsFromSettings();

        frameTimer.Tick += (_, _) => OnAnimationTick();
        fullscreenTimer.Tick += (_, _) => CheckFullscreenAndTaskbarZOrder();
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
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
            var card = new DesktopPreviewCard(mode) { Margin = new Thickness(4, 0, 4, 0) };
            card.ModeSelected += SelectDisplayMode;
            previewCards.Add(card);
            DesktopPreviewCardsHost.Children.Add(card);
        }

        // 2. Display Screen Monitor List
        RefreshDisplayMonitors();

        // 3. Five-Group Player Dropdown on General Page
        PopulatePlayerCombo();

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
        floatingOverlay.CycleModeRequested += () => SelectDisplayMode(LyricsDisplayMode.Taskbar);
        floatingOverlay.OpenAppearanceRequested += () => { BringMainToFront(); NavigateTo("Appearance"); };
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
        menu.Items.Add("退出 NotchMuse", null, (_, _) => Dispatcher.Invoke(Close));
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => Dispatcher.Invoke(BringMainToFront);
    }

    private void BringMainToFront()
    {
        if (!IsVisible) Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
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
            RefreshOverlayVisibility();
            _ = RefreshReleaseInfoAsync();
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

        FontSizeSlider.Value = settings.FontSize;
        AnimSpeedSlider.Value = settings.AnimationSpeed;
        OpacitySlider.Value = settings.LyricOpacity;
        CapsuleOpacitySlider.Value = settings.CapsuleBackgroundOpacity;
        CustomCapsuleHexBox.Text = settings.CapsuleCustomHex;
        UpdateCustomCapsuleControls();

        LangZhRadio.IsChecked = !settings.EnglishLanguage;
        LangEnRadio.IsChecked = settings.EnglishLanguage;
        BilingualToggle.IsChecked = settings.BilingualEnabled;
        OverlayLockToggle.IsChecked = settings.OverlayLocked;

        var startup = IsStartupEnabled();
        DisplayStartupToggle.IsChecked = startup;
        GeneralStartupToggle.IsChecked = startup;

        SelectComboItemByTag(StopBehaviorCombo, settings.StopBehavior);
        SelectComboItemByTag(MissingAnimCombo, settings.MissingLyricsStyle);
        SelectComboItemByTag(PlayerSourceCombo, settings.PlayerSelection);
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
        CustomCapsuleBar.Visibility = settings.CapsulePreset == CapsuleBackgroundPreset.Custom
            ? Visibility.Visible
            : Visibility.Collapsed;
        CustomCapsuleSwatch.Background = new SolidColorBrush(
            ThemeManager.ParseColor(settings.CapsuleCustomHex, System.Windows.Media.Color.FromRgb(62, 62, 68)));
        CapsuleOpacityRow.IsEnabled = settings.CapsulePreset != CapsuleBackgroundPreset.Transparent;
        CapsuleOpacityRow.Opacity = settings.CapsulePreset == CapsuleBackgroundPreset.Transparent ? 0.42 : 1.0;
        CapsuleOpacityValueText.Text = settings.CapsulePreset == CapsuleBackgroundPreset.Transparent
            ? "0%"
            : $"{Math.Round(settings.CapsuleBackgroundOpacity * 100):0}%";
    }

    private void BuildStylePresetCards()
    {
        StylePresetsHost.Children.Clear();
        presetCardMap.Clear();

        var specs = new[]
        {
            (AppearanceStylePreset.Warm, "♪ Warm", "暖琥珀黑胶", "Warm Vinyl", "#E06D1B", "#F59E0B", 22.0, 1.0, true, LyricColorMode.Solid),
            (AppearanceStylePreset.Minimal, "♪ Minimal", "克制极简白", "Minimal Ink", "#3B82F6", "#60A5FA", 19.0, 0.92, false, LyricColorMode.Solid),
            (AppearanceStylePreset.Soft, "♪ Soft", "薄荷柔和渐变", "Soft Gradient", "#14B8A6", "#38BDF8", 23.0, 0.95, true, LyricColorMode.Gradient),
            (AppearanceStylePreset.Pure, "♪ Pure", "通透纯享大字", "Pure Stage", "#8B5CF6", "#A78BFA", 26.0, 1.0, false, LyricColorMode.Solid)
        };

        foreach (var spec in specs)
        {
            var card = new Border
            {
                CornerRadius = new CornerRadius(11),
                BorderThickness = new Thickness(1),
                Padding = new Thickness(12, 11, 12, 11),
                Margin = new Thickness(4, 0, 4, 0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            card.SetResourceReference(Border.BackgroundProperty, "CardBrush");
            card.SetResourceReference(Border.BorderBrushProperty, "BorderSubtleBrush");

            var stack = new StackPanel();
            var swatchBar = new Border
            {
                Height = 4,
                Width = 28,
                CornerRadius = new CornerRadius(2),
                HorizontalAlignment = System.Windows.HorizontalAlignment.Left,
                Margin = new Thickness(0, 0, 0, 8),
                Background = spec.Item10 == LyricColorMode.Gradient
                    ? new LinearGradientBrush(ThemeManager.ParseColor(spec.Item5, Colors.Orange), ThemeManager.ParseColor(spec.Item6, Colors.Cyan), 0)
                    : new SolidColorBrush(ThemeManager.ParseColor(spec.Item5, Colors.Orange))
            };
            var nameTb = new TextBlock
            {
                Text = spec.Item2,
                FontSize = 14,
                FontWeight = FontWeights.SemiBold
            };
            nameTb.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");

            var descTb = new TextBlock
            {
                Text = settings.EnglishLanguage ? spec.Item4 : spec.Item3,
                FontSize = 11,
                Margin = new Thickness(0, 3, 0, 0)
            };
            descTb.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");

            stack.Children.Add(swatchBar);
            stack.Children.Add(nameTb);
            stack.Children.Add(descTb);
            card.Child = stack;

            var captured = spec;
            card.MouseLeftButtonUp += (_, _) => ApplyStylePreset(captured.Item1, captured.Item5, captured.Item6, captured.Item7, captured.Item8, captured.Item9, captured.Item10);
            presetCardMap[spec.Item1] = card;
            StylePresetsHost.Children.Add(card);
        }

        HighlightSelectedPresetCard();
    }

    private void ApplyStylePreset(AppearanceStylePreset preset, string accentHex, string endHex, double fontSize, double opacity, bool capsule, LyricColorMode colorMode)
    {
        initializing = true;
        settings.StylePreset = preset;
        settings.ColorMode = colorMode;
        settings.AccentHex = accentHex;
        settings.GradientEndHex = endHex;
        settings.FontSize = fontSize;
        settings.LyricOpacity = opacity;
        settings.BackgroundCapsuleEnabled = capsule;
        settings.CapsulePreset = preset switch
        {
            AppearanceStylePreset.Warm => CapsuleBackgroundPreset.SoftGray,
            AppearanceStylePreset.Minimal => CapsuleBackgroundPreset.FrostedPaper,
            AppearanceStylePreset.Soft => CapsuleBackgroundPreset.SlateBlue,
            _ => CapsuleBackgroundPreset.Transparent
        };
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
                border.BorderThickness = new Thickness(1.5);
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
        settings.Save();
        RebuildAppearanceSwatches();
        ApplyAppearanceToAllViews();
    }

    private void ApplyAppearanceToAllViews()
    {
        var accentBrush = ThemeManager.CreateLyricAccentBrush(settings);
        NavAppearanceColorRing.Fill = accentBrush;
        UpdateAppearanceReadouts();
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
        if (sender is Border { Tag: string page }) NavigateTo(page);
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

    private void RefreshOverlayVisibility()
    {
        if (auditMode || closed) return;

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
            if (!taskbarOverlay.IsVisible) taskbarOverlay.Show();
            taskbarOverlay.EnsureTopmostAboveTaskbar();
        }
        else
        {
            if (taskbarOverlay.IsVisible) taskbarOverlay.Hide();
            floatingOverlay.ConfigureMode(settings.DisplayMode, settings);
            if (!floatingOverlay.IsVisible) floatingOverlay.Show();
        }
    }

    private void CheckFullscreenAndTaskbarZOrder()
    {
        if (closed || auditMode || !overlaysEnabled) return;

        var fg = GetForegroundWindow();
        var isFullscreen = false;
        if (fg != IntPtr.Zero && fg != windowHandle && GetWindowRect(fg, out var rect))
        {
            var primary = Forms.Screen.PrimaryScreen?.Bounds;
            if (primary is not null)
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
        if (nextKey == previousKey && activeCandidate is not null) return;

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

        VinylDeck.UpdateState(value?.Track.Title, subtitle, isPlaying, en);
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
            row.SeekRequested += async target => await media.SeekAsync(Math.Max(0, target - settings.TimeOffsetSeconds));
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

        if (activeLineIndex >= 0 && activeLineIndex < normalizedLines.Count)
        {
            var current = normalizedLines[activeLineIndex];
            taskbarOverlay.UpdateLyric(current.Text, current.Translation, lineProgress, settings.BilingualEnabled);
            floatingOverlay.UpdateLyric(current.Text, current.Translation, lineProgress, settings.BilingualEnabled);
        }
    }

    private double ComputeCurrentPositionSeconds()
    {
        if (auditPositionOverride >= 0) return auditPositionOverride;
        if (snapshot is null) return 0;
        var elapsed = snapshot.Playing ? (DateTimeOffset.UtcNow - snapshot.CapturedAt).TotalSeconds * snapshot.Rate : 0;
        var pos = snapshot.Position + elapsed;
        return snapshot.Track.Duration > 0 ? Math.Clamp(pos, 0, snapshot.Track.Duration) : Math.Max(0, pos);
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
                lyricLineControls[i].ApplyVisualState(distance, prog, settings.FontSize, accentBrush, settings.LyricOpacity);
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
        DisplayOffsetLabel.Text = en ? "Lyrics Time Offset" : "歌词时间偏移";
        DisplayOffsetDesc.Text = en ? "Fine-tune lyric timing ahead or behind across all views" : "微调歌词提前或延后，实时作用于所有视图";
        DisplayScreenLabel.Text = en ? "Display Monitor" : "显示屏幕";
        DisplayScreenDesc.Text = en ? "Choose which monitor hosts Top Island and Free Float" : "选择顶部悬浮岛与桌面自由悬浮所在显示器";
        DisplayStartupLabel.Text = en ? "Launch at Login" : "开机自启";
        DisplayStartupDesc.Text = en ? "Start quietly in the system tray when Windows boots" : "登录 Windows 时自动静默启动歌词服务";
        DisplayLockLabel.Text = en ? "Lock Desktop Overlay (Click-Through)" : "锁定桌面歌词（鼠标穿透）";
        DisplayLockDesc.Text = en ? "Pass mouse clicks straight through when locked" : "锁定后桌面悬浮歌词完全穿透点击，不影响办公与游戏";

        AppearanceHeaderTitle.Text = en ? "Appearance" : "外观";
        ColorModeLabel.Text = en ? "Lyrics Color" : "歌词颜色";
        ColorModeDesc.Text = en ? "Solid or gradient sweep synced across stage & overlays" : "支持纯色与渐变扫光，实时同步至任务栏与悬浮歌词";
        SolidColorRadio.Content = en ? "Solid" : "纯色";
        GradientColorRadio.Content = en ? "Gradient" : "渐变";
        FontSizeLabel.Text = en ? "Font Size" : "字体大小";
        AnimSpeedLabel.Text = en ? "Animation Speed" : "动画速度";
        OpacityLabel.Text = en ? "Lyrics Opacity" : "歌词不透明度";
        BgCapsuleLabel.Text = en ? "Capsule Background" : "胶囊背景颜色";
        BgCapsuleDesc.Text = en ? "Applies live to Desktop Free Float and Top Island with adaptive ink" : "实时作用于桌面自由悬浮歌词与顶部悬浮岛，自动适配浅/深字色";
        CapsuleOpacityLabel.Text = en ? "Background Opacity" : "背景不透明度";
        PickCustomColorBtn.Content = en ? "Pick Color…" : "系统取色…";
        QuickPresetsLabel.Text = en ? "QUICK STYLE PRESETS" : "风格快捷预设";

        GeneralHeaderTitle.Text = en ? "General" : "通用";
        PlayerSourceLabel.Text = en ? "Music Player" : "音乐播放器";
        PlayerSourceDesc.Text = en ? "Auto-detects 36+ desktop players and browser sessions" : "自动覆盖 36+ 主流及开源播放器与浏览器网页端";
        StopBehaviorLabel.Text = en ? "When Playback Stops" : "播放停止行为";
        StopBehaviorDesc.Text = en ? "Choose how lyrics behave when your player closes" : "当播放器退出或清空队列时的歌词显示策略";
        GeneralStartupLabel.Text = en ? "Launch at Login" : "开机自启";
        GeneralStartupDesc.Text = en ? "Start with Windows in low-memory tray mode" : "随 Windows 自动启动，保持低内存常驻托盘";
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
        VersionTitleLabel.Text = en ? "Version" : "版本信息";
        CheckUpdateButton.Content = en ? "Check for Updates" : "检查更新";

        SharePopupTitle.Text = en ? "Share Lyrics Card" : "生成歌词分享卡";
        ShareTemplateLabel.Text = en ? "Card Template" : "卡片风格";
        ShareLinesLabel.Text = en ? "Select 1–6 lines" : "选择 1–6 句歌词";
        CopyShareBtn.Content = en ? "Copy Image" : "复制图片";
        SaveShareBtn.Content = en ? "Save PNG…" : "保存 PNG…";

        initializing = true;
        PopulatePlayerCombo();
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

    private void OnCloseToTrayClick(object sender, RoutedEventArgs e)
    {
        if (auditMode) Close();
        else Hide();
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

    private void OnSponsorClick(object sender, RoutedEventArgs e) => OpenExternalUrl("https://github.com/sponsors/Xiye88");
    private void OnGitHubClick(object sender, RoutedEventArgs e) => OpenExternalUrl("https://github.com/Xiye88/NotchMuse");
    private void OnAnnouncementClick(object sender, System.Windows.Input.MouseButtonEventArgs e) => OpenExternalUrl(latestReleaseUrl);

    private static void OpenExternalUrl(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception) { }
    }

    private async void OnPlayClick(object sender, RoutedEventArgs e) => await media.ToggleAsync();
    private async void OnPreviousClick(object sender, RoutedEventArgs e) => await media.PreviousAsync();
    private async void OnNextClick(object sender, RoutedEventArgs e) => await media.NextAsync();

    private void OnProgressGrab(object sender, System.Windows.Input.MouseButtonEventArgs e) => draggingProgress = true;
    private async void OnProgressRelease(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        draggingProgress = false;
        await media.SeekAsync(ProgressSlider.Value);
    }

    private void OnQuickColorDotClick(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button { Background: SolidColorBrush scb })
        {
            var c = scb.Color;
            var hex = $"#{c.R:X2}{c.G:X2}{c.B:X2}";
            SelectAccentColors(hex, settings.GradientEndHex);
        }
    }

    private void OnColorModeChanged(object sender, RoutedEventArgs e)
    {
        if (initializing) return;
        settings.ColorMode = GradientColorRadio.IsChecked == true ? LyricColorMode.Gradient : LyricColorMode.Solid;
        settings.Save();
        RebuildAppearanceSwatches();
        ApplyAppearanceToAllViews();
    }

    private void OnAppearanceSliderChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (initializing) return;
        settings.FontSize = Math.Round(FontSizeSlider.Value);
        settings.AnimationSpeed = Math.Round(AnimSpeedSlider.Value, 1);
        settings.LyricOpacity = Math.Round(OpacitySlider.Value, 2);
        settings.Save();
        ApplyAppearanceToAllViews();
    }

    private void OnCapsuleOpacityChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (initializing) return;
        settings.CapsuleBackgroundOpacity = Math.Round(CapsuleOpacitySlider.Value, 2);
        settings.Save();
        ApplyAppearanceToAllViews();
    }

    private void OnCustomCapsuleHexChanged(object sender, TextChangedEventArgs e)
    {
        if (initializing) return;
        var raw = CustomCapsuleHexBox.Text.Trim();
        if (!raw.StartsWith('#')) raw = "#" + raw;
        if (raw.Length is 7 or 9)
        {
            var fallback = System.Windows.Media.Color.FromRgb(62, 62, 68);
            var parsed = ThemeManager.ParseColor(raw, fallback);
            if (parsed != fallback || string.Equals(raw, "#3E3E44", StringComparison.OrdinalIgnoreCase))
            {
                settings.CapsuleCustomHex = $"#{parsed.R:X2}{parsed.G:X2}{parsed.B:X2}";
                settings.CapsulePreset = CapsuleBackgroundPreset.Custom;
                settings.BackgroundCapsuleEnabled = true;
                settings.Save();
                BuildCapsulePresetChips();
                ApplyAppearanceToAllViews();
            }
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
        settings.TimeOffsetSeconds = Math.Round(Math.Clamp(settings.TimeOffsetSeconds + delta, -10, 10), 1);
        settings.Save();
        UpdateOffsetReadout();
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
        taskbarOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.ApplyLanguage(settings.EnglishLanguage);
    }

    private void ToggleOverlayLock()
    {
        settings.OverlayLocked = !settings.OverlayLocked;
        settings.Save();
        initializing = true;
        OverlayLockToggle.IsChecked = settings.OverlayLocked;
        initializing = false;
        taskbarOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.SetLocked(settings.OverlayLocked);
        floatingOverlay.ApplyLanguage(settings.EnglishLanguage);
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

    private static bool IsStartupEnabled() =>
        Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")?.GetValue("NotchMuse") is not null;

    private static void SetStartup(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        if (enabled) key?.SetValue("NotchMuse", Environment.ProcessPath ?? "");
        else key?.DeleteValue("NotchMuse", false);
    }

    private async void OnPlayerSourceChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || PlayerSourceCombo.SelectedItem is not ComboBoxItem { Tag: string selection }) return;
        settings.PlayerSelection = selection;
        settings.Save();
        if (!auditMode) await media.SelectAsync(selection);
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

    private async void OnCheckUpdateClick(object sender, RoutedEventArgs e)
    {
        CheckUpdateButton.IsEnabled = false;
        try
        {
            var latest = await updateService.GetLatestAsync(CancellationToken.None);
            CheckUpdateButton.Content = latest is not null && UpdateService.IsNewer("0.9.0", latest)
                ? (settings.EnglishLanguage ? $"Update {latest.TagName}" : $"发现新版本 {latest.TagName}")
                : (settings.EnglishLanguage ? "Up to date" : "已是最新版本");
        }
        catch (HttpRequestException)
        {
            CheckUpdateButton.Content = settings.EnglishLanguage ? "Check unavailable" : "暂时无法检查更新";
        }
        finally
        {
            CheckUpdateButton.IsEnabled = true;
        }
    }

    private async Task RefreshReleaseInfoAsync()
    {
        try
        {
            var latest = await updateService.GetLatestAsync(CancellationToken.None);
            if (latest is null || string.IsNullOrWhiteSpace(latest.TagName)) return;
            latestReleaseUrl = string.IsNullOrWhiteSpace(latest.HtmlUrl) ? latestReleaseUrl : latest.HtmlUrl;
            await Dispatcher.InvokeAsync(() =>
            {
                AnnouncementText.Text = settings.EnglishLanguage
                    ? $"✨ {latest.TagName} Release Notes"
                    : $"✨ {latest.TagName} 新公告";
                AnnouncementCapsule.Visibility = Visibility.Visible;
            });
        }
        catch (HttpRequestException) { }
        catch (JsonException) { }
    }

    // =========================================================================
    // SHARE CARD POPUP
    // =========================================================================
    private void OnShareClick(object sender, RoutedEventArgs e)
    {
        ShareLinesList.Items.Clear();
        var start = Math.Max(0, activeLineIndex - 1);
        var slice = normalizedLines.Skip(start).Take(6).ToArray();
        if (slice.Length == 0)
        {
            slice = [new LyricLine(0, "NotchMuse · Vinyl Studio Hi-Fi")];
        }
        foreach (var line in slice)
        {
            var view = new LyricView(line.Text, line.Start);
            ShareLinesList.Items.Add(view);
            if (ShareLinesList.SelectedItems.Count < 4) ShareLinesList.SelectedItems.Add(view);
        }
        ShareStatusLabel.Text = "";
        SharePopup.IsOpen = true;
    }

    private async void OnCopyShareClick(object sender, RoutedEventArgs e)
    {
        var png = RenderSelectedShareCard();
        System.Windows.Clipboard.SetImage(ShareCardRenderer.Decode(png));
        ShareStatusLabel.Text = settings.EnglishLanguage ? "Copied ✓" : "已复制 ✓";
        await Task.Delay(1200);
        if (!closed) ShareStatusLabel.Text = "";
    }

    private void OnSaveShareClick(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.SaveFileDialog { Filter = "PNG Image|*.png", FileName = "NotchMuse-lyrics.png" };
        if (dialog.ShowDialog(this) != true) return;
        File.WriteAllBytes(dialog.FileName, RenderSelectedShareCard());
        ShareStatusLabel.Text = settings.EnglishLanguage ? "Saved ✓" : "已保存 ✓";
    }

    private byte[] RenderSelectedShareCard()
    {
        var lines = ShareLinesList.SelectedItems.Cast<LyricView>().Take(6).Select(line => line.DisplayText).ToArray();
        if (lines.Length == 0) lines = ["♪"];
        var theme = ShareThemeCombo.SelectedIndex switch
        {
            1 => ShareCardTheme.WarmAlabaster,
            2 => ShareCardTheme.SodaMist,
            _ => ShareCardTheme.VinylNight
        };
        return ShareCardRenderer.RenderPng(snapshot?.Track.Title ?? "NotchMuse", snapshot?.Track.Artist ?? "Lyrics", lines, theme);
    }

    // =========================================================================
    // VISUAL AUDIT MODE SUPPORT (Real WPF Layout & Render Inspection)
    // =========================================================================
    internal void LoadAuditDemoSession()
    {
        var demoTrack = new Track("稻香 (Vinyl Studio Session)", "周杰伦", "魔杰座", 223, Platform: "spotify");
        snapshot = new PlaybackSnapshot("Spotify.exe", demoTrack, Playing: true, Position: 46.8, CapturedAt: DateTimeOffset.UtcNow, Rate: 1.0);
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
        lookupCts?.Cancel();
        lookupCts?.Dispose();
        frameTimer.Stop();
        fullscreenTimer.Stop();
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
