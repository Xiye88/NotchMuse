import AppKit

final class InteractionSoundEngine: @unchecked Sendable {
    enum Cue: CaseIterable, Sendable {
        case tick, step, latch, dial, landed, hush

        var volume: Float {
            switch self {
            case .tick: 0.25
            case .step: 0.28
            case .latch: 0.30
            case .dial: 0.26
            case .landed: 0.32
            case .hush: 0.22
            }
        }
    }

    static let shared = InteractionSoundEngine()
    private let queue = DispatchQueue(label: "app.notchmuse.interaction-sounds", qos: .userInitiated)
    // Sound creation and playback are confined to this queue.
    private lazy var sounds: [Cue: NSSound] = Dictionary(uniqueKeysWithValues: Cue.allCases.compactMap { cue in
        guard let sound = NSSound(data: Self.waveData(for: cue)) else { return nil }
        sound.volume = cue.volume
        return (cue, sound)
    })
    private var playingSound: NSSound?

    private init() {}

    @MainActor
    func play(_ cue: Cue) {
        guard AppPreferences.interactionSoundsEnabled() else { return }
        enqueue(cue)
    }

    @MainActor
    func setEnabled(_ enabled: Bool) {
        guard AppPreferences.interactionSoundsEnabled() != enabled else { return }
        AppPreferences.setInteractionSoundsEnabled(enabled)
        enqueue(enabled ? .tick : .hush)
    }

    private func enqueue(_ cue: Cue) {
        queue.async {
            self.playingSound?.stop()
            self.playingSound = self.sounds[cue]
            self.playingSound?.play()
        }
    }

    static func waveData(for cue: Cue) -> Data {
        let tones: [(start: Double, end: Double, duration: Double)]
        switch cue {
        case .tick: tones = [(560, 380, 0.032)]
        case .step: tones = [(380, 240, 0.048)]
        case .latch: tones = [(315, 260, 0.026), (510, 400, 0.032)]
        case .dial: tones = [(820, 1040, 0.030)]
        case .landed: tones = [(660, 660, 0.039), (880, 880, 0.060)]
        case .hush: tones = [(330, 247, 0.080)]
        }

        let sampleRate = 24_000
        let counts = tones.map { Int($0.duration * Double(sampleRate)) }
        let pcmSize = counts.reduce(0, +) * MemoryLayout<Int16>.size
        var wave = Data(capacity: 44 + pcmSize)
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { wave.append(contentsOf: $0) }
        }

        wave.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + pcmSize))
        wave.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1)) // Linear PCM
        append(UInt16(1)) // Mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        wave.append(contentsOf: "data".utf8)
        append(UInt32(pcmSize))

        for (tone, count) in zip(tones, counts) {
            for index in 0..<count {
                let t = Double(index) / Double(sampleRate)
                let progress = Double(index) / Double(count - 1)
                let phase = 2 * Double.pi * t * (tone.start + (tone.end - tone.start) * progress / 2)
                let envelope = min(1, t / 0.003) * pow(1 - progress, 2)
                append(Int16(sin(phase) * envelope * 0.38 * Double(Int16.max)))
            }
        }
        return wave
    }
}
