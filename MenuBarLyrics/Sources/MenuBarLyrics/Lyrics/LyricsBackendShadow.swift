import Foundation
import CryptoKit

/// Preview-only observation. This type cannot return a candidate or lyric document.
actor LyricsBackendShadow {
    struct Request: Encodable, Sendable {
        let request_id: String
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let player_source: String?
        let native_track_id: String?
        let isrc: String?

        // Keep optional keys explicit for the server's strict schema.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(request_id, forKey: .request_id); try c.encode(title, forKey: .title)
            try c.encode(artist, forKey: .artist); try c.encode(album, forKey: .album)
            try c.encode(duration, forKey: .duration); try c.encode(player_source, forKey: .player_source)
            try c.encode(native_track_id, forKey: .native_track_id); try c.encode(isrc, forKey: .isrc)
        }
        enum Keys: String, CodingKey { case request_id, title, artist, album, duration, player_source, native_track_id, isrc }
    }

    struct Response: Decodable, Sendable {
        let request_id: String
        let native_track_id: String?
        let status: String
        let provider: String?
        let source_platform: String?
        let source_track_id: String?
        let source_title: String?
        let source_artist: String?
        let source_album: String?
        let source_duration: Double?
        let source_isrc: String?
        let identity_provenance: String
        let recording_identity: String
        let timing_type: String?
        let timestamps_ms: [Int]
        let text_hashes: [String]
        let timeline_signature: String
        let upstream_pin: String
        let latency_ms: Double

        func validate(for request: Request) throws {
            let hit = status == "hit"
            guard request_id == request.request_id, native_track_id == request.native_track_id,
                  ["hit", "no_lyrics"].contains(status), upstream_pin == LyricsBackendShadow.pin,
                  latency_ms.isFinite, (0...12000).contains(latency_ms), source_isrc == nil,
                  recording_identity == "UNVERIFIED", timestamps_ms.count == text_hashes.count,
                  timestamps_ms.count <= 2000, hit == !timestamps_ms.isEmpty,
                  timestamps_ms.allSatisfy({ $0 >= 0 && Double($0) <= (request.duration + 30) * 1000 }),
                  zip(timestamps_ms, timestamps_ms.dropFirst()).allSatisfy({ $0 <= $1 }),
                  text_hashes.allSatisfy({ Self.isHash($0) }), Self.isHash(timeline_signature),
                  timeline_signature == LyricsBackendShadow.signature(times: timestamps_ms, hashes: text_hashes),
                  [source_title, source_artist, source_album, source_track_id, timing_type].allSatisfy({ LyricsBackendShadow.safeText($0, optional: true) }),
                  source_duration == nil || (source_duration!.isFinite && (0...7200).contains(source_duration!)),
                  (!hit && provider == nil && source_platform == nil && source_track_id == nil && identity_provenance == "unverified") ||
                  (hit && provider == "qq" && source_platform == "qq" && source_track_id?.range(of: #"^[A-Za-z0-9]{10,20}$"#, options: .regularExpression) != nil && identity_provenance == "qq_search_metadata_query_fallback_possible" && LyricsBackendShadow.safeText(source_title) && LyricsBackendShadow.safeText(source_artist))
            else { throw URLError(.cannotParseResponse) }
        }
        private static func isHash(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
    }

    nonisolated static let pin = "96d7e2b1063360d061534ae41310fc06ed537010"
    private let preview: Bool
    private let endpoint: URL?
    private var task: Task<Void, Never>?
    private var generation: UUID?
    private var request: Request?
    private var backend: Response?
    private var local: LyricsCandidate?
    private var localCompleted = false
    private var localTier = "unavailable"
    private var localElapsed: TimeInterval = 0
    private var backendStatus = "pending"
    private var onUpdate: (@MainActor @Sendable (String) -> Void)?
    private(set) var diagnostics = "Shadow: disabled"

    init(preview: Bool = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true,
         endpoint: URL? = configuredEndpoint()) {
        self.preview = preview; self.endpoint = endpoint.flatMap { Self.validEndpoint($0) ? $0 : nil }
    }

    nonisolated static func configuredEndpoint() -> URL? {
        let raw = ProcessInfo.processInfo.environment["NOTCHMUSE_SHADOW_URL"] ?? Bundle.main.object(forInfoDictionaryKey: "NotchMuseShadowURL") as? String
        return raw.flatMap(URL.init(string:)).flatMap { validEndpoint($0) ? $0 : nil }
    }

    nonisolated static func validEndpoint(_ url: URL) -> Bool {
        url.scheme == "http" && ["127.0.0.1", "localhost"].contains(url.host) &&
        url.port.map { (1...65535).contains($0) } == true && url.user == nil && url.password == nil &&
        url.query == nil && url.fragment == nil && url.path == "/v1/shadow/resolve"
    }

    @discardableResult
    func begin(track: SpotifyTrack, playerSource: String?, nativeTrackID: String?, isrc: String?,
               onUpdate: @escaping @MainActor @Sendable (String) -> Void = { _ in }) -> UUID? {
        cancel()
        guard preview, let endpoint else {
            diagnostics = "Shadow: disabled (Preview loopback endpoint absent)"
            deliver(diagnostics, to: onUpdate); return nil
        }
        guard track.duration.isFinite, track.duration > 0, track.duration <= 7200,
              Self.safeText(track.name), Self.safeText(track.artist), Self.safeText(track.album, optional: true),
              Self.safeText(playerSource, optional: true), Self.safeText(nativeTrackID, optional: true),
              isrc == nil || RecordingISRC.normalized(isrc) != nil,
              playerSource?.lowercased() != "spotify" || nativeTrackID?.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil
        else { diagnostics = "Shadow: rejected request metadata"; deliver(diagnostics, to: onUpdate); return nil }
        let id = UUID()
        let value = Request(request_id: id.uuidString, title: track.name, artist: track.artist, album: track.album,
                            duration: track.duration, player_source: playerSource, native_track_id: nativeTrackID, isrc: RecordingISRC.normalized(isrc))
        generation = id; request = value; self.onUpdate = onUpdate
        DebugLog.lyricsDiagnostic("performance.shadow_start request=\(id) uptime=\(ProcessInfo.processInfo.systemUptime)")
        backendStatus = "pending"; publish()
        task = Task { [weak self] in
            do {
                let result = try await Self.fetch(value, endpoint: endpoint)
                try Task.checkCancellation()
                await self?.finished(result, id: id)
            } catch {
                guard !Task.isCancelled else { return }
                await self?.finished(nil, id: id)
            }
        }
        return id
    }

    private func finished(_ response: Response?, id: UUID) {
        guard generation == id else { return }
        backend = response; backendStatus = response?.status ?? "unavailable_or_rejected"
        publish()
        DebugLog.lyricsDiagnostic("performance.shadow_finish request=\(id) uptime=\(ProcessInfo.processInfo.systemUptime) status=\(backendStatus)")
    }

    func completeLocal(requestID: UUID?, candidate: LyricsCandidate?, identityTier: String?, elapsed: TimeInterval) {
        guard let requestID, generation == requestID else { return }
        local = candidate; localCompleted = true; localTier = identityTier ?? "unavailable"
        localElapsed = elapsed.isFinite ? max(0, elapsed) : 0; publish()
    }

    func cancel(requestID: UUID? = nil) {
        if let requestID, generation != requestID { return }
        task?.cancel(); task = nil; generation = nil; request = nil; backend = nil
        local = nil; localCompleted = false; onUpdate = nil; diagnostics = "Shadow: cancelled"
    }

    private func publish() {
        guard generation != nil, let request else { return }
        let sameSource = local?.sourcePlatform == "qq" && local?.provider == "QQ" && local?.sourceTrackID != nil && local?.sourceTrackID == backend?.source_track_id
        let localLines = local?.document.normalizedLines.filter { !Self.normalizedText($0.text).isEmpty } ?? []
        // ponytail: line starts/text only; add word/end comparisons after the
        // recording and line-timeline evidence warrants a richer protocol.
        let validLocalTimeline = localLines.count <= 2000 && localLines.allSatisfy { $0.time.isFinite && $0.time >= 0 && $0.time <= request.duration + 30 }
        let times = validLocalTimeline ? localLines.map { Int(($0.time * 1000).rounded()) } : []
        let hashes = localLines.map { Self.hash(Self.normalizedText($0.text)) }
        let timeline = !validLocalTimeline ? "invalid local timeline" : localCompleted && backend != nil ? (times == backend!.timestamps_ms && hashes == backend!.text_hashes ? "agree" : "disagree") : "pending"
        let metadata: String
        if let local, let backend, backend.status == "hit" {
            let namesMatch = Self.normalizedText(local.sourceTitle) == Self.normalizedText(backend.source_title ?? "") && Self.normalizedText(local.sourceArtist) == Self.normalizedText(backend.source_artist ?? "")
            let durationMatch = local.sourceDuration.flatMap { l in backend.source_duration.map { abs(l - $0) <= 2 } } ?? false
            metadata = namesMatch && durationMatch ? "agree (query fallback possible)" : "disagree"
        } else { metadata = localCompleted && backend != nil ? "not comparable (missing result)" : "pending" }
        diagnostics = """
        Shadow Request: \(request.request_id)
        Shadow Native Track ID: \(request.native_track_id ?? "unavailable")
        Shadow Query Artist: \(request.artist) (native metadata; local canonical collaborators may differ)
        Shadow Backend: \(backendStatus)
        Shadow Local Provider: \(local?.provider ?? (localCompleted ? "No Lyrics" : "pending"))
        Shadow Local Identity: \(localTier)
        Shadow Backend Provider: \(backend?.provider ?? "unavailable")
        Shadow Backend Source ID: \(backend?.source_track_id ?? "unavailable")
        Shadow Backend Metadata: \(backend?.source_title ?? "unavailable") / \(backend?.source_artist ?? "unavailable") / \(backend?.source_album ?? "unavailable")
        Shadow Identity Provenance: \(backend?.identity_provenance ?? "unavailable")
        Shadow Recording Agreement: \(sameSource ? "same QQ source ID" : "UNVERIFIED")
        Shadow Metadata Agreement: \(metadata)
        Shadow Timeline Agreement: \(timeline)
        Shadow Local Timeline Signature: \(localCompleted ? (validLocalTimeline ? Self.signature(times: times, hashes: hashes) : "invalid local timeline") : "pending")
        Shadow Backend Timeline Signature: \(backend?.timeline_signature ?? "unavailable")
        Shadow Local Latency: \(Int(localElapsed * 1000)) ms
        Shadow Backend Latency: \(backend.map { String(Int($0.latency_ms)) } ?? "unavailable") ms
        """
        if let onUpdate { deliver(diagnostics, to: onUpdate) }
        DebugLog.lyricsDiagnostic(diagnostics.replacingOccurrences(of: "\n", with: " | "))
    }

    private func deliver(_ text: String, to update: @escaping @MainActor @Sendable (String) -> Void) {
        Task { @MainActor in update(text) }
    }

    nonisolated static func safeText(_ value: String?, optional: Bool = false) -> Bool {
        guard let value else { return optional }
        return value.utf8.count <= 512 && !value.unicodeScalars.contains { $0.value < 32 } && (optional || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    nonisolated static func normalizedText(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.components(separatedBy: .whitespacesAndNewlines).joined()
    }
    nonisolated static func hash(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    nonisolated static func signature(times: [Int], hashes: [String]) -> String {
        hash(zip(times, hashes).map { "\($0)\t\($1)" }.joined(separator: "\n"))
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
    }

    nonisolated static func fetch(_ value: Request, endpoint: URL) async throws -> Response {
        guard validEndpoint(endpoint) else { throw URLError(.badURL) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 12
        let session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(value)
        let (bytes, response) = try await session.bytes(for: request)
        guard response.url == endpoint, let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= 256 * 1024 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 256 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        let result = try JSONDecoder().decode(Response.self, from: data)
        try result.validate(for: value)
        return result
    }
}
