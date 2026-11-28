using System.IO;
using NotchMuse.Core;
using NotchMuse.App;
using Xunit;

namespace NotchMuse.Tests;

public sealed class M4Tests
{
    [Theory]
    [InlineData("0.9.0", "0.9.1", -1)]
    [InlineData("v0.9.1", "0.9.1", 0)]
    [InlineData("1.0.0", "0.9.9", 1)]
    public void ReleaseVersionsCompare(string current, string latest, int expected) => Assert.Equal(expected, Math.Sign(VersionComparison.Compare(current, latest)));

    [Fact]
    public void No404CopyInWindowsSource()
    {
        var root = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "src"));
        var files = Directory.EnumerateFiles(root, "*.cs", SearchOption.AllDirectories).Where(path => !path.Contains("bin") && !path.Contains("obj"));
        Assert.DoesNotContain(files, path => File.ReadAllText(path).Contains("404", StringComparison.Ordinal));
    }

    [Fact]
    public void MicroAnimationCatalogHasSixSafePhrases()
    {
        Assert.Equal(6, MicroAnimationCatalog.Phrases.Count);
        Assert.DoesNotContain(MicroAnimationCatalog.Phrases, phrase => phrase.Contains("404", StringComparison.Ordinal));
    }

    [Fact]
    public void ShareCardPngIsNonEmpty()
    {
        var png = ShareCardRenderer.RenderPng("Song", "Artist", ["First line", "Second line"], ShareCardTheme.VinylNight);
        Assert.True(png.Length > 256);
        Assert.Equal(new byte[] { 137, 80, 78, 71 }, png[..4]);
    }

    [Fact]
    public void TaskbarLocatorCentersLeftGapWhenWidgetsHidden()
    {
        var slot = NotchMuse.App.Overlays.TaskbarLocator.ComputeSlot(
            barLeft: 0, barTop: 816, barWidth: 1536, barHeight: 48,
            isCentered: true, widgetsVisible: false, isLightTaskbar: true,
            widgetsRightDip: null, startLeftDip: 560, trayNotifyLeftDip: 1320);

        Assert.True(slot.IsCenteredTaskbar);
        Assert.Equal(12, slot.Left);
        Assert.Equal(816, slot.Top);
        Assert.Equal(48, slot.Height);
        Assert.InRange(slot.Width, 240, 420);
        Assert.True(slot.Left + slot.Width < 560);
    }

    [Fact]
    public void TaskbarLocatorClearsWidgetsButtonWhenPresent()
    {
        var slot = NotchMuse.App.Overlays.TaskbarLocator.ComputeSlot(
            barLeft: 0, barTop: 1032, barWidth: 1920, barHeight: 48,
            isCentered: true, widgetsVisible: true, isLightTaskbar: false,
            widgetsRightDip: 162, startLeftDip: 680, trayNotifyLeftDip: 1700);

        Assert.Equal(172, slot.Left);
        Assert.True(slot.Left + slot.Width <= 666);
        Assert.InRange(slot.Width, 240, 420);
        Assert.False(slot.IsLightTaskbar);
    }

    [Fact]
    public void TaskbarLocatorFallsBackCleanlyWhenLeftAligned()
    {
        var slot = NotchMuse.App.Overlays.TaskbarLocator.ComputeSlot(
            barLeft: 0, barTop: 816, barWidth: 1536, barHeight: 48,
            isCentered: false, widgetsVisible: false, isLightTaskbar: true,
            widgetsRightDip: null, startLeftDip: null, trayNotifyLeftDip: 1320);

        Assert.False(slot.IsCenteredTaskbar);
        Assert.True(slot.Left >= 260);
        Assert.True(slot.Left + slot.Width <= 1306);
    }

    [Fact]
    public void ClickThroughStateMachineFlipsTransparentFlagCleanly()
    {
        var unlocked = NotchMuse.App.Overlays.WindowClickThroughHelper.ComputeOverlayExStyle(0, locked: false);
        Assert.False(NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(unlocked));
        Assert.NotEqual(0, unlocked & NotchMuse.App.Overlays.WindowClickThroughHelper.WsExLayered);
        Assert.NotEqual(0, unlocked & NotchMuse.App.Overlays.WindowClickThroughHelper.WsExNoActivate);
        Assert.NotEqual(0, unlocked & NotchMuse.App.Overlays.WindowClickThroughHelper.WsExToolWindow);

        var locked = NotchMuse.App.Overlays.WindowClickThroughHelper.ComputeOverlayExStyle(unlocked, locked: true);
        Assert.True(NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(locked));
        Assert.NotEqual(0, locked & NotchMuse.App.Overlays.WindowClickThroughHelper.WsExLayered);

        var restored = NotchMuse.App.Overlays.WindowClickThroughHelper.ComputeOverlayExStyle(locked, locked: false);
        Assert.False(NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(restored));
        Assert.NotEqual(0, restored & NotchMuse.App.Overlays.WindowClickThroughHelper.WsExLayered);
    }

    [Fact]
    public void FloatingWindowLiveHwndTogglesWsExTransparentBit()
    {
        Exception? threadError = null;
        var unlockedFlag = true;
        var lockedFlag = false;
        var restoredFlag = true;

        var sta = new Thread(() =>
        {
            try
            {
                var win = new NotchMuse.App.Overlays.FloatingLyricsWindow
                {
                    Left = -4000,
                    Top = -4000,
                    ShowInTaskbar = false
                };
                var helper = new System.Windows.Interop.WindowInteropHelper(win);
                var hwnd = helper.EnsureHandle();

                var styleUnlocked = NotchMuse.App.Overlays.WindowClickThroughHelper.ApplyClickThrough(hwnd, locked: false);
                unlockedFlag = NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(styleUnlocked);

                var styleLocked = NotchMuse.App.Overlays.WindowClickThroughHelper.ApplyClickThrough(hwnd, locked: true);
                lockedFlag = NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(styleLocked);

                var styleRestored = NotchMuse.App.Overlays.WindowClickThroughHelper.ApplyClickThrough(hwnd, locked: false);
                restoredFlag = NotchMuse.App.Overlays.WindowClickThroughHelper.HasTransparentFlag(styleRestored);

                win.Close();
            }
            catch (Exception ex)
            {
                threadError = ex;
            }
        });
        sta.SetApartmentState(ApartmentState.STA);
        sta.Start();
        sta.Join(TimeSpan.FromSeconds(10));

        Assert.Null(threadError);
        Assert.False(unlockedFlag);
        Assert.True(lockedFlag);
        Assert.False(restoredFlag);
    }

    [Theory]
    [InlineData(CapsuleBackgroundPreset.SoftGray, "#3E3E44", 0.82)]
    [InlineData(CapsuleBackgroundPreset.FrostedPaper, "#F8F6F1", 0.88)]
    [InlineData(CapsuleBackgroundPreset.ObsidianDark, "#18181C", 0.84)]
    [InlineData(CapsuleBackgroundPreset.SlateBlue, "#1E293B", 0.82)]
    [InlineData(CapsuleBackgroundPreset.Transparent, "#000000", 0.0)]
    public void CapsulePresetDefaultsMatchDesignSpec(CapsuleBackgroundPreset preset, string expectedHex, double expectedOpacity)
    {
        var (hex, opacity) = AppSettings.GetCapsulePresetDefaults(preset);
        Assert.Equal(expectedHex, hex);
        Assert.Equal(expectedOpacity, opacity, precision: 2);
    }

    [Fact]
    public void CliqueConsensusBeatsSingleShiftedOutlier()
    {
        var track = new Track("稻香", "周杰伦", "魔杰座", 220, Platform: "apple");
        static LyricsCandidate Make(string provider, string platform, double shift, string? album) =>
            new(provider, platform, "id", "稻香", "周杰伦", album, 220,
                new(Enumerable.Range(0, 15).Select(i => new LyricLine(10 + i * 12 + shift, $"这是第{i}句歌词文本内容")).ToArray()), 100);

        var decision = LyricsSelection.Select(
            [Make("NetEase", "netease", 0, null), Make("QQ", "qq", 0.2, null), Make("Kugou", "kugou", 7.0, null)],
            track);

        Assert.NotNull(decision.Winner);
        Assert.Contains(decision.Winner.Provider, new[] { "NetEase", "QQ" });
    }

    [Fact]
    public void AlbumBoundStrongMetadataBeatsTier4Outlier()
    {
        var track = new Track("晴天", "周杰伦", "叶惠美", 269, Platform: "apple");
        static LyricsCandidate Make(string provider, string platform, double shift, string? album) =>
            new(provider, platform, "id", "晴天", "周杰伦", album, 269,
                new(Enumerable.Range(0, 16).Select(i => new LyricLine(15 + i * 13 + shift, $"故事的小黄花第{i}句")).ToArray()), 100);

        var decision = LyricsSelection.Select(
            [Make("QQ", "qq", 0, "叶惠美"), Make("LRCLIB", "lrclib", 8.0, "精选集")],
            track);

        Assert.NotNull(decision.Winner);
        Assert.Equal("QQ", decision.Winner.Provider);
    }

    [Fact]
    public void EmptyAlbumYoutubeTrackAllowsHighConfidenceDirectFallback()
    {
        var track = new Track("Lemon", "米津玄师", "", 255, IsMusicVideo: true, Platform: "youtube");
        var cand = new LyricsCandidate("NetEase", "netease", "id", "Lemon", "米津玄师", "Lemon", 252,
            new(Enumerable.Range(0, 8).Select(i => new LyricLine(10 + i * 20, $"夢ならばどれほどよかったでしょう{i}")).ToArray()), 88);

        var decision = LyricsSelection.Select([cand], track);
        Assert.NotNull(decision.Winner);
        Assert.Equal("NetEase", decision.Winner.Provider);
    }

    [Fact]
    public void DefaultPlayerLauncherContainsExpectedOptions()
    {
        var players = DefaultPlayerLauncher.DetectAll();
        Assert.Contains(players, p => p.Id == "none");
        Assert.Contains(players, p => p.Id == "spotify");
        Assert.Contains(players, p => p.Id == "netease");
        Assert.Contains(players, p => p.Id == "qq");
        Assert.Contains(players, p => p.Id == "soda");
        Assert.Contains(players, p => p.Id == "apple");
    }

    [Theory]
    [InlineData(0, 0, true)]
    [InlineData(40, 0, true)]
    [InlineData(72, 0, false)]
    [InlineData(650, 0, false)]
    public void FloatingToolbarAnchorsAboveAndFlipsOnlyNearTopEdge(double windowTop, double workTop, bool expectedBelow) =>
        Assert.Equal(expectedBelow, NotchMuse.App.Overlays.FloatingLyricsWindow.ShouldFlipToolbarBelow(windowTop, workTop));

    [Fact]
    public void DefaultSettingsEnableDoubleLineFloatingAndInteractionSounds()
    {
        var defaults = new AppSettings();
        Assert.True(defaults.FloatingDoubleLine);
        Assert.True(defaults.InteractionSoundsEnabled);
        Assert.True(defaults.AutoUpdateEnabled);
    }

    [Fact]
    public void QuickGradientPaletteHasThreeCuratedMacParityGradients()
    {
        var gradients = NotchMuse.App.Overlays.FloatingLyricsWindow.QuickGradientPalette;
        Assert.Equal(3, gradients.Length);
        Assert.Contains(gradients, g => g.StartHex == "#FF8A36" && g.EndHex == "#FF4D8D");
        Assert.Contains(gradients, g => g.StartHex == "#38BDF8" && g.EndHex == "#A855F7");
        Assert.Contains(gradients, g => g.StartHex == "#34D399" && g.EndHex == "#0EA5E9");
    }

    [Fact]
    public void ShareCardWithAlbumAndArtworkRendersValidPng()
    {
        var basePng = ShareCardRenderer.RenderPng("稻香", "周杰伦", ["请你打开电视看看"], ShareCardTheme.VinylNight);
        var withArtPng = ShareCardRenderer.RenderPng("稻香", "周杰伦", "魔杰座", ["请你打开电视看看"], ShareCardTheme.WarmAlabaster, artworkBytes: basePng);
        Assert.True(withArtPng.Length > 1000);
        Assert.Equal(new byte[] { 137, 80, 78, 71 }, withArtPng[..4]);
    }

    [Theory]
    [InlineData(InteractionSoundCue.Tick)]
    [InlineData(InteractionSoundCue.Step)]
    [InlineData(InteractionSoundCue.Latch)]
    [InlineData(InteractionSoundCue.Dial)]
    [InlineData(InteractionSoundCue.Landed)]
    [InlineData(InteractionSoundCue.Hush)]
    public void SynthesizedPcmWaveHeadersAreValidForAllSixCues(InteractionSoundCue cue)
    {
        var wav = InteractionSoundEngine.SynthesizeWave(cue);
        Assert.True(wav.Length > 44);
        Assert.Equal("RIFF"u8.ToArray(), wav[..4]);
        Assert.Equal("WAVE"u8.ToArray(), wav[8..12]);
        Assert.Equal("data"u8.ToArray(), wav[36..40]);
        Assert.InRange(InteractionSoundEngine.GetCueVolume(cue), 0.22, 0.32);
    }

    [Theory]
    [InlineData(true, System.Windows.WindowState.Normal, true)]
    [InlineData(true, System.Windows.WindowState.Maximized, true)]
    [InlineData(true, System.Windows.WindowState.Minimized, false)]
    [InlineData(false, System.Windows.WindowState.Normal, false)]
    public void KeepMainWindowFrontOnModeSwitchStateMachine(bool isVisible, System.Windows.WindowState state, bool expectedKeepFront) =>
        Assert.Equal(expectedKeepFront, MainWindow.ShouldKeepFrontAfterModeSwitch(isVisible, state));

    [Fact]
    public void WndProcClickThroughReturnsHtTransparentOnlyWhenLocked()
    {
        var handled = false;
        var resUnlocked = NotchMuse.App.Overlays.WindowClickThroughHelper.HandleClickThroughMessage(
            NotchMuse.App.Overlays.WindowClickThroughHelper.WmNcHitTest, locked: false, ref handled);
        Assert.False(handled);
        Assert.Equal(IntPtr.Zero, resUnlocked);

        var resLocked = NotchMuse.App.Overlays.WindowClickThroughHelper.HandleClickThroughMessage(
            NotchMuse.App.Overlays.WindowClickThroughHelper.WmNcHitTest, locked: true, ref handled);
        Assert.True(handled);
        Assert.Equal(NotchMuse.App.Overlays.WindowClickThroughHelper.HtTransparent, resLocked);
    }

    [Fact]
    public void FreeWindowSnapMagneticallySnapsCenterAndBypassesWithAlt()
    {
        var work = new NotchMuse.App.Overlays.NativeWindowRect { Left = 0, Top = 0, Right = 1920, Bottom = 1040 };
        var nearCenter = new NotchMuse.App.Overlays.NativeWindowRect { Left = 616, Top = 500, Right = 1316, Bottom = 700 }; // center is 610 (within 10px)

        var snapped = NotchMuse.App.Overlays.WindowClickThroughHelper.SnapFreeWindowRect(nearCenter, work, snapThresholdPx: 10, edgeInsetPx: 12, altBypass: false);
        Assert.True(snapped.SnappedCenterX);
        Assert.Equal(610, snapped.Rect.Left);

        var bypassed = NotchMuse.App.Overlays.WindowClickThroughHelper.SnapFreeWindowRect(nearCenter, work, snapThresholdPx: 10, edgeInsetPx: 12, altBypass: true);
        Assert.False(bypassed.SnappedCenterX);
        Assert.Equal(616, bypassed.Rect.Left);
    }

    [Theory]
    [InlineData(0, 400, 200, 0)]
    [InlineData(200, 400, 200, 100)]
    [InlineData(400, 400, 200, 200)]
    [InlineData(-20, 400, 200, 0)]
    [InlineData(500, 400, 200, 200)]
    public void ProgressBarClickToSeekComputesExactTargetSeconds(double clickX, double trackWidth, double duration, double expected) =>
        Assert.Equal(expected, MainWindow.ComputeSeekTargetFromPoint(clickX, trackWidth, duration), precision: 3);

    [Fact]
    public void AppearanceHasEightCuratedVisualStylePresets()
    {
        Assert.Equal(8, MainWindow.StylePresetSpecs.Length);
        Assert.Equal(8, MainWindow.StylePresetSpecs.Select(p => p.Preset).Distinct().Count());
        Assert.Contains(MainWindow.StylePresetSpecs, p => p.ColorMode == LyricColorMode.Gradient);
        Assert.Contains(MainWindow.StylePresetSpecs, p => p.ColorMode == LyricColorMode.Solid);
    }

    [Fact]
    public void QrCodeRendererEncodesEvmAndQqGroupPayloads()
    {
        var evmMatrix = QrCodeRenderer.EncodeVersion3M(SupportWindow.EvmAddress);
        var qqMatrix = QrCodeRenderer.EncodeVersion3M(SupportWindow.QqGroupJoinUrl);
        Assert.Equal(29, evmMatrix.GetLength(0));
        Assert.Equal(29, evmMatrix.GetLength(1));
        Assert.Equal(29, qqMatrix.GetLength(0));
        Assert.Equal("1137981671", SupportWindow.QqGroupId);
        // Top-left finder corners must be dark
        Assert.True(evmMatrix[0, 0]);
        Assert.True(evmMatrix[3, 3]);
        Assert.True(qqMatrix[0, 0]);
    }

    [Fact]
    public void UpdateServiceParsesSetupAssetDownloadUrl()
    {
        const string json = """
        {
          "tag_name": "v1.0.0",
          "name": "NotchMuse v1.0.0",
          "body": "New release",
          "html_url": "https://github.com/Xiye88/NotchMuse/releases/tag/v1.0.0",
          "assets": [
            { "name": "NotchMuse-Windows-win-x64-portable.exe", "browser_download_url": "https://example.com/portable.exe" },
            { "name": "NotchMuse-Setup.exe", "browser_download_url": "https://example.com/setup.exe" }
          ]
        }
        """;
        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var info = UpdateService.ParseReleaseJson(doc.RootElement);
        Assert.Equal("v1.0.0", info.TagName);
        Assert.Equal("https://example.com/setup.exe", info.DownloadUrl);
        Assert.True(UpdateService.IsNewer("0.9.0", info));
    }

    [Fact]
    public void LowColorContrastDetectorFlagsNearIdenticalGradientEnds()
    {
        Assert.True(NotchMuse.App.Themes.ThemeManager.HasLowColorContrast("#E06D1B", "#F59E0B"));
        Assert.False(NotchMuse.App.Themes.ThemeManager.HasLowColorContrast("#FF7B2C", "#FF2E88"));
    }

    [Fact]
    public async Task LyricsEngineEarlyExitsOnceNetEaseAndPeerAgreeWithoutWaitingOnSlowStraggler()
    {
        var track = new Track("稻香", "周杰伦", "魔杰座", 220, Platform: "apple");
        static LyricsCandidate Make(string provider, string platform) =>
            new(provider, platform, "id", "稻香", "周杰伦", "魔杰座", 220,
                new(Enumerable.Range(0, 15).Select(i => new LyricLine(10 + i * 12, $"这是第{i}句歌词文本内容")).ToArray()), 100);

        var fastNetEase = new FakeTimedSource("NetEase", Make("NetEase", "netease"), 40);
        var fastQq = new FakeTimedSource("QQ", Make("QQ", "qq"), 60);
        var slowKugou = new FakeTimedSource("Kugou", Make("Kugou", "kugou"), 3500);
        var engine = new NotchMuse.Sources.LyricsEngine([fastNetEase, fastQq, slowKugou]);

        var sw = System.Diagnostics.Stopwatch.StartNew();
        var result = await engine.FindAsync(track, CancellationToken.None, force: true);
        sw.Stop();

        Assert.NotNull(result.Decision.Winner);
        Assert.True(sw.ElapsedMilliseconds < 1200, $"Expected early-exit <1200ms, took {sw.ElapsedMilliseconds}ms");
    }

    [Fact]
    public void TaskbarAndTopIslandRespondToDoubleLineToggle()
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try
            {
                var singleSettings = new AppSettings { FloatingDoubleLine = false, BilingualEnabled = false };
                var doubleSettings = new AppSettings { FloatingDoubleLine = true, BilingualEnabled = false };

                // 1. Taskbar bottom-left overlay
                var tb = new NotchMuse.App.Overlays.TaskbarLyricsWindow();
                tb.UpdateAppearance(singleSettings);
                tb.UpdateLyric("主行歌词", null, 0.5, showBilingual: false, nextLine: "下一句预告歌词");
                var tbSub = (System.Windows.Controls.TextBlock)tb.FindName("SubLyricText")!;
                Assert.Equal(System.Windows.Visibility.Collapsed, tbSub.Visibility);

                tb.UpdateAppearance(doubleSettings);
                tb.UpdateLyric("主行歌词", null, 0.5, showBilingual: false, nextLine: "下一句预告歌词");
                Assert.Equal(System.Windows.Visibility.Visible, tbSub.Visibility);
                Assert.Equal("下一句预告歌词", tbSub.Text);

                // 2. Top Island overlay
                var island = new NotchMuse.App.Overlays.FloatingLyricsWindow();
                island.ConfigureMode(LyricsDisplayMode.TopIsland, singleSettings);
                island.UpdateLyric("主行歌词", null, 0.5, showBilingual: false, nextLine: "下一句预告歌词");
                var islandSub = (System.Windows.Controls.TextBlock)island.FindName("SubLyricText")!;
                Assert.Equal(System.Windows.Visibility.Collapsed, islandSub.Visibility);

                island.ConfigureMode(LyricsDisplayMode.TopIsland, doubleSettings);
                island.UpdateLyric("主行歌词", null, 0.5, showBilingual: false, nextLine: "下一句预告歌词");
                Assert.Equal(System.Windows.Visibility.Visible, islandSub.Visibility);
                Assert.Equal("下一句预告歌词", islandSub.Text);
            }
            catch (Exception ex)
            {
                failure = ex;
            }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        if (failure is not null) throw new Exception("STA double-line test failed", failure);
    }

    private sealed class FakeTimedSource(string name, LyricsCandidate? candidate, int delayMs) : ILyricsSource
    {
        public string Name => name;
        public async Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken)
        {
            await Task.Delay(delayMs, cancellationToken);
            return candidate;
        }
    }
}

