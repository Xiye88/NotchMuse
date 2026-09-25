import Foundation

struct MediaRemoteIdentifier: Decodable, Equatable, Sendable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let string = try? value.decode(String.self) {
            rawValue = string
        } else if let integer = try? value.decode(Int64.self) {
            rawValue = String(integer)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected a string or integer identifier")
            )
        }
    }
}

struct MediaRemoteEvent: Decodable, Equatable, Sendable {
    let bundleIdentifier: String
    let parentApplicationBundleIdentifier: String?
    var playing: Bool
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval?
    let elapsedTimeNow: TimeInterval?
    let timestamp: String?
    let uniqueIdentifier: MediaRemoteIdentifier?
    let contentItemIdentifier: String?
    let mediaType: String?
}

enum MediaRemoteBridgeError: Error, Sendable {
    case resourcesMissing(String)
    case commandFailed(Int32, String)
    case invalidResponse
    case timedOut
    case streamAlreadyRunning
}

private final class BridgeOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ value: Data) {
        lock.withLock { data.append(value) }
    }

    func value() -> Data {
        lock.withLock { data }
    }
}

private final class StreamAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data) -> [MediaRemoteEvent] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var events = [MediaRemoteEvent]()
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            do {
                if let event = try MediaRemoteBridge.decodeStreamLine(line) {
                    events.append(event)
                }
            } catch {
                continue
            }
        }
        return events
    }
}

final class MediaRemoteBridge: @unchecked Sendable {
    struct Paths: Equatable, Sendable {
        let script: URL
        let framework: URL
        let testClient: URL
        let watchdog: URL

        init(resourceDirectory: URL) {
            script = resourceDirectory.appendingPathComponent("mediaremote-adapter.pl")
            framework = resourceDirectory.appendingPathComponent("MediaRemoteAdapter.framework")
            testClient = resourceDirectory.appendingPathComponent("MediaRemoteAdapterTestClient")
            watchdog = resourceDirectory.appendingPathComponent("mediaremote-watchdog.sh")
        }
    }

    private let paths: Paths
    private let lock = NSLock()
    private var streamProcess: Process?
    private var streamPipe: Pipe?
    private var stoppingStream = false

    init(paths: Paths) {
        self.paths = paths
    }

    static func bundled(in bundle: Bundle = .main) throws -> MediaRemoteBridge {
        guard let resources = bundle.resourceURL else {
            throw MediaRemoteBridgeError.resourcesMissing("Bundle resources are unavailable")
        }
        let paths = Paths(resourceDirectory: resources.appendingPathComponent("MediaRemoteBridge"))
        let manager = FileManager.default
        guard manager.fileExists(atPath: paths.script.path),
              manager.fileExists(atPath: paths.framework.path),
              manager.isExecutableFile(atPath: paths.testClient.path),
              manager.isExecutableFile(atPath: paths.watchdog.path) else {
            throw MediaRemoteBridgeError.resourcesMissing(paths.script.deletingLastPathComponent().path)
        }
        return MediaRemoteBridge(paths: paths)
    }

    var isStreamRunning: Bool {
        lock.withLock { streamProcess?.isRunning == true }
    }

    func healthCheck(timeout: TimeInterval = 5) throws {
        let result = try run(command: "test", timeout: timeout)
        guard result.status == 0 else {
            throw MediaRemoteBridgeError.commandFailed(result.status, result.stderr)
        }
    }

    func get(timeout: TimeInterval = 5) throws -> MediaRemoteEvent {
        let result = try run(command: "get", options: ["--now"], timeout: timeout)
        guard result.status == 0,
              let line = result.stdout.split(separator: "\n").last,
              let data = String(line).data(using: .utf8),
              let event = try? JSONDecoder().decode(MediaRemoteEvent.self, from: data) else {
            throw MediaRemoteBridgeError.invalidResponse
        }
        return event
    }

    func startStream(
        onEvent: @escaping @Sendable (MediaRemoteEvent) -> Void,
        onFailure: @escaping @Sendable (MediaRemoteBridgeError) -> Void
    ) throws {
        let process = makeProcess(command: "stream", options: ["--no-diff", "--debounce=100"])
        let stdout = Pipe()
        let stderr = Pipe()
        let errors = BridgeOutput()
        let accumulator = StreamAccumulator()
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            for event in accumulator.append(data) {
                onEvent(event)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { errors.append(data) }
        }

        lock.lock()
        guard streamProcess == nil else {
            lock.unlock()
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            throw MediaRemoteBridgeError.streamAlreadyRunning
        }
        streamProcess = process
        streamPipe = stdout
        stoppingStream = false
        lock.unlock()

        process.terminationHandler = { [weak self] terminated in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            guard let self else { return }
            let wasExpected = self.lock.withLock { () -> Bool in
                guard self.streamProcess === terminated else { return true }
                self.streamProcess = nil
                self.streamPipe = nil
                let expected = self.stoppingStream
                self.stoppingStream = false
                return expected
            }
            if !wasExpected {
                let message = String(data: errors.value(), encoding: .utf8) ?? ""
                onFailure(.commandFailed(terminated.terminationStatus, message))
            }
        }

        do {
            try process.run()
        } catch {
            lock.withLock {
                streamProcess = nil
                streamPipe = nil
            }
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            throw error
        }
    }

    func shutdown() {
        let state = lock.withLock { () -> (Process?, Pipe?) in
            stoppingStream = true
            return (streamProcess, streamPipe)
        }
        state.1?.fileHandleForReading.readabilityHandler = nil
        if let process = state.0, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        lock.withLock {
            if streamProcess === state.0 {
                streamProcess = nil
                streamPipe = nil
            }
            stoppingStream = false
        }
    }

    deinit {
        shutdown()
    }

    static func decodeStreamLine(_ data: Data) throws -> MediaRemoteEvent? {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              !payload.isEmpty else { return nil }
        return try JSONDecoder().decode(
            MediaRemoteEvent.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
    }

    private func run(
        command: String,
        options: [String] = [],
        timeout: TimeInterval
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = makeProcess(command: command, options: options)
        let stdout = Pipe()
        let stderr = Pipe()
        let output = BridgeOutput()
        let errors = BridgeOutput()
        let readers = DispatchGroup()
        let terminated = DispatchSemaphore(value: 0)
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { _ in terminated.signal() }

        readers.enter()
        DispatchQueue.global().async {
            output.append(stdout.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global().async {
            errors.append(stderr.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        try process.run()
        if terminated.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            process.waitUntilExit()
            readers.wait()
            throw MediaRemoteBridgeError.timedOut
        }
        readers.wait()
        return (
            process.terminationStatus,
            String(data: output.value(), encoding: .utf8) ?? "",
            String(data: errors.value(), encoding: .utf8) ?? ""
        )
    }

    private func makeProcess(command: String, options: [String]) -> Process {
        let process = Process()
        if command == "stream" {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [paths.watchdog.path, paths.script.path, paths.framework.path, paths.testClient.path, command] + options
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [paths.script.path, paths.framework.path, paths.testClient.path, command] + options
        }
        return process
    }
}
