import AppKit
import Darwin
import QuartzCore
import LyricsCore

enum MissingLyricsAnimationStyle: String, CaseIterable, Equatable, Sendable {
    case vinylSeek = "Vinyl Seek (Default)"
    case cassetteB = "Cassette Side B"
    case runawayNotes = "Runaway Notes"
    case radarPulse = "Sound Radar"
    case floatingCloud = "Drifting Cloud"
    case equalizerBounce = "Rhythm Bars"

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "黑胶寻轨（默认）"
        case (.cassetteB, .simplifiedChinese): return "复古磁带"
        case (.runawayNotes, .simplifiedChinese): return "小音符逃跑"
        case (.radarPulse, .simplifiedChinese): return "声波雷达"
        case (.floatingCloud, .simplifiedChinese): return "云端漂浮"
        case (.equalizerBounce, .simplifiedChinese): return "律动音柱"
        default: return rawValue
        }
    }

    func playfulCaption(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "唱针没找到这首歌的词，正在黑胶纹路里打捞…"
        case (.cassetteB, .simplifiedChinese): return "歌词走失在磁带 B 面，正在帮你倒带找回…"
        case (.runawayNotes, .simplifiedChinese): return "歌词溜走了，这首大概是纯音乐？"
        case (.radarPulse, .simplifiedChinese): return "正在声波雷达里搜寻这首歌的词…"
        case (.floatingCloud, .simplifiedChinese): return "歌词飘在云端，先听听旋律吧~"
        case (.equalizerBounce, .simplifiedChinese): return "纯享旋律时刻，歌词休假去了~"
        case (.vinylSeek, _): return "Tonearm couldn't find lyrics in the grooves…"
        case (.cassetteB, _): return "Lyrics wandered off to Cassette Side B…"
        case (.runawayNotes, _): return "Lyrics ran away — maybe an instrumental?"
        case (.radarPulse, _): return "Scanning the sound radar for lyrics…"
        case (.floatingCloud, _): return "Lyrics are drifting in the clouds — enjoy the melody~"
        case (.equalizerBounce, _): return "Pure melody time — lyrics are on vacation~"
        }
    }

    func shortBarCaption(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "歌词跑丢了…"
        case (.cassetteB, .simplifiedChinese): return "歌词走失在磁带B面…"
        case (.runawayNotes, .simplifiedChinese): return "歌词溜走了，纯享旋律~"
        case (.radarPulse, .simplifiedChinese): return "声波搜词中…"
        case (.floatingCloud, .simplifiedChinese): return "歌词飘在云端~"
        case (.equalizerBounce, .simplifiedChinese): return "纯享旋律时刻~"
        case (.vinylSeek, _): return "Lyrics wandered off…"
        case (.cassetteB, _): return "Lyrics lost on Side B…"
        case (.runawayNotes, _): return "Lyrics slipped away~"
        case (.radarPulse, _): return "Scanning radar…"
        case (.floatingCloud, _): return "Drifting in the clouds~"
        case (.equalizerBounce, _): return "Pure melody time~"
        }
    }
}

enum MediaTransportCommand: Sendable {
    case previous
    case playPause
    case next

    var mediaRemoteCode: UInt32 {
        switch self {
        case .playPause: return 2 // kMRTogglePlayPause
        case .next: return 4      // kMRNextTrack
        case .previous: return 5  // kMRPreviousTrack
        }
    }
}

enum SystemMediaTransport {
    private typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> DarwinBoolean
    private typealias SetElapsedTimeFn = @convention(c) (Double) -> Void

    private static let sendCommandSymbol: SendCommandFn? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let sym = dlsym(handle, "MRMediaRemoteSendCommand") else { return nil }
        return unsafeBitCast(sym, to: SendCommandFn.self)
    }()

    private static let setElapsedTimeSymbol: SetElapsedTimeFn? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let sym = dlsym(handle, "MRMediaRemoteSetElapsedTime") else { return nil }
        return unsafeBitCast(sym, to: SetElapsedTimeFn.self)
    }()

    static var isMediaRemoteCommandAvailable: Bool {
        sendCommandSymbol != nil
    }

    @discardableResult
    static func send(
        _ command: MediaTransportCommand,
        activeSource: PlayerSource?,
        sendRemote: (UInt32) -> Bool = sendMediaRemote,
        postKey: (Int) -> Void = postMediaKey
    ) -> Bool {
        guard command != .playPause || activeSource != nil else { return false }
        if sendRemote(command.mediaRemoteCode) { return true }

        if activeSource == .spotify {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Spotify\" to \(verb)") { return true }
        } else if activeSource == .appleMusic {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Music\" to \(verb)") { return true }
        }

        let keyCode: Int
        switch command {
        case .playPause: keyCode = 16
        case .next: keyCode = 17
        case .previous: keyCode = 18
        }
        postKey(keyCode)
        return true
    }

    @MainActor
    static func launchPreferredPlayer(
        _ preferred: PreferredLaunchPlayer,
        resolve: (PreferredLaunchPlayer) -> (url: URL, source: PlayerSource)? = { $0.resolveApplicationURL() },
        open: (URL) async -> String? = openPlayer,
        runScript: (String, String) -> Bool = playUsingAppleScript,
        isActiveBundle: (String) async -> Bool = isActiveMediaRemoteBundle,
        sendRemote: (UInt32) -> Bool = sendMediaRemote
    ) async {
        guard preferred != .none, let target = resolve(preferred),
              let bundleID = await open(target.url) else { return }

        switch target.source {
        case .spotify:
            let script = "tell application \"Spotify\" to play"
            if !runScript(script, bundleID) {
                try? await Task.sleep(for: .milliseconds(400))
                if !Task.isCancelled { _ = runScript(script, bundleID) }
            }
        case .appleMusic:
            _ = runScript("tell application \"Music\" to play", bundleID)
        default:
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, await isActiveBundle(bundleID) else { return }
            _ = sendRemote(0) // kMRPlay
        }
    }

    @MainActor
    private static func openPlayer(at url: URL) async -> String? {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let app = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return app?.bundleIdentifier
    }

    private static func playUsingAppleScript(_ script: String, bundleID: String) -> Bool {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { !$0.isTerminated }) else {
            return false
        }
        return runAppleScript(script)
    }

    private static func isActiveMediaRemoteBundle(_ bundleID: String) async -> Bool {
        await Task.detached {
            guard let event = try? MediaRemoteBridge.bundled().get(timeout: 1) else { return false }
            return (event.parentApplicationBundleIdentifier ?? event.bundleIdentifier) == bundleID
        }.value
    }

    private static func sendMediaRemote(_ code: UInt32) -> Bool {
        sendCommandSymbol?(code, nil).boolValue ?? false
    }

    static func seek(to seconds: TimeInterval, activeSource: PlayerSource?) {
        let target = max(0, seconds)
        if activeSource == .spotify {
            if runAppleScript("tell application \"Spotify\" to set player position to \(target)") { return }
        } else if activeSource == .appleMusic {
            if runAppleScript("tell application \"Music\" to set player position to \(target)") { return }
        }
        if let seekFn = setElapsedTimeSymbol {
            seekFn(target)
        }
    }

    private static func postMediaKey(_ keyCode: Int) {
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xa00 : 0xb00)
            let data1 = (keyCode << 16) | (isDown ? 0xa00 : 0xb00)
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent {
                event.post(tap: .cghidEventTap)
            }
        }
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}

@MainActor
final class MissingLyricsAnimationView: NSView {
    var style: MissingLyricsAnimationStyle = .vinylSeek {
        didSet {
            if style != oldValue {
                rebuildArtwork()
                updateCaption()
                if isActive { startAnimations() }
            }
        }
    }
    var isIdlePreview: Bool = false {
        didSet {
            if isIdlePreview != oldValue {
                updateCaption()
            }
        }
    }
    var onRetry: (() -> Void)?

    private let stageView = NSView()
    private let captionLabel = NSTextField(wrappingLabelWithString: "")
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private var isActive = false
    private var animatedLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        stageView.wantsLayer = true
        stageView.layer?.masksToBounds = false
        stageView.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.alignment = .center
        captionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        retryButton.title = AppPreferences.language == .simplifiedChinese ? "重试匹配" : "Retry Match"
        retryButton.bezelStyle = .rounded
        retryButton.controlSize = .regular
        retryButton.target = self
        retryButton.action = #selector(retryClicked)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stageView)
        addSubview(captionLabel)
        addSubview(retryButton)

        NSLayoutConstraint.activate([
            stageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -36),
            stageView.widthAnchor.constraint(equalToConstant: 140),
            stageView.heightAnchor.constraint(equalToConstant: 96),

            captionLabel.topAnchor.constraint(equalTo: stageView.bottomAnchor, constant: 14),
            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),

            retryButton.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 14),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        rebuildArtwork()
        updateCaption()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimations()
        } else if isActive && !isHidden {
            startAnimations()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildArtwork()
        if isActive && !isHidden { startAnimations() }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active && !isHidden && window != nil {
            startAnimations()
        } else {
            stopAnimations()
        }
    }

    @objc private func retryClicked() {
        onRetry?()
    }

    private func updateCaption() {
        if isIdlePreview {
            captionLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "等待播放音乐…" : "Waiting for music…"
            retryButton.isHidden = true
        } else {
            captionLabel.stringValue = style.playfulCaption()
            retryButton.isHidden = false
        }
    }

    private func stopAnimations() {
        animatedLayers.forEach { $0.removeAllAnimations() }
    }

    private func rebuildArtwork() {
        stopAnimations()
        animatedLayers.removeAll()
        stageView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let root = stageView.layer else { return }

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = AppearanceSurfaceColors.accent.cgColor
            let ink = NSColor.labelColor.withAlphaComponent(0.75).cgColor
            let subtle = NSColor.labelColor.withAlphaComponent(0.18).cgColor

            switch style {
            case .vinylSeek:
                let disc = CALayer()
                disc.bounds = CGRect(x: 0, y: 0, width: 64, height: 64)
                disc.position = CGPoint(x: 56, y: 42)
                disc.cornerRadius = 32
                disc.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1).cgColor
                disc.borderWidth = 1
                disc.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
                for r: CGFloat in [27, 22, 17] {
                    let g = CAShapeLayer()
                    g.path = CGPath(ellipseIn: CGRect(x: 32 - r, y: 32 - r, width: r * 2, height: r * 2), transform: nil)
                    g.fillColor = nil
                    g.strokeColor = NSColor.white.withAlphaComponent(0.10).cgColor
                    g.lineWidth = 0.6
                    disc.addSublayer(g)
                }
                let centerLabel = CAShapeLayer()
                centerLabel.path = CGPath(ellipseIn: CGRect(x: 22, y: 22, width: 20, height: 20), transform: nil)
                centerLabel.fillColor = accent
                disc.addSublayer(centerLabel)
                let hole = CAShapeLayer()
                hole.path = CGPath(ellipseIn: CGRect(x: 29.5, y: 29.5, width: 5, height: 5), transform: nil)
                hole.fillColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1).cgColor
                disc.addSublayer(hole)
                root.addSublayer(disc)
                animatedLayers.append(disc)

                let arm = CALayer()
                arm.bounds = CGRect(x: 0, y: 0, width: 24, height: 42)
                arm.anchorPoint = CGPoint(x: 0.8, y: 0.9)
                arm.position = CGPoint(x: 100, y: 66)
                let armLine = CAShapeLayer()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 19, y: 38))
                p.addLine(to: CGPoint(x: 16, y: 14))
                p.addLine(to: CGPoint(x: 8, y: 6))
                armLine.path = p
                armLine.fillColor = nil
                armLine.strokeColor = ink
                armLine.lineWidth = 2
                armLine.lineCap = .round
                arm.addSublayer(armLine)
                let head = CAShapeLayer()
                head.path = CGPath(roundedRect: CGRect(x: 5, y: 3, width: 6, height: 6), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
                head.fillColor = accent
                arm.addSublayer(head)
                root.addSublayer(arm)
                animatedLayers.append(arm)

                let note = makeTextLayer("? ♪", size: 15, color: accent)
                note.position = CGPoint(x: 112, y: 78)
                root.addSublayer(note)
                animatedLayers.append(note)

            case .cassetteB:
                let body = CAShapeLayer()
                body.path = CGPath(roundedRect: CGRect(x: 24, y: 24, width: 92, height: 56), cornerWidth: 8, cornerHeight: 8, transform: nil)
                body.fillColor = AppearanceSurfaceColors.card.cgColor
                body.strokeColor = ink
                body.lineWidth = 1.25
                root.addSublayer(body)

                let windowBand = CAShapeLayer()
                windowBand.path = CGPath(roundedRect: CGRect(x: 34, y: 42, width: 72, height: 22), cornerWidth: 4, cornerHeight: 4, transform: nil)
                windowBand.fillColor = subtle
                root.addSublayer(windowBand)

                for cx: CGFloat in [52, 88] {
                    let reel = CAShapeLayer()
                    reel.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
                    reel.position = CGPoint(x: cx, y: 53)
                    let rp = CGMutablePath()
                    rp.addEllipse(in: CGRect(x: 1, y: 1, width: 14, height: 14))
                    rp.move(to: CGPoint(x: 8, y: 2)); rp.addLine(to: CGPoint(x: 8, y: 14))
                    rp.move(to: CGPoint(x: 2, y: 8)); rp.addLine(to: CGPoint(x: 14, y: 8))
                    reel.path = rp
                    reel.fillColor = nil
                    reel.strokeColor = accent
                    reel.lineWidth = 1.4
                    root.addSublayer(reel)
                    animatedLayers.append(reel)
                }

                let ribbon = CAShapeLayer()
                let wp = CGMutablePath()
                wp.move(to: CGPoint(x: 42, y: 24))
                wp.addCurve(to: CGPoint(x: 98, y: 24), control1: CGPoint(x: 56, y: 4), control2: CGPoint(x: 82, y: 34))
                ribbon.path = wp
                ribbon.fillColor = nil
                ribbon.strokeColor = accent
                ribbon.lineWidth = 1.6
                ribbon.lineCap = .round
                ribbon.bounds = CGRect(x: 0, y: 0, width: 140, height: 40)
                ribbon.position = CGPoint(x: 70, y: 20)
                root.addSublayer(ribbon)
                animatedLayers.append(ribbon)

            case .runawayNotes:
                let n1 = makeTextLayer("♪", size: 24, color: accent)
                n1.position = CGPoint(x: 52, y: 46)
                root.addSublayer(n1)
                animatedLayers.append(n1)

                let n2 = makeTextLayer("♫", size: 22, color: accent)
                n2.position = CGPoint(x: 82, y: 50)
                root.addSublayer(n2)
                animatedLayers.append(n2)

                let glass = makeTextLayer("⌕", size: 26, color: ink)
                glass.position = CGPoint(x: 108, y: 44)
                root.addSublayer(glass)
                animatedLayers.append(glass)

            case .radarPulse:
                // Static outer guide rings
                for r: CGFloat in [18, 30, 42] {
                    let ring = CAShapeLayer()
                    ring.path = CGPath(ellipseIn: CGRect(x: 70 - r, y: 48 - r, width: r * 2, height: r * 2), transform: nil)
                    ring.fillColor = nil
                    ring.strokeColor = subtle
                    ring.lineWidth = 0.8
                    root.addSublayer(ring)
                }
                // 2 expanding radar pulse rings
                for _ in 0..<2 {
                    let pulseRing = CAShapeLayer()
                    pulseRing.bounds = CGRect(x: 0, y: 0, width: 84, height: 84)
                    pulseRing.position = CGPoint(x: 70, y: 48)
                    pulseRing.path = CGPath(ellipseIn: pulseRing.bounds, transform: nil)
                    pulseRing.fillColor = nil
                    pulseRing.strokeColor = accent
                    pulseRing.lineWidth = 1.4
                    root.addSublayer(pulseRing)
                    animatedLayers.append(pulseRing)
                }
                // Rotating sweep hand
                let sweep = CAShapeLayer()
                sweep.bounds = CGRect(x: 0, y: 0, width: 84, height: 84)
                sweep.position = CGPoint(x: 70, y: 48)
                let sp = CGMutablePath()
                sp.move(to: CGPoint(x: 42, y: 42))
                sp.addLine(to: CGPoint(x: 42, y: 82))
                sweep.path = sp
                sweep.strokeColor = accent
                sweep.lineWidth = 1.8
                sweep.lineCap = .round
                root.addSublayer(sweep)
                animatedLayers.append(sweep)

                let dot = CAShapeLayer()
                dot.path = CGPath(ellipseIn: CGRect(x: 67, y: 45, width: 6, height: 6), transform: nil)
                dot.fillColor = accent
                root.addSublayer(dot)

            case .floatingCloud:
                // Minimalist cloud vector
                let cloud = CAShapeLayer()
                cloud.bounds = CGRect(x: 0, y: 0, width: 76, height: 40)
                cloud.position = CGPoint(x: 70, y: 44)
                let cp = CGMutablePath()
                cp.addRoundedRect(in: CGRect(x: 10, y: 6, width: 56, height: 18), cornerWidth: 9, cornerHeight: 9)
                cp.addEllipse(in: CGRect(x: 18, y: 12, width: 24, height: 22))
                cp.addEllipse(in: CGRect(x: 36, y: 15, width: 22, height: 20))
                cloud.path = cp
                cloud.fillColor = AppearanceSurfaceColors.card.cgColor
                cloud.strokeColor = ink
                cloud.lineWidth = 1.2
                root.addSublayer(cloud)
                animatedLayers.append(cloud)

                let star1 = makeTextLayer("✦", size: 12, color: accent)
                star1.position = CGPoint(x: 34, y: 68)
                root.addSublayer(star1)
                animatedLayers.append(star1)

                let star2 = makeTextLayer("✦", size: 10, color: ink)
                star2.position = CGPoint(x: 106, y: 62)
                root.addSublayer(star2)
                animatedLayers.append(star2)

                let note = makeTextLayer("♪", size: 16, color: accent)
                note.position = CGPoint(x: 96, y: 74)
                root.addSublayer(note)
                animatedLayers.append(note)

            case .equalizerBounce:
                for i in 0..<5 {
                    let bar = CALayer()
                    bar.anchorPoint = CGPoint(x: 0.5, y: 0)
                    bar.bounds = CGRect(x: 0, y: 0, width: 7, height: 18)
                    bar.position = CGPoint(x: 42 + CGFloat(i) * 14, y: 24)
                    bar.cornerRadius = 3.5
                    bar.backgroundColor = (i == 2 || i == 1 || i == 3) ? accent : ink
                    root.addSublayer(bar)
                    animatedLayers.append(bar)
                }
            }
        }
    }

    private func makeTextLayer(_ text: String, size: CGFloat, color: CGColor) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        layer.fontSize = size
        layer.foregroundColor = color
        layer.alignmentMode = .center
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.bounds = CGRect(x: 0, y: 0, width: 42, height: 32)
        return layer
    }

    private func startAnimations() {
        stopAnimations()
        guard !animatedLayers.isEmpty else { return }

        switch style {
        case .vinylSeek:
            if animatedLayers.indices.contains(0) {
                let wobble = CABasicAnimation(keyPath: "transform.rotation.z")
                wobble.fromValue = -0.10
                wobble.toValue = 0.10
                wobble.duration = 1.4
                wobble.autoreverses = true
                wobble.repeatCount = .infinity
                wobble.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[0].add(wobble, forKey: "wobble")
            }
            if animatedLayers.indices.contains(1) {
                let seek = CABasicAnimation(keyPath: "transform.rotation.z")
                seek.fromValue = -0.05
                seek.toValue = 0.22
                seek.duration = 1.8
                seek.autoreverses = true
                seek.repeatCount = .infinity
                seek.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[1].add(seek, forKey: "seek")
            }
            if animatedLayers.indices.contains(2) {
                let floatAnim = CABasicAnimation(keyPath: "position.y")
                floatAnim.fromValue = 74
                floatAnim.toValue = 84
                floatAnim.duration = 1.2
                floatAnim.autoreverses = true
                floatAnim.repeatCount = .infinity
                floatAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(floatAnim, forKey: "float")
            }

        case .cassetteB:
            for i in 0..<min(2, animatedLayers.count) {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = CGFloat.pi * 2
                spin.duration = 2.6
                spin.repeatCount = .infinity
                animatedLayers[i].add(spin, forKey: "reelSpin")
            }
            if animatedLayers.indices.contains(2) {
                let sway = CABasicAnimation(keyPath: "position.y")
                sway.fromValue = 18
                sway.toValue = 23
                sway.duration = 1.1
                sway.autoreverses = true
                sway.repeatCount = .infinity
                sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(sway, forKey: "sway")
            }

        case .runawayNotes:
            for (idx, layer) in animatedLayers.prefix(2).enumerated() {
                let hop = CAKeyframeAnimation(keyPath: "position.y")
                hop.values = [44, 58, 44]
                hop.duration = 0.72 + Double(idx) * 0.14
                hop.repeatCount = .infinity
                hop.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(hop, forKey: "hop")

                let drift = CABasicAnimation(keyPath: "position.x")
                drift.fromValue = (idx == 0 ? 44 : 74)
                drift.toValue = (idx == 0 ? 60 : 90)
                drift.duration = 1.4
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(drift, forKey: "drift")
            }
            if animatedLayers.indices.contains(2) {
                let chase = CABasicAnimation(keyPath: "transform.rotation.z")
                chase.fromValue = -0.18
                chase.toValue = 0.18
                chase.duration = 0.9
                chase.autoreverses = true
                chase.repeatCount = .infinity
                chase.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(chase, forKey: "chase")
            }

        case .radarPulse:
            for i in 0..<min(2, animatedLayers.count) {
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.25
                scale.toValue = 1.05
                scale.duration = 2.2
                scale.timeOffset = Double(i) * 1.1
                scale.repeatCount = .infinity
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animatedLayers[i].add(scale, forKey: "radarScale")

                let opacity = CABasicAnimation(keyPath: "opacity")
                opacity.fromValue = 0.85
                opacity.toValue = 0.0
                opacity.duration = 2.2
                opacity.timeOffset = Double(i) * 1.1
                opacity.repeatCount = .infinity
                animatedLayers[i].add(opacity, forKey: "radarOpacity")
            }
            if animatedLayers.indices.contains(2) {
                let rot = CABasicAnimation(keyPath: "transform.rotation.z")
                rot.fromValue = 0
                rot.toValue = -CGFloat.pi * 2
                rot.duration = 3.2
                rot.repeatCount = .infinity
                animatedLayers[2].add(rot, forKey: "radarSweep")
            }

        case .floatingCloud:
            if animatedLayers.indices.contains(0) {
                let bob = CABasicAnimation(keyPath: "position.y")
                bob.fromValue = 40
                bob.toValue = 50
                bob.duration = 2.2
                bob.autoreverses = true
                bob.repeatCount = .infinity
                bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[0].add(bob, forKey: "cloudBob")
            }
            for i in 1..<min(3, animatedLayers.count) {
                let twinkle = CABasicAnimation(keyPath: "opacity")
                twinkle.fromValue = 0.25
                twinkle.toValue = 1.0
                twinkle.duration = 1.1 + Double(i) * 0.35
                twinkle.autoreverses = true
                twinkle.repeatCount = .infinity
                animatedLayers[i].add(twinkle, forKey: "starTwinkle")
            }
            if animatedLayers.indices.contains(3) {
                let drift = CABasicAnimation(keyPath: "position.y")
                drift.fromValue = 68
                drift.toValue = 82
                drift.duration = 1.8
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[3].add(drift, forKey: "noteDrift")
            }

        case .equalizerBounce:
            let peaks: [CGFloat] = [32, 46, 54, 42, 28]
            let durations: [CFTimeInterval] = [0.58, 0.46, 0.64, 0.52, 0.60]
            for (idx, bar) in animatedLayers.prefix(5).enumerated() {
                let bounce = CABasicAnimation(keyPath: "bounds.size.height")
                bounce.fromValue = 10
                bounce.toValue = peaks[idx]
                bounce.duration = durations[idx]
                bounce.autoreverses = true
                bounce.repeatCount = .infinity
                bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.add(bounce, forKey: "eqBounce")
            }
        }
    }
}

@MainActor
final class SweepLyricLineView: NSView {
    let primaryText: String
    let translationText: String?
    let lineTime: TimeInterval
    var onSeek: ((TimeInterval) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    var isActive: Bool = false { didSet { if isActive != oldValue { invalidateIntrinsicContentSize(); needsDisplay = true } } }
    var distanceFromActive: Int = 99 { didSet { if distanceFromActive != oldValue { needsDisplay = true } } }
    var sweepProgress: CGFloat = 0 { didSet { if abs(sweepProgress - oldValue) > 0.004 { needsDisplay = true } } }
    var customSweepColor: NSColor? { didSet { needsDisplay = true } }
    var customNormalColor: NSColor? { didSet { needsDisplay = true } }

    private var tracking: NSTrackingArea?
    var isHovered = false {
        didSet {
            if isHovered != oldValue {
                if !isHovered { isPressed = false }
                needsDisplay = true
            }
        }
    }
    private var isPressed = false { didSet { if isPressed != oldValue { needsDisplay = true } } }

    override var isFlipped: Bool { true }

    init(primaryText: String, translationText: String?, lineTime: TimeInterval) {
        self.primaryText = primaryText
        self.translationText = translationText
        self.lineTime = lineTime
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onHoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { onHoverChanged?(false) }

    override func mouseDown(with event: NSEvent) {
        if onSeek != nil {
            wantsLayer = true
            InteractionMotion.rebound(layer, from: 0.94)
            InteractionSoundEngine.shared.play(.step)
        }
        isPressed = true
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        onSeek?(lineTime)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            self?.isPressed = false
        }
    }

    override var intrinsicContentSize: NSSize {
        let width = max(220, (bounds.width > 0 ? bounds.width : 420) - 84)
        let font = currentFont()
        let primaryHeight = measuredHeight(primaryText, font: font, width: width)
        let transHeight = translationText.map { measuredHeight($0, font: .systemFont(ofSize: isActive ? 13 : 11.5, weight: .regular), width: width) + 4 } ?? 0
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(primaryHeight + transHeight + 14))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(newSize.width - frame.width) > 1
        super.setFrameSize(newSize)
        if widthChanged { invalidateIntrinsicContentSize() }
    }

    private func currentFont() -> NSFont {
        // Calm typography hierarchy (no abrupt whole-block font zoom on line switch)
        if isActive { return .systemFont(ofSize: 18, weight: .bold) }
        if distanceFromActive == 1 { return .systemFont(ofSize: 16, weight: .medium) }
        return .systemFont(ofSize: 15.5, weight: .regular)
    }

    private func measuredHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style]
        )
        return rect.height
    }

    private func formattedTimestamp() -> String {
        let total = max(0, Int(lineTime.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Computes exact per-visual-line clip widths so wrapped multi-line lyrics sweep sequentially
    /// (line 1 from 0→100% first, then line 2 from 0→100%, etc.).
    static func sequentialSweepLineSlices(
        text: String,
        font: NSFont,
        paragraphStyle: NSParagraphStyle,
        in rect: NSRect,
        progress: CGFloat
    ) -> [(lineRect: NSRect, clipWidth: CGFloat)] {
        let storage = NSTextStorage(string: text, attributes: [.font: font, .paragraphStyle: paragraphStyle])
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: max(20, rect.width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let glyphRange = layoutManager.glyphRange(for: container)
        var lineRects: [NSRect] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            let r = NSRect(
                x: rect.minX + usedRect.minX,
                y: rect.minY + usedRect.minY,
                width: usedRect.width,
                height: usedRect.height
            )
            if r.width > 0 && r.height > 0 {
                lineRects.append(r)
            }
        }
        guard !lineRects.isEmpty else { return [] }
        let totalWidth = lineRects.reduce(CGFloat(0)) { $0 + $1.width }
        var remaining = totalWidth * min(1, max(0, progress))
        return lineRects.map { lineRect in
            if remaining <= 0 {
                return (lineRect, 0)
            }
            let w = min(lineRect.width, remaining)
            remaining -= w
            return (lineRect, w)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            // Soft hover / press rounded pill backdrop
            if isHovered || isPressed {
                let bgAlpha: CGFloat = isPressed ? 0.13 : 0.065
                let baseTint = customNormalColor ?? NSColor.labelColor
                baseTint.withAlphaComponent(bgAlpha).setFill()
                NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 10, yRadius: 10).fill()
            }

            let font = currentFont()
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byWordWrapping

            let horizontalPad: CGFloat = 42
            let textAreaWidth = max(140, bounds.width - horizontalPad * 2)
            let baseNormal = customNormalColor ?? NSColor.labelColor
            let primaryH = measuredHeight(primaryText, font: font, width: textAreaWidth)
            let primaryRect = NSRect(x: horizontalPad, y: 6, width: textAreaWidth, height: ceil(primaryH + 2))

            if isActive {
                let sweepColor = customSweepColor ?? AppearanceSurfaceColors.accent
                let unsweptColor = baseNormal.withAlphaComponent(isHovered ? 0.48 : 0.32)

                let baseStorage = NSTextStorage(
                    string: primaryText,
                    attributes: [.font: font, .foregroundColor: unsweptColor, .paragraphStyle: style]
                )
                let layoutManager = NSLayoutManager()
                let container = NSTextContainer(size: NSSize(width: textAreaWidth, height: .greatestFiniteMagnitude))
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                baseStorage.addLayoutManager(layoutManager)
                layoutManager.ensureLayout(for: container)
                let glyphRange = layoutManager.glyphRange(for: container)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: primaryRect.origin)

                let slices = Self.sequentialSweepLineSlices(
                    text: primaryText,
                    font: font,
                    paragraphStyle: style,
                    in: primaryRect,
                    progress: sweepProgress
                )
                let clipPath = CGMutablePath()
                var hasClip = false
                for slice in slices where slice.clipWidth > 0.25 {
                    let isFull = slice.clipWidth >= slice.lineRect.width - 0.5
                    let padRight: CGFloat = isFull ? 4 : 0
                    let r = CGRect(
                        x: slice.lineRect.minX - 2,
                        y: slice.lineRect.minY - 3,
                        width: slice.clipWidth + 2 + padRight,
                        height: slice.lineRect.height + 6
                    )
                    clipPath.addRect(r)
                    hasClip = true
                }

                if hasClip, let cgCtx = NSGraphicsContext.current?.cgContext {
                    NSGraphicsContext.saveGraphicsState()
                    cgCtx.addPath(clipPath)
                    cgCtx.clip()
                    let glow = NSShadow()
                    glow.shadowColor = sweepColor.withAlphaComponent(0.42)
                    glow.shadowBlurRadius = 8
                    glow.shadowOffset = .zero
                    baseStorage.setAttributes(
                        [.font: font, .foregroundColor: sweepColor, .paragraphStyle: style, .shadow: glow],
                        range: NSRange(location: 0, length: baseStorage.length)
                    )
                    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: primaryRect.origin)
                    NSGraphicsContext.restoreGraphicsState()
                }
            } else {
                let alpha: CGFloat = isHovered ? 0.92 : (distanceFromActive == 1 ? 0.62 : 0.34)
                let color = customNormalColor?.withAlphaComponent(alpha)
                    ?? (isHovered ? NSColor.labelColor : (distanceFromActive == 1 ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor))
                (primaryText as NSString).draw(
                    with: primaryRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
                )
            }

            if let translationText {
                let transFont = NSFont.systemFont(ofSize: isActive ? 13 : 11.5, weight: .regular)
                let transColor = (customNormalColor ?? NSColor.secondaryLabelColor).withAlphaComponent(isActive || isHovered ? 0.80 : 0.40)
                let transRect = NSRect(x: horizontalPad, y: primaryRect.maxY + 2, width: textAreaWidth, height: bounds.height - primaryRect.maxY - 4)
                (translationText as NSString).draw(
                    with: transRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: transFont, .foregroundColor: transColor, .paragraphStyle: style]
                )
            }

            // Hover timestamp badge on right side (Soda Music style)
            if isHovered {
                let ts = formattedTimestamp()
                let tsStyle = NSMutableParagraphStyle()
                tsStyle.alignment = .right
                let tsColor = (customSweepColor ?? AppearanceSurfaceColors.accent).withAlphaComponent(0.88)
                (ts as NSString).draw(
                    in: NSRect(x: bounds.width - 44, y: (bounds.height - 13) / 2, width: 36, height: 13),
                    withAttributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                        .foregroundColor: tsColor,
                        .paragraphStyle: tsStyle
                    ]
                )
            }
        }
    }
}

enum ImmersiveLyricsThemePreset: String, CaseIterable, Equatable, Sendable {
    case followTheme = "Follow Theme"
    case warmAmber = "Warm Amber Vinyl"
    case midnightAurora = "Midnight Aurora"
    case pineGlow = "Pine Glow"
    case warmPaper = "Warm Paper"
    case sakuraMist = "Sakura Mist"

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.followTheme, .simplifiedChinese): return "跟随主题"
        case (.warmAmber, .simplifiedChinese): return "暖琥珀黑胶"
        case (.midnightAurora, .simplifiedChinese): return "午夜极光"
        case (.pineGlow, .simplifiedChinese): return "松林微光"
        case (.warmPaper, .simplifiedChinese): return "暖纸墨黑"
        case (.sakuraMist, .simplifiedChinese): return "樱花粉雾"
        default: return rawValue
        }
    }

    var backgroundColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.086, alpha: 1)
        case .midnightAurora: return NSColor(calibratedRed: 0.059, green: 0.090, blue: 0.165, alpha: 1)
        case .pineGlow: return NSColor(calibratedRed: 0.059, green: 0.122, blue: 0.102, alpha: 1)
        case .warmPaper: return NSColor(calibratedRed: 0.973, green: 0.965, blue: 0.941, alpha: 1)
        case .sakuraMist: return NSColor(calibratedRed: 1.0, green: 0.961, blue: 0.969, alpha: 1)
        }
    }

    var sweepColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1)
        case .midnightAurora: return NSColor(calibratedRed: 0.220, green: 0.741, blue: 0.973, alpha: 1)
        case .pineGlow: return NSColor(calibratedRed: 0.204, green: 0.827, blue: 0.600, alpha: 1)
        case .warmPaper: return NSColor(calibratedRed: 0.851, green: 0.420, blue: 0.153, alpha: 1)
        case .sakuraMist: return NSColor(calibratedRed: 0.882, green: 0.114, blue: 0.282, alpha: 1)
        }
    }

    var normalTextColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.85, alpha: 1)
        case .midnightAurora: return NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.92, alpha: 1)
        case .pineGlow: return NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.79, alpha: 1)
        case .warmPaper: return NSColor(calibratedRed: 0.20, green: 0.19, blue: 0.17, alpha: 1)
        case .sakuraMist: return NSColor(calibratedRed: 0.36, green: 0.29, blue: 0.32, alpha: 1)
        }
    }
}

@MainActor
private final class ThemeSwatchDotButton: NSButton {
    let preset: ImmersiveLyricsThemePreset
    var isSelectedPreset: Bool = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(preset: ImmersiveLyricsThemePreset, target: AnyObject?, action: Selector?) {
        self.preset = preset
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.target = target
        self.action = action
        self.wantsLayer = true
        self.toolTip = preset.displayName()
        self.setAccessibilityLabel(preset.displayName())
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 18),
            heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let outerRect = bounds.insetBy(dx: 1.0, dy: 1.0)
            let inset: CGFloat = isHovered ? 2.6 : 3.2
            let dotRect = bounds.insetBy(dx: inset, dy: inset)

            if preset == .followTheme {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(ovalIn: dotRect).addClip()
                NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
                NSRect(x: dotRect.minX, y: dotRect.minY, width: dotRect.width / 2, height: dotRect.height).fill()
                NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
                NSRect(x: dotRect.midX, y: dotRect.minY, width: dotRect.width / 2, height: dotRect.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            } else {
                (preset.backgroundColor ?? .black).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                if let accent = preset.sweepColor {
                    accent.setFill()
                    NSBezierPath(ovalIn: dotRect.insetBy(dx: 3.0, dy: 3.0)).fill()
                }
            }

            NSColor.labelColor.withAlphaComponent(0.22).setStroke()
            let innerRim = NSBezierPath(ovalIn: dotRect)
            innerRim.lineWidth = 0.6
            innerRim.stroke()

            if isSelectedPreset {
                (preset.sweepColor ?? AppearanceSurfaceColors.accent).setStroke()
                let ring = NSBezierPath(ovalIn: outerRect)
                ring.lineWidth = 1.6
                ring.stroke()
            } else if isHovered {
                NSColor.labelColor.withAlphaComponent(0.50).setStroke()
                let ring = NSBezierPath(ovalIn: outerRect)
                ring.lineWidth = 1.0
                ring.stroke()
            }
        }
    }
}

@MainActor
private final class TransportButton: NSButton {
    let isCapsulePrimary: Bool
    private var tracking: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    init(symbol: String, size: CGFloat, isCapsulePrimary: Bool, target: AnyObject?, action: Selector?) {
        self.isCapsulePrimary = isCapsulePrimary
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.isEnabled = true
        self.target = target
        self.action = action
        self.wantsLayer = true
        self.layer?.cornerRadius = isCapsulePrimary ? 17 : 14
        self.layer?.cornerCurve = .continuous
        self.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        self.translatesAutoresizingMaskIntoConstraints = false
        refreshStyle()
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshStyle()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        refreshStyle()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        refreshStyle()
        super.mouseDown(with: event)
        isPressed = false
        refreshStyle()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshStyle()
    }

    func refreshStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isCapsulePrimary {
                contentTintColor = .white
                let base = AppearanceSurfaceColors.accent
                layer?.borderWidth = 0.5
                layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
                if isPressed {
                    layer?.backgroundColor = base.blended(withFraction: 0.25, of: .black)?.cgColor ?? base.cgColor
                    alphaValue = 0.84
                } else if isHovered {
                    layer?.backgroundColor = base.blended(withFraction: 0.14, of: .white)?.cgColor ?? base.cgColor
                    alphaValue = 1.0
                } else {
                    layer?.backgroundColor = base.withAlphaComponent(0.94).cgColor
                    alphaValue = 1.0
                }
            } else {
                contentTintColor = isHovered ? .labelColor : .secondaryLabelColor
                if isPressed {
                    layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.18).cgColor
                    alphaValue = 0.72
                } else if isHovered {
                    layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
                    alphaValue = 1.0
                } else {
                    layer?.backgroundColor = NSColor.clear.cgColor
                    alphaValue = 1.0
                }
            }
        }
    }
}

struct ImmersiveSeekFeedback {
    let target: TimeInterval
    let issuedAt: TimeInterval

    func awaitsPlayer(position: TimeInterval, playing: Bool, now: TimeInterval) -> Bool {
        let elapsed = max(0, now - issuedAt)
        let expected = target + (playing ? elapsed : 0)
        // Allow poll latency, including at the end of a track where playback is clamped.
        return elapsed < 1.5 && abs(position - target) > 0.35 && abs(position - expected) > 0.35
    }
}

@MainActor
private final class InteractiveProgressBarView: NSView {
    private var playerPosition: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var pendingSeek: ImmersiveSeekFeedback?
    private var trackIdentity: String?
    private var canSeek = false
    var onDisplayPosition: ((TimeInterval) -> Void)?
    var onSeekFraction: ((CGFloat) -> Void)?
    private var scrubProgress: CGFloat?
    private var lastSeekTime: TimeInterval = 0
    private var lastSeekFraction: CGFloat = 0
    private var isHovered = false { didSet { if isHovered != oldValue { needsDisplay = true } } }
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        if canSeek { addCursorRect(bounds, cursor: .pointingHand) }
    }

    func update(position: TimeInterval, duration: TimeInterval, identity: String?, playing: Bool, canSeek: Bool) {
        if trackIdentity != identity || self.duration != duration || !canSeek {
            resetSeek()
        }
        if self.canSeek != canSeek {
            self.canSeek = canSeek
            window?.invalidateCursorRects(for: self)
        }
        trackIdentity = identity
        playerPosition = position
        self.duration = duration
        if let pendingSeek, !pendingSeek.awaitsPlayer(position: position, playing: playing, now: ProcessInfo.processInfo.systemUptime) {
            self.pendingSeek = nil
        }
        updateDisplayPosition()
    }

    func resetSeek() {
        scrubProgress = nil
        pendingSeek = nil
        updateDisplayPosition()
    }

    private var displayedPosition: TimeInterval {
        scrubProgress.map { Double($0) * duration } ?? pendingSeek?.target ?? playerPosition
    }

    private func updateDisplayPosition() {
        onDisplayPosition?(displayedPosition)
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard canSeek else { return }
        scrubProgress = nil
        updateScrub(with: event, sendSeek: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard scrubProgress != nil else { return }
        updateScrub(with: event, sendSeek: ProcessInfo.processInfo.systemUptime - lastSeekTime >= 0.1)
    }

    override func mouseUp(with event: NSEvent) {
        guard scrubProgress != nil else { return }
        updateScrub(with: event, sendSeek: true)
        scrubProgress = nil
        updateDisplayPosition()
    }

    private func updateScrub(with event: NSEvent, sendSeek: Bool) {
        let pt = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0 else { return }
        let fraction = min(1, max(0, (pt.x - bounds.minX) / bounds.width))
        let isFirstSeek = scrubProgress == nil
        scrubProgress = fraction
        // Spotify and Music seek via synchronous Apple Events. Bound the command rate during a drag.
        if sendSeek && (isFirstSeek || fraction != lastSeekFraction) {
            lastSeekTime = ProcessInfo.processInfo.systemUptime
            lastSeekFraction = fraction
            pendingSeek = ImmersiveSeekFeedback(target: Double(fraction) * duration, issuedAt: lastSeekTime)
            onSeekFraction?(fraction)
        }
        updateDisplayPosition()
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let barH: CGFloat = isHovered ? 5 : 2.5
            let barY = (bounds.height - barH) / 2
            let trackRect = NSRect(x: 0, y: barY, width: bounds.width, height: barH)
            NSColor.labelColor.withAlphaComponent(isHovered ? 0.14 : 0.09).setFill()
            NSBezierPath(roundedRect: trackRect, xRadius: barH / 2, yRadius: barH / 2).fill()

            let clamped = duration > 0 ? min(1, max(0, CGFloat(displayedPosition / duration))) : 0
            let fillW = bounds.width * clamped
            if fillW > 0 {
                let fillRect = NSRect(x: 0, y: barY, width: fillW, height: barH)
                AppearanceSurfaceColors.accent.setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: barH / 2, yRadius: barH / 2).fill()
            }

            if isHovered && canSeek {
                let thumbD: CGFloat = 10
                let thumbX = min(max(0, fillW - thumbD / 2), max(0, bounds.width - thumbD))
                let thumbRect = NSRect(x: thumbX, y: (bounds.height - thumbD) / 2, width: thumbD, height: thumbD)
                NSGraphicsContext.saveGraphicsState()
                let glow = NSShadow()
                glow.shadowColor = AppearanceSurfaceColors.accent.withAlphaComponent(0.65)
                glow.shadowBlurRadius = 6
                glow.shadowOffset = .zero
                glow.set()
                AppearanceSurfaceColors.accent.setFill()
                NSBezierPath(ovalIn: thumbRect).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}

@MainActor
private final class FadedScrollContainerView: NSView {
    private let maskLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        maskLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 0.12, 0.88, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer?.mask = maskLayer
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = bounds
        CATransaction.commit()
    }
}

@MainActor
final class ImmersiveLyricsView: NSView {
    var onTransportCommand: ((MediaTransportCommand) -> Void)?
    var onSeek: ((TimeInterval) -> Void)?
    var onRetryMatch: (() -> Void)?

    private let stageBackground = AppearanceSurfaceView()
    private let scrollFadeContainer = FadedScrollContainerView()
    private let scrollView = ImmersiveLyricsScrollView()
    private let documentView = FlippedImmersiveDocumentView()
    private let linesStack = NSStackView()
    private var lineViews: [SweepLyricLineView] = []
    private var currentLines: [LyricLine] = []
    private var currentAlbumName: String = ""
    private var currentArtworkImage: NSImage?
    private var activeIndex: Int = -1
    private(set) var hoveredLineIndex: Int?
    private var currentDuration: TimeInterval = 0
    private var userBrowsingUntil: TimeInterval = 0

    let missingView = MissingLyricsAnimationView()

    private let transportBar = AppearanceSurfaceView()
    private let progressBar = InteractiveProgressBarView()
    private let trackTitleLabel = NSTextField(labelWithString: "")
    private let trackArtistLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private lazy var prevButton = TransportButton(symbol: "backward.fill", size: 13, isCapsulePrimary: false, target: self, action: #selector(prevClicked(_:)))
    private lazy var playPauseButton = TransportButton(symbol: "play.fill", size: 15, isCapsulePrimary: true, target: self, action: #selector(playPauseClicked(_:)))
    private lazy var nextButton = TransportButton(symbol: "forward.fill", size: 13, isCapsulePrimary: false, target: self, action: #selector(nextClicked(_:)))
    private lazy var shareButton = TransportButton(symbol: "square.and.arrow.up", size: 12.5, isCapsulePrimary: false, target: self, action: #selector(shareCardClicked))
    private var sharePopover: NSPopover?
    private var swatchButtons: [ThemeSwatchDotButton] = []
    private var isPlayingState = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
        applyCustomColors()
    }

    required init?(coder: NSCoder) { nil }

    var animationStyle: MissingLyricsAnimationStyle {
        get { missingView.style }
        set { missingView.style = newValue }
    }

    func setStageVisible(_ visible: Bool) {
        isHidden = !visible
        missingView.setActive(visible && !missingView.isHidden)
        if !visible {
            progressBar.resetSeek()
            setHoveredLine(nil)
            sharePopover?.close()
            sharePopover = nil
        } else if activeIndex >= 0 {
            scrollActiveLineToCenterIfAllowed(animated: false)
        }
    }

    func applyCustomColors() {
        let preset = AppPreferences.immersiveThemePreset
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if let customBg = preset.backgroundColor {
                stageBackground.surfaceColor = customBg
                stageBackground.layer?.cornerRadius = 12
                stageBackground.layer?.borderWidth = 0.5
                stageBackground.surfaceBorderColor = AppearanceSurfaceColors.border
            } else {
                stageBackground.surfaceColor = .clear
                stageBackground.layer?.borderWidth = 0
                stageBackground.surfaceBorderColor = .clear
            }
            for btn in swatchButtons {
                btn.isSelectedPreset = (btn.preset == preset)
            }
            let sweep = preset.sweepColor
            let normal = preset.normalTextColor
            for view in lineViews {
                view.customSweepColor = sweep
                view.customNormalColor = normal
            }
        }
    }

    private func setupLayout() {
        let isZh = AppPreferences.language == .simplifiedChinese

        stageBackground.wantsLayer = true
        stageBackground.layer?.cornerCurve = .continuous
        stageBackground.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = SlimOverlayScroller()
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.onUserScroll = { [weak self] in
            self?.userBrowsingUntil = ProcessInfo.processInfo.systemUptime + 4.0
            self?.revalidateHoverFromPointer()
        }
        scrollView.onMouseExited = { [weak self] in
            self?.setHoveredLine(nil)
        }

        linesStack.orientation = .vertical
        linesStack.alignment = .centerX
        linesStack.spacing = 14
        linesStack.edgeInsets = NSEdgeInsets(top: 180, left: 16, bottom: 180, right: 16)
        linesStack.translatesAutoresizingMaskIntoConstraints = false

        documentView.addSubview(linesStack)
        scrollView.documentView = documentView
        scrollFadeContainer.addSubview(scrollView)

        missingView.isIdlePreview = true
        missingView.isHidden = false
        missingView.onRetry = { [weak self] in self?.onRetryMatch?() }

        transportBar.wantsLayer = true
        transportBar.surfaceColor = AppearanceSurfaceColors.card
        transportBar.surfaceBorderColor = AppearanceSurfaceColors.border
        transportBar.layer?.cornerRadius = 12
        transportBar.layer?.cornerCurve = .continuous
        transportBar.layer?.borderWidth = 0.5
        transportBar.translatesAutoresizingMaskIntoConstraints = false

        progressBar.onSeekFraction = { [weak self] frac in
            guard let self, self.currentDuration > 0 else { return }
            self.onSeek?(self.currentDuration * Double(frac))
        }

        progressBar.onDisplayPosition = { [weak self] position in
            guard let self else { return }
            self.timeLabel.stringValue = "\(self.formatClock(position)) / \(self.formatClock(self.currentDuration))"
        }

        trackTitleLabel.stringValue = isZh ? "未在播放" : "Not Playing"
        trackTitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        trackTitleLabel.textColor = .labelColor
        trackTitleLabel.lineBreakMode = .byTruncatingTail
        trackTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        trackArtistLabel.stringValue = "NotchMuse"
        trackArtistLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        trackArtistLabel.textColor = .secondaryLabelColor
        trackArtistLabel.lineBreakMode = .byTruncatingTail
        trackArtistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trackArtistLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let metaBottomRow = NSStackView(views: [trackArtistLabel, timeLabel])
        metaBottomRow.orientation = .horizontal
        metaBottomRow.alignment = .centerY
        metaBottomRow.spacing = 6
        metaBottomRow.translatesAutoresizingMaskIntoConstraints = false

        swatchButtons = ImmersiveLyricsThemePreset.allCases.map { preset in
            ThemeSwatchDotButton(preset: preset, target: self, action: #selector(swatchClicked(_:)))
        }
        shareButton.toolTip = isZh ? "生成歌词分享卡" : "Create Lyric Share Card"
        shareButton.isEnabled = false
        shareButton.alphaValue = 0.45

        let swatchRow = NSStackView(views: swatchButtons)
        swatchRow.orientation = .horizontal
        swatchRow.alignment = .centerY
        swatchRow.spacing = 4
        swatchRow.translatesAutoresizingMaskIntoConstraints = false

        transportBar.addSubview(progressBar)
        transportBar.addSubview(trackTitleLabel)
        transportBar.addSubview(metaBottomRow)
        transportBar.addSubview(prevButton)
        transportBar.addSubview(playPauseButton)
        transportBar.addSubview(nextButton)
        transportBar.addSubview(swatchRow)
        transportBar.addSubview(shareButton)

        addSubview(stageBackground)
        addSubview(scrollFadeContainer)
        addSubview(missingView)
        addSubview(transportBar)

        NSLayoutConstraint.activate([
            stageBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stageBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stageBackground.topAnchor.constraint(equalTo: topAnchor),
            stageBackground.bottomAnchor.constraint(equalTo: transportBar.topAnchor, constant: -10),

            scrollFadeContainer.leadingAnchor.constraint(equalTo: stageBackground.leadingAnchor),
            scrollFadeContainer.trailingAnchor.constraint(equalTo: stageBackground.trailingAnchor),
            scrollFadeContainer.topAnchor.constraint(equalTo: stageBackground.topAnchor),
            scrollFadeContainer.bottomAnchor.constraint(equalTo: stageBackground.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: scrollFadeContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: scrollFadeContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: scrollFadeContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: scrollFadeContainer.bottomAnchor),

            linesStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            linesStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            linesStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            linesStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            missingView.leadingAnchor.constraint(equalTo: stageBackground.leadingAnchor),
            missingView.trailingAnchor.constraint(equalTo: stageBackground.trailingAnchor),
            missingView.topAnchor.constraint(equalTo: stageBackground.topAnchor),
            missingView.bottomAnchor.constraint(equalTo: stageBackground.bottomAnchor),

            transportBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            transportBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            transportBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            transportBar.heightAnchor.constraint(equalToConstant: 66),

            // Edge-to-edge interactive progress bar along very top of transport bar
            progressBar.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 10),
            progressBar.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -10),
            progressBar.topAnchor.constraint(equalTo: transportBar.topAnchor, constant: 1),
            progressBar.heightAnchor.constraint(equalToConstant: 16),

            trackTitleLabel.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 14),
            trackTitleLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 2),
            trackTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -10),

            metaBottomRow.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            metaBottomRow.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 2),
            metaBottomRow.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -10),

            // Soda Music iconic 56x34 rounded capsule Play/Pause button centered
            playPauseButton.centerXAnchor.constraint(equalTo: transportBar.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: transportBar.centerYAnchor, constant: 6),
            playPauseButton.widthAnchor.constraint(equalToConstant: 56),
            playPauseButton.heightAnchor.constraint(equalToConstant: 34),

            prevButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -10),
            prevButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 28),
            prevButton.heightAnchor.constraint(equalToConstant: 28),

            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 10),
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 28),
            nextButton.heightAnchor.constraint(equalToConstant: 28),

            shareButton.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -12),
            shareButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 26),
            shareButton.heightAnchor.constraint(equalToConstant: 26),

            swatchRow.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -8),
            swatchRow.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            swatchRow.leadingAnchor.constraint(greaterThanOrEqualTo: nextButton.trailingAnchor, constant: 10)
        ])
        refreshTransportAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshTransportAppearance()
        applyCustomColors()
    }

    override func layout() {
        super.layout()
        layoutDocumentWidth()
    }

    private func layoutDocumentWidth() {
        let visibleH = max(200, scrollView.contentView.bounds.height)
        let pad = max(80, ceil(visibleH / 2))
        if abs(linesStack.edgeInsets.top - pad) > 1 {
            linesStack.edgeInsets = NSEdgeInsets(top: pad, left: 16, bottom: pad, right: 16)
        }
        let width = max(200, scrollView.contentView.bounds.width)
        let height = max(visibleH, linesStack.fittingSize.height)
        if documentView.frame.size != NSSize(width: width, height: height) {
            documentView.setFrameSize(NSSize(width: width, height: height))
        }
    }

    private func refreshTransportAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            progressBar.needsDisplay = true
            prevButton.refreshStyle()
            playPauseButton.refreshStyle()
            nextButton.refreshStyle()
            shareButton.refreshStyle()
            if !shareButton.isEnabled { shareButton.alphaValue = 0.42 }
        }
    }

    func update(
        lines: [LyricLine],
        activeIndex: Int,
        lineProgress: CGFloat,
        trackTitle: String?,
        artistName: String?,
        albumName: String? = nil,
        artworkImage: NSImage? = nil,
        isPlaying: Bool,
        isPaused: Bool,
        position: TimeInterval,
        duration: TimeInterval,
        lyricsMissing: Bool,
        trackIdentity: String?
    ) {
        isPlayingState = isPlaying
        currentDuration = duration.isFinite ? max(0, duration) : 0
        currentAlbumName = albumName ?? ""
        currentArtworkImage = artworkImage
        playPauseButton.image = NSImage(systemSymbolName: isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))

        let hasTrack = (trackTitle?.isEmpty == false)
        if let title = trackTitle, !title.isEmpty {
            trackTitleLabel.stringValue = title
            trackArtistLabel.stringValue = (artistName?.isEmpty == false) ? artistName! : "NotchMuse"
        } else {
            trackTitleLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "未在播放" : "Not Playing"
            trackArtistLabel.stringValue = "NotchMuse"
        }

        let finitePosition = position.isFinite ? max(0, position) : 0
        let safePos = currentDuration > 0 ? min(finitePosition, currentDuration) : finitePosition
        progressBar.update(position: safePos, duration: currentDuration, identity: trackIdentity,
                           playing: isPlaying, canSeek: hasTrack && (isPlaying || isPaused) && currentDuration > 0 && onSeek != nil)

        if !hasTrack {
            shareButton.isEnabled = false
            shareButton.alphaValue = 0.42
            scrollFadeContainer.isHidden = true
            missingView.isIdlePreview = true
            missingView.isHidden = false
            missingView.setActive(!isHidden)
            return
        }

        if lines.isEmpty {
            shareButton.isEnabled = false
            shareButton.alphaValue = 0.42
            scrollFadeContainer.isHidden = true
            missingView.isIdlePreview = !lyricsMissing
            missingView.isHidden = false
            missingView.setActive(!isHidden)
            return
        }

        shareButton.isEnabled = true
        shareButton.alphaValue = 1.0

        missingView.isHidden = true
        missingView.setActive(false)
        scrollFadeContainer.isHidden = false

        if lines != currentLines {
            rebuildLines(lines)
        }
        let lineChanged = activeIndex != self.activeIndex
        if lineChanged {
            self.activeIndex = activeIndex
            highlightActiveLine(progress: lineProgress)
            scrollActiveLineToCenterIfAllowed(animated: true)
        } else if lineViews.indices.contains(activeIndex) {
            lineViews[activeIndex].sweepProgress = lineProgress
        }
    }

    private func setHoveredLine(_ index: Int?) {
        let validIndex = index.flatMap { lineViews.indices.contains($0) ? $0 : nil }
        hoveredLineIndex = validIndex
        for (i, view) in lineViews.enumerated() {
            let shouldHover = (validIndex == i)
            if view.isHovered != shouldHover {
                view.isHovered = shouldHover
            }
        }
    }

    private func revalidateHoverFromPointer() {
        guard let window, !isHidden, !scrollFadeContainer.isHidden else {
            setHoveredLine(nil)
            return
        }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let pointInScroll = scrollView.convert(mouseInWindow, from: nil)
        guard scrollView.bounds.contains(pointInScroll) else {
            setHoveredLine(nil)
            return
        }
        for (i, view) in lineViews.enumerated() {
            let pt = view.convert(mouseInWindow, from: nil)
            if view.bounds.contains(pt) {
                setHoveredLine(i)
                return
            }
        }
        setHoveredLine(nil)
    }

    private func rebuildLines(_ lines: [LyricLine]) {
        currentLines = lines
        activeIndex = -1
        setHoveredLine(nil)
        linesStack.arrangedSubviews.forEach {
            linesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        lineViews.removeAll()

        let preset = AppPreferences.immersiveThemePreset
        let sweep = preset.sweepColor
        let normal = preset.normalTextColor
        for (idx, line) in lines.enumerated() {
            let view = SweepLyricLineView(primaryText: line.text, translationText: line.translation, lineTime: line.time)
            view.customSweepColor = sweep
            view.customNormalColor = normal
            view.onSeek = { [weak self] seconds in
                self?.onSeek?(seconds)
            }
            view.onHoverChanged = { [weak self] entered in
                guard let self else { return }
                if entered {
                    self.setHoveredLine(idx)
                } else if self.hoveredLineIndex == idx {
                    self.setHoveredLine(nil)
                }
            }
            linesStack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: linesStack.widthAnchor, constant: -32).isActive = true
            lineViews.append(view)
        }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
    }

    private func highlightActiveLine(progress: CGFloat) {
        for (idx, view) in lineViews.enumerated() {
            let isCurrent = idx == activeIndex
            view.isActive = isCurrent
            view.distanceFromActive = abs(idx - activeIndex)
            view.sweepProgress = isCurrent ? progress : 0
        }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
    }

    func scrollActiveLineToCenterIfAllowed(animated: Bool) {
        guard ProcessInfo.processInfo.systemUptime >= userBrowsingUntil,
              lineViews.indices.contains(activeIndex) else { return }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
        documentView.layoutSubtreeIfNeeded()
        let target = lineViews[activeIndex]
        let centerInDoc = documentView.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), from: target)
        let visibleHeight = scrollView.contentView.bounds.height
        let maxY = max(0, documentView.bounds.height - visibleHeight)
        let clampedY = min(max(0, centerInDoc.y - visibleHeight * 0.5), maxY)
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: clampedY))
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.revalidateHoverFromPointer()
                }
            })
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: clampedY))
            revalidateHoverFromPointer()
        }
    }

    #if DEBUG
    var debugHoveredLineCount: Int { lineViews.filter(\.isHovered).count }

    func debugSimulateHover(at index: Int?) {
        setHoveredLine(index)
    }

    func debugLineCenterAndVisibleMidY(for index: Int) -> (lineMidY: CGFloat, visibleMidY: CGFloat)? {
        guard lineViews.indices.contains(index) else { return nil }
        activeIndex = index
        highlightActiveLine(progress: 0.5)
        userBrowsingUntil = 0
        scrollActiveLineToCenterIfAllowed(animated: false)
        let target = lineViews[index]
        let centerInDoc = documentView.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), from: target)
        let visibleMidY = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height * 0.5
        return (centerInDoc.y, visibleMidY)
    }
    #endif

    private func formatClock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    @objc private func prevClicked(_ sender: NSButton) { transport(.previous, from: sender) }
    @objc private func playPauseClicked(_ sender: NSButton) { transport(.playPause, from: sender) }
    @objc private func nextClicked(_ sender: NSButton) { transport(.next, from: sender) }

    private func transport(_ command: MediaTransportCommand, from button: NSButton) {
        InteractionMotion.rebound(button.layer, from: 0.94)
        InteractionSoundEngine.shared.play(.latch)
        onTransportCommand?(command)
    }

    @objc private func swatchClicked(_ sender: NSButton) {
        guard let dot = sender as? ThemeSwatchDotButton else { return }
        InteractionMotion.rebound(dot.layer, from: 0.94)
        InteractionSoundEngine.shared.play(.step)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        UserDefaults.standard.set(dot.preset.rawValue, forKey: AppPreferences.immersiveThemePresetKey)
        applyCustomColors()
    }

    @objc private func shareCardClicked() {
        guard !currentLines.isEmpty else { return }
        if let existing = sharePopover, existing.isShown {
            existing.close()
            sharePopover = nil
            return
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        let vc = LyricSharePopoverController(
            lines: currentLines,
            activeIndex: activeIndex,
            trackTitle: trackTitleLabel.stringValue,
            artistName: trackArtistLabel.stringValue,
            albumName: currentAlbumName,
            artworkImage: currentArtworkImage
        )
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = vc
        vc.popover = popover
        popover.contentSize = NSSize(width: 610, height: 456)
        popover.show(relativeTo: shareButton.bounds, of: shareButton, preferredEdge: .maxY)
        sharePopover = popover
    }
}

private final class ImmersiveLyricsScrollView: NSScrollView {
    var onUserScroll: (() -> Void)?
    var onMouseExited: (() -> Void)?
    private var hoverTracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }

    override func scrollWheel(with event: NSEvent) {
        onUserScroll?()
        super.scrollWheel(with: event)
    }
}

private final class FlippedImmersiveDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class SidebarResizeDividerView: NSView {
    var onDragDelta: ((CGFloat) -> Void)?
    var onDragEnd: ((CGFloat) -> Void)?

    private let hairline = AppearanceSurfaceView()
    private var dragStartX: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        hairline.wantsLayer = true
        hairline.surfaceColor = AppearanceSurfaceColors.border
        hairline.surfaceBorderColor = .clear
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)
        NSLayoutConstraint.activate([
            hairline.centerXAnchor.constraint(equalTo: centerXAnchor),
            hairline.topAnchor.constraint(equalTo: topAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            hairline.widthAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        onDragDelta?(event.locationInWindow.x - dragStartX)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?(event.locationInWindow.x - dragStartX)
    }
}
