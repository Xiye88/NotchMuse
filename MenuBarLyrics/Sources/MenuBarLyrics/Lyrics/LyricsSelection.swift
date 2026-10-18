import Foundation
import LyricsCore

/// Identity gates precede timing quality. Network completion order is never confidence.
enum LyricsSelection {
    struct Decision: Sendable {
        let winner: LyricsCandidate?
        let tier: String?
        let reason: String
        let rejected: [String: String]
    }

    static func select(_ candidates: [LyricsCandidate], context: LyricsSelectionContext) -> Decision {
        let candidates = context.platform == "spotify" ? candidates.map { repairedTiming($0, among: candidates, context: context) } : candidates
        var rejected: [String: String] = [:]
        var eligible: [(candidate: LyricsCandidate, tier: Int)] = []
        for candidate in candidates {
            if let reason = rejection(candidate, context: context) {
                rejected[candidate.provider] = reason
            } else {
                eligible.append((candidate, identityTier(candidate, context: context)))
            }
        }
        // The live guarded result establishes the NetEase catalog namespace for this request.
        // Another payload for that same catalog ID has equal identity, not merely affinity.
        if let bound = eligible.first(where: { $0.tier == 1 && $0.candidate.liveIdentityVerified })?.candidate,
           bound.sourcePlatform == "netease" {
            eligible = eligible.map { item in
                let sameID = item.candidate.provider == "NetEase" && item.candidate.sourcePlatform == "netease" && item.candidate.sourceTrackID == bound.sourceTrackID
                return (item.candidate, sameID ? 1 : item.tier)
            }
        }
        // Resolver track metadata is not automatically bound to its lyric payload.
        // A direct adapter for the backing platform must corroborate the vocal timeline.
        let direct = eligible.filter { $0.candidate.provider != "LRCMux" }
        eligible = eligible.filter { item in
            guard item.candidate.provider == "LRCMux" else { return true }
            let supported = item.candidate.sourcePlatform != nil && direct.contains {
                $0.candidate.sourcePlatform == item.candidate.sourcePlatform && timelinesAgree(item.candidate, $0.candidate)
            }
            if !supported { rejected[item.candidate.provider] = "resolver_metadata_unverified" }
            return supported
        }
        // Unknown album evidence needs independent corroboration; it cannot veto an
        // explicitly matched album before its own recording identity is established.
        let evidencePool = eligible
        eligible = evidencePool.compactMap { item in
            guard item.tier == 4 else { return item }
            let bound = evidencePool.filter { identityTier($0.candidate, context: context) == 3 && $0.candidate.provider != "LRCMux" }
            let compatibleWithBound = context.platform != "spotify" || bound.allSatisfy { timelinesAgree(item.candidate, $0.candidate) }
            let corroborated = compatibleWithBound && evidencePool.contains { other in
                guard item.candidate.provider != other.candidate.provider,
                      let platform = item.candidate.sourcePlatform,
                      let otherPlatform = other.candidate.sourcePlatform else { return false }
                let independent = platform != otherPlatform && other.candidate.provider != "LRCMux"
                let backedResolver = item.candidate.provider == "LRCMux" && platform == otherPlatform && other.tier <= 3
                return (independent || backedResolver) && timelinesAgree(item.candidate, other.candidate)
            }
            if !corroborated { rejected[item.candidate.provider] = "identity_ambiguous" }
            return corroborated ? (item.candidate, 3) : nil
        }
        // Conflicting generic timelines cannot establish the player's recording identity.
        var conflicting: [String: String] = [:]
        for i in eligible.indices {
            for j in eligible.indices where j > i {
                if let reason = disagreement(eligible[i].candidate, eligible[j].candidate) {
                    for item in [eligible[i], eligible[j]] {
                        if conflicting[item.candidate.provider] != "timeline_conflict" { conflicting[item.candidate.provider] = reason }
                    }
                }
            }
        }
        if let bestTier = eligible.map(\.tier).min(), bestTier < 3 {
            let trusted = eligible.filter { $0.tier == bestTier }
            if trusted.contains(where: { a in trusted.contains { b in
                a.candidate.provider != b.candidate.provider && timelinesConflict(a.candidate, b.candidate)
            } }) {
                for item in eligible { rejected[item.candidate.provider] = "trusted_timeline_conflict" }
                return Decision(winner: nil, tier: nil, reason: "timeline_conflict", rejected: rejected)
            }
            eligible = trusted
        } else if !conflicting.isEmpty {
            let bound = eligible.filter { identityTier($0.candidate, context: context) == 3 && $0.candidate.provider != "LRCMux" }
            let boundConflicts = bound.contains { a in bound.contains { b in
                a.candidate.provider != b.candidate.provider && timelinesConflict(a.candidate, b.candidate)
            } }
            if context.platform == "spotify", !bound.isEmpty, !boundConflicts,
               bound.contains(where: { strongMetadata($0.candidate, context: context) }) {
                // Release-unbound outliers cannot veto an otherwise validated album recording.
                // Never use source majority to break a conflict between equally bound recordings.
                for item in eligible where identityTier(item.candidate, context: context) == 4 {
                    rejected[item.candidate.provider] = "lower_confidence_content_conflict"
                }
                eligible = bound
            } else {
                let reason = conflicting.values.contains("timeline_conflict") ? "timeline_conflict" : "content_ambiguity"
                for item in eligible { rejected[item.candidate.provider] = conflicting[item.candidate.provider] ?? "unresolved_\(reason)" }
                return Decision(winner: nil, tier: nil, reason: reason, rejected: rejected)
            }
        }
        // Strict album-bound metadata plus a substantial vocal span can stand alone.
        // Other Spotify generic timelines still need independent source agreement.
        if context.platform == "spotify", eligible.allSatisfy({ $0.tier == 3 }) {
            let pool = eligible
            eligible = pool.filter { item in
                strongMetadata(item.candidate, context: context) || pool.contains { other in
                    item.candidate.provider != other.candidate.provider &&
                    item.candidate.sourcePlatform != nil && other.candidate.sourcePlatform != nil &&
                    item.candidate.sourcePlatform != other.candidate.sourcePlatform &&
                    timelinesAgree(item.candidate, other.candidate)
                }
            }
            if eligible.isEmpty {
                for candidate in candidates where rejected[candidate.provider] == nil { rejected[candidate.provider] = "unverified_cross_platform_timeline" }
            }
        }
        let scores = Dictionary(eligible.map { ($0.candidate.provider, confidence($0.candidate, among: eligible.map(\.candidate), context: context)) }, uniquingKeysWith: max)
        let ranked = eligible.sorted { a, b in
            if a.tier != b.tier { return a.tier < b.tier }
            let af = a.candidate.sourcePlatform == context.platform, bf = b.candidate.sourcePlatform == context.platform
            if af != bf { return af }
            if context.platform == "spotify" {
                let ac = scores[a.candidate.provider] ?? 0
                let bc = scores[b.candidate.provider] ?? 0
                if ac != bc { return ac > bc }
            }
            let aq = fidelityRank(a.candidate.document), bq = fidelityRank(b.candidate.document)
            if aq != bq { return aq < bq }
            if a.candidate.matcherScore != b.candidate.matcherScore { return (a.candidate.matcherScore ?? 0) > (b.candidate.matcherScore ?? 0) }
            let ao = sourceOrder(a.candidate.provider), bo = sourceOrder(b.candidate.provider)
            if ao != bo { return ao < bo }
            return a.candidate.elapsed < b.candidate.elapsed
        }
        guard let selected = ranked.first else {
            return Decision(winner: nil, tier: nil, reason: candidates.isEmpty ? "no_candidates" : "rejected", rejected: rejected)
        }
        for candidate in candidates where candidate.provider != selected.candidate.provider && rejected[candidate.provider] == nil {
            rejected[candidate.provider] = conflicting[candidate.provider].map { "\($0)_lower_identity" } ?? "lower_rank"
        }
        let tier = selected.tier == 3 ? (albumMatches(selected.candidate, context: context) ? "C strong metadata" : "C corroborated metadata") : [1: "A exact platform", 2: "B exact ISRC"][selected.tier]
        return Decision(winner: selected.candidate, tier: tier, reason: "selected", rejected: rejected)
    }

    static func identityTier(_ candidate: LyricsCandidate, context: LyricsSelectionContext) -> Int {
        // LRCMux's resolver IDs/ISRC describe its lookup, not proven lyric identity.
        guard candidate.provider != "LRCMux" else { return 4 }
        if candidate.liveIdentityVerified && candidate.provider == "NetEaseExactID (Preview)" && context.platform == "netease" && candidate.sourcePlatform == "netease" && candidate.sourceTrackID?.isEmpty == false { return 1 }
        if candidate.sourcePlatform == context.platform, let source = candidate.sourceTrackID,
           let native = context.nativeTrackID, !source.isEmpty,
           context.platform != "netease", normalizedID(source, platform: context.platform) == normalizedID(native, platform: context.platform) { return 1 }
        if let source = RecordingISRC.normalized(candidate.sourceISRC), let isrc = RecordingISRC.normalized(context.isrc),
           source == isrc { return 2 }
        return albumMatches(candidate, context: context) ? 3 : 4
    }

    private static func albumKey(_ value: String) -> String {
        let releaseName = value.replacingOccurrences(of: #"\s*[-–—]\s*Single\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        let simplified = releaseName.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? releaseName
        return TrackMatcher.parsedTitle(simplified).name
    }
    private static func albumMatches(_ candidate: LyricsCandidate, context: LyricsSelectionContext) -> Bool {
        albumMatches(candidate.sourceAlbum, track: context.track)
    }
    static func albumMatches(_ album: String?, track: SpotifyTrack) -> Bool {
        let requested = albumKey(track.album)
        guard let album else { return false }
        return !requested.isEmpty && requested == albumKey(album)
    }

    static func strongMetadata(_ candidate: LyricsCandidate, context: LyricsSelectionContext) -> Bool {
        guard candidate.provider != "LRCMux", candidate.sourcePlatform != nil,
              candidate.sourceTrackID?.isEmpty == false, albumMatches(candidate, context: context),
              rejection(candidate, context: context) == nil else { return false }
        let vocalTimes = anchors(candidate).values.flatMap { $0 }.sorted()
        guard vocalTimes.count >= 5, let first = vocalTimes.first, let last = vocalTimes.last else { return false }
        return last >= context.track.duration * 0.6 && last - first >= context.track.duration * 0.5
    }

    /// An explainable evidence score, not a probability. Hard contradictions always win.
    static func confidence(_ candidate: LyricsCandidate, among pool: [LyricsCandidate], context: LyricsSelectionContext) -> Int {
        guard rejection(candidate, context: context) == nil else { return 0 }
        if identityTier(candidate, context: context) < 3 { return 100 }
        let independent = pool.contains {
            $0.provider != candidate.provider && $0.provider != "LRCMux" && candidate.provider != "LRCMux" &&
            $0.sourcePlatform != nil && candidate.sourcePlatform != nil && $0.sourcePlatform != candidate.sourcePlatform &&
            rejection($0, context: context) == nil && timelinesAgree(candidate, $0)
        }
        // Valid title/artist/version/duration: 80, bound release: 10, independent recording: 10.
        return 80 + (albumMatches(candidate, context: context) ? 10 : 0) + (independent ? 10 : 0)
    }

    private static func repairedTiming(_ candidate: LyricsCandidate, among pool: [LyricsCandidate], context: LyricsSelectionContext) -> LyricsCandidate {
        guard candidate.document.normalizedLines.contains(where: { ($0.endTime ?? $0.time) > context.track.duration + 2 }),
              rejection(candidate, context: context) == "timeline_out_of_recording",
              rejection(candidate, context: context, checkRichEnds: false) == nil,
              candidate.provider != "LRCMux", candidate.sourcePlatform != nil,
              candidate.sourceTrackID?.isEmpty == false else { return candidate }
        let valid = pool.filter { $0.provider != "LRCMux" && rejection($0, context: context) == nil }
        let bound = valid.filter { identityTier($0, context: context) == 3 }
        guard bound.allSatisfy({ timelinesAgree(candidate, $0) }), valid.contains(where: {
            $0.provider != candidate.provider && $0.sourcePlatform != nil &&
            $0.sourcePlatform != candidate.sourcePlatform && timelinesAgree(candidate, $0)
        }) else { return candidate }
        let offset = candidate.document.metadata.lyricOffset
        let lines = candidate.document.lines.map { line in
            if let end = line.endTime, !end.isFinite || end - offset > context.track.duration + 2 || end < line.time {
                return LyricLine(time: line.time, text: line.text)
            }
            return line
        }
        let repaired = LyricsCandidate(document: TimedLyricDocument(lines: lines, metadata: candidate.document.metadata),
            provider: candidate.provider, sourcePlatform: candidate.sourcePlatform, sourceTrackID: candidate.sourceTrackID,
            sourceTitle: candidate.sourceTitle, sourceArtist: candidate.sourceArtist, sourceAlbum: candidate.sourceAlbum,
            sourceDuration: candidate.sourceDuration, sourceISRC: candidate.sourceISRC, matcherScore: candidate.matcherScore,
            elapsed: candidate.elapsed, liveIdentityVerified: candidate.liveIdentityVerified)
        DebugLog.lyricsDiagnostic("selection.timing_downgrade provider=\(candidate.provider) reason=independently_verified_line_starts")
        return repaired
    }

    static func rejection(_ candidate: LyricsCandidate, context: LyricsSelectionContext, checkRichEnds: Bool = true) -> String? {
        let lines = candidate.document.normalizedLines
        guard !lines.isEmpty, lines.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return "empty" }
        if lines.contains(where: { !$0.time.isFinite || $0.time < -1 || $0.time > context.track.duration + 2 ||
            (checkRichEnds && (!($0.endTime ?? $0.time).isFinite || ($0.endTime ?? $0.time) > context.track.duration + 2)) }) { return "timeline_out_of_recording" }
        if let reason = TrackMatcher.identityRejectReason(context.track, title: candidate.sourceTitle, artist: candidate.sourceArtist, album: candidate.sourceAlbum) { return reason }
        let tier = identityTier(candidate, context: context)
        if context.platform != "spotify", tier >= 3, let album = candidate.sourceAlbum,
           !albumKey(album).isEmpty, !albumKey(context.track.album).isEmpty,
           !albumMatches(candidate, context: context) { return "album_mismatch" }
        if candidate.provider != "LRCMux", candidate.sourcePlatform == context.platform,
           context.platform != "netease", let sourceID = candidate.sourceTrackID, let native = context.nativeTrackID,
           normalizedID(sourceID, platform: context.platform) != normalizedID(native, platform: context.platform) { return "exact_id_mismatch" }
        if candidate.provider != "LRCMux", let source = RecordingISRC.normalized(candidate.sourceISRC), let isrc = RecordingISRC.normalized(context.isrc),
           source != isrc { return "isrc_mismatch" }
        guard let duration = candidate.sourceDuration, duration.isFinite, duration > 0 else { return "source_duration_unknown" }
        let delta = abs(duration - context.track.duration)
        if delta > (tier == 1 ? 5 : 2) { return "duration_risk" }
        return nil
    }

    private static func normalizedID(_ value: String, platform: String?) -> String {
        platform == "spotify" ? value.replacingOccurrences(of: "spotify:track:", with: "") : value
    }

    /// Align matching vocal text; raw first timestamps often refer to credits.
    private static func vocalText(_ line: LyricLine, candidate: LyricsCandidate) -> String? {
        func normalized(_ value: String) -> String {
            let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            let hasHan = folded.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x323AF).contains($0.value) }
            let simplified = hasHan ? (folded.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? folded) : folded
            let canonical = !hasHan || simplified.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) == folded ? simplified : folded
            return canonical.unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(String.init).joined()
        }
        let raw = line.text.trimmingCharacters(in: .whitespacesAndNewlines), text = normalized(raw)
        guard !text.isEmpty,
              text != normalized(candidate.sourceTitle + candidate.sourceArtist),
              !["作词", "作曲", "编曲", "制作", "词", "曲", "lyrics", "composer", "produced", "written"].contains(where: { text.hasPrefix($0) }) else { return nil }
        if raw.range(of: "[:：]", options: .regularExpression) != nil,
           ["录音", "混音", "母带", "人声", "和声", "弦乐", "音乐录音", "音乐工作", "插画", "吉他", "古典吉他", "贝斯", "鼓", "键盘"].contains(where: { raw.hasPrefix($0) }) { return nil }
        return text
    }
    private static func anchors(_ candidate: LyricsCandidate) -> [String: [Double]] {
        var result: [String: [Double]] = [:]
        for line in candidate.document.normalizedLines {
            guard let text = vocalText(line, candidate: candidate), text.count >= 4 else { continue }
            result[text, default: []].append(line.time)
        }
        return result
    }
    private static func deltas(_ a: LyricsCandidate, _ b: LyricsCandidate) -> [Double] {
        if let shifts = completeBodyBoundaryDeltas(a, b) { return shifts }
        let aa = anchors(a), bb = anchors(b)
        return aa.keys.sorted().flatMap { key -> [Double] in
            guard let av = aa[key], let bv = bb[key], av.count == bv.count else { return [] }
            return zip(av, bv).map { abs($0 - $1) }
        }.sorted()
    }
    // Different line breaks are not a different lyric body. Only byte-equivalent
    // normalized complete vocals and shared timed boundaries qualify; no fuzzy text.
    private static func completeBodyBoundaryDeltas(_ a: LyricsCandidate, _ b: LyricsCandidate) -> [Double]? {
        func body(_ candidate: LyricsCandidate) -> (String, [Int: Double]) {
            var text = "", boundaries: [Int: Double] = [:]
            for line in candidate.document.normalizedLines {
                guard let normalized = vocalText(line, candidate: candidate) else { continue }
                boundaries[text.count] = line.time
                text += normalized
            }
            return (text, boundaries)
        }
        let (at, ab) = body(a), (bt, bb) = body(b)
        guard !at.isEmpty, at == bt else { return nil }
        let shared = ab.keys.filter { bb[$0] != nil }.sorted()
        guard shared.count >= min(5, min(ab.count, bb.count)),
              let first = shared.first, let last = shared.last, last - first >= at.count / 2 else { return nil }
        return shared.map { abs(ab[$0]! - bb[$0]!) }.sorted()
    }
    static func timelinesAgree(_ a: LyricsCandidate, _ b: LyricsCandidate) -> Bool {
        let shifts = deltas(a, b)
        let required = completeBodyBoundaryDeltas(a, b) == nil ? requiredAnchors(a, b) : min(5, shifts.count)
        return required > 0 && shifts.count >= required && shifts[shifts.count / 2] <= 1 && shifts.filter { $0 > 2 }.count * 5 <= shifts.count
    }
    static func timelinesConflict(_ a: LyricsCandidate, _ b: LyricsCandidate) -> Bool {
        disagreement(a, b) != nil
    }
    private static func disagreement(_ a: LyricsCandidate, _ b: LyricsCandidate) -> String? {
        let shifts = deltas(a, b)
        // Disjoint or insufficiently comparable bodies are ambiguity, not agreement.
        let required = completeBodyBoundaryDeltas(a, b) == nil ? requiredAnchors(a, b) : min(5, shifts.count)
        guard required > 0, shifts.count >= required else { return "content_ambiguity" }
        if shifts[shifts.count / 2] > 3 || shifts.filter({ $0 > 3 }).count * 2 > shifts.count { return "timeline_conflict" }
        // A partial timeline may share its intro but truncate the rest of the recording.
        let al = a.document.normalizedLines.filter { vocalText($0, candidate: a) != nil }
        let bl = b.document.normalizedLines.filter { vocalText($0, candidate: b) != nil }
        if abs((al.last?.time ?? 0) - (bl.last?.time ?? 0)) > 20 && Double(min(al.count, bl.count)) / Double(max(al.count, bl.count)) < 0.65 { return "timeline_conflict" }
        return nil
    }
    private static func requiredAnchors(_ a: LyricsCandidate, _ b: LyricsCandidate) -> Int {
        let shorter = min(anchors(a).values.reduce(0) { $0 + $1.count }, anchors(b).values.reduce(0) { $0 + $1.count })
        return max(min(5, shorter), Int(ceil(Double(shorter) * 0.5)))
    }
    private static func fidelityRank(_ document: TimedLyricDocument) -> Int {
        switch document.timingFidelity { case .word: return 0; case .lineWithEnd: return 1; case .lineStartOnly: return 2; case .estimated: return 3 }
    }
    private static func sourceOrder(_ provider: String) -> Int {
        ["NetEaseExactID (Preview)", "LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"].firstIndex(of: provider) ?? 100
    }
}
