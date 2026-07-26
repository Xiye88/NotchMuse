import AppKit
import ServiceManagement

enum AppPreferences {
    static let displayModeKey = "DisplayMode"
    static let positionKey = "LyricsPosition"
    static let notchStyleKey = "NotchStyle"
    static let colorPresetKey = "LyricsColorPreset"
    static let fontSizeKey = "LyricsFontSize"
    static let animationSpeedKey = "LyricsAnimationSpeed"
    static let opacityKey = "LyricsOpacity"
    static let displayTargetKey = "DisplayTarget"
    static let displayWidthKey = "DisplayWidth"
    static let customWidthKey = "CustomWidth"
    static let hasShownFirstLaunchGuideKey = "HasShownFirstLaunchGuide"
    static let languageKey = "AppLanguage"

    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .english
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

    static var fontSize: CGFloat {
        let stored = UserDefaults.standard.double(forKey: fontSizeKey)
        return stored == 0 ? NSFont.menuBarFont(ofSize: 0).pointSize : min(26, max(10, stored))
    }

    static var animationSpeed: CGFloat {
        let stored = UserDefaults.standard.double(forKey: animationSpeedKey)
        return stored == 0 ? 1 : min(2, max(0.5, stored))
    }

    static var opacity: CGFloat {
        let stored = UserDefaults.standard.double(forKey: opacityKey)
        return stored == 0 ? 1 : min(1, max(0.3, stored))
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
    private let fontSizeSlider = NSSlider(value: 13, minValue: 10, maxValue: 26, target: nil, action: nil)
    private let animationSpeedSlider = NSSlider(value: 1, minValue: 0.5, maxValue: 2, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 1, minValue: 0.3, maxValue: 1, target: nil, action: nil)
    private let fontSizeValue = NSTextField(labelWithString: "")
    private let animationSpeedValue = NSTextField(labelWithString: "")
    private let opacityValue = NSTextField(labelWithString: "")
    private let customWidthValue = NSTextField(labelWithString: "")
    private let launchAtLoginSwitch = NSSwitch()
    private let languagePopUp = NSPopUpButton()
    private let contentStack = NSStackView()
    private var positionRow: NSGridRow?
    private var notchStyleRow: NSGridRow?
    private var customWidthRow: NSGridRow?
    private let onSettingsChange: () -> Void

    init(onSettingsChange: @escaping () -> Void) {
        self.onSettingsChange = onSettingsChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("NotchMuse Settings")
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

        for preset in LyricsColorPreset.allCases {
            colorPopUp.addItem(withTitle: L10n.text(preset.rawValue))
            colorPopUp.lastItem?.image = swatch(BrandStyle.gradientColors(for: preset)[0])
        }
        colorPopUp.target = self
        colorPopUp.action = #selector(colorChanged)

        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged)
        fontSizeSlider.numberOfTickMarks = 17
        fontSizeSlider.allowsTickMarkValuesOnly = true
        animationSpeedSlider.target = self
        animationSpeedSlider.action = #selector(animationSpeedChanged)
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)
        for language in AppLanguage.allCases {
            languagePopUp.addItem(withTitle: language.displayName)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(sectionTitle(L10n.text("Display")))
        let displayGrid = grid([
            [label(L10n.text("Display Mode")), displayModeControl],
            [label(L10n.text("Status Bar Position")), positionControl],
            [label(L10n.text("Notch Style")), notchStyleControl],
            [label(L10n.text("Display Screen")), displayScreenControl()],
            [label(L10n.text("Lyrics Width")), widthControl],
            [label(L10n.text("Custom Width")), valueRow(slider: customWidthSlider, value: customWidthValue)]
        ])
        positionRow = displayGrid.row(at: 1)
        notchStyleRow = displayGrid.row(at: 2)
        customWidthRow = displayGrid.row(at: 5)
        contentStack.addArrangedSubview(displayGrid)
        contentStack.addArrangedSubview(separator())
        contentStack.addArrangedSubview(sectionTitle(L10n.text("Appearance")))
        let appearanceGrid = grid([
            [label(L10n.text("Lyrics Color")), colorPopUp],
            [label(L10n.text("Font Size")), valueRow(slider: fontSizeSlider, value: fontSizeValue)],
            [label(L10n.text("Animation Speed")), valueRow(slider: animationSpeedSlider, value: animationSpeedValue)],
            [label(L10n.text("Opacity")), valueRow(slider: opacitySlider, value: opacityValue)]
        ])
        contentStack.addArrangedSubview(appearanceGrid)
        contentStack.addArrangedSubview(separator())
        contentStack.addArrangedSubview(sectionTitle(L10n.text("General")))
        contentStack.addArrangedSubview(grid([
            [label(L10n.text("Language")), languagePopUp],
            [label(L10n.text("Launch at Login")), launchAtLoginSwitch]
        ]))

        guard let contentView = window?.contentView else { return }
        contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func label(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        return label
    }

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 14
        grid.columnSpacing = 18
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.widthAnchor.constraint(equalToConstant: 504).isActive = true
        return grid
    }

    private func valueRow(slider: NSSlider, value: NSTextField) -> NSView {
        value.alignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)
        value.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let stack = NSStackView(views: [slider, value])
        stack.orientation = .horizontal
        stack.spacing = 10
        return stack
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
        box.widthAnchor.constraint(equalToConstant: 504).isActive = true
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
        fontSizeSlider.doubleValue = Double(AppPreferences.fontSize)
        animationSpeedSlider.doubleValue = Double(AppPreferences.animationSpeed)
        opacitySlider.doubleValue = Double(AppPreferences.opacity)
        fontSizeValue.stringValue = "\(Int(fontSizeSlider.doubleValue)) pt"
        animationSpeedValue.stringValue = String(format: "%.1fx", animationSpeedSlider.doubleValue)
        opacityValue.stringValue = "\(Int(opacitySlider.doubleValue * 100))%"
        customWidthValue.stringValue = "\(Int(customWidthSlider.doubleValue)) pt"
        launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        languagePopUp.selectItem(at: AppLanguage.allCases.firstIndex(of: AppPreferences.language) ?? 0)
        updateControlAvailability()
    }

    private func save<T: RawRepresentable>(_ value: T, key: String) where T.RawValue == String {
        UserDefaults.standard.set(value.rawValue, forKey: key)
        onSettingsChange()
    }

    private func updateControlAvailability() {
        let statusBarMode = AppPreferences.displayMode == .statusBar
        positionRow?.isHidden = !statusBarMode
        notchStyleRow?.isHidden = statusBarMode
        customWidthRow?.isHidden = AppPreferences.displayWidth != .custom
        resizeWindowToFit()
    }

    private func resizeWindowToFit() {
        guard let window else { return }
        window.contentView?.layoutSubtreeIfNeeded()
        let oldTop = window.frame.maxY
        window.setContentSize(NSSize(width: 560, height: contentStack.fittingSize.height + 48))
        var frame = window.frame
        frame.origin.y = oldTop - frame.height
        window.setFrame(frame, display: true, animate: window.isVisible)
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
        customWidthValue.stringValue = "\(Int(customWidthSlider.doubleValue)) pt"
        onSettingsChange()
    }

    @objc private func colorChanged() {
        let presets = LyricsColorPreset.allCases
        guard presets.indices.contains(colorPopUp.indexOfSelectedItem) else { return }
        save(presets[colorPopUp.indexOfSelectedItem], key: AppPreferences.colorPresetKey)
    }

    @objc private func fontSizeChanged() {
        UserDefaults.standard.set(fontSizeSlider.doubleValue, forKey: AppPreferences.fontSizeKey)
        fontSizeValue.stringValue = "\(Int(fontSizeSlider.doubleValue)) pt"
        onSettingsChange()
    }

    @objc private func animationSpeedChanged() {
        UserDefaults.standard.set(animationSpeedSlider.doubleValue, forKey: AppPreferences.animationSpeedKey)
        animationSpeedValue.stringValue = String(format: "%.1fx", animationSpeedSlider.doubleValue)
        onSettingsChange()
    }

    @objc private func opacityChanged() {
        UserDefaults.standard.set(opacitySlider.doubleValue, forKey: AppPreferences.opacityKey)
        opacityValue.stringValue = "\(Int(opacitySlider.doubleValue * 100))%"
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
}
