using System.Text.RegularExpressions;

namespace NotchMuse.Core;

public static class LyricsSelection
{
    private static readonly string[] Credits = ["作词", "作曲", "编曲", "制作", "词", "曲", "监制", "出品", "发行", "统筹", "企划", "文案", "宣传", "版权", "未经许可", "lyrics", "composer", "produced", "written"];
    private static readonly string[] InstrumentalMarkers = ["纯音乐请欣赏", "纯音乐", "instrumental", "no lyrics", "music only"];
    public static IReadOnlyList<(string Text, double Time)> Anchors(LyricsCandidate c) => c.Document.Normalized
        .Where(l => !Credits.Any(p => TrackMatcher.Normalize(l.Text).StartsWith(p, StringComparison.OrdinalIgnoreCase)))
        .Where(l => !Regex.IsMatch(l.Text, @"^(?:录音|混音|母带|人声|和声|弦乐|吉他|贝斯|鼓|键盘|OP|SP)\s*[:：]", RegexOptions.IgnoreCase))
        .Select(l => (Text: TrackMatcher.Normalize(l.Text), Time: l.Start))
        .Where(l => l.Text.Length >= 4 && l.Text != TrackMatcher.Normalize(c.Title + c.Artist) && l.Text != TrackMatcher.Normalize(c.Artist + c.Title)).ToArray();

    private static double[] Deltas(LyricsCandidate a, LyricsCandidate b)
    {
        var aa = Anchors(a); var bb = Anchors(b);
        // Equivalent complete vocal bodies may use different line breaks.
        if (string.Concat(aa.Select(x => x.Text)) == string.Concat(bb.Select(x => x.Text)) && aa.Count >= 5 && bb.Count >= 5)
        {
            static Dictionary<int, double> Boundaries(IReadOnlyList<(string Text, double Time)> lines)
            {
                var d = new Dictionary<int, double>(); var index = 0;
                foreach (var l in lines) { d[index] = l.Time; index += l.Text.Length; } return d;
            }
            var x = Boundaries(aa); var y = Boundaries(bb);
            var common = x.Keys.Intersect(y.Keys).Order().ToArray();
            if (common.Length >= 5 && common[^1] - common[0] >= aa.Sum(l => l.Text.Length) / 2)
                return common.Select(k => Math.Abs(x[k] - y[k])).Order().ToArray();
        }
        var available = bb.ToList(); var deltas = new List<double>();
        foreach (var l in aa)
        {
            var matches = available.Select((v, i) => (v, i)).Where(x => x.v.Text == l.Text).ToArray();
            if (matches.Length == 0 && l.Text.Length >= 5)
            {
                var prefixes = available.Select((v, i) => (v, i)).Where(x => x.v.Text.Length >= 5 &&
                    (x.v.Text.StartsWith(l.Text, StringComparison.Ordinal) || l.Text.StartsWith(x.v.Text, StringComparison.Ordinal))).ToArray();
                if (prefixes.Length == 1) matches = prefixes;
            }
            if (matches.Length == 0) continue;
            var best = matches.MinBy(x => Math.Abs(x.v.Time - l.Time));
            deltas.Add(Math.Abs(l.Time - best.v.Time)); available.RemoveAt(best.i);
        }
        return deltas.Order().ToArray();
    }

    public static bool TimelinesAgree(LyricsCandidate a, LyricsCandidate b)
    {
        var deltas = Deltas(a, b);
        var required = Math.Max(5, (int)Math.Ceiling(Math.Min(Anchors(a).Count, Anchors(b).Count) * .35));
        return deltas.Length >= required && deltas[deltas.Length / 2] <= 1 && deltas.Count(d => d > 2) * 5 <= deltas.Length;
    }

    public static bool TimelinesConflict(LyricsCandidate a, LyricsCandidate b)
    {
        var d = Deltas(a, b); var aa = Anchors(a); var bb = Anchors(b);
        var required = Math.Max(5, (int)Math.Ceiling(Math.Min(aa.Count, bb.Count) * .35));
        return d.Length >= required && (d[d.Length / 2] > 3 || d.Count(x => x > 3) * 2 > d.Length ||
            aa.Count > 0 && bb.Count > 0 && Math.Abs(aa[^1].Time - bb[^1].Time) > 20 && (double)Math.Min(aa.Count, bb.Count) / Math.Max(aa.Count, bb.Count) < .65);
    }

    public static string? Rejection(LyricsCandidate c, Track t)
    {
        var lines = c.Document.Normalized;
        if (lines.Count == 0 || !lines.Any(l => !string.IsNullOrWhiteSpace(l.Text))) return "empty";
        var lyricText = string.Concat(lines.Select(l => TrackMatcher.Normalize(l.Text)));
        if (InstrumentalMarkers.Any(marker => lyricText.Contains(TrackMatcher.Normalize(marker), StringComparison.OrdinalIgnoreCase)) &&
            lines.Count(l => !string.IsNullOrWhiteSpace(l.Text) && !Credits.Any(p => TrackMatcher.Normalize(l.Text).StartsWith(TrackMatcher.Normalize(p), StringComparison.OrdinalIgnoreCase))) <= 2)
            return "instrumental";
        if (!double.IsFinite(t.Duration) || t.Duration <= 0) return "track_duration_unknown";
        if (lines.Any(l => !double.IsFinite(l.Start) || l.Start < -1 || l.Start > t.Duration + (t.IsMusicVideo ? 15 : 4) ||
            l.End is { } end && (!double.IsFinite(end) || end < l.Start || end > t.Duration + (t.IsMusicVideo ? 20 : 8)) ||
            l.Words?.Any(w => !double.IsFinite(w.Start) || !double.IsFinite(w.End) || w.End < w.Start || w.Start < l.Start || w.End > (l.End ?? t.Duration + 8)) == true))
            return "timeline_out_of_recording";
        if (TrackMatcher.IdentityRejection(t, c.Title, c.Artist, c.Album) is { } reason) return reason;
        if (c.Provider != "LRCMux" && c.Platform == t.Platform && t.Platform != "netease" && t.NativeId is not null && c.Id is not null &&
            c.Id.Replace("spotify:track:", "", StringComparison.Ordinal) != t.NativeId.Replace("spotify:track:", "", StringComparison.Ordinal)) return "exact_id_mismatch";
        if (c.Provider != "LRCMux" && t.Isrc is not null && c.Isrc is not null && TrackMatcher.Normalize(t.Isrc) != TrackMatcher.Normalize(c.Isrc)) return "isrc_mismatch";
        if (!double.IsFinite(c.Duration) || c.Duration <= 0) return "source_duration_unknown";
        if (Math.Abs(t.Duration - c.Duration) > (t.IsMusicVideo ? 22 : 5)) return "duration_risk";
        return null;
    }

    public static LyricsCandidate RepairTrailingOverflow(LyricsCandidate c, Track t)
    {
        if (c.Provider == "LRCMux" || string.IsNullOrEmpty(c.Id) || Rejection(c, t) != "timeline_out_of_recording") return c;
        var lines = c.Document.Normalized; var ceiling = t.Duration + (t.IsMusicVideo ? 15 : 4);
        var good = lines.Count(l => l.Start >= -1 && l.Start <= ceiling);
        if (lines.Count < 8 || good * 10 < lines.Count * 9) return c;
        var repaired = lines.Where(l => l.Start <= ceiling).Select(l => l.End is { } end &&
            (!double.IsFinite(end) || end < l.Start || end > t.Duration + (t.IsMusicVideo ? 20 : 8))
            ? l with { End = null, Words = null } : l).ToArray();
        return c with { Document = new(repaired) };
    }

    private static int Tier(LyricsCandidate c, Track t)
    {
        if (c.Provider != "LRCMux" && c.Platform == t.Platform && c.Id is not null && c.Id == t.NativeId &&
            (t.Platform != "netease" || c.LiveIdentityVerified)) return 1;
        if (c.Provider != "LRCMux" && c.Isrc is not null && t.Isrc is not null && TrackMatcher.Normalize(c.Isrc) == TrackMatcher.Normalize(t.Isrc)) return 2;
        return TrackMatcher.AlbumMatches(c.Album, t) ? 3 : 4;
    }

    public static SelectionDecision Select(IEnumerable<LyricsCandidate> candidates, Track track)
    {
        var rejected = new Dictionary<string, string>();
        var valid = new List<LyricsCandidate>();
        foreach (var c in candidates.Select(c => RepairTrailingOverflow(c, track)))
        {
            if (Rejection(c, track) is { } reason) rejected[c.Provider] = reason; else valid.Add(c);
        }
        var direct = valid.Where(c => c.Provider != "LRCMux").ToArray();
        bool ResolverSolo(LyricsCandidate c)
        {
            var a = Anchors(c);
            return direct.Length == 0 && (string.IsNullOrWhiteSpace(track.Album) || TrackMatcher.AlbumMatches(c.Album, track)) &&
                a.Count >= 10 && a[^1].Time >= track.Duration * .5 && a[^1].Time - a[0].Time >= track.Duration * .45;
        }
        var eligible = valid.Where(c =>
        {
            var conflict = direct.Any(o => o.Provider != c.Provider && TimelinesConflict(c, o));
            var independent = direct.Any(o => o.Provider != c.Provider && o.Platform != c.Platform && TimelinesAgree(c, o));
            if (c.Provider == "LRCMux" && !direct.Any(o => TimelinesAgree(c, o)) && !ResolverSolo(c))
            { rejected[c.Provider] = "resolver_metadata_unverified"; return false; }
            if (Tier(c, track) < 4) return true;
            var anchors = Anchors(c);
            var solo = c.Provider != "LRCMux" && c.MatcherScore >= 96 && anchors.Count >= 12 &&
                anchors[^1].Time >= track.Duration * .55 && anchors[^1].Time - anchors[0].Time >= track.Duration * .45;
            if (!conflict && (independent || solo || c.Provider == "LRCMux" && ResolverSolo(c))) return true;
            rejected[c.Provider] = conflict ? "timeline_conflict" : "identity_ambiguous"; return false;
        }).ToList();
        if (eligible.Count == 0) return new(null, "no_verified_candidate", rejected);
        var bestTier = eligible.Min(c => Tier(c, track));
        if (bestTier < 3) eligible = eligible.Where(c => Tier(c, track) == bestTier).ToList();
        var ordered = eligible.OrderByDescending(c => c.MatcherScore)
            .ThenByDescending(c => c.Document.Normalized.Count)
            .ToList();
        if (ordered.Count > 1)
        {
            var preferred = ordered[0];
            var competing = ordered.Skip(1).Where(c => c.Provider != preferred.Provider).ToArray();
            foreach (var other in competing)
            {
                if (TimelinesAgree(preferred, other)) continue;
                var sameTrustedTier = Tier(preferred, track) <= 3 && Tier(other, track) <= 3;
                var scoreGap = preferred.MatcherScore - other.MatcherScore;
                var preferredHasFullSpan = Anchors(preferred).Count >= 12 &&
                    Anchors(preferred)[^1].Time >= track.Duration * .55 &&
                    Anchors(preferred)[^1].Time - Anchors(preferred)[0].Time >= track.Duration * .45;
                if (sameTrustedTier && scoreGap < 6 && !preferredHasFullSpan)
                    return new(null, TimelinesConflict(preferred, other) ? "timeline_conflict" : "content_ambiguity", rejected);
                rejected[other.Provider] = "lower_confidence_content_conflict";
            }
            eligible = [preferred];
        }
        var winner = eligible.OrderBy(c => Tier(c, track)).ThenByDescending(c => c.Document.Lines.Sum(l => l.Words?.Count ?? 0))
            .ThenByDescending(c => c.MatcherScore).ThenBy(c => c.Provider, StringComparer.Ordinal).First();
        return new(winner, "selected", rejected);
    }
}
