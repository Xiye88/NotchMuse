namespace NotchMuse.Core;

public sealed record Track(string Title, string Artist, string Album, double Duration,
    bool IsMusicVideo = false, string Platform = "unknown", string? NativeId = null, string? Isrc = null);
public sealed record LyricWord(double Start, double End, string Text);
public sealed record LyricLine(double Start, string Text, double? End = null,
    IReadOnlyList<LyricWord>? Words = null, string? Translation = null);
public sealed record LyricDocument(IReadOnlyList<LyricLine> Lines, double Offset = 0)
{
    public IReadOnlyList<LyricLine> Normalized => Lines.Select(l => l with
    {
        Start = l.Start - Offset, End = l.End - Offset,
        Words = l.Words?.Select(w => w with { Start = w.Start - Offset, End = w.End - Offset }).ToArray()
    }).OrderBy(l => l.Start).ToArray();
}
public sealed record LyricsCandidate(string Provider, string Platform, string? Id,
    string Title, string Artist, string? Album, double Duration, LyricDocument Document,
    int MatcherScore = 0, string? Isrc = null, bool LiveIdentityVerified = false);
public sealed record SelectionDecision(LyricsCandidate? Winner, string Reason,
    IReadOnlyDictionary<string, string> Rejected);
public sealed record SourceResult(string Provider, LyricsCandidate? Candidate, string Status,
    string? Error = null, double ElapsedMs = 0);
public interface ILyricsSource
{
    string Name { get; }
    Task<LyricsCandidate?> FetchAsync(Track track, CancellationToken cancellationToken);
}
