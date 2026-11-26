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
}

