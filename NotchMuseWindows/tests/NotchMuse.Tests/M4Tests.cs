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
}

