import Foundation
import LyricsCore

// Core lyric capabilities are shared by production and Preview; diagnostics remain Preview-only.
enum LyricsRuntimeCapabilities {
    static func enabled(preview: Bool, version: Int?) -> Bool { preview || version == 1 }
    static var current: Bool {
        enabled(preview: Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true,
                version: Bundle.main.object(forInfoDictionaryKey: "NotchMuseLyricsCapabilitiesVersion") as? Int)
    }
}

enum LyricsClientError: Error, Equatable { case networkFailure, timeout }

@MainActor
final class LyricsClient {
    typealias Source = @Sendable (SpotifyTrack) async throws -> [LyricLine]
    typealias CandidateSource = @Sendable (SpotifyTrack) async throws -> LyricsCandidate?
    typealias IdentityResolver = @Sendable (String) async throws -> SpotifyCanonicalIdentity
    private let identityResolver: IdentityResolver?
    var hasIdentityResolver: Bool { identityResolver != nil }
    private let legacySources: [Source]?
    private let candidateSources: [CandidateSource]
    private let sourceNames: [String]
    private var cache = LyricsCache(capacity: 100)
    private var candidateCache: [String: [LyricsCandidate]] = [:]
    private var cacheKeys: [String] = []
    private var candidateCacheExpiry: [String: Double] = [:]
    private var candidateCacheStatuses: [String: [String: String]] = [:]
    private(set) var selectedProvider: String?
    private(set) var selectedDocument: TimedLyricDocument?
    private(set) var selectedCandidate: LyricsCandidate?
    private(set) var selectionDiagnostics = "Player: unavailable\nTrack title: unavailable\nResolution Status: no selection yet"
    private(set) var diagnosticsRequestID = UUID()
    private var shadowDiagnostics = ""
    private let backendShadow: LyricsBackendShadow
    private var shadowRequestID: UUID?
    private var shadowTask: Task<Void, Never>?
    private var activeResolution: Task<[LyricLine], Error>?
    // ponytail: bounded in-memory cache; persist only if restart profiling warrants it.
    private var identityCache: [String: (SpotifyCanonicalIdentity, Double)] = [:]
    private var identityFailures: [String: Double] = [:]

    var diagnosticsText: String {
        Self.sanitizedDiagnostics(selectionDiagnostics + (shadowDiagnostics.isEmpty ? "" : "\n\n" + shadowDiagnostics))
    }

    func setShadowDiagnostics(_ text: String, requestID: UUID) {
        guard diagnosticsRequestID == requestID else { return }
        shadowDiagnostics = Self.sanitizedDiagnostics(text)
    }

    func clearDiagnostics(_ reason: String = "Player: unavailable\nTrack title: unavailable\nResolution Status: no current playback selection") {
        activeResolution?.cancel()
        activeResolution = nil
        shadowTask?.cancel(); shadowTask = nil
        if let id = shadowRequestID { Task { await backendShadow.cancel(requestID: id) } }
        shadowRequestID = nil
        diagnosticsRequestID = UUID()
        selectionDiagnostics = Self.sanitizedDiagnostics(reason)
        shadowDiagnostics = ""
    }

    // Copy only music metadata and resolver decisions, never request/error payloads.
    nonisolated static func sanitizedDiagnostics(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?im)^.*(?:access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|cookie|authorization)\s*[=:].*$"#,
            with: "[redacted credential field]", options: .regularExpression)
            .replacingOccurrences(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                with: "[redacted account]", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"(?:https?://|file://|/Users/)[^\s]+"#,
                with: "[redacted URL or path]", options: .regularExpression)
    }

    private static func diagnosticValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "unavailable" }
        return sanitizedDiagnostics(value.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }.joined())
    }

    private static func diagnosticID(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "unavailable" }
        return value.range(of: #"^[A-Za-z0-9:_-]{1,128}$"#, options: .regularExpression) != nil ? value : "[redacted unsupported identifier]"
    }

    // Array injection is retained for legacy self-tests; production uses evidence sources.
    init(sources: [Source]? = nil, candidateSources: [CandidateSource]? = nil, names: [String]? = nil,
         identityResolver: IdentityResolver? = nil, backendShadow: LyricsBackendShadow? = nil) {
        self.backendShadow = backendShadow ?? LyricsBackendShadow()
        self.legacySources = sources
        if let identityResolver { self.identityResolver = identityResolver }
        else if LyricsRuntimeCapabilities.current {
            self.identityResolver = { try await SpotifyIdentityResolver.resolvePublic($0) }
        } else { self.identityResolver = nil }
        self.candidateSources = candidateSources ?? [
            { try await LRCLIBLyricsSource().candidate(for: $0) },
            { try await NetEaseLyricsSource().candidate(for: $0) },
            { try await LRCMuxLyricsSource().candidate(for: $0) },
            { try await QQMusicLyricsSource().candidate(for: $0) },
            { try await KugouLyricsSource().candidate(for: $0) },
            { try await SodaMusicLyricsSource().candidate(for: $0) }
        ]
        self.sourceNames = names ?? ["LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"]
    }

    func syncedLyrics(for track: SpotifyTrack, bypassCache: Bool = false, fallback: Source? = nil,
                      exactSource: CandidateSource? = nil, playerSource: String? = nil,
                      nativeTrackID: String? = nil, isrc: String? = nil) async throws -> [LyricLine] {
        try Task.checkCancellation()
        clearDiagnostics()
        let task = Task { try await resolveLyrics(for: track, bypassCache: bypassCache, fallback: fallback,
            exactSource: exactSource, playerSource: playerSource, nativeTrackID: nativeTrackID, isrc: isrc) }
        activeResolution = task
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    private func resolveLyrics(for track: SpotifyTrack, bypassCache: Bool, fallback: Source?,
                               exactSource: CandidateSource?, playerSource: String?, nativeTrackID: String?, isrc: String?) async throws -> [LyricLine] {
        try Task.checkCancellation()
        let started = ProcessInfo.processInfo.systemUptime
        let requestContext = LyricsSelectionContext(track: track, playerSource: playerSource, nativeTrackID: nativeTrackID, isrc: isrc)
        var context = requestContext
        let requestID = diagnosticsRequestID
        DebugLog.lyricsDiagnostic("performance.primary_start request=\(requestID) uptime=\(started)")
        selectionDiagnostics = """
        Player: \(Self.diagnosticValue(playerSource))
        Track title: \(Self.diagnosticValue(track.name))
        Artist: \(Self.diagnosticValue(track.artist))
        Album: \(Self.diagnosticValue(track.album))
        Duration: \(track.duration) s
        Native Track ID: \(Self.diagnosticID(nativeTrackID))
        ISRC: \(RecordingISRC.normalized(isrc) ?? "unavailable")
        Resolution Status: searching / collecting source evidence
        Chosen Provider: pending
        Candidate Providers: pending
        Cache Hit / Miss: pending
        Cache Source: pending
        Resolution Latency: pending (includes identity resolution)
        """
        if let legacySources {
            return try await legacyLyrics(legacySources, track: track, key: context.cacheKey, bypass: bypassCache, fallback: fallback)
        }
        selectedCandidate = nil; selectedProvider = nil; selectedDocument = nil
        var bridgeStatus: String?
        var cacheStatus = bypassCache ? "bypassed (refresh)" : (exactSource == nil ? "miss" : "bypassed (live Exact-ID authorization)")
        // Revalidate an exact request cache locally before starting any network.
        // Canonical collaborators/ISRC remain bound to the same validated URI.
        var cachedContext = requestContext
        if context.platform == "spotify", let nativeTrackID,
           let cached = identityCache[nativeTrackID], ProcessInfo.processInfo.systemUptime - cached.1 < 3600,
           let canonical = try? cached.0.validatedTrack(for: track, expectedURI: nativeTrackID) {
            cachedContext = LyricsSelectionContext(track: canonical, playerSource: playerSource, nativeTrackID: nativeTrackID, isrc: cached.0.isrc)
            bridgeStatus = "identity_cache_hit: " + cached.0.identitySource
        }
        // Live NetEase Exact-ID always requires new player authorization.
        if exactSource == nil, !bypassCache, (candidateCacheExpiry[cachedContext.cacheKey] ?? 0) > ProcessInfo.processInfo.systemUptime,
           let cached = candidateCache[cachedContext.cacheKey] {
            let decision = LyricsSelection.select(cached, context: cachedContext)
            if decision.winner != nil || context.platform == "spotify" {
                var statuses = candidateCacheStatuses[cachedContext.cacheKey] ?? [:]
                statuses["cache"] = "validated"
                if let bridgeStatus { statuses["SpotifyIdentity (Preview)"] = bridgeStatus }
                return record(decision, context: cachedContext, statuses: statuses, candidates: cached,
                    requestContext: requestContext, requestID: requestID, cacheStatus: "hit (revalidated)", started: started)
            }
            cacheStatus = "miss (cached candidates rejected on revalidation)"
        }
        // Keep the fast selection window independent of optional URI enrichment.
        // Only a missing strict winner waits for the bounded recovery lane.
        context = cachedContext
        let identityTask: Task<SpotifyCanonicalIdentity, Error>?
        if context.platform == "spotify", let nativeTrackID, let identityResolver,
           bridgeStatus == nil, (identityFailures[nativeTrackID] ?? 0) <= ProcessInfo.processInfo.systemUptime {
            identityTask = Task { [weak self] in
                let official = try await Self.boundedIdentity(nativeTrackID, resolver: identityResolver)
                try Task.checkCancellation()
                _ = try official.validatedTrack(for: track, expectedURI: nativeTrackID)
                guard let self, self.diagnosticsRequestID == requestID else { throw CancellationError() }
                self.identityCache[nativeTrackID] = (official, ProcessInfo.processInfo.systemUptime)
                self.identityFailures.removeValue(forKey: nativeTrackID)
                if self.identityCache.count > 100, let oldest = self.identityCache.min(by: { $0.value.1 < $1.value.1 }) { self.identityCache.removeValue(forKey: oldest.key) }
                return official
            }
        } else { identityTask = nil }
        defer { identityTask?.cancel() }
        var sources = candidateSources, names = sourceNames
        if let exactSource { sources.append(exactSource); names.append("NetEaseExactID (Preview)") }
        var collected = await Self.collect(sources, names: names, for: context.track,
            window: context.platform == "spotify" ? 2.75 : 8, context: context, boundedSpotify: context.platform == "spotify")
        try Task.checkCancellation()
        var decision = LyricsSelection.select(collected.candidates, context: context)
        var statuses = collected.statuses
        var recoveredIdentity = false
        var transientIdentityFailure = nativeTrackID.map { identityFailures[$0] != nil } ?? false
        // Already-arrived canonical evidence still participates in selection. A
        // strict primary winner only skips metadata that has not arrived yet.
        if let identityTask, let nativeTrackID, decision.winner == nil || (identityCache[nativeTrackID]?.1 ?? 0) >= started {
            do {
                let official = try await withTaskCancellationHandler { try await identityTask.value } onCancel: { identityTask.cancel() }
                try Task.checkCancellation()
                let canonical = try official.validatedTrack(for: track, expectedURI: nativeTrackID)
                transientIdentityFailure = false
                bridgeStatus = "validated: " + official.identitySource + (official.isrc == nil ? "; no ISRC" : "; canonical ISRC")
                let canonicalContext = LyricsSelectionContext(track: canonical, playerSource: playerSource, nativeTrackID: nativeTrackID, isrc: official.isrc)
                if canonicalContext.cacheKey != context.cacheKey {
                    // Provider adapters make their own artist/album selection. A raw
                    // candidate cannot stand in for a query using the full identity.
                    context = canonicalContext
                    collected = await Self.collect(sources, names: names, for: canonical,
                        window: 2.75, context: context, boundedSpotify: true)
                    try Task.checkCancellation()
                    statuses = collected.statuses
                    statuses["Recovery"] = "validated_identity_requery"
                    recoveredIdentity = true
                    decision = LyricsSelection.select(collected.candidates, context: context)
                }
            } catch {
                try Task.checkCancellation()
                transientIdentityFailure = LyricsHTTP.isTransient(error)
                identityFailures[nativeTrackID] = ProcessInfo.processInfo.systemUptime + (transientIdentityFailure ? 1 : 5)
                if identityFailures.count > 100 { identityFailures.removeAll() }
                bridgeStatus = transientIdentityFailure ? "transient_transport_failure" : "unavailable_or_identity_rejected"
            }
        }
        // One recovery pass, only for transport/deadline failures. Empty responses
        // and rejected candidates are evidence, not reasons to repeat requests.
        if context.platform == "spotify", decision.winner == nil, !recoveredIdentity {
            let indices = sources.indices.filter { names.indices.contains($0) && LyricsHTTP.retryableStatus(statuses[names[$0]] ?? "") }
            if !indices.isEmpty {
                try await Task.sleep(for: .milliseconds(150))
                let retry = await Self.collect(indices.map { sources[$0] }, names: indices.map { names[$0] },
                    for: context.track, window: 2.75, context: context, boundedSpotify: true)
                try Task.checkCancellation()
                for (name, status) in retry.statuses { statuses[name] = status; statuses[name + " first attempt"] = collected.statuses[name] }
                statuses["Recovery"] = "one_transient_source_retry"
                collected = Collection(candidates: collected.candidates + retry.candidates, statuses: statuses,
                    hadSuccessfulSource: collected.hadSuccessfulSource || retry.hadSuccessfulSource)
                decision = LyricsSelection.select(collected.candidates, context: context)
            }
        }
        try Task.checkCancellation()
        if let bridgeStatus { statuses["SpotifyIdentity (Preview)"] = bridgeStatus }
        let lines = record(decision, context: context, statuses: statuses, candidates: collected.candidates,
            requestContext: requestContext, requestID: requestID, cacheStatus: cacheStatus, started: started)
        if (!lines.isEmpty || (context.platform == "spotify" && collected.hadSuccessfulSource && !transientIdentityFailure && !statuses.values.contains(where: LyricsHTTP.retryableStatus))), !collected.candidates.contains(where: \.liveIdentityVerified) {
            if candidateCache[context.cacheKey] == nil { cacheKeys.append(context.cacheKey) }
            candidateCache[context.cacheKey] = collected.candidates
            candidateCacheStatuses[context.cacheKey] = statuses
            candidateCacheExpiry[context.cacheKey] = ProcessInfo.processInfo.systemUptime + (lines.isEmpty ? 5 : 600)
            if cacheKeys.count > 100 {
                let removed = cacheKeys.removeFirst()
                candidateCache.removeValue(forKey: removed); candidateCacheExpiry.removeValue(forKey: removed)
                candidateCacheStatuses.removeValue(forKey: removed)
            }
        }
        if lines.isEmpty {
            if Self.shouldSurfaceTimeout(candidates: collected.candidates, statuses: statuses) {
                throw LyricsClientError.timeout
            }
            if !collected.hadSuccessfulSource { throw LyricsClientError.networkFailure }
        }
        return lines
    }

    nonisolated static func shouldSurfaceTimeout(candidates: [LyricsCandidate], statuses: [String: String]) -> Bool {
        guard candidates.isEmpty else { return false }
        let timedOut = statuses.values.contains { $0 == "timeout" || $0 == "deadline" }
        let definitiveEmpty = statuses.values.contains { $0 == "empty" }
        return timedOut && !definitiveEmpty
    }

    private func record(_ decision: LyricsSelection.Decision, context: LyricsSelectionContext, statuses: [String: String], candidates: [LyricsCandidate],
                        requestContext: LyricsSelectionContext, requestID: UUID, cacheStatus: String, started: TimeInterval) -> [LyricLine] {
        let winner = decision.winner
        guard diagnosticsRequestID == requestID, !Task.isCancelled else { return [] }
        DebugLog.lyricsDiagnostic("performance.primary_winner request=\(requestID) uptime=\(ProcessInfo.processInfo.systemUptime) provider=\(winner?.provider ?? "none")")
        selectedCandidate = winner; selectedProvider = winner?.provider
        if let winner {
            // Preserve real source identity and offset; never substitute the player's ID/ISRC.
            let metadata = LyricsMetadata(provider: winner.provider, platformTrackID: winner.sourceTrackID,
                isrc: winner.provider == "LRCMux" ? nil : RecordingISRC.normalized(winner.sourceISRC), lyricOffset: winner.document.metadata.lyricOffset,
                leadingSilence: winner.document.metadata.leadingSilence)
            selectedDocument = TimedLyricDocument(lines: winner.document.lines, metadata: metadata)
        } else { selectedDocument = nil }
        let top = winner ?? candidates.sorted {
            let a = LyricsSelection.identityTier($0, context: context), b = LyricsSelection.identityTier($1, context: context)
            return a == b ? ($0.matcherScore ?? 0) > ($1.matcherScore ?? 0) : a < b
        }.first
        let reasons = Array(decision.rejected.values)
        let noLyricsReason: String
        if winner != nil { noLyricsReason = "none" }
        else if decision.reason == "timeline_conflict" || reasons.contains(where: { $0.contains("timeline") }) { noLyricsReason = "timeline_conflict" }
        else if reasons.contains(where: { $0.contains("version") }) { noLyricsReason = "version_conflict" }
        else if reasons.contains(where: { $0.contains("duration") }) { noLyricsReason = "duration_conflict" }
        else if reasons.contains("identity_ambiguous") || reasons.contains("unverified_cross_platform_timeline") { noLyricsReason = "identity_ambiguous" }
        else if !candidates.isEmpty { noLyricsReason = "matcher_too_strict" }
        else if statuses.values.contains("timeout") || statuses.values.contains("deadline") { noLyricsReason = "timeout" }
        else if statuses.values.contains("error") || statuses.values.contains("transient_network_error") || statuses.values.contains("deadline") { noLyricsReason = "provider_error" }
        else if statuses["NetEaseExactID (Preview)"] != nil { noLyricsReason = "exact_id_unavailable" }
        else { noLyricsReason = "provider_missing" }
        let candidateDetails = candidates.sorted { $0.provider < $1.provider }.map { candidate in
            let accepted = candidate.provider == winner?.provider && candidate.sourceTrackID == winner?.sourceTrackID
            let reason = accepted ? (decision.tier ?? decision.reason) : (decision.rejected[candidate.provider] ?? "not_selected")
            return """
            Candidate Provider: \(Self.diagnosticValue(candidate.provider))
              Accepted / Rejected: \(accepted ? "accepted" : "rejected")
              Reason: \(Self.diagnosticValue(reason))
              Source Track ID: \(Self.diagnosticID(candidate.sourceTrackID))
              Identity Tier: \(accepted ? (decision.tier ?? "unavailable") : String(LyricsSelection.identityTier(candidate, context: context)))
              Duration: \(candidate.sourceDuration.map(String.init(describing:)) ?? "unavailable") s
              Duration Difference: \(candidate.sourceDuration.map { String(abs($0 - context.track.duration)) } ?? "unavailable") s
              Timeline Conflict: \(decision.rejected[candidate.provider]?.contains("timeline_conflict") ?? false)
              First Lyric Timestamp: \(candidate.document.normalizedLines.first.map { String($0.time) } ?? "unavailable") s
              Timing Fidelity: \(candidate.document.timingFidelity.rawValue)
              Recording Confidence Score: \(LyricsSelection.confidence(candidate, among: candidates, context: context)) / 100 (evidence, not probability)
              Rich Timing Downgraded: \(accepted && candidate.document != winner?.document)
              Provider Latency: \(candidate.elapsed) s
            """
        }.joined(separator: "\n")
        let report = """
        Player: \(Self.diagnosticValue(requestContext.playerSource))
        Track title: \(Self.diagnosticValue(requestContext.track.name))
        Artist: \(Self.diagnosticValue(requestContext.track.artist))
        Album: \(Self.diagnosticValue(requestContext.track.album))
        Duration: \(requestContext.track.duration) s
        Resolved Track title: \(Self.diagnosticValue(context.track.name))
        Resolved Artist: \(Self.diagnosticValue(context.track.artist))
        Resolved Album: \(Self.diagnosticValue(context.track.album))
        Resolved Duration: \(context.track.duration) s
        Resolution Status: \(winner == nil ? "No Lyrics" : "selected")
        Cache Hit / Miss: \(cacheStatus)
        Cache Source: \(cacheStatus.hasPrefix("hit") ? "in-memory candidate cache / " + Self.diagnosticValue(winner?.provider) : "none (fresh provider collection)")
        Resolution Latency: \(ProcessInfo.processInfo.systemUptime - started) s (includes identity resolution)
        Native Track ID: \(Self.diagnosticID(context.nativeTrackID))
        Player ISRC: \(RecordingISRC.normalized(context.isrc) ?? "unavailable")
        ISRC identity status: \(context.isrc == nil ? "unavailable at player source" : (RecordingISRC.normalized(context.isrc) == nil ? "invalid format; not used as identity" : "canonical " + RecordingISRC.normalized(context.isrc)!))
        No Lyrics Reason: \(noLyricsReason)
        Exact-ID status: \(statuses["NetEaseExactID (Preview)"] ?? "not requested for this player")
        Top candidate: \(top?.provider ?? "none")
        Top identity tier: \(top.map { String(LyricsSelection.identityTier($0, context: context)) } ?? "none")
        Top duration diff: \(top?.sourceDuration.map { String(abs($0 - context.track.duration)) } ?? "unavailable") s
        Top timeline conflict: \(top.flatMap { decision.rejected[$0.provider] }?.contains("timeline_conflict") ?? false)
        Top reject reason: \(top.flatMap { decision.rejected[$0.provider] } ?? (winner == nil ? "no_candidate" : "selected"))
        Chosen Provider: \(winner?.provider ?? "No Lyrics")
        Identity Tier: \(decision.tier ?? decision.reason)
        Identity confidence: \(decision.tier ?? decision.reason)
        Source Track ID: \(Self.diagnosticValue(winner?.sourcePlatform)) / \(Self.diagnosticID(winner?.sourceTrackID))
        Source ISRC: \(winner?.provider == "LRCMux" ? "unverified resolver hint: " + (RecordingISRC.normalized(winner?.sourceISRC) ?? "unavailable") : (RecordingISRC.normalized(winner?.sourceISRC) ?? "unavailable"))
        Source Duration: \(winner?.sourceDuration.map(String.init(describing:)) ?? "unavailable") s
        Player Duration: \(requestContext.track.duration) s
        Timing Fidelity: \(winner?.document.timingFidelity.rawValue ?? "unavailable")
        Matcher Confidence: \(winner?.matcherScore.map(String.init) ?? "unavailable")
        First Lyric Timestamp: \(winner?.document.normalizedLines.first.map { String($0.time) } ?? "unavailable") s
        Sources: \(statuses.keys.sorted().map { "\($0)=\(statuses[$0]!)" }.joined(separator: "; "))
        Rejected: \(decision.rejected.keys.sorted().map { "\($0)=\(decision.rejected[$0]!)" }.joined(separator: "; "))
        Timeline Conflict: \(decision.reason.contains("timeline_conflict") || reasons.contains(where: { $0.contains("timeline_conflict") }))
        Duration Difference: \(winner?.sourceDuration.map { String(abs($0 - context.track.duration)) } ?? "unavailable") s
        Candidate Providers:
        \(candidateDetails.isEmpty ? "none (see source statuses above)" : candidateDetails)
        """
        if diagnosticsRequestID == requestID {
            selectionDiagnostics = Self.sanitizedDiagnostics(report)
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            // Launch observation only after the primary result has been committed.
            shadowTask = Task { [weak self] in
                guard let self, diagnosticsRequestID == requestID, !Task.isCancelled else { return }
                let id = await backendShadow.begin(track: requestContext.track, playerSource: requestContext.playerSource,
                    nativeTrackID: requestContext.nativeTrackID, isrc: requestContext.isrc) { [weak self] text in
                        self?.setShadowDiagnostics(text, requestID: requestID)
                    }
                guard diagnosticsRequestID == requestID, !Task.isCancelled else {
                    if let id { await backendShadow.cancel(requestID: id) }
                    return
                }
                shadowRequestID = id
                await backendShadow.completeLocal(requestID: id, candidate: winner, identityTier: decision.tier, elapsed: elapsed)
            }
        }
        DebugLog.lyricsDiagnostic("selection.final " + selectionDiagnostics.replacingOccurrences(of: "\n", with: " | "))
        return selectedDocument?.normalizedLines ?? []
    }

    struct Collection: Sendable {
        let candidates: [LyricsCandidate]
        let statuses: [String: String]
        let hadSuccessfulSource: Bool
    }
    nonisolated static func boundedIdentity(_ uri: String, resolver: @escaping IdentityResolver) async throws -> SpotifyCanonicalIdentity {
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        return try await withThrowingTaskGroup(of: SpotifyCanonicalIdentity.self) { group in
            group.addTask {
                try await LyricsHTTP.$deadline.withValue(deadline) {
                    do { return try await resolver(uri) }
                    catch {
                        try Task.checkCancellation()
                        guard LyricsHTTP.isTransient(error), deadline - ProcessInfo.processInfo.systemUptime > 0.3 else { throw error }
                        DebugLog.lyricsDiagnostic("identity.transport_retry attempt=2")
                        try await Task.sleep(for: .milliseconds(150))
                        return try await resolver(uri)
                    }
                }
            }
            group.addTask { try await Task.sleep(for: .seconds(6)); throw URLError(.timedOut) }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    nonisolated private static func boundedSource(_ source: @escaping CandidateSource, track: SpotifyTrack, budget: Double, label: String) async -> (LyricsCandidate?, String) {
        let start = Date(), timing = LyricsHTTP.Timing()
        DebugLog.lyricsDiagnostic("performance.provider_start provider=\(label) time=\(start.timeIntervalSince1970) budget=\(budget)")
        var status: String
        var candidate: LyricsCandidate?
        do {
            candidate = try await withThrowingTaskGroup(of: LyricsCandidate?.self) { children in
                children.addTask {
                    try await LyricsHTTP.$deadline.withValue(ProcessInfo.processInfo.systemUptime + budget) {
                        try await LyricsHTTP.$timing.withValue(timing) { try await source(track) }
                    }
                }
                children.addTask { try await Task.sleep(for: .seconds(budget)); throw URLError(.timedOut) }
                defer { children.cancelAll() }
                return try await children.next() ?? nil
            }
            candidate?.elapsed = Date().timeIntervalSince(start)
            status = candidate == nil ? "empty" : "candidate"
        } catch {
            status = Task.isCancelled ? "cancelled" : ((error as? URLError)?.code == .timedOut ? "timeout" : (LyricsHTTP.isTransient(error) ? "transient_network_error" : "error"))
            let category = error is DecodingError ? "decoding" : (error is URLError ? "url" : "other")
            DebugLog.lyricsDiagnostic("performance.provider_failure provider=\(label) category=\(category) url_code=\((error as? URLError)?.code.rawValue ?? 0)")
        }
        let firstByte = timing.firstResponseTime.map { String($0) } ?? "unavailable"
        DebugLog.lyricsDiagnostic("performance.provider_complete provider=\(label) complete=\(Date().timeIntervalSince1970) first_byte=\(firstByte) elapsed=\(Date().timeIntervalSince(start)) status=\(status)")
        return (candidate, status)
    }
    /// Deadline bounds collection; cancellation cooperates with URLSession. Bridge subprocesses
    /// retain their own 3s timeout, so cancellation can take that additional time to drain.
    nonisolated static func collect(_ sources: [CandidateSource], names: [String], for track: SpotifyTrack,
                                   window: Double = 8, context: LyricsSelectionContext? = nil, boundedSpotify: Bool = false) async -> Collection {
        enum Result: Sendable { case source(Int, LyricsCandidate?, String); case deadline }
        return await withTaskGroup(of: Result.self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    let label = names.indices.contains(index) ? names[index] : "source_\(index + 1)"
                    let budget = boundedSpotify ? min(window, ["LRCLIB": 2.5, "NetEase": 2.5, "QQ": 2.4, "Kugou": 2.2, "LRCMux": 1.8, "Soda": 0.5][label] ?? window) : window
                    let (candidate, status) = await boundedSource(source, track: track, budget: budget, label: label)
                    return .source(index, candidate, status)
                }
            }
            group.addTask { try? await Task.sleep(for: .seconds(window)); return .deadline }
            var candidates: [LyricsCandidate] = [], statuses: [String: String] = [:]
            var completed = 0, successful = false
            for await result in group {
                switch result {
                case .deadline:
                    group.cancelAll()
                    for index in sources.indices where statuses[names.indices.contains(index) ? names[index] : "source_\(index + 1)"] == nil {
                        statuses[names.indices.contains(index) ? names[index] : "source_\(index + 1)"] = "deadline"
                    }
                    return Collection(candidates: candidates, statuses: statuses, hadSuccessfulSource: successful)
                case let .source(index, candidate, status):
                    completed += 1; successful = successful || ["empty", "candidate"].contains(status)
                    let name = names.indices.contains(index) ? names[index] : "source_\(index + 1)"
                    statuses[name] = status
                    if let candidate {
                        candidates.append(candidate)
                        DebugLog.lyricsDiagnostic("selection.candidate provider=\(candidate.provider) source_platform=\(candidate.sourcePlatform ?? "unknown") source_id=\(candidate.sourceTrackID ?? "unknown") title=\(DebugLog.metadata(candidate.sourceTitle)) artist=\(DebugLog.metadata(candidate.sourceArtist)) album=\(DebugLog.metadata(candidate.sourceAlbum ?? "unknown")) duration=\(candidate.sourceDuration ?? -1) score=\(candidate.matcherScore ?? -1) first=\(candidate.document.normalizedLines.first?.time ?? -1) last=\(candidate.document.normalizedLines.last?.time ?? -1) fidelity=\(candidate.document.timingFidelity.rawValue) elapsed=\(candidate.elapsed)")
                    }
                    // All primary direct providers must finish before generic selection.
                    // A validated recording need not wait for supplemental Soda or the unbound resolver.
                    if boundedSpotify, let context,
                       sources.indices.allSatisfy({ names.indices.contains($0) && ["LRCMux", "Soda"].contains(names[$0]) || statuses[names.indices.contains($0) ? names[$0] : "source_\($0 + 1)"] != nil }),
                       let winner = LyricsSelection.select(candidates, context: context).winner,
                       winner.provider != "LRCMux" {
                        group.cancelAll()
                        for supplemental in ["LRCMux", "Soda"] where statuses[supplemental] == nil && names.contains(supplemental) {
                            statuses[supplemental] = "skipped_after_strict_direct_selection"
                        }
                        return Collection(candidates: candidates, statuses: statuses, hadSuccessfulSource: successful)
                    }
                    // Only live same-platform proof may end collection early. Wait for
                    // the direct NetEase source too, so same proven-ID conflicts still veto.
                    if let context, context.platform == "netease",
                       statuses["NetEase"] != nil, statuses["NetEaseExactID (Preview)"] != nil,
                       candidates.contains(where: { $0.liveIdentityVerified && LyricsSelection.identityTier($0, context: context) == 1 }),
                       LyricsSelection.select(candidates, context: context).tier == "A exact platform" {
                        group.cancelAll()
                        for index in sources.indices {
                            let label = names.indices.contains(index) ? names[index] : "source_\(index + 1)"
                            if statuses[label] == nil { statuses[label] = "skipped_after_verified_exact" }
                        }
                        return Collection(candidates: candidates, statuses: statuses, hadSuccessfulSource: successful)
                    }
                    if completed == sources.count {
                        group.cancelAll()
                        return Collection(candidates: candidates, statuses: statuses, hadSuccessfulSource: successful)
                    }
                }
            }
            return Collection(candidates: candidates, statuses: statuses, hadSuccessfulSource: successful)
        }
    }

    private func legacyLyrics(_ sources: [Source], track: SpotifyTrack, key: String, bypass: Bool, fallback: Source?) async throws -> [LyricLine] {
        if let lines = cache.value(for: key, bypass: bypass) {
            selectedProvider = cache.provider(for: key); selectedDocument = TimedLyricDocument(lines: lines, metadata: LyricsMetadata(provider: selectedProvider)); return lines
        }
        selectedProvider = nil; selectedDocument = nil
        let result = await Self.firstNonEmptyResult(sources, for: track)
        try Task.checkCancellation()
        if result.lines.isEmpty, let fallback, let lines = try? await fallback(track), !lines.isEmpty {
            try Task.checkCancellation(); selectedProvider = "NetEaseExactID (Preview)"
            selectedDocument = TimedLyricDocument(lines: lines, metadata: LyricsMetadata(provider: selectedProvider)); return lines
        }
        guard result.hadSuccessfulSource else { throw LyricsClientError.networkFailure }
        selectedProvider = result.selectedProvider
        selectedDocument = TimedLyricDocument(lines: result.lines, metadata: LyricsMetadata(provider: selectedProvider))
        cache.insert(result.lines, provider: selectedProvider, for: key)
        return result.lines
    }

    // Legacy array test compatibility: collect first, then deterministic source order.
    // This never participates in the application's default evidence pipeline.
    struct SourceAggregate { let lines: [LyricLine]; let hadSuccessfulSource: Bool; let aggregateReason: String; let selectedProvider: String? }
    nonisolated static func firstNonEmpty(_ sources: [Source], for track: SpotifyTrack, window: Double = 8) async -> [LyricLine] {
        await firstNonEmptyResult(sources, for: track, window: window).lines
    }
    nonisolated static func firstNonEmptyResult(_ sources: [Source], names: [String]? = nil, for track: SpotifyTrack, window: Double = 8) async -> SourceAggregate {
        let converted: [CandidateSource] = sources.enumerated().map { index, source in
            { track in
                let lines = try await source(track)
                guard !lines.isEmpty else { return nil }
                return LyricsCandidate(document: TimedLyricDocument(lines: lines), provider: names?[index] ?? "source_\(index + 1)", sourceTitle: "", sourceArtist: "")
            }
        }
        let labels = names ?? sources.indices.map { "source_\($0 + 1)" }
        let result = await collect(converted, names: labels, for: track, window: window)
        let winner = result.candidates.min { (labels.firstIndex(of: $0.provider) ?? 100) < (labels.firstIndex(of: $1.provider) ?? 100) }
        return SourceAggregate(lines: winner?.document.normalizedLines ?? [], hadSuccessfulSource: result.hadSuccessfulSource,
            aggregateReason: winner != nil ? "hit" : (result.hadSuccessfulSource ? "empty" : "all_failed"), selectedProvider: winner?.provider)
    }
}

struct LyricsCache {
    private struct Entry {
        let lines: [LyricLine]
        let provider: String?
    }

    private let capacity: Int
    private var values: [String: Entry] = [:]
    private var keys: [String] = []

    init(capacity: Int) {
        self.capacity = capacity
    }

    func value(for key: String, bypass: Bool = false) -> [LyricLine]? {
        bypass ? nil : values[key]?.lines
    }

    func provider(for key: String) -> String? {
        values[key]?.provider
    }

    mutating func insert(_ lines: [LyricLine], provider: String? = nil, for key: String) {
        guard !lines.isEmpty else { return }
        if values.updateValue(Entry(lines: lines, provider: provider), forKey: key) == nil {
            keys.append(key)
        }
        if keys.count > capacity {
            values.removeValue(forKey: keys.removeFirst())
        }
    }
}
