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
}

