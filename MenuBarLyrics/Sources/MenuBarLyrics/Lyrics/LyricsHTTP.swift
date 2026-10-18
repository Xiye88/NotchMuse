import Foundation

enum LyricsHTTP {
    // Each source inherits its own absolute deadline across search + lyric requests.
    @TaskLocal static var deadline: Double?
    @TaskLocal static var timing: Timing?

    final class Timing: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var firstByte: Double?
        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            guard let date = metrics.transactionMetrics.compactMap(\.responseStartDate).min() else { return }
            lock.lock(); defer { lock.unlock() }
            firstByte = min(firstByte ?? date.timeIntervalSince1970, date.timeIntervalSince1970)
        }
        var firstResponseTime: Double? {
            lock.lock(); defer { lock.unlock() }; return firstByte
        }
    }

    static func data(for original: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        var request = original
        if let deadline {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw URLError(.timedOut) }
            request.timeoutInterval = min(request.timeoutInterval, remaining)
        }
        let result = try await URLSession.shared.data(for: request, delegate: timing)
        try Task.checkCancellation()
        return result
    }

    struct StatusError: Error { let code: Int; let retryAllowed: Bool }

    static func isTransient(_ error: Error) -> Bool {
        if let error = error as? StatusError { return error.retryAllowed && [502, 503, 504].contains(error.code) }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed].contains(error.code)
    }

    static func retryableStatus(_ status: String) -> Bool {
        ["timeout", "deadline", "transient_network_error"].contains(status)
    }

    static func validate(data: Data, response: URLResponse) throws -> Data {
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw StatusError(code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                retryAllowed: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") == nil)
        }
        return data
    }
}
