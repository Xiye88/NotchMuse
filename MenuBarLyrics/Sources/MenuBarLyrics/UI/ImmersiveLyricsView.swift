import AppKit
import QuartzCore
import LyricsCore

enum MissingLyricsAnimationStyle: String, CaseIterable, Equatable, Sendable {
    case vinylSeek = "Vinyl Seek (Default)"
    case cassetteB = "Cassette Side B"
    case runawayNotes = "Runaway Notes"

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "黑胶寻轨（默认）"
        case (.cassetteB, .simplifiedChinese): return "复古磁带"
        case (.runawayNotes, .simplifiedChinese): return "小音符逃跑"
        default: return rawValue
        }
    }

    func playfulCaption(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "404 · 唱针没找到这首歌的词，正在黑胶纹路里打捞…"
        case (.cassetteB, .simplifiedChinese): return "404 · 歌词走失在磁带 B 面"
        case (.runawayNotes, .simplifiedChinese): return "歌词溜走了，这首大概是纯音乐？"
        case (.vinylSeek, _): return "404 · Tonearm couldn't find lyrics in the grooves…"
        case (.cassetteB, _): return "404 · Lyrics wandered off to Cassette Side B"
        case (.runawayNotes, _): return "Lyrics ran away — maybe an instrumental?"
        }
    }
}

enum MediaTransportCommand: Sendable {
    case previous
    case playPause
    case next
}

enum SystemMediaTransport {
    static func send(_ command: MediaTransportCommand, activeSource: PlayerSource?) {
        // Prefer direct AppleScript for Spotify & Apple Music so it works even without Accessibility tap
        if activeSource == .spotify {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Spotify\" to \(verb)") { return }
        } else if activeSource == .appleMusic {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Music\" to \(verb)") { return }
        }

        // Universal macOS system media key fallback (NX_KEYTYPE_PLAY=16, NEXT=17, PREVIOUS=18)
        let keyCode: Int
        switch command {
        case .playPause: keyCode = 16
        case .next: keyCode = 17
        case .previous: keyCode = 18
        }
        postMediaKey(keyCode)
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
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
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
        captionLabel.stringValue = style.playfulCaption()
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
                // Mini wobbling vinyl disc
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

                // Seeking tonearm
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

                // Floating "? ♪"
                let note = makeTextLayer("? ♪", size: 15, color: accent)
                note.position = CGPoint(x: 112, y: 78)
                root.addSublayer(note)
                animatedLayers.append(note)

            case .cassetteB:
                // Cassette body
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

                // Waving tape ribbon underneath
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
        }
    }
}

@MainActor
final class ImmersiveLyricsView: NSView {
    var onTransportCommand: ((MediaTransportCommand) -> Void)?
    var onRetryMatch: (() -> Void)?

    private let scrollView = ImmersiveLyricsScrollView()
    private let documentView = FlippedImmersiveDocumentView()
    private let linesStack = NSStackView()
    private var lineLabels: [NSTextField] = []
    private var currentLines: [LyricLine] = []
    private var activeIndex: Int = -1
    private var userBrowsingUntil: TimeInterval = 0

    private let missingView = MissingLyricsAnimationView()
    private let waitingLabel = NSTextField(labelWithString: "")

    private let transportBar = AppearanceSurfaceView()
    private let progressTrack = NSView()
    private let progressFill = NSView()
    private var progressFillWidth: NSLayoutConstraint?
    private let trackTitleLabel = NSTextField(labelWithString: "")
    private let trackArtistLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    private let prevButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    private var isPlayingState = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
    }

    required init?(coder: NSCoder) { nil }

    var animationStyle: MissingLyricsAnimationStyle {
        get { missingView.style }
        set { missingView.style = newValue }
    }

    func setStageVisible(_ visible: Bool) {
        isHidden = !visible
        missingView.setActive(visible && !missingView.isHidden)
    }

    private func setupLayout() {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.onUserScroll = { [weak self] in
            self?.userBrowsingUntil = ProcessInfo.processInfo.systemUptime + 4.0
        }

        linesStack.orientation = .vertical
        linesStack.alignment = .centerX
        linesStack.spacing = 16
        linesStack.edgeInsets = NSEdgeInsets(top: 120, left: 28, bottom: 140, right: 28)
        linesStack.translatesAutoresizingMaskIntoConstraints = false

        documentView.addSubview(linesStack)
        scrollView.documentView = documentView

        missingView.isHidden = true
        missingView.onRetry = { [weak self] in self?.onRetryMatch?() }

        waitingLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "等待播放音乐…" : "Waiting for music…"
        waitingLabel.font = .systemFont(ofSize: 15, weight: .medium)
        waitingLabel.textColor = .tertiaryLabelColor
        waitingLabel.alignment = .center
        waitingLabel.translatesAutoresizingMaskIntoConstraints = false

        // Bottom minimal transport bar
        transportBar.wantsLayer = true
        transportBar.surfaceColor = AppearanceSurfaceColors.card
        transportBar.surfaceBorderColor = AppearanceSurfaceColors.border
        transportBar.layer?.cornerRadius = 12
        transportBar.layer?.cornerCurve = .continuous
        transportBar.layer?.borderWidth = 0.5
        transportBar.translatesAutoresizingMaskIntoConstraints = false

        progressTrack.wantsLayer = true
        progressTrack.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        progressTrack.layer?.cornerRadius = 1.5
        progressTrack.translatesAutoresizingMaskIntoConstraints = false

        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
        progressFill.layer?.cornerRadius = 1.5
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        trackTitleLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "未在播放" : "Not Playing"
        trackTitleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        trackTitleLabel.textColor = .labelColor
        trackTitleLabel.lineBreakMode = .byTruncatingTail
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        trackArtistLabel.stringValue = "NotchMuse"
        trackArtistLabel.font = .systemFont(ofSize: 11, weight: .regular)
        trackArtistLabel.textColor = .secondaryLabelColor
        trackArtistLabel.lineBreakMode = .byTruncatingTail
        trackArtistLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        configureTransportButton(prevButton, symbol: "backward.fill", size: 13, action: #selector(prevClicked))
        configureTransportButton(playPauseButton, symbol: "play.fill", size: 15, action: #selector(playPauseClicked))
        configureTransportButton(nextButton, symbol: "forward.fill", size: 13, action: #selector(nextClicked))
        playPauseButton.wantsLayer = true
        playPauseButton.layer?.cornerRadius = 16
        playPauseButton.contentTintColor = .white

        transportBar.addSubview(progressTrack)
        transportBar.addSubview(trackTitleLabel)
        transportBar.addSubview(trackArtistLabel)
        transportBar.addSubview(prevButton)
        transportBar.addSubview(playPauseButton)
        transportBar.addSubview(nextButton)
        transportBar.addSubview(timeLabel)

        addSubview(scrollView)
        addSubview(missingView)
        addSubview(waitingLabel)
        addSubview(transportBar)

        let widthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidth = widthConstraint

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: transportBar.topAnchor, constant: -10),

            linesStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            linesStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            linesStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            linesStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            missingView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            missingView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            missingView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            missingView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            waitingLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            waitingLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            transportBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            transportBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            transportBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            transportBar.heightAnchor.constraint(equalToConstant: 64),

            progressTrack.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 14),
            progressTrack.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -14),
            progressTrack.topAnchor.constraint(equalTo: transportBar.topAnchor, constant: 8),
            progressTrack.heightAnchor.constraint(equalToConstant: 3),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            widthConstraint,

            trackTitleLabel.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 14),
            trackTitleLabel.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 8),
            trackTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -12),

            trackArtistLabel.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            trackArtistLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 2),
            trackArtistLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -12),

            playPauseButton.centerXAnchor.constraint(equalTo: transportBar.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: transportBar.centerYAnchor, constant: 6),
            playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),

            prevButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),
            prevButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 26),
            prevButton.heightAnchor.constraint(equalToConstant: 26),

            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 12),
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 26),
            nextButton.heightAnchor.constraint(equalToConstant: 26),

            timeLabel.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -14),
            timeLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor)
        ])
        refreshTransportAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshTransportAppearance()
    }

    override func layout() {
        super.layout()
        layoutDocumentWidth()
    }

    private func layoutDocumentWidth() {
        let width = max(200, scrollView.contentView.bounds.width)
        let height = max(scrollView.contentView.bounds.height, linesStack.fittingSize.height)
        if documentView.frame.size != NSSize(width: width, height: height) {
            documentView.setFrameSize(NSSize(width: width, height: height))
        }
    }

    private func configureTransportButton(_ button: NSButton, symbol: String, size: CGFloat, action: Selector) {
        button.title = ""
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        button.contentTintColor = .labelColor
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func refreshTransportAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            progressTrack.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
            progressFill.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
            playPauseButton.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
        }
    }

    func update(
        lines: [LyricLine],
        activeIndex: Int,
        trackTitle: String?,
        artistName: String?,
        isPlaying: Bool,
        isPaused: Bool,
        position: TimeInterval,
        duration: TimeInterval,
        lyricsNotFound: Bool
    ) {
        isPlayingState = isPlaying
        playPauseButton.image = NSImage(systemSymbolName: isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))

        let hasTrack = (trackTitle?.isEmpty == false)
        if let title = trackTitle, !title.isEmpty {
            trackTitleLabel.stringValue = title
            trackArtistLabel.stringValue = (artistName?.isEmpty == false) ? artistName! : "NotchMuse"
        } else {
            trackTitleLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "未在播放" : "Not Playing"
            trackArtistLabel.stringValue = "NotchMuse"
        }

        let safeDuration = max(0, duration)
        let safePos = min(max(0, position), safeDuration > 0 ? safeDuration : max(0, position))
        timeLabel.stringValue = "\(formatClock(safePos)) / \(formatClock(safeDuration))"
        let trackWidth = progressTrack.bounds.width
        if trackWidth > 0 && safeDuration > 0 {
            progressFillWidth?.constant = trackWidth * CGFloat(safePos / safeDuration)
        } else {
            progressFillWidth?.constant = 0
        }

        if !hasTrack {
            scrollView.isHidden = true
            missingView.isHidden = true
            missingView.setActive(false)
            waitingLabel.isHidden = false
            return
        }

        if lines.isEmpty {
            scrollView.isHidden = true
            waitingLabel.isHidden = !(!lyricsNotFound && !isPlaying && !isPaused)
            missingView.isHidden = !lyricsNotFound
            missingView.setActive(!isHidden && lyricsNotFound)
            return
        }

        waitingLabel.isHidden = true
        missingView.isHidden = true
        missingView.setActive(false)
        scrollView.isHidden = false

        if lines != currentLines {
            rebuildLines(lines)
        }
        if activeIndex != self.activeIndex {
            self.activeIndex = activeIndex
            highlightActiveLine()
            scrollActiveLineToCenterIfAllowed()
        }
    }

    private func rebuildLines(_ lines: [LyricLine]) {
        currentLines = lines
        activeIndex = -1
        linesStack.arrangedSubviews.forEach {
            linesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        lineLabels.removeAll()

        for line in lines {
            let text = line.translation.map { "\(line.text)\n\($0)" } ?? line.text
            let label = NSTextField(wrappingLabelWithString: text)
            label.alignment = .center
            label.font = .systemFont(ofSize: 15, weight: .regular)
            label.textColor = .tertiaryLabelColor
            label.wantsLayer = true
            label.translatesAutoresizingMaskIntoConstraints = false
            linesStack.addArrangedSubview(label)
            label.widthAnchor.constraint(lessThanOrEqualTo: linesStack.widthAnchor, constant: -40).isActive = true
            lineLabels.append(label)
        }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
    }

    private func highlightActiveLine() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            for (idx, label) in lineLabels.enumerated() {
                let dist = abs(idx - activeIndex)
                if idx == activeIndex {
                    label.font = .systemFont(ofSize: 20, weight: .bold)
                    label.textColor = .labelColor
                    label.layer?.shadowColor = AppearanceSurfaceColors.accent.cgColor
                    label.layer?.shadowRadius = 8
                    label.layer?.shadowOpacity = 0.35
                    label.layer?.shadowOffset = .zero
                } else if dist == 1 {
                    label.font = .systemFont(ofSize: 15, weight: .medium)
                    label.textColor = .secondaryLabelColor
                    label.layer?.shadowOpacity = 0
                } else {
                    label.font = .systemFont(ofSize: 14, weight: .regular)
                    label.textColor = .tertiaryLabelColor
                    label.layer?.shadowOpacity = 0
                }
            }
        }
    }

    private func scrollActiveLineToCenterIfAllowed() {
        guard ProcessInfo.processInfo.systemUptime >= userBrowsingUntil,
              lineLabels.indices.contains(activeIndex) else { return }
        layoutDocumentWidth()
        let target = lineLabels[activeIndex]
        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = max(0, target.frame.midY - visibleHeight * 0.44)
        let maxY = max(0, documentView.bounds.height - visibleHeight)
        let clampedY = min(targetY, maxY)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: clampedY))
        }
    }

    private func formatClock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func prevClicked() { onTransportCommand?(.previous) }
    @objc private func playPauseClicked() { onTransportCommand?(.playPause) }
    @objc private func nextClicked() { onTransportCommand?(.next) }
}

private final class ImmersiveLyricsScrollView: NSScrollView {
    var onUserScroll: (() -> Void)?
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
