import AppKit
import ServiceManagement

enum AppPreferences {
    static let displayModeKey = "DisplayMode"
    static let positionKey = "LyricsPosition"
    static let notchStyleKey = "NotchStyle"
    static let colorPresetKey = "LyricsColorPreset"
    static let customLyricsColorKey = "CustomLyricsColor"
    static let fontSizeKey = "LyricsFontSize"
    static let animationSpeedKey = "LyricsAnimationSpeed"
    static let opacityKey = "LyricsOpacity"
    static let displayTargetKey = "DisplayTarget"
    static let displayWidthKey = "DisplayWidth"
    static let customWidthKey = "CustomWidth"
    static let hasShownFirstLaunchGuideKey = "HasShownFirstLaunchGuide"
    static let languageKey = "AppLanguage"
    static let playerSourceKey = "PlayerSource"
    static let playerStopBehaviorKey = "PlayerStopBehavior"
    static let notchBackgroundEnabledKey = "NotchBackgroundEnabled"
    static let notchBackgroundColorKey = "NotchBackgroundColor"
    static let notchHideOnHoverKey = "NotchHideOnHover"

    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .english
    }

    static var playerSource: PlayerSource {
        playerSource(in: .standard)
    }

    static func playerSource(in defaults: UserDefaults) -> PlayerSource {
        normalizedPlayerSource(defaults.string(forKey: playerSourceKey))
    }

    static func setPlayerSource(_ source: PlayerSource, in defaults: UserDefaults = .standard) {
        defaults.set(source.rawValue, forKey: playerSourceKey)
    }

    static func normalizedPlayerSource(_ rawValue: String?) -> PlayerSource {
        PlayerSource(rawValue: rawValue ?? "") ?? .auto
    }

    static var playerStopBehavior: PlayerStopBehavior {
        playerStopBehavior(in: .standard)
    }

    static func playerStopBehavior(in defaults: UserDefaults) -> PlayerStopBehavior {
        PlayerStopBehavior(rawValue: defaults.string(forKey: playerStopBehaviorKey) ?? "") ?? .hide
    }

    static var displayMode: DisplayMode {
        DisplayMode(rawValue: UserDefaults.standard.string(forKey: displayModeKey) ?? "") ?? .statusBar
    }

    static var position: LyricsPosition {
        let stored = UserDefaults.standard.string(forKey: positionKey)
            ?? UserDefaults(suiteName: "local.menubarlyrics.app")?.string(forKey: positionKey)
        if stored == "Both" {
            UserDefaults.standard.set(LyricsPosition.right.rawValue, forKey: positionKey)
        }
        return normalizedPosition(stored)
    }

    static func normalizedPosition(_ rawValue: String?) -> LyricsPosition {
        rawValue == "Both" ? .right : LyricsPosition(rawValue: rawValue ?? "") ?? .right
    }

    static var notchStyle: NotchStyle {
        NotchStyle(rawValue: UserDefaults.standard.string(forKey: notchStyleKey) ?? "") ?? .lyricOnly
    }

    static var colorPreset: LyricsColorPreset {
        LyricsColorPreset(rawValue: UserDefaults.standard.string(forKey: colorPresetKey) ?? "") ?? .orange
    }

    static var customLyricsColor: NSColor {
        color(forKey: customLyricsColorKey) ?? BrandStyle.gradientColors[0]
    }

    static var fontSize: CGFloat {
        let stored = UserDefaults.standard.double(forKey: fontSizeKey)
        return stored == 0 ? NSFont.menuBarFont(ofSize: 0).pointSize : min(60, max(10, stored))
    }

    static var animationSpeed: CGFloat {
        let stored = UserDefaults.standard.double(forKey: animationSpeedKey)
        return stored == 0 ? 1 : min(3, max(0.1, stored))
    }

    static var opacity: CGFloat {
        let stored = UserDefaults.standard.double(forKey: opacityKey)
        return stored == 0 ? 1 : min(1, max(0.1, stored))
    }

    static var displayTarget: DisplayTarget {
        let stored = UserDefaults.standard.string(forKey: displayTargetKey) ?? ""
        if stored == "Follow Active Screen" { return .auto }
        return DisplayTarget(rawValue: stored) ?? .auto
    }

    static var displayWidth: DisplayWidth {
        DisplayWidth(rawValue: UserDefaults.standard.string(forKey: displayWidthKey) ?? "") ?? .auto
    }

    static var customWidth: CGFloat {
        let stored = UserDefaults.standard.double(forKey: customWidthKey)
        return stored == 0 ? 500 : min(1000, max(180, stored))
    }

    static var notchBackgroundEnabled: Bool { notchBackgroundEnabled(in: .standard) }

    static func notchBackgroundEnabled(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: notchBackgroundEnabledKey)
    }

    static func notchBackgroundMode(in defaults: UserDefaults = .standard) -> NotchBackgroundMode {
        guard notchBackgroundEnabled(in: defaults) else { return .none }
        return defaults.data(forKey: notchBackgroundColorKey) == nil ? .black : .custom
    }

    static var notchHideOnHover: Bool { notchHideOnHover(in: .standard) }

    static func notchHideOnHover(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: notchHideOnHoverKey) as? Bool ?? true
    }

    static var notchBackgroundColor: NSColor {
        color(forKey: notchBackgroundColorKey) ?? .black
    }

    static func color(forKey key: String, in defaults: UserDefaults = .standard) -> NSColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    static func setColor(_ color: NSColor, forKey key: String, in defaults: UserDefaults = .standard) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) else { return }
        defaults.set(data, forKey: key)
    }

}

enum NumericInput {
    static func parse(_ text: String, minimum: Double, maximum: Double) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
            return nil
        }
        return min(maximum, max(minimum, value))
    }
}

enum PlayerStopBehavior: String, CaseIterable {
    case hide = "Hide Lyrics and Wait"
    case keep = "Keep Last Lyrics and Pause"
}

enum NotchBackgroundMode: String, CaseIterable {
    case none = "None"
    case black = "Black"
    case custom = "Custom"
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let displayModeControl = NSSegmentedControl(labels: DisplayMode.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let positionControl = NSSegmentedControl(labels: LyricsPosition.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let notchStyleControl = NSSegmentedControl(labels: NotchStyle.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let displayTargetPopUp = NSPopUpButton()
    private let widthControl = NSSegmentedControl(labels: DisplayWidth.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let customWidthSlider = NSSlider(value: 500, minValue: 180, maxValue: 1000, target: nil, action: nil)
    private let colorPopUp = NSPopUpButton()
    private let lyricsColorWell = NSColorWell()
    private let fontSizeSlider = NSSlider(value: 13, minValue: 10, maxValue: 60, target: nil, action: nil)
    private let animationSpeedSlider = NSSlider(value: 1, minValue: 0.1, maxValue: 3, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 1, minValue: 0.1, maxValue: 1, target: nil, action: nil)
    private let fontSizeValue = NSTextField(string: "")
    private let animationSpeedValue = NSTextField(string: "")
    private let opacityValue = NSTextField(string: "")
    private let customWidthValue = NSTextField(string: "")
    private let launchAtLoginSwitch = NSSwitch()
    private let languagePopUp = NSPopUpButton()
    private let playerPopUp = NSPopUpButton()
    private let playerStopBehaviorPopUp = NSPopUpButton()
    private let notchBackgroundPopUp = NSPopUpButton()
    private let notchBackgroundColorWell = NSColorWell()
    private let notchHideOnHoverSwitch = NSSwitch()
    private let contentStack = NSStackView()
    private let preview = SettingsPreviewView()
    private let previewModeControl = NSSegmentedControl(labels: [L10n.text("Status Bar Preview"), L10n.text("Notch Preview")], trackingMode: .selectOne, target: nil, action: nil)
    private let displayPage = NSStackView()
    private let appearancePage = NSStackView()
    private let generalPage = NSStackView()
    private var selectedPage: SettingsPage = .display
    private var sidebarButtons: [SettingsPage: NSButton] = [:]
    private var positionRow: NSGridRow?
    private var notchStyleRow: NSGridRow?
    private var customWidthRow: NSGridRow?
    private var notchBackgroundRow: NSGridRow?
    private var notchBackgroundColorRow: NSGridRow?
    private var notchHideOnHoverRow: NSGridRow?
    private let onSettingsChange: () -> Void

    init(onSettingsChange: @escaping () -> Void) {
        self.onSettingsChange = onSettingsChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1160, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("NotchMuse Settings")
        window.minSize = NSSize(width: 1160, height: 700)
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        sync()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        displayModeControl.target = self
        displayModeControl.action = #selector(displayModeChanged)
        positionControl.target = self
        positionControl.action = #selector(positionChanged)
        notchStyleControl.target = self
        notchStyleControl.action = #selector(notchStyleChanged)

        for target in DisplayTarget.allCases {
            displayTargetPopUp.addItem(withTitle: L10n.text(target.rawValue))
        }
        displayTargetPopUp.target = self
        displayTargetPopUp.action = #selector(displayTargetChanged)
        widthControl.target = self
        widthControl.action = #selector(widthChanged)
        customWidthSlider.target = self
        customWidthSlider.action = #selector(customWidthChanged)
        configureNumericField(customWidthValue, action: #selector(customWidthEntered))

        for preset in LyricsColorPreset.allCases {
            colorPopUp.addItem(withTitle: L10n.text(preset.rawValue))
            colorPopUp.lastItem?.image = swatch(BrandStyle.gradientColors(for: preset)[0])
        }
        colorPopUp.target = self
        colorPopUp.action = #selector(colorChanged)
        lyricsColorWell.target = self
        lyricsColorWell.action = #selector(lyricsColorChanged)
        lyricsColorWell.isContinuous = true

        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged)
        fontSizeSlider.isContinuous = true
        configureNumericField(fontSizeValue, action: #selector(fontSizeEntered))
        animationSpeedSlider.target = self
        animationSpeedSlider.action = #selector(animationSpeedChanged)
        animationSpeedSlider.isContinuous = true
        configureNumericField(animationSpeedValue, action: #selector(animationSpeedEntered))
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.isContinuous = true
        configureNumericField(opacityValue, action: #selector(opacityEntered))
        for mode in NotchBackgroundMode.allCases {
            notchBackgroundPopUp.addItem(withTitle: L10n.text(mode.rawValue))
        }
        notchBackgroundPopUp.target = self
        notchBackgroundPopUp.action = #selector(notchBackgroundChanged)
        notchBackgroundColorWell.target = self
        notchBackgroundColorWell.action = #selector(notchBackgroundColorChanged)
        notchBackgroundColorWell.isContinuous = true
        notchHideOnHoverSwitch.target = self
        notchHideOnHoverSwitch.action = #selector(notchHideOnHoverChanged)
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)
        for language in AppLanguage.allCases {
            languagePopUp.addItem(withTitle: language.displayName)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        for source in PlayerSource.allCases {
            playerPopUp.addItem(withTitle: source.displayName())
        }
        playerPopUp.target = self
        playerPopUp.action = #selector(playerChanged)
        for behavior in PlayerStopBehavior.allCases {
            playerStopBehaviorPopUp.addItem(withTitle: L10n.text(behavior.rawValue))
        }
        playerStopBehaviorPopUp.target = self
        playerStopBehaviorPopUp.action = #selector(playerStopBehaviorChanged)

        previewModeControl.target = self
        previewModeControl.action = #selector(previewModeChanged)
        previewModeControl.selectedSegment = 0
        let displayGrid = grid([
            [label(L10n.text("Display Mode")), displayModeControl],
            [label(L10n.text("Status Bar Position")), positionControl],
            [label(L10n.text("Notch Style")), notchStyleControl],
            [label(L10n.text("Display Screen")), displayScreenControl()],
            [label(L10n.text("Lyrics Width")), widthControl],
            [label(L10n.text("Custom Width")), valueRow(slider: customWidthSlider, value: customWidthValue, unit: "pt")]
        ])
        positionRow = displayGrid.row(at: 1)
        notchStyleRow = displayGrid.row(at: 2)
        customWidthRow = displayGrid.row(at: 5)
        configure(page: displayPage)
        configure(page: appearancePage)
        let appearanceGrid = grid([
            [label(L10n.text("Lyrics Color")), NSStackView(views: [colorPopUp, lyricsColorWell])],
            [label(L10n.text("Font Size")), valueRow(slider: fontSizeSlider, value: fontSizeValue, unit: "pt")],
            [label(L10n.text("Animation Speed")), valueRow(slider: animationSpeedSlider, value: animationSpeedValue, unit: "×")],
            [label(L10n.text("Opacity")), valueRow(slider: opacitySlider, value: opacityValue, unit: "%")],
            [label(L10n.text("Background")), notchBackgroundPopUp],
            [label(L10n.text("Background Color")), notchBackgroundColorWell],
            [label(L10n.text("Hide on Hover")), notchHideOnHoverSwitch]
        ])
        notchBackgroundRow = appearanceGrid.row(at: 4)
        notchBackgroundColorRow = appearanceGrid.row(at: 5)
        notchHideOnHoverRow = appearanceGrid.row(at: 6)
        appearancePage.addArrangedSubview(card(content: cardBody(title: "Appearance", subtitle: "Customize the look of your lyrics.", grid: appearanceGrid, trailing: resetButton(for: .appearance))))
        appearancePage.addArrangedSubview(quickPresetsCard())
        configure(page: generalPage)
        let generalGrid = grid([
            [label(L10n.text("Music Player")), playerPopUp],
            [label(L10n.text("When Player Stops")), playerStopBehaviorPopUp],
            [label(L10n.text("Language")), languagePopUp],
            [label(L10n.text("Launch at Login")), launchAtLoginSwitch]
        ])
        generalPage.addArrangedSubview(card(content: cardBody(title: "General", subtitle: "Player and system behavior.", grid: generalGrid, trailing: resetButton(for: .general))))

        displayPage.addArrangedSubview(card(content: cardBody(title: "Display", subtitle: "Choose how and where lyrics appear.", grid: displayGrid, trailing: resetButton(for: .display))))

        guard let contentView = window?.contentView else { return }
        let backdrop = SettingsBackdropView(frame: contentView.bounds)
        backdrop.autoresizingMask = [.width, .height]
        contentView.addSubview(backdrop)
        let sidebar = NSStackView()
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 10
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addArrangedSubview(sidebarTitle())
        sidebar.setCustomSpacing(28, after: sidebar.arrangedSubviews[0])
        for page in SettingsPage.allCases {
            let button = sidebarButton(for: page)
            sidebarButtons[page] = button
            sidebar.addArrangedSubview(button)
        }
        updateSidebarSelection()
        let sidebarPanel = NSView()
        sidebarPanel.wantsLayer = true
        sidebarPanel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.46).cgColor
        sidebarPanel.layer?.cornerRadius = 14
        sidebarPanel.layer?.borderWidth = 1
        sidebarPanel.layer?.borderColor = NSColor.white.withAlphaComponent(0.65).cgColor
        sidebarPanel.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebar)

        let previewHeader = NSStackView(views: [sectionTitle(L10n.text("Live Preview")), previewModeControl])
        previewHeader.orientation = .horizontal
        previewHeader.distribution = .equalSpacing
        previewHeader.alignment = .centerY
        let previewContents = NSStackView(views: [previewHeader, preview])
        previewContents.orientation = .vertical
        previewContents.spacing = 16
        let previewCard = card(content: previewContents)
        preview.widthAnchor.constraint(equalToConstant: 830).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 226).isActive = true
        previewHeader.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(previewCard)
        contentStack.addArrangedSubview(displayPage)
        contentStack.addArrangedSubview(appearancePage)
        contentStack.addArrangedSubview(generalPage)
        appearancePage.isHidden = true
        generalPage.isHidden = true
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedSettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(contentStack)
        scrollView.documentView = document
        contentView.addSubview(sidebarPanel)
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            sidebarPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sidebarPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            sidebarPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            sidebarPanel.widthAnchor.constraint(equalToConstant: 220),
            sidebar.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 14),
            sidebar.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -14),
            sidebar.topAnchor.constraint(equalTo: sidebarPanel.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            contentStack.topAnchor.constraint(equalTo: document.topAnchor),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -18)
        ])
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }

    private func configure(page: NSStackView) {
        page.orientation = .vertical
        page.alignment = .leading
        page.spacing = 12
    }

    private func sidebarTitle() -> NSView {
        let title = NSTextField(labelWithString: "NotchMuse")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = NSColor(calibratedRed: 0.10, green: 0.27, blue: 0.51, alpha: 1)
        let icon = NSImageView(image: NSImage(systemSymbolName: "waveform", accessibilityDescription: "NotchMuse") ?? NSImage())
        icon.contentTintColor = .systemBlue
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let row = NSStackView(views: [icon, title])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func sidebarButton(for page: SettingsPage) -> NSButton {
        let button = NSButton(title: L10n.text(page.title), target: self, action: #selector(pageChanged))
        button.isBordered = false
        button.setButtonType(.toggle)
        button.cell?.wraps = true
        button.alignment = .left
        button.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: L10n.text(page.title))
        button.imagePosition = .imageLeading
        button.identifier = NSUserInterfaceItemIdentifier(page.rawValue)
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.widthAnchor.constraint(equalToConstant: 192).isActive = true
        button.heightAnchor.constraint(equalToConstant: 62).isActive = true
        button.toolTip = L10n.text(page.help)
        return button
    }

    private func card(content: NSView) -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.73).cgColor
        box.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        box.layer?.borderWidth = 1
        box.layer?.cornerRadius = 14
        box.layer?.shadowColor = NSColor(calibratedRed: 0.19, green: 0.31, blue: 0.53, alpha: 1).cgColor
        box.layer?.shadowOpacity = 0.12
        box.layer?.shadowRadius = 14
        box.layer?.shadowOffset = CGSize(width: 0, height: -4)
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -18)
        ])
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 870).isActive = true
        return box
    }

    private func cardBody(title: String, subtitle: String, grid: NSGridView, trailing: NSView) -> NSStackView {
        let header = cardHeader(title: title, subtitle: subtitle, trailing: trailing)
        let body = NSStackView(views: [header, grid])
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 18
        header.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        return body
    }

    private func cardHeader(title: String, subtitle: String, trailing: NSView) -> NSStackView {
        let heading = NSTextField(labelWithString: L10n.text(title))
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        let detail = NSTextField(labelWithString: L10n.text(subtitle))
        detail.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: 13)
        let symbol: String
        switch title {
        case "Display": symbol = "rectangle.on.rectangle"
        case "Appearance": symbol = "sparkles"
        default: symbol = "gearshape"
        }
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: L10n.text(title)) ?? NSImage())
        icon.contentTintColor = .systemBlue
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        let labels = NSStackView(views: [heading, detail])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        let headingGroup = NSStackView(views: [icon, labels])
        headingGroup.orientation = .horizontal
        headingGroup.spacing = 10
        headingGroup.alignment = .centerY
        let header = NSStackView(views: [headingGroup, trailing])
        header.orientation = .horizontal
        header.distribution = .equalSpacing
        header.alignment = .top
        return header
    }

    private func resetButton(for page: SettingsPage) -> NSButton {
        NSButton(title: L10n.text("Restore Defaults"), target: self, action: #selector(resetSection))
    }

    private func quickPresetsCard() -> NSView {
        let titles = ["Warm Orange", "Fresh Minimal", "Dreamy Soft", "Pure"]
        let colors: [NSColor] = [.systemOrange, .systemTeal, .systemPurple, .systemGreen]
        let tiles = zip(titles, colors).enumerated().map { index, entry in
            let button = NSButton(title: L10n.text(entry.0), target: self, action: #selector(presetButtonChanged))
            button.tag = index + 1
            button.isBordered = false
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: L10n.text(entry.0))
            button.imagePosition = .imageAbove
            button.contentTintColor = entry.1
            button.font = .systemFont(ofSize: 12, weight: .medium)
            button.wantsLayer = true
            button.layer?.backgroundColor = entry.1.withAlphaComponent(0.09).cgColor
            button.layer?.borderColor = entry.1.withAlphaComponent(0.25).cgColor
            button.layer?.borderWidth = 1
            button.layer?.cornerRadius = 10
            button.widthAnchor.constraint(equalToConstant: 190).isActive = true
            button.heightAnchor.constraint(equalToConstant: 72).isActive = true
            return button
        }
        let row = NSStackView(views: tiles)
        row.orientation = .horizontal
        row.spacing = 12
        let contents = NSStackView(views: [sectionTitle(L10n.text("Quick Presets")), row])
        contents.orientation = .vertical
        contents.alignment = .leading
        contents.spacing = 14
        return card(content: contents)
    }

    private func label(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = .systemFont(ofSize: 13, weight: .medium)
        return label
    }

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 18
        grid.columnSpacing = 20
        grid.column(at: 0).width = 170
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.widthAnchor.constraint(equalToConstant: 830).isActive = true
        return grid
    }

    private func valueRow(slider: NSSlider, value: NSTextField, unit: String) -> NSView {
        value.alignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)
        value.widthAnchor.constraint(equalToConstant: 58).isActive = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 390).isActive = true
        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [slider, value, unitLabel])
        stack.orientation = .horizontal
        stack.spacing = 10
        return stack
    }

    private func configureNumericField(_ field: NSTextField, action: Selector) {
        field.target = self
        field.action = action
        field.alignment = .right
        field.placeholderString = "0"
    }

    private func displayScreenControl() -> NSView {
        let help = NSTextField(wrappingLabelWithString: L10n.text("Choose which screen displays lyrics when multiple monitors are connected."))
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [displayTargetPopUp, help])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 604).isActive = true
        return box
    }

    private func swatch(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12))
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 10, height: 10)).fill()
        image.unlockFocus()
        return image
    }

    private func sync() {
        displayModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: AppPreferences.displayMode) ?? 0
        positionControl.selectedSegment = LyricsPosition.allCases.firstIndex(of: AppPreferences.position) ?? 1
        notchStyleControl.selectedSegment = NotchStyle.allCases.firstIndex(of: AppPreferences.notchStyle) ?? 0
        displayTargetPopUp.selectItem(at: DisplayTarget.allCases.firstIndex(of: AppPreferences.displayTarget) ?? 0)
        widthControl.selectedSegment = DisplayWidth.allCases.firstIndex(of: AppPreferences.displayWidth) ?? 0
        customWidthSlider.doubleValue = Double(AppPreferences.customWidth)
        colorPopUp.selectItem(at: LyricsColorPreset.allCases.firstIndex(of: AppPreferences.colorPreset) ?? 0)
        lyricsColorWell.color = AppPreferences.customLyricsColor
        updateCustomColorSwatch()
        fontSizeSlider.doubleValue = Double(AppPreferences.fontSize)
        animationSpeedSlider.doubleValue = Double(AppPreferences.animationSpeed)
        opacitySlider.doubleValue = Double(AppPreferences.opacity)
        notchBackgroundPopUp.selectItem(at: NotchBackgroundMode.allCases.firstIndex(of: AppPreferences.notchBackgroundMode()) ?? 0)
        notchBackgroundColorWell.color = AppPreferences.notchBackgroundColor
        notchHideOnHoverSwitch.state = AppPreferences.notchHideOnHover ? .on : .off
        fontSizeValue.stringValue = String(format: "%.0f", fontSizeSlider.doubleValue)
        animationSpeedValue.stringValue = String(format: "%.1f", animationSpeedSlider.doubleValue)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        customWidthValue.stringValue = String(format: "%.0f", customWidthSlider.doubleValue)
        launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        playerPopUp.selectItem(at: PlayerSource.allCases.firstIndex(of: AppPreferences.playerSource) ?? 0)
        playerStopBehaviorPopUp.selectItem(at: PlayerStopBehavior.allCases.firstIndex(of: AppPreferences.playerStopBehavior) ?? 0)
        languagePopUp.selectItem(at: AppLanguage.allCases.firstIndex(of: AppPreferences.language) ?? 0)
        updateControlAvailability()
        updatePreview()
    }

    private func save<T: RawRepresentable>(_ value: T, key: String) where T.RawValue == String {
        UserDefaults.standard.set(value.rawValue, forKey: key)
        onSettingsChange()
        updatePreview()
    }

    private func updateControlAvailability() {
        let statusBarMode = AppPreferences.displayMode == .statusBar
        positionRow?.isHidden = !statusBarMode
        notchStyleRow?.isHidden = statusBarMode
        customWidthRow?.isHidden = AppPreferences.displayWidth != .custom
        notchBackgroundRow?.isHidden = statusBarMode
        notchBackgroundColorRow?.isHidden = statusBarMode || AppPreferences.notchBackgroundMode() != .custom
        notchHideOnHoverRow?.isHidden = statusBarMode
    }

    @objc private func displayModeChanged() {
        let modes = DisplayMode.allCases
        guard modes.indices.contains(displayModeControl.selectedSegment) else { return }
        save(modes[displayModeControl.selectedSegment], key: AppPreferences.displayModeKey)
        updateControlAvailability()
    }

    @objc private func positionChanged() {
        let positions = LyricsPosition.allCases
        guard positions.indices.contains(positionControl.selectedSegment) else { return }
        let position = positions[positionControl.selectedSegment]
        save(position, key: AppPreferences.positionKey)
        AccessibilityManager.requestIfNeeded(mode: AppPreferences.displayMode, position: position)
    }

    @objc private func notchStyleChanged() {
        let styles = NotchStyle.allCases
        guard styles.indices.contains(notchStyleControl.selectedSegment) else { return }
        save(styles[notchStyleControl.selectedSegment], key: AppPreferences.notchStyleKey)
    }

    @objc private func displayTargetChanged() {
        let targets = DisplayTarget.allCases
        guard targets.indices.contains(displayTargetPopUp.indexOfSelectedItem) else { return }
        save(targets[displayTargetPopUp.indexOfSelectedItem], key: AppPreferences.displayTargetKey)
    }

    @objc private func widthChanged() {
        let widths = DisplayWidth.allCases
        guard widths.indices.contains(widthControl.selectedSegment) else { return }
        save(widths[widthControl.selectedSegment], key: AppPreferences.displayWidthKey)
        updateControlAvailability()
    }

    @objc private func customWidthChanged() {
        UserDefaults.standard.set(customWidthSlider.doubleValue, forKey: AppPreferences.customWidthKey)
        customWidthValue.stringValue = String(format: "%.0f", customWidthSlider.doubleValue)
        onSettingsChange()
        updatePreview()
    }

    @objc private func customWidthEntered() {
        commit(customWidthValue, slider: customWidthSlider, key: AppPreferences.customWidthKey, minimum: 180, maximum: 1000, format: "%.0f")
    }

    @objc private func colorChanged() {
        let presets = LyricsColorPreset.allCases
        guard presets.indices.contains(colorPopUp.indexOfSelectedItem) else { return }
        let preset = presets[colorPopUp.indexOfSelectedItem]
        save(preset, key: AppPreferences.colorPresetKey)
        if preset == .custom { lyricsColorWell.activate(true) }
    }

    @objc private func lyricsColorChanged() {
        AppPreferences.setColor(lyricsColorWell.color, forKey: AppPreferences.customLyricsColorKey)
        updateCustomColorSwatch()
        colorPopUp.selectItem(at: LyricsColorPreset.allCases.firstIndex(of: .custom) ?? 0)
        UserDefaults.standard.set(LyricsColorPreset.custom.rawValue, forKey: AppPreferences.colorPresetKey)
        onSettingsChange()
        updatePreview()
    }

    @objc private func fontSizeChanged() {
        UserDefaults.standard.set(fontSizeSlider.doubleValue, forKey: AppPreferences.fontSizeKey)
        fontSizeValue.stringValue = String(format: "%.0f", fontSizeSlider.doubleValue)
        onSettingsChange()
        updatePreview()
    }

    @objc private func fontSizeEntered() {
        commit(fontSizeValue, slider: fontSizeSlider, key: AppPreferences.fontSizeKey, minimum: 10, maximum: 60, format: "%.0f")
    }

    @objc private func animationSpeedChanged() {
        UserDefaults.standard.set(animationSpeedSlider.doubleValue, forKey: AppPreferences.animationSpeedKey)
        animationSpeedValue.stringValue = String(format: "%.1f", animationSpeedSlider.doubleValue)
        onSettingsChange()
        updatePreview()
    }

    @objc private func animationSpeedEntered() {
        commit(animationSpeedValue, slider: animationSpeedSlider, key: AppPreferences.animationSpeedKey, minimum: 0.1, maximum: 3, format: "%.1f")
    }

    @objc private func opacityChanged() {
        UserDefaults.standard.set(opacitySlider.doubleValue, forKey: AppPreferences.opacityKey)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        onSettingsChange()
        updatePreview()
    }

    @objc private func opacityEntered() {
        guard let percent = NumericInput.parse(opacityValue.stringValue, minimum: 10, maximum: 100) else {
            opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
            NSSound.beep()
            return
        }
        opacitySlider.doubleValue = percent / 100
        opacityChanged()
    }

    @objc private func notchBackgroundChanged() {
        let modes = NotchBackgroundMode.allCases
        guard modes.indices.contains(notchBackgroundPopUp.indexOfSelectedItem) else { return }
        switch modes[notchBackgroundPopUp.indexOfSelectedItem] {
        case .none:
            UserDefaults.standard.set(false, forKey: AppPreferences.notchBackgroundEnabledKey)
        case .black:
            UserDefaults.standard.set(true, forKey: AppPreferences.notchBackgroundEnabledKey)
            UserDefaults.standard.removeObject(forKey: AppPreferences.notchBackgroundColorKey)
        case .custom:
            UserDefaults.standard.set(true, forKey: AppPreferences.notchBackgroundEnabledKey)
            AppPreferences.setColor(notchBackgroundColorWell.color, forKey: AppPreferences.notchBackgroundColorKey)
        }
        updateControlAvailability()
        onSettingsChange()
    }

    @objc private func notchBackgroundColorChanged() {
        AppPreferences.setColor(notchBackgroundColorWell.color, forKey: AppPreferences.notchBackgroundColorKey)
        onSettingsChange()
    }

    private func updateCustomColorSwatch() {
        guard let index = LyricsColorPreset.allCases.firstIndex(of: .custom) else { return }
        colorPopUp.item(at: index)?.image = swatch(lyricsColorWell.color)
    }

    private func commit(
        _ field: NSTextField,
        slider: NSSlider,
        key: String,
        minimum: Double,
        maximum: Double,
        format: String
    ) {
        guard let value = NumericInput.parse(field.stringValue, minimum: minimum, maximum: maximum) else {
            field.stringValue = String(format: format, slider.doubleValue)
            NSSound.beep()
            return
        }
        slider.doubleValue = value
        UserDefaults.standard.set(value, forKey: key)
        field.stringValue = String(format: format, value)
        onSettingsChange()
    }

    @objc private func notchHideOnHoverChanged() {
        UserDefaults.standard.set(notchHideOnHoverSwitch.state == .on, forKey: AppPreferences.notchHideOnHoverKey)
        onSettingsChange()
    }

    @objc private func launchAtLoginChanged() {
        do {
            if launchAtLoginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
            let alert = NSAlert(error: error)
            alert.messageText = L10n.text("Could not update Launch at Login")
            alert.runModal()
        }
    }

    @objc private func languageChanged() {
        let languages = AppLanguage.allCases
        guard languages.indices.contains(languagePopUp.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(languages[languagePopUp.indexOfSelectedItem].rawValue, forKey: AppPreferences.languageKey)
        let alert = NSAlert()
        alert.messageText = L10n.text("Language Change")
        alert.informativeText = L10n.text("Restart NotchMuse to apply the new language.")
        alert.addButton(withTitle: L10n.text("OK"))
        alert.runModal()
    }

    @objc private func playerChanged() {
        let sources = PlayerSource.allCases
        guard sources.indices.contains(playerPopUp.indexOfSelectedItem) else { return }
        AppPreferences.setPlayerSource(sources[playerPopUp.indexOfSelectedItem])
        onSettingsChange()
    }

    @objc private func playerStopBehaviorChanged() {
        let behaviors = PlayerStopBehavior.allCases
        guard behaviors.indices.contains(playerStopBehaviorPopUp.indexOfSelectedItem) else { return }
        save(behaviors[playerStopBehaviorPopUp.indexOfSelectedItem], key: AppPreferences.playerStopBehaviorKey)
    }

    @objc private func pageChanged(_ sender: NSButton) {
        guard let page = SettingsPage(rawValue: sender.identifier?.rawValue ?? "") else { return }
        selectedPage = page
        displayPage.isHidden = page != .display
        appearancePage.isHidden = page != .appearance
        generalPage.isHidden = page != .general
        DispatchQueue.main.async { self.updateSidebarSelection() }
    }

    private func updateSidebarSelection() {
        sidebarButtons.forEach { page, button in
            let selected = page == selectedPage
            button.state = selected ? .on : .off
            button.layer?.backgroundColor = selected
                ? NSColor(calibratedRed: 0.17, green: 0.48, blue: 0.93, alpha: 1).cgColor
                : NSColor.clear.cgColor
            button.contentTintColor = selected ? .white : NSColor(calibratedRed: 0.30, green: 0.38, blue: 0.53, alpha: 1)
            let text = NSMutableAttributedString(string: L10n.text(page.title) + "\n" + L10n.text(page.help))
            text.addAttributes([.font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                                .foregroundColor: selected ? NSColor.white : NSColor.labelColor],
                               range: NSRange(location: 0, length: L10n.text(page.title).utf16.count))
            let subtitleStart = L10n.text(page.title).utf16.count + 1
            text.addAttributes([.font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: selected ? NSColor.white.withAlphaComponent(0.82) : NSColor.secondaryLabelColor],
                               range: NSRange(location: subtitleStart, length: text.length - subtitleStart))
            button.attributedTitle = text
        }
    }

    @objc private func previewModeChanged() {
        preview.mode = previewModeControl.selectedSegment == 1 ? .notch : .statusBar
    }

    @objc private func presetButtonChanged(_ sender: NSButton) {
        switch sender.tag {
        case 1: applyPreset(.orange, fontSize: 16, speed: 1.3, opacity: 1, width: .wide)
        case 2: applyPreset(.green, fontSize: 13, speed: 1, opacity: 1, width: .normal)
        case 3: applyPreset(.purple, fontSize: 18, speed: 0.8, opacity: 0.9, width: .wide)
        case 4: applyPreset(.white, fontSize: 13, speed: 1, opacity: 1, width: .auto)
        default: return
        }
    }

    private func applyPreset(_ color: LyricsColorPreset, fontSize: Double, speed: Double, opacity: Double, width: DisplayWidth) {
        UserDefaults.standard.set(color.rawValue, forKey: AppPreferences.colorPresetKey)
        UserDefaults.standard.set(fontSize, forKey: AppPreferences.fontSizeKey)
        UserDefaults.standard.set(speed, forKey: AppPreferences.animationSpeedKey)
        UserDefaults.standard.set(opacity, forKey: AppPreferences.opacityKey)
        UserDefaults.standard.set(width.rawValue, forKey: AppPreferences.displayWidthKey)
        sync()
        onSettingsChange()
    }

    @objc private func resetSection(_ sender: NSButton) {
        let page = selectedPage
        let keys: [String]
        switch page {
        case .display:
            keys = [AppPreferences.displayModeKey, AppPreferences.positionKey, AppPreferences.notchStyleKey, AppPreferences.displayTargetKey, AppPreferences.displayWidthKey, AppPreferences.customWidthKey]
        case .appearance:
            keys = [AppPreferences.colorPresetKey, AppPreferences.customLyricsColorKey, AppPreferences.fontSizeKey, AppPreferences.animationSpeedKey, AppPreferences.opacityKey, AppPreferences.notchBackgroundEnabledKey, AppPreferences.notchBackgroundColorKey, AppPreferences.notchHideOnHoverKey]
        case .general:
            keys = [AppPreferences.playerSourceKey, AppPreferences.playerStopBehaviorKey, AppPreferences.languageKey]
        }
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
        sync()
        onSettingsChange()
    }

    private func updatePreview() {
        preview.apply(
            color: BrandStyle.gradientColors(for: AppPreferences.colorPreset, customColor: AppPreferences.customLyricsColor).first ?? .labelColor,
            fontSize: AppPreferences.fontSize,
            opacity: AppPreferences.opacity,
            width: AppPreferences.displayWidth,
            position: AppPreferences.position
        )
    }
}

private final class SettingsBackdropView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: NSColor(calibratedRed: 1, green: 0.91, blue: 0.88, alpha: 1),
                   ending: NSColor(calibratedRed: 0.79, green: 0.87, blue: 1, alpha: 1))?
            .draw(in: bounds, angle: 18)
        NSColor.white.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), xRadius: 18, yRadius: 18).fill()
    }
}

private final class FlippedSettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private enum SettingsPage: String, CaseIterable {
    case display, appearance, general

    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .display: return "display"
        case .appearance: return "paintpalette"
        case .general: return "gearshape"
        }
    }
    var help: String {
        switch self {
        case .display: return "Lyrics display mode, position, and screen."
        case .appearance: return "Lyrics color, typography, and motion."
        case .general: return "Player selection and system behavior."
        }
    }
}

@MainActor
private final class SettingsPreviewView: NSView {
    enum Mode { case statusBar, notch }
    var mode: Mode = .statusBar { didSet { needsDisplay = true } }
    private var lyricColor = NSColor.systemOrange
    private var lyricFontSize: CGFloat = 13
    private var lyricOpacity: CGFloat = 1
    private var lyricWidth: DisplayWidth = .auto
    private var position: LyricsPosition = .right
    private lazy var wallpaper: NSImage? = Bundle.main.path(forResource: "SettingsPreviewWallpaper", ofType: "png")
        .flatMap(NSImage.init(contentsOfFile:))

    override var isFlipped: Bool { true }

    func apply(color: NSColor, fontSize: CGFloat, opacity: CGFloat, width: DisplayWidth, position: LyricsPosition) {
        lyricColor = color
        lyricFontSize = fontSize
        lyricOpacity = opacity
        lyricWidth = width
        self.position = position
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let gap: CGFloat = 16
        let panelWidth = (bounds.width - gap) / 2
        drawPanel(NSRect(x: 0, y: 0, width: panelWidth, height: bounds.height), notch: false)
        drawPanel(NSRect(x: panelWidth + gap, y: 0, width: panelWidth, height: bounds.height), notch: true)
    }

    private func drawPanel(_ rect: NSRect, notch: Bool) {
        let selected = (mode == .notch) == notch
        let title = L10n.text(notch ? "Notch Preview" : "Status Bar Preview")
        (title as NSString).draw(in: NSRect(x: rect.minX + 10, y: rect.minY + 2, width: rect.width - 20, height: 22),
                                 withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                                                  .foregroundColor: NSColor.secondaryLabelColor])
        let screen = NSRect(x: rect.minX + 2, y: rect.minY + 28, width: rect.width - 4, height: rect.height - 32)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: screen, xRadius: 11, yRadius: 11).addClip()
        if let wallpaper {
            let cropHeight = wallpaper.size.width * screen.height / screen.width
            let crop = NSRect(x: 0, y: (wallpaper.size.height - cropHeight) / 2,
                              width: wallpaper.size.width, height: cropHeight)
            wallpaper.draw(in: screen, from: crop, operation: .sourceOver, fraction: 1,
                           respectFlipped: true, hints: nil)
        } else {
            NSGradient(starting: NSColor.systemOrange, ending: NSColor.systemBlue)?
                .draw(in: screen, angle: -18)
        }

        if notch {
            let cutout = NSRect(x: screen.midX - 118, y: screen.minY - 1, width: 236, height: 72)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: cutout, xRadius: 22, yRadius: 22).fill()
            let textRect = cutout.insetBy(dx: 14, dy: 25)
            drawLyric(in: textRect, size: 13)
        } else {
            let bar = NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: 36)
            NSColor.white.withAlphaComponent(0.84).setFill()
            NSBezierPath(rect: bar).fill()
            ("●" as NSString).draw(in: NSRect(x: bar.minX + 14, y: bar.minY + 8, width: 18, height: 20),
                                    withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.black])
            let widths: [DisplayWidth: CGFloat] = [.compact: 145, .normal: 205, .wide: 260, .custom: 220, .auto: 205]
            let width = min(widths[lyricWidth] ?? 205, bar.width - 116)
            let x = position == .left ? bar.minX + 46 : bar.maxX - width - 58
            drawLyric(in: NSRect(x: x, y: bar.minY + 9, width: width, height: 22), size: 13)
            ("◕  ◖◗" as NSString).draw(in: NSRect(x: bar.maxX - 50, y: bar.minY + 10, width: 46, height: 20),
                                       withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray])
        }
        NSGraphicsContext.restoreGraphicsState()
        (selected ? NSColor.systemBlue : NSColor.white.withAlphaComponent(0.85)).setStroke()
        let outline = NSBezierPath(roundedRect: screen.insetBy(dx: 0.5, dy: 0.5), xRadius: 11, yRadius: 11)
        outline.lineWidth = selected ? 2.5 : 1.5
        outline.stroke()
    }

    private func drawLyric(in rect: NSRect, size: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(size, lyricFontSize), weight: .semibold),
            .foregroundColor: lyricColor.withAlphaComponent(lyricOpacity)
        ]
        ("♪ The music finds us here" as NSString).draw(in: rect, withAttributes: attributes)
    }
}
