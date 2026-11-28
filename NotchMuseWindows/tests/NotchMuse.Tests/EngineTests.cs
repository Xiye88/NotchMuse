using System.IO.Compression;
using System.IO;
using System.Net.Http;
using System.Text;
using NotchMuse.Core;
using NotchMuse.Sources;
using Xunit;

namespace NotchMuse.Tests;

public sealed class EngineTests
{
    private static readonly Track Song = new("Song", "Artist", "", 200);
    private static LyricsCandidate Candidate(string provider = "QQ", int count = 15, double shift = 0, string? album = null) =>
        new(provider, provider.ToLowerInvariant(), "id", "Song", "Artist", album, 200,
            new(Enumerable.Range(0, count).Select(i => new LyricLine(i * 10 + shift, $"Vocal phrase number {i}")).ToArray()), 100);

    [Theory]
    [InlineData("Kenshi Yonezu", "米津玄师")]
    [InlineData("Hikaru Utada", "宇多田ヒカル")]
    [InlineData("Official HIGE DANdism", "Official髭男dism")]
    [InlineData("Fujii Kaze", "藤井風")]
    [InlineData("Yorushika", "ヨルシカ")]
    [InlineData("Aimyon", "あいみょん")]
    [InlineData("Sakanaction", "サカナクション")]
    [InlineData("Sukima Switch", "スキマスイッチ")]
    [InlineData("Jay Chou", "周杰倫")]
    public void ArtistAliasesNormalize(string a, string b) => Assert.Equal(TrackMatcher.ArtistKey(a), TrackMatcher.ArtistKey(b));

    [Theory]
    [InlineData(5, false, true)] [InlineData(5.01, false, false)]
    [InlineData(22, true, true)] [InlineData(22.01, true, false)] [InlineData(41, true, false)]
    public void DurationGates(double difference, bool video, bool accepted) =>
        Assert.Equal(accepted, TrackMatcher.Score(Song with { IsMusicVideo = video }, "Song", "Artist", 200 + difference) > 0);

    [Fact] public void EnhancedLrcRetainsWordTimingsAndOffset()
    {
        var doc = LyricParser.Parse("[offset:500]\n[00:10.000]<00:10.000>Hello <00:11.000>world<00:12.000>");
        Assert.Equal(9.5, doc.Normalized[0].Start); Assert.Equal(2, doc.Normalized[0].Words!.Count);
        Assert.Equal(11.5, doc.Normalized[0].End); Assert.Equal("Hello world", doc.Lines[0].Text);
    }
    [Fact] public void RepeatedLrcTimestampsExpand() => Assert.Equal(new[] { 10d, 20d }, LyricParser.Parse("[00:10][00:20]Hello").Lines.Select(l => l.Start));
    [Fact] public void MalformedLrcIsIgnored() => Assert.Empty(LyricParser.Parse("[bad]Hello\nhello").Lines);
    [Fact] public void YrcAbsoluteWordsAndKrcRelativeWordsAgree()
    {
        var y = LyricParser.ParseRich("[10000,2000](10000,1000,0)Hello(11000,1000,0)world", false);
        var k = LyricParser.ParseRich("[10000,2000]<0,1000,0>Hello<1000,1000,0>world", true);
        Assert.Equal(y.Lines[0].Words, k.Lines[0].Words);
    }
    [Fact] public void KrcDecryptsOfficialEnvelope()
    {
        const string raw = "[1000,2000]<0,2000,0>hello";
        using var output = new MemoryStream();
        using (var zlib = new ZLibStream(output, CompressionMode.Compress, true)) zlib.Write(Encoding.UTF8.GetBytes(raw));
        byte[] key = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69];
        var bytes = output.ToArray(); for (var i = 0; i < bytes.Length; i++) bytes[i] ^= key[i % key.Length];
        Assert.Equal(raw, KugouSource.DecodeKrc(Convert.ToBase64String(Encoding.ASCII.GetBytes("krc1").Concat(bytes).ToArray())));
    }
    [Fact] public void FeatIsPreservedInArtist()
    {
        var t = MediaMetadataSanitizer.Clean(new("Artist - Song (feat. Guest) (Official Video) - YouTube Music", "", "", 200), true);
        Assert.Equal("Song", t.Title); Assert.Equal("Artist, Guest", t.Artist); Assert.True(t.IsMusicVideo);
    }
    [Fact] public void NaturalAndArtistIsNotSplit() => Assert.Equal(100, TrackMatcher.Score(Song with { Artist = "Of Monsters and Men" }, "Song", "Of Monsters and Men", 200));
    [Fact] public void MainArtistSubsetScores27() => Assert.Equal(97, TrackMatcher.Score(Song, "Song", "Artist, Guest", 200));
    [Fact] public void UnrelatedArtistCannotScore() => Assert.Equal(0, TrackMatcher.Score(Song, "Song", "Other", 200));
    [Fact] public void MissingAlbumSkipsAlbumVersionGate() => Assert.Null(TrackMatcher.IdentityRejection(Song, "Song", "Artist", "Live"));
    [Fact] public void LiveRecordingIsRejected() => Assert.Equal("version_mismatch", TrackMatcher.IdentityRejection(Song, "Song (Live)", "Artist", ""));
    [Fact] public void StrictSoloFallbackAcceptsFullVocals() => Assert.NotNull(LyricsSelection.Select([Candidate()], Song).Winner);
    [Theory] [InlineData(5, 100)] [InlineData(11, 100)] [InlineData(15, 95)]
    public void StrictSoloRejectsWeakEvidence(int count, int score) => Assert.Null(LyricsSelection.Select([Candidate(count: count) with { MatcherScore = score }], Song).Winner);
    [Fact] public void SoloRejectsShortCoverage() => Assert.Null(LyricsSelection.Select([Candidate() with { Document = new(Enumerable.Range(0, 15).Select(i => new LyricLine(i * 2, "vocal number " + i)).ToArray()) }], Song).Winner);
    [Fact] public void IndependentTimingConflictRejectsBoth() => Assert.Null(LyricsSelection.Select([Candidate(), Candidate("NetEase", shift: 5)], Song).Winner);
    [Fact] public void IndependentAnchorsAllowSmallError() => Assert.True(LyricsSelection.TimelinesAgree(Candidate(), Candidate("NetEase", shift: .7)));
    [Fact] public void SparseAnchorsCannotCorroborate() => Assert.False(LyricsSelection.TimelinesAgree(Candidate(count: 4), Candidate("NetEase", count: 4)));
    [Fact] public void ResolverSoloRequiresTenLines() => Assert.Null(LyricsSelection.Select([Candidate("LRCMux", count: 9)], Song).Winner);
    [Fact] public void ResolverSoloAllowsMissingAlbumWithFullSpan() => Assert.NotNull(LyricsSelection.Select([Candidate("LRCMux")], Song).Winner);
    [Fact] public void ResolverCannotOverrideExistingDirectFailure() => Assert.Null(LyricsSelection.Select([Candidate("QQ", count: 4), Candidate("LRCMux")], Song).Winner);
    [Fact] public void TrailingWatermarkIsTrimmed()
    {
        var c = Candidate(); c = c with { Document = new(c.Document.Lines.Append(new(240, "watermark")).ToArray()) };
        Assert.Equal(15, LyricsSelection.RepairTrailingOverflow(c, Song).Document.Lines.Count);
        Assert.NotNull(LyricsSelection.Select([c], Song).Winner);
    }
    [Fact] public void MostlyInvalidTimelineIsNotRepaired()
    { var c = Candidate(shift: 150); Assert.Same(c, LyricsSelection.RepairTrailingOverflow(c, Song)); }
    [Fact] public void CreditsCannotSatisfyVocalCount()
    { var c = Candidate() with { Document = new(Enumerable.Range(0, 15).Select(i => new LyricLine(i * 10, "作词：someone" + i)).ToArray()) }; Assert.Null(LyricsSelection.Select([c], Song).Winner); }
    [Theory] [InlineData("vlc.exe")] [InlineData("potplayer.exe")] [InlineData("mpv.exe")] [InlineData("bilibili.exe")]
    public void VideoPlayersAreManualOnly(string id) => Assert.False(PlayerCatalog.Allows(id, "Song", "auto"));
    [Theory] [InlineData("Zoom.exe")] [InlineData("wemeetapp.exe")] [InlineData("Discord.exe")] [InlineData("MicrosoftTeams.exe")] [InlineData("obs64.exe")]
    public void CallsCannotTriggerEvenInAllMode(string id) => Assert.False(PlayerCatalog.Allows(id, "Song", "all"));
    [Fact] public void BrowserRequiresMusicIdentity() { Assert.False(PlayerCatalog.Allows("chrome.exe", "Video - YouTube", "auto")); Assert.True(PlayerCatalog.Allows("chrome.exe", "Song - YouTube Music", "auto")); }
    [Fact] public void CatalogContains36Profiles() => Assert.True(PlayerCatalog.Players.Length >= 36);
    [Fact] public void UnknownSourceDurationIsRejected() => Assert.Equal("source_duration_unknown", LyricsSelection.Rejection(Candidate() with { Duration = 0 }, Song));
    [Fact] public void EmptyLinesNeverMatchInstrumental() => Assert.Null(LyricsSelection.Select([Candidate() with { Document = new([]) }], Song).Winner);
    [Fact] public void AlbumSuffixMatches() => Assert.True(TrackMatcher.AlbumMatches("After Hours", Song with { Album = "After Hours - Single" }));
    [Fact] public void WithInsideSongTitleIsNotCollaborator()
    {
        var t = MediaMetadataSanitizer.Clean(new("작은 것들을 위한 시 (Boy With Luv)", "BTS", "", 200));
        Assert.Equal("작은 것들을 위한 시 (Boy With Luv)", t.Title); Assert.Equal("BTS", t.Artist);
    }
    [Fact] public async Task QqSearchSendsChineseUtf8AndParsesLyrics()
    {
        using var handler = new QqHandler(); using var client = new HttpClient(handler);
        var source = new QqSource(client);
        var candidate = await source.FetchAsync(new("七里香", "周杰伦", "七里香", 299), CancellationToken.None);
        Assert.NotNull(candidate); Assert.Equal("窗外的麻雀", candidate.Document.Lines[0].Text);
        Assert.Contains("七里香", handler.Body, StringComparison.Ordinal);
    }
    private sealed class QqHandler : HttpMessageHandler
    {
        public string Body { get; private set; } = "";
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.Method == HttpMethod.Post)
            {
                Body = await request.Content!.ReadAsStringAsync(cancellationToken);
                Assert.Equal("application/json", request.Content.Headers.ContentType!.ToString());
                return new(System.Net.HttpStatusCode.OK) { Content = new StringContent("""{"req_1":{"data":{"body":{"song":{"list":[{"mid":"mid","title":"七里香","singer":[{"name":"周杰伦"}],"album":{"name":"七里香"},"interval":299}]}}}}}""") };
            }
            return new(System.Net.HttpStatusCode.OK) { Content = new StringContent("""{"lyric":"[00:27.74]窗外的麻雀"}""") };
        }
    }
    [Fact] public void InvalidRichWordEndDowngradesOnlyThatLine()
    {
        var doc = LyricParser.ParseRich("[10000,1000]<0,2000,0>Hello\n[12000,1000]<0,1000,0>World", true);
        Assert.Equal(2, doc.Lines.Count); Assert.Null(doc.Lines[0].Words); Assert.Single(doc.Lines[1].Words!);
    }

    // === Mac 4f79bc4 4-Rule Precision Sprint Parity Tests ===

    [Fact]
    public void NetEasePureMusicVetoesGenericFakeLyrics()
    {
        var track = new Track("River Flows In You", "Yiruma", "First Love", 188, Platform: "apple");
        var neteasePure = new LyricsCandidate("NetEase", "netease", "123", "River Flows In You", "Yiruma", "First Love", 188,
            new([]), 100, Evidence: LyricsEvidence.Instrumental);
        var fakeVocals = new LyricsCandidate("QQ", "qq", "qq1", "River Flows In You", "Yiruma", "First Love", 188,
            new(Enumerable.Range(0, 15).Select(i => new LyricLine(i * 10, $"Fake lyric line {i}")).ToArray()), 100);

        var decision = LyricsSelection.Select([neteasePure, fakeVocals], track);
        Assert.Null(decision.Winner);
        Assert.Equal("instrumental_recording", decision.Reason);
    }

    [Fact]
    public void StrongerVerifiedVocalBeatsNetEasePureMusic()
    {
        var track = new Track("Song", "Artist", "Album", 200, Platform: "spotify", NativeId: "sp123");
        var neteasePure = new LyricsCandidate("NetEase", "netease", "999", "Song", "Artist", "Album", 200,
            new([]), 100, Evidence: LyricsEvidence.Instrumental); // Tier 3
        var spotifyExact = new LyricsCandidate("Spotify", "spotify", "sp123", "Song", "Artist", "Album", 200,
            new(Enumerable.Range(0, 15).Select(i => new LyricLine(i * 10, $"Verified vocal line {i}")).ToArray()), 100); // Tier 1

        var decision = LyricsSelection.Select([neteasePure, spotifyExact], track);
        Assert.NotNull(decision.Winner);
        Assert.Equal("Spotify", decision.Winner.Provider);
    }

    [Fact]
    public void StandaloneInstrumentalNoticeNeverCountsAsVocalAnchor()
    {
        var track = new Track("Kiss the Rain", "Yiruma", "", 256);
        var noticeCand = new LyricsCandidate("QQ", "qq", "q1", "Kiss the Rain", "Yiruma", "", 256,
            new([new LyricLine(0, "纯音乐，请欣赏")]), 100);
        Assert.Empty(LyricsSelection.Anchors(noticeCand));
        Assert.Equal("instrumental_notice", LyricsSelection.Rejection(noticeCand, track));
        Assert.Null(LyricsSelection.Select([noticeCand], track).Winner);
    }

    [Fact]
    public void KugouUgcRejectedSoloButAcceptedWhenCorroborated()
    {
        var ugc = Candidate("Kugou") with { Evidence = LyricsEvidence.UserContribution };
        var soloDecision = LyricsSelection.Select([ugc], Song);
        Assert.Null(soloDecision.Winner);
        Assert.Equal("unverified_user_contribution", soloDecision.Rejected["Kugou"]);

        var qqDirect = Candidate("QQ");
        var backedDecision = LyricsSelection.Select([ugc, qqDirect], Song);
        Assert.NotNull(backedDecision.Winner);
    }

    [Fact]
    public void ResolverSoloEmptyAlbumRequiresSourceTrackId()
    {
        var noIdMux = Candidate("LRCMux") with { Id = "" };
        Assert.Null(LyricsSelection.Select([noIdMux], Song).Winner);

        var withIdMux = Candidate("LRCMux") with { Id = "1824045033" };
        Assert.NotNull(LyricsSelection.Select([withIdMux], Song).Winner);

        Assert.Equal("1824045033", LrcMuxSource.ExtractSourceTrackId("https://music.163.com/#/song?id=1824045033", "netease"));
        Assert.Equal("4cOdK2wGLETKBW3PvgPWqT", LrcMuxSource.ExtractSourceTrackId("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT", "spotify"));
    }

    [Fact]
    public void DirtyYouTubeTitlePreservesHyphenTitleAndLiveMarker()
    {
        var hyphenSong = MediaMetadataSanitizer.Clean(new("烏 - Raven", "Ado", "", 210, IsMusicVideo: true, Platform: "youtube"));
        Assert.Equal("烏 - Raven", hyphenSong.Title);
        Assert.Equal("Ado", hyphenSong.Artist);

        var multiHyphen = MediaMetadataSanitizer.Clean(new("LiSA - 残酷な夜に輝け - Shine in the Cruel Night (Official Video)", "LiSA", "", 230, IsMusicVideo: true, Platform: "youtube"));
        Assert.Equal("残酷な夜に輝け - Shine in the Cruel Night", multiHyphen.Title);
        Assert.Equal("LiSA", multiHyphen.Artist);

        var liveMarked = MediaMetadataSanitizer.Clean(new("Artist - Song (Live Video) - YouTube Music", "Artist", "", 240));
        Assert.Contains("Live", liveMarked.Title, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void EmptyAlbumStudioRejectsConcertAlbums()
    {
        var studio = new Track("少女的祈禱", "杨千嬅", "", 212);
        Assert.Equal("album_version_mismatch", TrackMatcher.IdentityRejection(studio, "少女的祈禱", "杨千嬅", "杨千嬅演唱会2010"));
        Assert.Equal("album_version_mismatch", TrackMatcher.IdentityRejection(studio with { IsMusicVideo = true }, "少女的祈禱", "杨千嬅", "Live at Coliseum"));
    }

    [Fact]
    public void LocalizedSoundtrackBillingAndChineseAmpersandAndContextualCleanNormalize()
    {
        var ost = new Track("告白 (电视剧《偷偷藏不住》心动曲)", "汪苏泷 & 赵露思", "", 220);
        Assert.Equal("告白 汪苏泷 赵露思", TrackMatcher.SearchQuery(ost));
        Assert.Equal(TrackMatcher.ParseTitle("告白").Name, TrackMatcher.ParseTitle("告白 (電視劇《偷偷藏不住》心動曲)").Name);

        // Contextual 乾淨 -> 干净 while preserving 乾隆
        Assert.Equal(TrackMatcher.Normalize("干净"), TrackMatcher.Normalize("乾淨"));
        Assert.NotEqual(TrackMatcher.Normalize("乾隆"), TrackMatcher.Normalize("干隆"));

        // Girls' Generation / SNSD / 소녀시대 -> 少女时代
        Assert.Equal(TrackMatcher.ArtistKey("少女时代"), TrackMatcher.ArtistKey("Girls' Generation"));
        Assert.Equal(TrackMatcher.ArtistKey("少女时代"), TrackMatcher.ArtistKey("SNSD"));
        Assert.Equal(TrackMatcher.ArtistKey("少女时代"), TrackMatcher.ArtistKey("소녀시대"));
    }
}
