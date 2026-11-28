using System.Text.RegularExpressions;

namespace NotchMuse.Core;

public static class LyricsSelection
{
    private static readonly string[] Credits =
    [
        "作词", "作曲", "编曲", "制作", "词", "曲", "监制", "出品", "发行",
        "统筹", "企划", "文案", "宣传", "版权", "未经许可",
        "lyrics", "composer", "produced", "written"
    ];

    private static readonly HashSet<string> InstrumentalNotices = new(StringComparer.Ordinal)
    {
        "纯音乐请欣赏", "純音樂請欣賞", "纯音乐无歌词", "純音樂無歌詞",
        "本歌曲为纯音乐请欣赏", "本歌曲為純音樂請欣賞",
        "instrumental", "instrumentalonly", "instrumentalnolyric", "instrumentalnolyrics"
    };

    private static readonly string[] SourcePriority =
    [
        "LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"
    ];

    public static bool IsInstrumentalNotice(string value)
    {
        var normalized = new System.Text.StringBuilder(value.Length);
        foreach (var rune in value.ToLowerInvariant().EnumerateRunes())
            if (System.Text.Rune.IsLetterOrDigit(rune))
                normalized.Append(rune.ToString());
        return InstrumentalNotices.Contains(normalized.ToString());
    }

    public static IReadOnlyList<(string Text, double Time)> Anchors(LyricsCandidate c) => c.Document.Normalized
        .Where(l => !IsInstrumentalNotice(l.Text))
        .Where(l => !Credits.Any(p => TrackMatcher.Normalize(l.Text).StartsWith(p, StringComparison.OrdinalIgnoreCase)))
        .Where(l => !Regex.IsMatch(l.Text, @"^(?:录音|混音|母带|人声|和声|弦乐|音乐录音|音乐工作|插画|吉他|古典吉他|贝斯|鼓|键盘|OP|SP)\s*[:：]", RegexOptions.IgnoreCase))
        .Select(l => (Text: TrackMatcher.Normalize(l.Text), Time: l.Start))
        .Where(l => l.Text.Length >= 4 && l.Text != TrackMatcher.Normalize(c.Title + c.Artist) && l.Text != TrackMatcher.Normalize(c.Artist + c.Title))
        .ToArray();

    private static double[]? CompleteBodyBoundaryDeltas(LyricsCandidate a, LyricsCandidate b)
    {
        var aa = Anchors(a);
        var bb = Anchors(b);
        if (aa.Count < 5 || bb.Count < 5) return null;
        var textA = string.Concat(aa.Select(x => x.Text));
        var textB = string.Concat(bb.Select(x => x.Text));
        if (textA.Length == 0 || textA != textB) return null;

        static Dictionary<int, double> Boundaries(IReadOnlyList<(string Text, double Time)> lines)
        {
            var d = new Dictionary<int, double>();
            var index = 0;
            foreach (var l in lines)
            {
                d.TryAdd(index, l.Time);
                index += l.Text.Length;
            }
            return d;
        }

        var x = Boundaries(aa);
        var y = Boundaries(bb);
        var common = x.Keys.Intersect(y.Keys).Order().ToArray();
        if (common.Length >= Math.Min(5, Math.Min(aa.Count, bb.Count)) && common[^1] - common[0] >= textA.Length / 2)
            return common.Select(k => Math.Abs(x[k] - y[k])).Order().ToArray();
        return null;
    }

    private static double[] Deltas(LyricsCandidate a, LyricsCandidate b)
    {
        if (CompleteBodyBoundaryDeltas(a, b) is { } bodyDeltas) return bodyDeltas;
        var aa = Anchors(a);
        var bb = Anchors(b);
        var available = bb.ToList();
        var deltas = new List<double>();
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
            deltas.Add(Math.Abs(l.Time - best.v.Time));
            available.RemoveAt(best.i);
        }
        return deltas.Order().ToArray();
    }

    private static int RequiredAnchors(LyricsCandidate a, LyricsCandidate b)
    {
        var shorter = Math.Min(Anchors(a).Count, Anchors(b).Count);
        return Math.Max(5, (int)Math.Ceiling(shorter * .35));
    }

    public static bool TimelinesAgree(LyricsCandidate a, LyricsCandidate b)
    {
        var deltas = Deltas(a, b);
        var required = CompleteBodyBoundaryDeltas(a, b) is null ? RequiredAnchors(a, b) : Math.Min(5, deltas.Length);
        return required > 0 && deltas.Length >= required && deltas[deltas.Length / 2] <= 1.0 && deltas.Count(d => d > 2.0) * 5 <= deltas.Length;
    }

    public static bool TimelinesConflict(LyricsCandidate a, LyricsCandidate b) =>
        Disagreement(a, b) == "timeline_conflict";

    private static string? Disagreement(LyricsCandidate a, LyricsCandidate b)
    {
        var d = Deltas(a, b);
        var aa = Anchors(a);
        var bb = Anchors(b);
        var required = CompleteBodyBoundaryDeltas(a, b) is null ? RequiredAnchors(a, b) : Math.Min(5, d.Length);
        if (required <= 0 || d.Length < required) return "content_ambiguity";
        if (d[d.Length / 2] > 3.0 || d.Count(x => x > 3.0) * 2 > d.Length) return "timeline_conflict";
        if (aa.Count > 0 && bb.Count > 0 && Math.Abs(aa[^1].Time - bb[^1].Time) > 20 &&
            (double)Math.Min(aa.Count, bb.Count) / Math.Max(aa.Count, bb.Count) < .65)
            return "timeline_conflict";
        return null;
    }

    public static string? Rejection(LyricsCandidate c, Track t)
    {
        if (c.Evidence == LyricsEvidence.Instrumental) return "instrumental_recording";
        var lines = c.Document.Normalized;
        if (lines.Count == 0 || !lines.Any(l => !string.IsNullOrWhiteSpace(l.Text))) return "empty";
        if (lines.Any(l => IsInstrumentalNotice(l.Text)) && Anchors(c).Count == 0)
            return "instrumental_notice";
        if (!double.IsFinite(t.Duration) || t.Duration <= 0) return "track_duration_unknown";
        var startCeiling = t.Duration + (t.IsMusicVideo ? 15 : 4);
        var endCeiling = t.Duration + (t.IsMusicVideo ? 20 : 8);
        if (lines.Any(l => !double.IsFinite(l.Start) || l.Start < -1 || l.Start > startCeiling ||
            l.End is { } end && (!double.IsFinite(end) || end < l.Start || end > endCeiling)))
            return "timeline_out_of_recording";
        return RecordingRejection(c, t);
    }

    private static string? RecordingRejection(LyricsCandidate c, Track t)
    {
        if (!double.IsFinite(t.Duration) || t.Duration <= 0) return "track_duration_unknown";
        if (TrackMatcher.IdentityRejection(t, c.Title, c.Artist, c.Album) is { } reason) return reason;
        if (c.Provider != "LRCMux" && c.Platform == t.Platform && t.Platform != "netease" && t.NativeId is not null && c.Id is not null &&
            c.Id.Replace("spotify:track:", "", StringComparison.Ordinal) != t.NativeId.Replace("spotify:track:", "", StringComparison.Ordinal)) return "exact_id_mismatch";
        if (c.Provider != "LRCMux" && t.Isrc is not null && c.Isrc is not null && TrackMatcher.Normalize(t.Isrc) != TrackMatcher.Normalize(c.Isrc)) return "isrc_mismatch";
        if (!double.IsFinite(c.Duration) || c.Duration <= 0) return "source_duration_unknown";
        if (Math.Abs(t.Duration - c.Duration) > (t.IsMusicVideo ? 22 : 5)) return "duration_risk";
        return null;
    }

    private static bool ConfirmsInstrumental(LyricsCandidate c, Track t) =>
        c.Platform == "netease" &&
        c.Evidence == LyricsEvidence.Instrumental &&
        RecordingRejection(c, t) is null &&
        (Tier(c, t) <= 2 ||
            c.MatcherScore == 100 && Math.Abs(c.Duration - t.Duration) <= 1.0 &&
            (TrackMatcher.AlbumMatches(c.Album, t) || string.IsNullOrWhiteSpace(t.Album)));

    public static LyricsCandidate RepairTrailingOverflow(LyricsCandidate c, Track t)
    {
        if (c.Provider == "LRCMux" || string.IsNullOrEmpty(c.Id) || Rejection(c, t) != "timeline_out_of_recording") return c;
        var lines = c.Document.Normalized;
        var ceiling = t.Duration + (t.IsMusicVideo ? 15 : 4);
        var good = lines.Count(l => l.Start >= -1 && l.Start <= ceiling);
        if (lines.Count < 8 || good * 10 < lines.Count * 9) return c;
        var repaired = lines.Where(l => l.Start <= ceiling).Select(l => l.End is { } end &&
            (!double.IsFinite(end) || end < l.Start || end > t.Duration + (t.IsMusicVideo ? 20 : 8))
            ? l with { End = null, Words = null } : l).ToArray();
        return repaired.Length == 0 ? c : c with { Document = new(repaired) };
    }

    private static int Tier(LyricsCandidate c, Track t)
    {
        if (c.Provider == "LRCMux") return 4;
        if (c.Platform == t.Platform && !string.IsNullOrEmpty(c.Id) && c.Id == t.NativeId &&
            (t.Platform != "netease" || c.LiveIdentityVerified)) return 1;
        if (!string.IsNullOrEmpty(c.Isrc) && !string.IsNullOrEmpty(t.Isrc) &&
            TrackMatcher.Normalize(c.Isrc) == TrackMatcher.Normalize(t.Isrc)) return 2;
        if (TrackMatcher.AlbumMatches(c.Album, t)) return 3;
        if (string.IsNullOrWhiteSpace(t.Album) && c.Platform == t.Platform && !string.IsNullOrEmpty(c.Id)) return 3;
        return 4;
    }

    private static bool StrongMetadata(LyricsCandidate c, Track t)
    {
        if (c.Provider == "LRCMux" || string.IsNullOrEmpty(c.Id) || !TrackMatcher.AlbumMatches(c.Album, t)) return false;
        var a = Anchors(c);
        return a.Count >= 5 && a[^1].Time >= t.Duration * 0.6 && a[^1].Time - a[0].Time >= t.Duration * 0.5;
    }

    private static bool HasFullVocalSpan(LyricsCandidate c, Track t)
    {
        var a = Anchors(c);
        return a.Count >= 12 && a[^1].Time >= t.Duration * 0.55 && a[^1].Time - a[0].Time >= t.Duration * 0.45;
    }

    private static int SourceRank(string provider)
    {
        var idx = Array.IndexOf(SourcePriority, provider);
        return idx >= 0 ? idx : 100;
    }

    public static SelectionDecision Select(IEnumerable<LyricsCandidate> candidates, Track track)
    {
        var repaired = candidates.Select(c => RepairTrailingOverflow(c, track)).ToArray();
        var rejected = new Dictionary<string, string>();
        var instrumentalTier = repaired.Where(c => ConfirmsInstrumental(c, track))
            .Select(c => Tier(c, track)).DefaultIfEmpty(int.MaxValue).Min();

        var valid = new List<LyricsCandidate>();
        foreach (var c in repaired)
        {
            if (Rejection(c, track) is { } reason) rejected[c.Provider] = reason;
            else valid.Add(c);
        }

        // Community UGC lyrics (e.g. Kugou product_from=ugc) require independent direct timed corroboration
        var directEvidence = valid.Where(c => c.Provider != "LRCMux" &&
            c.Evidence == LyricsEvidence.TimedLyrics && !string.IsNullOrWhiteSpace(c.Platform)).ToArray();
        valid.RemoveAll(c =>
        {
            if (c.Evidence != LyricsEvidence.UserContribution) return false;
            var corroboratedByDirect = directEvidence.Any(o =>
                o.Provider != c.Provider && o.Platform != c.Platform &&
                TimelinesAgree(c, o) && Disagreement(c, o) is null);
            if (corroboratedByDirect) return false;
            rejected[c.Provider] = "unverified_user_contribution";
            return true;
        });

        // NetEase pureMusic negative evidence vetoes unless a stronger-tier verified vocal candidate exists
        if (instrumentalTier != int.MaxValue && !valid.Any(c => Tier(c, track) < instrumentalTier))
        {
            foreach (var c in repaired) rejected[c.Provider] = "instrumental_recording";
            return new(null, "instrumental_recording", rejected);
        }

        var direct = valid.Where(c => c.Provider != "LRCMux").ToArray();
        var trackHasNoAlbum = string.IsNullOrWhiteSpace(track.Album);

        bool ResolverSolo(LyricsCandidate c)
        {
            var a = Anchors(c);
            return direct.Length == 0 &&
                   (trackHasNoAlbum ? !string.IsNullOrWhiteSpace(c.Id) : TrackMatcher.AlbumMatches(c.Album, track)) &&
                   a.Count >= 10 && a[^1].Time >= track.Duration * 0.5 && a[^1].Time - a[0].Time >= track.Duration * 0.45;
        }

        // Step 1: Filter uncorroborated LRCMux
        var afterResolverGate = valid.Where(c =>
        {
            if (c.Provider != "LRCMux") return true;
            var backedByDirect = direct.Any(o => TimelinesAgree(c, o));
            if (backedByDirect || ResolverSolo(c)) return true;
            rejected[c.Provider] = "resolver_metadata_unverified";
            return false;
        }).ToList();

        // Step 2: Mac Build 97 Tier-4 corroboration & controlled fallback rules
        var boundTier3 = afterResolverGate.Where(c => Tier(c, track) == 3 && c.Provider != "LRCMux").ToArray();
        var eligible = new List<(LyricsCandidate Candidate, int EffectiveTier)>();

        foreach (var c in afterResolverGate)
        {
            var tier = Tier(c, track);
            if (tier < 4)
            {
                eligible.Add((c, tier));
                continue;
            }

            var compatibleWithBound = !boundTier3.Any(b => Disagreement(c, b) == "timeline_conflict");
            var anchors = Anchors(c);
            var hasTimelineConflict = afterResolverGate.Any(o =>
                o.Provider != c.Provider && o.Provider != "LRCMux" && Disagreement(c, o) == "timeline_conflict");

            var independentPeer = afterResolverGate.Any(o =>
                o.Provider != c.Provider &&
                o.Platform != c.Platform &&
                TimelinesAgree(c, o) &&
                (c.Provider != "LRCMux" || o.Provider != "LRCMux"));

            // Controlled empty-album fallback for real players (YouTube Music / Kugou / Soda / Apple / Spotify)
            var singleDirectEmptyAlbumFallback = trackHasNoAlbum &&
                (track.IsMusicVideo || track.Platform != "unknown") &&
                boundTier3.Length == 0 &&
                c.Provider != "LRCMux" &&
                c.MatcherScore >= 85 &&
                anchors.Count >= 5 &&
                !hasTimelineConflict;

            var fullSongExactDirectFallback = boundTier3.Length == 0 &&
                c.Provider != "LRCMux" &&
                c.MatcherScore >= 96 &&
                HasFullVocalSpan(c, track) &&
                !hasTimelineConflict;

            var corroborated = compatibleWithBound && (
                independentPeer ||
                singleDirectEmptyAlbumFallback ||
                fullSongExactDirectFallback ||
                (c.Provider == "LRCMux" && ResolverSolo(c)));

            if (corroborated)
            {
                eligible.Add((c, 3));
            }
            else
            {
                rejected[c.Provider] = hasTimelineConflict ? "timeline_conflict" : "identity_ambiguous";
            }
        }

        if (eligible.Count == 0) return new(null, "no_verified_candidate", rejected);

        // Step 3: Conflict & clique consensus resolution (Mac LyricsSelection.swift parity)
        var bestTier = eligible.Min(x => x.EffectiveTier);
        if (bestTier < 3)
        {
            var trusted = eligible.Where(x => x.EffectiveTier == bestTier).ToList();
            if (trusted.Any(a => trusted.Any(b => a.Candidate.Provider != b.Candidate.Provider && TimelinesConflict(a.Candidate, b.Candidate))))
            {
                foreach (var item in eligible) rejected[item.Candidate.Provider] = "trusted_timeline_conflict";
                return new(null, "timeline_conflict", rejected);
            }
            eligible = trusted;
        }
        else if (eligible.Count > 1)
        {
            var hasAnyDisagreement = false;
            var hasAnyTimelineConflict = false;
            for (var i = 0; i < eligible.Count; i++)
            {
                for (var j = i + 1; j < eligible.Count; j++)
                {
                    var dis = Disagreement(eligible[i].Candidate, eligible[j].Candidate);
                    if (dis is not null)
                    {
                        hasAnyDisagreement = true;
                        if (dis == "timeline_conflict") hasAnyTimelineConflict = true;
                    }
                }
            }

            if (hasAnyDisagreement)
            {
                // Priority A: Non-conflicting album-bound direct Tier-3 candidates with strong metadata beat release-unbound Tier-4 outliers
                var bound = eligible.Where(x => Tier(x.Candidate, track) == 3 && x.Candidate.Provider != "LRCMux").ToList();
                var boundConflicts = bound.Any(a => bound.Any(b => a.Candidate.Provider != b.Candidate.Provider && TimelinesConflict(a.Candidate, b.Candidate)));
                if (bound.Count > 0 && !boundConflicts && bound.Any(x => StrongMetadata(x.Candidate, track)))
                {
                    foreach (var item in eligible.Where(x => Tier(x.Candidate, track) == 4))
                        rejected[item.Candidate.Provider] = "lower_confidence_content_conflict";
                    eligible = bound;
                }
                else
                {
                    // Priority B: Largest mutually-agreeing clique of >=2 independent direct providers beats uncorroborated outliers!
                    var cliquePool = eligible.Where(x => x.Candidate.Provider != "LRCMux").ToList();
                    var bestClique = new List<(LyricsCandidate Candidate, int EffectiveTier)>();
                    foreach (var seed in cliquePool)
                    {
                        var clique = new List<(LyricsCandidate Candidate, int EffectiveTier)> { seed };
                        foreach (var other in cliquePool.Where(o => o.Candidate.Provider != seed.Candidate.Provider))
                        {
                            var agreesWithAll = clique.All(member =>
                                member.Candidate.Platform != other.Candidate.Platform &&
                                TimelinesAgree(member.Candidate, other.Candidate) &&
                                Disagreement(member.Candidate, other.Candidate) is null);
                            if (agreesWithAll) clique.Add(other);
                        }
                        if (clique.Count > bestClique.Count) bestClique = clique;
                    }

                    if (bestClique.Count >= 2)
                    {
                        var kept = bestClique.Select(x => x.Candidate.Provider).ToHashSet(StringComparer.Ordinal);
                        foreach (var item in eligible.Where(x => !kept.Contains(x.Candidate.Provider)))
                            rejected[item.Candidate.Provider] = "uncorroborated_content_outlier";
                        eligible = bestClique;
                    }
                    else if (!hasAnyTimelineConflict)
                    {
                        // Content ambiguity only (e.g., formatting/script divergence): prefer highest-scoring full-span direct candidate
                        var ordered = eligible
                            .OrderBy(x => Tier(x.Candidate, track))
                            .ThenByDescending(x => x.Candidate.MatcherScore)
                            .ThenByDescending(x => Anchors(x.Candidate).Count)
                            .ToList();
                        var preferred = ordered[0];
                        var runnerUp = ordered[1];
                        if (HasFullVocalSpan(preferred.Candidate, track) || preferred.Candidate.MatcherScore - runnerUp.Candidate.MatcherScore >= 4)
                        {
                            foreach (var other in ordered.Skip(1))
                                rejected[other.Candidate.Provider] = "lower_confidence_content_conflict";
                            eligible = [preferred];
                        }
                        else
                        {
                            foreach (var item in eligible) rejected[item.Candidate.Provider] = "unresolved_content_ambiguity";
                            return new(null, "content_ambiguity", rejected);
                        }
                    }
                    else
                    {
                        foreach (var item in eligible) rejected[item.Candidate.Provider] = "timeline_conflict";
                        return new(null, "timeline_conflict", rejected);
                    }
                }
            }
        }

        var winner = eligible
            .OrderBy(x => x.EffectiveTier)
            .ThenByDescending(x => x.Candidate.Platform == track.Platform)
            .ThenByDescending(x => x.Candidate.Document.Lines.Sum(l => l.Words?.Count ?? 0))
            .ThenByDescending(x => x.Candidate.MatcherScore)
            .ThenBy(x => SourceRank(x.Candidate.Provider))
            .First()
            .Candidate;

        return new(winner, "selected", rejected);
    }
}
