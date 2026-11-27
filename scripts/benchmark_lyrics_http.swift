import CryptoKit
import Foundation

/// Benchmark-only transport. Reuse identical requests while each platform still
/// builds its own queries, decodes the results and runs recording selection.
actor BenchmarkLyricsHTTP {
    static let shared = BenchmarkLyricsHTTP()

    private struct Key: Codable, Hashable {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data?
    }

    private struct StoredResponse: Codable {
        let data: Data
        let status: Int
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    private var responses: [Key: (Data, URLResponse)] = [:]
    private var inFlight: [Key: Task<(Data, URLResponse), Error>] = [:]
    private var blockedUntil: [String: Double] = [:]
    private var nextRequest: [String: Double] = [:]
    private var requests: [String: Int] = [:]
    private var cacheHits = 0
    private var diskHits = 0
    private var diskDirectory: URL?

    func enableDiskCache(_ path: String) throws {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        diskDirectory = directory
    }

    private func diskFile(for key: Key) throws -> URL? {
        guard let diskDirectory else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let digest = SHA256.hash(data: try encoder.encode(key))
        return diskDirectory.appendingPathComponent(digest.map { String(format: "%02x", $0) }.joined())
    }

    func data(for original: URLRequest, deadline: Double?) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = original.url, let host = url.host else { throw URLError(.badURL) }
        let body = original.httpBody
        let canonicalBody = body.flatMap { data -> Data? in
            guard original.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return try? JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        }
        let key = Key(url: url, method: original.httpMethod ?? "GET",
                      headers: original.allHTTPHeaderFields ?? [:], body: canonicalBody ?? body)
        if let response = responses[key] {
            cacheHits += 1
            return response
        }
        if let task = inFlight[key] {
            cacheHits += 1
            return try await task.value
        }
        let file = try diskFile(for: key)
        if let file, let bytes = try? Data(contentsOf: file),
           let stored = try? PropertyListDecoder().decode(StoredResponse.self, from: bytes),
           let response = HTTPURLResponse(url: url, statusCode: stored.status, httpVersion: nil, headerFields: nil) {
            diskHits += 1
            let cached = (stored.data, response)
            responses[key] = cached
            return cached
        }
        let now = ProcessInfo.processInfo.systemUptime
        let start = max(now, nextRequest[host] ?? now, blockedUntil[host] ?? now)
        guard start < deadline ?? .infinity else { throw URLError(.timedOut) }
        nextRequest[host] = start + 0.25
        let task = Task {
            try await Task.sleep(for: .seconds(start - now))
            return try await send(original, host: host, deadline: deadline)
        }
        inFlight[key] = task
        defer { inFlight.removeValue(forKey: key) }
        let response = try await task.value
        if let http = response.1 as? HTTPURLResponse, [200, 404].contains(http.statusCode) {
            responses[key] = response
            if let file {
                let payload = try PropertyListEncoder().encode(StoredResponse(data: response.0, status: http.statusCode))
                try payload.write(to: file, options: .atomic)
            }
        }
        return response
    }

    private func send(_ original: URLRequest, host: String, deadline: Double?) async throws -> (Data, URLResponse) {
        let now = ProcessInfo.processInfo.systemUptime
        let remaining = min(original.timeoutInterval, (deadline ?? .infinity) - now)
        guard remaining > 0, (blockedUntil[host] ?? 0) <= now else { throw URLError(.timedOut) }
        var request = original
        request.timeoutInterval = remaining
        requests[host, default: 0] += 1
        let result = try await session.data(for: request)
        if let http = result.1 as? HTTPURLResponse, http.statusCode == 429 || http.statusCode == 503,
           let delay = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? (http.statusCode == 429 ? 60 : nil) {
            let retry = ProcessInfo.processInfo.systemUptime + max(60, delay)
            blockedUntil[host] = max(blockedUntil[host] ?? 0, retry)
        }
        if let http = result.1 as? HTTPURLResponse, http.statusCode >= 400 {
            requests["\(host) HTTP \(http.statusCode)", default: 0] += 1
        }
        return result
    }

    func summary() -> String {
        "Transport cache/join hits: \(cacheHits). Disk hits: \(diskHits). Requests: " +
            requests.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
}
