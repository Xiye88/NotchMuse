import AppKit
import QuartzCore
import ServiceManagement

enum AppPreferences {
    static let displayModeKey = "DisplayMode"
    static let positionKey = "LyricsPosition"
    static let notchStyleKey = "NotchStyle"
    static let notchPlacementKey = "NotchPlacement"
    static let colorPresetKey = "LyricsColorPreset"
    static let customLyricsColorKey = "CustomLyricsColor"
    static let customLyricsEndColorKey = "CustomLyricsEndColor"
    static let fontSizeKey = "LyricsFontSize"
    static let animationSpeedKey = "LyricsAnimationSpeed"
    static let opacityKey = "LyricsOpacity"
    static let displayTargetKey = "DisplayTarget"
    static let displayWidthKey = "DisplayWidth"
    static let customWidthKey = "CustomWidth"
    static let statusBarOffsetKey = "StatusBarHorizontalOffset"
    static let hasShownFirstLaunchGuideKey = "HasShownFirstLaunchGuide"
    static let languageKey = "AppLanguage"
    static let playerSourceKey = "PlayerSource"
    static let playerStopBehaviorKey = "PlayerStopBehavior"
    static let notchBackgroundEnabledKey = "NotchBackgroundEnabled"
    static let notchBackgroundColorKey = "NotchBackgroundColor"
    static let notchBackgroundOpacityKey = "NotchBackgroundOpacity"
    static let notchBackgroundPaddingKey = "NotchBackgroundPadding"
    static let notchHideOnHoverKey = "NotchHideOnHover"
    static let showInDockKey = "ShowInDock"
    static let showMenuBarIconKey = "ShowMenuBarIcon"
    static let hiddenControlsNoticeKey = "HiddenControlsNoticeShown"
    static let bilingualLyricsKey = "BilingualLyricsEnabled"
    static var bilingualLyricsEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true &&
        UserDefaults.standard.bool(forKey: bilingualLyricsKey)
    }

    static var showInDock: Bool { showInDock(in: .standard) }

    static func showInDock(in defaults: UserDefaults) -> Bool {
        if let saved = defaults.object(forKey: showInDockKey) as? Bool { return saved }
        return defaults.object(forKey: hasShownFirstLaunchGuideKey) != nil
    }

    static func restorePreviewMenuBarIfNeeded(in defaults: UserDefaults, isPreview: Bool) {
        guard isPreview, !defaults.bool(forKey: "PreviewMenuBarInitialized") else { return }
        defaults.set(true, forKey: showMenuBarIconKey)
        defaults.set(true, forKey: "PreviewMenuBarInitialized")
    }

    static var showMenuBarIcon: Bool { showMenuBarIcon(in: .standard) }

    static func showMenuBarIcon(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: showMenuBarIconKey) as? Bool ?? true
    }

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
            ?? (Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
                ? nil : UserDefaults(suiteName: "local.menubarlyrics.app")?.string(forKey: positionKey))
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

    static var notchPlacement: NotchPlacement {
        NotchPlacement(rawValue: UserDefaults.standard.string(forKey: notchPlacementKey) ?? "") ?? .top
    }

    static var colorPreset: LyricsColorPreset {
        LyricsColorPreset(rawValue: UserDefaults.standard.string(forKey: colorPresetKey) ?? "") ?? .orange
    }

    static var customLyricsColor: NSColor {
        color(forKey: customLyricsColorKey) ?? BrandStyle.gradientColors[0]
    }

    static var customLyricsEndColor: NSColor {
        color(forKey: customLyricsEndColorKey) ?? .systemTeal
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

    static var statusBarOffset: CGFloat {
        min(200, max(-200, UserDefaults.standard.double(forKey: statusBarOffsetKey)))
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
        guard let stored = color(forKey: notchBackgroundColorKey) else { return NotchBackgroundPreset.softGray.color! }
        let oldDefault = NSColor(calibratedWhite: 0.36, alpha: 1)
        return stored.usingColorSpace(.deviceRGB) == oldDefault.usingColorSpace(.deviceRGB)
            ? NotchBackgroundPreset.softGray.color! : stored
    }

    static var notchBackgroundOpacity: CGFloat { notchBackgroundOpacity(in: .standard) }

    static func notchBackgroundOpacity(in defaults: UserDefaults) -> CGFloat {
        let stored = defaults.object(forKey: notchBackgroundOpacityKey) as? Double
        return min(1, max(0, stored.map { CGFloat($0) } ?? 0.82))
    }

    static var notchBackgroundPadding: CGFloat {
        let value = UserDefaults.standard.object(forKey: notchBackgroundPaddingKey) as? Double
        return min(120, max(0, value.map { CGFloat($0) } ?? fontSize * 2))
    }

    static func notchBackgroundPreset(in defaults: UserDefaults = .standard) -> NotchBackgroundPreset {
        guard let color = color(forKey: notchBackgroundColorKey, in: defaults) else { return .softGray }
        return NotchBackgroundPreset.matching(color)
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

enum NotchBackgroundPreset: String, CaseIterable {
    case orange = "Orange"
    case black = "Black"
    case white = "White"
    case softGray = "Soft Gray"
    case blue = "Blue"
    case custom = "Custom"

    var color: NSColor? {
        switch self {
        case .orange: NSColor(calibratedRed: 0.94, green: 0.58, blue: 0.38, alpha: 1)
        case .black: NSColor(calibratedWhite: 0.22, alpha: 1)
        case .white: NSColor(calibratedWhite: 0.94, alpha: 1)
        case .softGray: NSColor(calibratedWhite: 0.27, alpha: 1)
        case .blue: NSColor(calibratedRed: 0.38, green: 0.56, blue: 0.72, alpha: 1)
        case .custom: nil
        }
    }

    static func matching(_ color: NSColor) -> NotchBackgroundPreset {
        if color.usingColorSpace(.deviceRGB) == NSColor(calibratedWhite: 0.36, alpha: 1).usingColorSpace(.deviceRGB) {
            return .softGray
        }
        return allCases.first { preset in
            guard let presetColor = preset.color,
                  let lhs = presetColor.usingColorSpace(.deviceRGB),
                  let rhs = color.usingColorSpace(.deviceRGB) else { return false }
            return lhs == rhs
        } ?? .custom
    }
}

private func notchMuseAppIcon() -> NSImage {
    Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSImage()
}

enum PermissionFixKind: Equatable {
    case accessibility
    case automation
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let displayModeControl = NSSegmentedControl(labels: DisplayMode.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let positionControl = NSSegmentedControl(labels: LyricsPosition.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let notchStyleControl = NSSegmentedControl(labels: NotchStyle.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let notchPlacementControl = NSSegmentedControl(labels: NotchPlacement.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let displayTargetPopUp = NSPopUpButton()
    private let widthControl = NSSegmentedControl(labels: DisplayWidth.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let customWidthSlider = NSSlider(value: 500, minValue: 180, maxValue: 1000, target: nil, action: nil)
    private let statusBarOffsetSlider = NSSlider(value: 0, minValue: -200, maxValue: 200, target: nil, action: nil)
    private var colorButtons: [NSButton] = []
    private let colorModeControl = NSSegmentedControl(labels: [L10n.text("Solid"), L10n.text("Gradient")], trackingMode: .selectOne, target: nil, action: nil)
    private let solidPalette = NSStackView()
    private let gradientPalette = NSStackView()
    private let lyricsColorWell = NSColorWell()
    private let gradientStartWell = NSColorWell()
    private let lyricsColorEndWell = NSColorWell()
    private let fontSizeSlider = NSSlider(value: 13, minValue: 10, maxValue: 60, target: nil, action: nil)
    private let animationSpeedSlider = NSSlider(value: 1, minValue: 0.1, maxValue: 3, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 1, minValue: 0.1, maxValue: 1, target: nil, action: nil)
    private let opacityLabel = NSTextField(labelWithString: "")
    private let fontSizeValue = NSTextField(string: "")
    private let animationSpeedValue = NSTextField(string: "")
    private let opacityValue = NSTextField(string: "")
    private let customWidthValue = NSTextField(string: "")
    private let statusBarOffsetValue = NSTextField(string: "")
    private let launchAtLoginSwitch = NSSwitch()
    private let showInDockSwitch = NSSwitch()
    private let showMenuBarIconSwitch = NSSwitch()
    private let automaticUpdateSwitch = NSSwitch()
    private let automaticInstallSwitch = NSSwitch()
    private var announcementBanner: NSView?
    private var announcementTitleButton: NSButton?
    private var announcementUnreadDot: NSView?
    private var announcementObserver: NSObjectProtocol?
    private let bilingualLyricsSwitch = NSSwitch()
    private let languagePopUp = NSPopUpButton()
    private let appAppearanceControl = NSSegmentedControl(labels: AppAppearance.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let playerPopUp = NSPopUpButton()
    private let playerStopBehaviorPopUp = NSPopUpButton()
    private let notchBackgroundSwitch = NSSwitch()
    private let notchBackgroundPresetPopUp = NSPopUpButton()
    private let notchBackgroundColorWell = NSColorWell()
    private let notchBackgroundPaddingSlider = NSSlider(value: 40, minValue: 0, maxValue: 120, target: nil, action: nil)
    private let notchBackgroundPaddingValue = NSTextField(string: "")
    private let notchHideOnHoverSwitch = NSSwitch()
    private let contentStack = NSStackView()
    private var cards: [NSView] = []
    private let preview = SettingsPreviewView()
    private let previewModeControl = NSSegmentedControl(labels: DisplayMode.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let displayPage = NSStackView()
    private let appearancePage = NSStackView()
    private let generalPage = NSStackView()
    private var selectedPage: SettingsPage = .display
    private weak var settingsScrollView: SettingsScrollView?
    private var sidebarButtons: [SettingsPage: NSButton] = [:]
    private let vinylDeck = VinylDeckCardView()
    private let sidebarQuickActions = SettingsSidebarQuickActionsView()
    private var supportWindow: SupportWindowController?
    private var positionRow: NSGridRow?
    private var notchStyleRow: NSGridRow?
    private var notchPlacementRow: NSGridRow?
    private var customWidthRow: NSGridRow?
    private var statusBarOffsetRow: NSGridRow?
    private var notchBackgroundRow: NSGridRow?
    private var notchBackgroundColorRow: NSGridRow?
    private var notchHideOnHoverRow: NSGridRow?
    private let freeOrientation = NSSegmentedControl(labels: [L10n.text("Horizontal"), L10n.text("Vertical")], trackingMode: .selectOne, target: nil, action: nil)
    private let freeLock = NSSwitch()
    private let freePassThrough = NSSwitch()
    private var freeCard: NSView?
    private let liveStatusDot = NSView()
    private let liveStatusLabel = NSTextField(labelWithString: "")
    private let permissionFixButton = NSButton(title: "", target: nil, action: nil)
    private var activePermissionFix: PermissionFixKind?
    var onFreeLockChanged: (() -> Void)?
    var onDisplayModeSelected: (() -> Void)?
    private let onSettingsChange: () -> Void

    init(onSettingsChange: @escaping () -> Void) {
        self.onSettingsChange = onSettingsChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
            ? "NotchMuse Preview · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development")"
            : "NotchMuse"
        window.minSize = NSSize(width: 720, height: 540)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("NotchMuseSettings")
        let restoredFrame = window.frame
        super.init(window: window)
        buildContent()
        window.setFrame(restoredFrame, display: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        sync()
        AnnouncementManager.shared.refreshIfStale()
        updateAnnouncementBanner()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    #if DEBUG
    static func testModeControls() {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let keys = [AppPreferences.displayModeKey, AppPreferences.displayWidthKey, AppPreferences.colorPresetKey, AppPreferences.notchPlacementKey,
                    AppAppearanceController.preferenceKey, "NSWindow Frame NotchMuseSettings"] + FreeLyricsPreferences.keys
        let saved = keys.map { defaults.object(forKey: $0) }
        let savedAppearance = NSApp.appearance
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            NSApp.appearance = savedAppearance
        }
        defaults.set(DisplayMode.statusBar.rawValue, forKey: AppPreferences.displayModeKey)
        defaults.set(DisplayWidth.auto.rawValue, forKey: AppPreferences.displayWidthKey)
        let controller = SettingsWindowController(onSettingsChange: {})
        controller.sync()
        controller.previewModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: .notch)!
        controller.previewModeChanged()
        precondition(AppPreferences.displayMode == .notch, "Top mode selector must update actual display mode")
        precondition(controller.notchBackgroundRow?.isHidden == false, "Background toggle must be discoverable")
        precondition(controller.notchBackgroundColorRow?.isHidden == false, "Background colors must remain visible")
        precondition(controller.customWidthRow?.isHidden == false, "Width control must remain visible")
        precondition(!controller.customWidthSlider.isEnabled, "Preset width must disable custom input")
        controller.widthControl.selectedSegment = DisplayWidth.allCases.firstIndex(of: .custom)!
        controller.widthChanged()
        precondition(controller.customWidthSlider.isEnabled, "Custom width must enable input")
        for (index, placement) in NotchPlacement.allCases.enumerated() {
            controller.notchPlacementControl.selectedSegment = index
            controller.notchPlacementChanged()
            precondition(AppPreferences.notchPlacement == placement, "Placement must persist")
        }
        controller.preview.onModeClick?(.free)
        precondition(AppPreferences.displayMode == .free && controller.freeCard?.isHidden == false, "Free mode must be reachable from preview card")
        precondition(controller.notchPlacementRow?.isHidden == true, "Free mode must not expose fixed notch placement")
        controller.freeOrientation.selectedSegment = 1
        controller.freeLock.state = .on
        controller.freePassThrough.state = .on
        controller.freeOptionsChanged()
        precondition(FreeLyricsPreferences.vertical && UserDefaults.standard.bool(forKey: FreeLyricsPreferences.lockedKey) && UserDefaults.standard.bool(forKey: FreeLyricsPreferences.passThroughKey), "Independent interaction preferences persist")
        controller.preview.onModeClick?(.notch)
        controller.colorModeControl.selectedSegment = 1
        controller.colorModeChanged()
        precondition(AppPreferences.colorPreset.isGradient && controller.solidPalette.isHidden && !controller.gradientPalette.isHidden,
                     "Gradient mode shows only gradient controls")
        controller.colorModeControl.selectedSegment = 0
        controller.colorModeChanged()
        controller.colorChanged(controller.colorButtons[1])
        precondition(AppPreferences.colorPreset == .red && !controller.solidPalette.isHidden && controller.gradientPalette.isHidden,
                     "Solid color selection remains solid in Notch mode")
        controller.previewModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: .statusBar)!
        controller.displayModeChanged()
        precondition(AppPreferences.displayMode == .statusBar && controller.preview.mode == .statusBar, "Mode selector must stay synchronized with preview")
        controller.preview.onModeClick?(.notch)
        precondition(AppPreferences.displayMode == .notch && controller.previewModeControl.selectedSegment == DisplayMode.allCases.firstIndex(of: .notch)!,
                     "Preview card must update mode selector")
        let lyricsKeys = [AppPreferences.colorPresetKey, AppPreferences.customLyricsColorKey,
                          AppPreferences.customLyricsEndColorKey, AppPreferences.notchBackgroundColorKey,
                          AppPreferences.notchBackgroundEnabledKey, AppPreferences.notchBackgroundOpacityKey]
        let lyricsBefore = lyricsKeys.map { defaults.object(forKey: $0) as? NSObject }
        let testFrame = NSRect(x: 90, y: 90, width: 1100, height: 800)
        controller.show()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        controller.window!.setFrame(testFrame, display: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        let manualFrame = controller.window!.frame
        precondition(manualFrame == testFrame, "Manual Settings size must be accepted: \(manualFrame)")
        for (index, appearance) in AppAppearance.allCases.enumerated() {
            controller.appAppearanceControl.selectedSegment = index
            controller.appAppearanceChanged()
            precondition(AppAppearanceController.selection == appearance, "App appearance must persist")
            precondition(NSApp.appearance?.name == appearance.appearance?.name, "NSApp must apply selected appearance")
            for page in SettingsPage.allCases {
                controller.pageChanged(controller.sidebarButtons[page]!)
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
                precondition(controller.window!.frame == manualFrame, "Page \(page) must preserve exact window frame: \(controller.window!.frame) != \(manualFrame)")
            }
        }
        let lyricsAfter = lyricsKeys.map { defaults.object(forKey: $0) as? NSObject }
        precondition(lyricsBefore == lyricsAfter, "App appearance must not change lyrics colors or background")
        precondition(controller.launchAtLoginSwitch.isEnabled, "Login toggle must remain enabled, including Preview")
        precondition(L10n.text("Launch at Login", language: .simplifiedChinese) == "开机自动启动", "Login label must match requested Chinese")
        var surfaceColors: [CGFloat] = []
        for name: NSAppearance.Name in [.aqua, .darkAqua] {
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                surfaceColors.append(AppearanceSurfaceColors.card.usingColorSpace(.deviceRGB)!.redComponent)
            }
        }
        precondition(surfaceColors[0] > surfaceColors[1], "Cards must adapt between Light and Dark")
        controller.window!.saveFrame(usingName: "NotchMuseSettings")
        let restoredController = SettingsWindowController(onSettingsChange: {})
        precondition(restoredController.window!.frame == manualFrame, "Manual window frame must restore")
        precondition(restoredController.window!.appearance == nil, "Settings must inherit global appearance")
        restoredController.window?.close()
        controller.window?.close()
        precondition(SupportWindowController().window?.contentView is NSStackView, "Support page must build")
        print("Settings interaction self-test passed")
    }
    #endif

    private func buildContent() {
        displayModeControl.target = self
        displayModeControl.action = #selector(displayModeChanged)
        positionControl.target = self
        positionControl.action = #selector(positionChanged)
        notchStyleControl.target = self
        notchStyleControl.action = #selector(notchStyleChanged)
        notchPlacementControl.target = self
        notchPlacementControl.action = #selector(notchPlacementChanged)
        colorModeControl.target = self
        colorModeControl.action = #selector(colorModeChanged)

        for target in DisplayTarget.allCases {
            displayTargetPopUp.addItem(withTitle: L10n.text(target.rawValue))
        }
        displayTargetPopUp.target = self
        displayTargetPopUp.action = #selector(displayTargetChanged)
        widthControl.target = self
        widthControl.action = #selector(widthChanged)
        customWidthSlider.target = self
        customWidthSlider.action = #selector(customWidthChanged)
        customWidthSlider.isContinuous = true
        configureNumericField(customWidthValue, action: #selector(customWidthEntered))
        statusBarOffsetSlider.target = self
        statusBarOffsetSlider.action = #selector(statusBarOffsetChanged)
        statusBarOffsetSlider.isContinuous = true
        statusBarOffsetSlider.toolTip = L10n.text("Offset is clamped to safe menu bar space; Compact or smaller Custom widths allow more movement.")
        configureNumericField(statusBarOffsetValue, action: #selector(statusBarOffsetEntered))

        lyricsColorWell.target = self
        lyricsColorWell.action = #selector(lyricsColorChanged)
        lyricsColorWell.isContinuous = true
        gradientStartWell.target = self
        gradientStartWell.action = #selector(gradientStartChanged)
        gradientStartWell.isContinuous = true
        lyricsColorEndWell.target = self
        lyricsColorEndWell.action = #selector(lyricsColorEndChanged)
        lyricsColorEndWell.isContinuous = true

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
        notchBackgroundSwitch.target = self
        notchBackgroundSwitch.action = #selector(notchBackgroundToggled)
        for preset in NotchBackgroundPreset.allCases {
            notchBackgroundPresetPopUp.addItem(withTitle: L10n.text(preset.rawValue))
        }
        notchBackgroundPresetPopUp.target = self
        notchBackgroundPresetPopUp.action = #selector(notchBackgroundPresetChanged)
        notchBackgroundColorWell.target = self
        notchBackgroundColorWell.action = #selector(notchBackgroundColorChanged)
        notchBackgroundColorWell.isContinuous = true
        notchBackgroundPaddingSlider.target = self
        notchBackgroundPaddingSlider.action = #selector(notchBackgroundPaddingChanged)
        notchBackgroundPaddingSlider.isContinuous = true
        configureNumericField(notchBackgroundPaddingValue, action: #selector(notchBackgroundPaddingEntered))
        notchHideOnHoverSwitch.target = self
        notchHideOnHoverSwitch.action = #selector(notchHideOnHoverChanged)
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)
        showInDockSwitch.target = self
        showInDockSwitch.action = #selector(showInDockChanged)
        showMenuBarIconSwitch.target = self
        showMenuBarIconSwitch.action = #selector(showMenuBarIconChanged)
        automaticUpdateSwitch.target = self
        automaticUpdateSwitch.action = #selector(automaticUpdateChanged)
        automaticInstallSwitch.target = self
        automaticInstallSwitch.action = #selector(automaticInstallChanged)
        bilingualLyricsSwitch.target = self
        bilingualLyricsSwitch.action = #selector(bilingualLyricsChanged)
        for language in AppLanguage.allCases {
            languagePopUp.addItem(withTitle: language.displayName)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        appAppearanceControl.target = self
        appAppearanceControl.action = #selector(appAppearanceChanged)
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
        previewModeControl.action = #selector(displayModeChanged)
        previewModeControl.selectedSegment = 0
        preview.onModeClick = { [weak self] mode in
            guard let self else { return }
            self.previewModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: mode) ?? 0
            self.displayModeChanged()
        }
        let displayGrid = grid([
            [label(L10n.text("Status Bar Position")), positionControl],
            [label(L10n.text("Horizontal Offset")), valueRow(slider: statusBarOffsetSlider, value: statusBarOffsetValue, unit: "pt")],
            [label(L10n.text("Notch Style")), notchStyleControl],
            [label(L10n.text("Notch Position")), notchPlacementControl],
            [label(L10n.text("Display Screen")), displayScreenControl()],
            [label(L10n.text("Lyrics Width")), widthControl],
            [label(L10n.text("Custom Width")), valueRow(slider: customWidthSlider, value: customWidthValue, unit: "pt")]
        ])
        positionRow = displayGrid.row(at: 0)
        statusBarOffsetRow = displayGrid.row(at: 1)
        notchStyleRow = displayGrid.row(at: 2)
        notchPlacementRow = displayGrid.row(at: 3)
        customWidthRow = displayGrid.row(at: 6)
        configure(page: displayPage)
        configure(page: appearancePage)
        let appearanceGrid = grid([
            [label(L10n.text("Lyrics Color")), colorPalette()],
            [label(L10n.text("Font Size")), valueRow(slider: fontSizeSlider, value: fontSizeValue, unit: "pt")],
            [label(L10n.text("Animation Speed")), valueRow(slider: animationSpeedSlider, value: animationSpeedValue, unit: "×")],
            [opacityLabel, valueRow(slider: opacitySlider, value: opacityValue, unit: "%")],
            [label(L10n.text("Notch Background")), notchBackgroundSwitch],
            [label(L10n.text("Background Color")), backgroundColorControls()],
            [label(L10n.text("Background Side Padding")), valueRow(slider: notchBackgroundPaddingSlider, value: notchBackgroundPaddingValue, unit: "pt")],
            [label(L10n.text("Hide on Hover")), notchHideOnHoverSwitch]
        ])
        notchBackgroundRow = appearanceGrid.row(at: 4)
        notchBackgroundColorRow = appearanceGrid.row(at: 5)
        notchHideOnHoverRow = appearanceGrid.row(at: 7)
        appearancePage.addArrangedSubview(card(content: cardBody(title: "Appearance", subtitle: "Customize the look of your lyrics.", grid: appearanceGrid, trailing: resetButton(for: .appearance))))
        appearancePage.addArrangedSubview(quickPresetsCard())
        configure(page: generalPage)
        var generalRows: [[NSView]] = [
            [label(L10n.text("Music Player")), playerPopUp],
            [label(L10n.text("When Player Stops")), playerStopBehaviorPopUp],
            [label(L10n.text("Launch at Login")), launchAtLoginSwitch],
            [label(L10n.text("Show in Dock")), showInDockSwitch],
            [label(L10n.text("Show Menu Bar Icon")), showMenuBarIconSwitch],
            [label(L10n.text("Auto-Check Updates")), automaticUpdateSwitch],
            [label(L10n.text("Auto-Install Updates")), automaticInstallSwitch],
            [label(L10n.text("Appearance Mode")), appAppearanceControl],
            [label(L10n.text("Language")), languagePopUp]
        ]
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            generalRows.append([label(L10n.text("Bilingual Lyrics")), bilingualLyricsSwitch])
        }
        let generalGrid = grid(generalRows)
        generalPage.addArrangedSubview(card(content: cardBody(title: "General", subtitle: "Player and system behavior.", grid: generalGrid, trailing: resetButton(for: .general))))
        let updateHelp = NSTextField(wrappingLabelWithString: L10n.text("Checks at launch and daily while enabled. Automatic installation requires automatic checks. Updates apply at launch; while running, downloads prompt you to restart. Turning this off does not cancel an installation already prepared."))
        updateHelp.font = .systemFont(ofSize: 11)
        updateHelp.textColor = .secondaryLabelColor
        generalPage.addArrangedSubview(updateHelp)
        let checkUpdates = NSButton(title: L10n.text("Check for Updates…"), target: self, action: #selector(checkForUpdates))
        checkUpdates.isEnabled = UpdateController.shared.isAvailable
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        let versionPrefix = AppPreferences.language == .simplifiedChinese ? "当前版本：" : "Version "
        let channelPrefix = isPreview ? "Preview " : ""
        let buildSuffix = buildNumber.isEmpty ? "" : " (Build \(buildNumber))"
        let versionLabel = NSTextField(labelWithString: "\(versionPrefix)\(channelPrefix)v\(shortVersion)\(buildSuffix)")
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        let updateActionRow = NSStackView(views: [checkUpdates, versionLabel])
        updateActionRow.orientation = .horizontal
        updateActionRow.alignment = .centerY
        updateActionRow.spacing = 12
        generalPage.addArrangedSubview(updateActionRow)

        displayPage.addArrangedSubview(card(content: cardBody(title: "Display", subtitle: L10n.text("Choose how and where lyrics appear."), grid: displayGrid, trailing: resetButton(for: .display))))
        freeOrientation.target = self
        freeOrientation.action = #selector(freeOptionsChanged)
        freeLock.target = self
        freeLock.action = #selector(freeLockChanged)
        freePassThrough.target = self
        freePassThrough.action = #selector(freeOptionsChanged)
        let freeGrid = grid([
            [label(L10n.text("Orientation")), freeOrientation],
            [label(L10n.text("Lock Position")), freeLock],
            [label(L10n.text("Click Through")), freePassThrough],
            [NSButton(title: L10n.text("Move Lyrics"), target: self, action: #selector(editFreeLyrics)),
             NSButton(title: L10n.text("Reset Position"), target: self, action: #selector(resetFreeLyrics))]
        ])
        let freeCard = card(content: cardBody(title: "Free Position", subtitle: "Use Move Lyrics to edit, even when locked or click-through is on.", grid: freeGrid, trailing: NSView()))
        self.freeCard = freeCard
        displayPage.addArrangedSubview(freeCard)

        guard let contentView = window?.contentView else { return }
        let backdrop = SettingsBackdropView(frame: contentView.bounds)
        backdrop.onAppearanceChange = { [weak self] in self?.updateSidebarSelection() }
        backdrop.autoresizingMask = [.width, .height]
        contentView.addSubview(backdrop)
        let sidebar = NSStackView()
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 4
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        let brandRow = sidebarTitle()
        sidebar.addArrangedSubview(brandRow)
        brandRow.widthAnchor.constraint(equalToConstant: 200).isActive = true
        sidebar.setCustomSpacing(14, after: brandRow)

        vinylDeck.translatesAutoresizingMaskIntoConstraints = false
        vinylDeck.widthAnchor.constraint(equalToConstant: 200).isActive = true
        vinylDeck.heightAnchor.constraint(equalToConstant: 78).isActive = true
        sidebar.addArrangedSubview(vinylDeck)
        sidebar.setCustomSpacing(16, after: vinylDeck)

        let sectionHeader = NSTextField(labelWithString: "")
        sectionHeader.attributedStringValue = NSAttributedString(
            string: "DECK",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .kern: 1.2
            ]
        )
        let sectionWrap = NSStackView(views: [sectionHeader])
        sectionWrap.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 2, right: 0)
        sidebar.addArrangedSubview(sectionWrap)
        sidebar.setCustomSpacing(6, after: sectionWrap)
        for page in SettingsPage.allCases {
            let button = sidebarButton(for: page)
            sidebarButtons[page] = button
            sidebar.addArrangedSubview(button)
        }
        updateSidebarSelection()
        let sidebarPanel = HiFiSidebarView()
        sidebarPanel.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebar)
        let sidebarDivider = AppearanceSurfaceView()
        sidebarDivider.wantsLayer = true
        sidebarDivider.surfaceColor = AppearanceSurfaceColors.border
        sidebarDivider.surfaceBorderColor = .clear
        sidebarDivider.translatesAutoresizingMaskIntoConstraints = false
        sidebarQuickActions.onThemeToggle = { [weak self] appearance in
            self?.selectAppAppearance(AppAppearanceController.selection.toggled(for: appearance))
        }
        sidebarQuickActions.onSupport = { [weak self] in self?.showSupport() }
        sidebarQuickActions.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebarQuickActions)

        let previewHeader = NSStackView(views: [sectionTitle(L10n.text("Live Preview")), previewModeControl])
        previewHeader.orientation = .horizontal
        previewHeader.distribution = .equalSpacing
        previewHeader.alignment = .centerY
        let previewContents = NSStackView(views: [previewHeader, preview])
        previewContents.orientation = .vertical
        previewContents.spacing = 16
        let previewCard = card(content: previewContents)
        preview.widthAnchor.constraint(equalTo: previewCard.widthAnchor, constant: -40).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 196).isActive = true
        previewHeader.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let statusStrip = makeLiveStatusStrip()
        contentStack.addArrangedSubview(statusStrip)
        statusStrip.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        contentStack.addArrangedSubview(previewCard)
        contentStack.addArrangedSubview(displayPage)
        contentStack.addArrangedSubview(appearancePage)
        let banner = makeAnnouncementBanner()
        announcementBanner = banner
        contentStack.insertArrangedSubview(banner, at: 0)
        banner.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        updateAnnouncementBanner()
        announcementObserver = NotificationCenter.default.addObserver(forName: AnnouncementManager.notification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAnnouncementBanner() }
        }
        contentStack.addArrangedSubview(generalPage)
        appearancePage.isHidden = true
        generalPage.isHidden = true
        let scrollView = SettingsScrollView()
        settingsScrollView = scrollView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedSettingsDocumentView()
        document.addSubview(contentStack)
        scrollView.documentView = document
        contentView.addSubview(sidebarPanel)
        contentView.addSubview(sidebarDivider)
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate(cards.map { $0.widthAnchor.constraint(equalTo: contentStack.widthAnchor) } + [
            sidebarPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebarPanel.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarPanel.widthAnchor.constraint(equalToConstant: 224),
            sidebarDivider.leadingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor),
            sidebarDivider.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarDivider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarDivider.widthAnchor.constraint(equalToConstant: 1),
            sidebar.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 12),
            sidebar.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -12),
            sidebar.topAnchor.constraint(equalTo: sidebarPanel.topAnchor, constant: 40),
            sidebarQuickActions.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 12),
            sidebarQuickActions.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -12),
            sidebarQuickActions.bottomAnchor.constraint(equalTo: sidebarPanel.bottomAnchor, constant: -12),
            sidebarQuickActions.heightAnchor.constraint(equalToConstant: 36),
            scrollView.leadingAnchor.constraint(equalTo: sidebarDivider.trailingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            contentStack.topAnchor.constraint(equalTo: document.topAnchor),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor, constant: -16)
        ])
        DispatchQueue.main.async { scrollView.hideIdleScroller() }
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
        let iconImage = NSApp.applicationIconImage ?? notchMuseAppIcon()
        let icon = NSImageView(image: iconImage)
        icon.setAccessibilityLabel("NotchMuse")
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 5
        icon.layer?.cornerCurve = .continuous
        icon.layer?.masksToBounds = true
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let title = NSTextField(labelWithString: "NotchMuse")
        title.font = .systemFont(ofSize: 12.5, weight: .semibold)
        title.textColor = .labelColor

        let leftStack = NSStackView(views: [icon, title])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 7

        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9"
        let versionPill = AppearanceSurfaceView()
        versionPill.wantsLayer = true
        versionPill.surfaceColor = AppearanceSurfaceColors.card
        versionPill.surfaceBorderColor = AppearanceSurfaceColors.border
        versionPill.layer?.cornerRadius = 5
        versionPill.layer?.cornerCurve = .continuous
        versionPill.layer?.borderWidth = 0.5
        versionPill.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "v\(shortVersion)")
        versionLabel.font = .monospacedSystemFont(ofSize: 9.5, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionPill.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            versionLabel.leadingAnchor.constraint(equalTo: versionPill.leadingAnchor, constant: 6),
            versionLabel.trailingAnchor.constraint(equalTo: versionPill.trailingAnchor, constant: -6),
            versionLabel.topAnchor.constraint(equalTo: versionPill.topAnchor, constant: 2),
            versionLabel.bottomAnchor.constraint(equalTo: versionPill.bottomAnchor, constant: -2)
        ])

        let row = NSStackView(views: [leftStack, versionPill])
        row.orientation = .horizontal
        row.distribution = .equalSpacing
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 2)
        return row
    }

    private func sidebarButton(for page: SettingsPage) -> NSButton {
        let button = SidebarNavButton(page: page, target: self, action: #selector(pageChanged))
        button.identifier = NSUserInterfaceItemIdentifier(page.rawValue)
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.toolTip = L10n.text(page.help)
        return button
    }

    private func card(content: NSView) -> NSView {
        let box = AppearanceSurfaceView()
        box.wantsLayer = true
        box.surfaceColor = AppearanceSurfaceColors.card
        box.layer?.borderWidth = 0.5
        box.layer?.cornerRadius = 10
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14)
        ])
        box.translatesAutoresizingMaskIntoConstraints = false
        cards.append(box)
        return box
    }

    private func cardBody(title: String, subtitle: String, grid: NSGridView, trailing: NSView) -> NSStackView {
        let header = cardHeader(title: title, subtitle: subtitle, trailing: trailing)
        let body = NSStackView(views: [header, grid])
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 14
        header.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        grid.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        return body
    }

    private func cardHeader(title: String, subtitle: String, trailing: NSView) -> NSStackView {
        let heading = NSTextField(labelWithString: L10n.text(title))
        heading.font = .systemFont(ofSize: 13.5, weight: .semibold)
        heading.textColor = .labelColor
        heading.setContentCompressionResistancePriority(.required, for: .vertical)
        let header = NSStackView(views: [heading, trailing])
        header.orientation = .horizontal
        header.distribution = .equalSpacing
        header.alignment = .centerY
        return header
    }

    private func resetButton(for page: SettingsPage) -> NSButton {
        let btn = NSButton(title: L10n.text("Restore Defaults"), target: self, action: #selector(resetSection))
        btn.controlSize = .small
        return btn
    }

    private func quickPresetsCard() -> NSView {
        let entries: [(title: String, sample: String, color: NSColor)] = [
            ("Warm Orange", "♪ Warm", .systemOrange),
            ("Fresh Minimal", "♪ Minimal", .white),
            ("Dreamy Soft", "♪ Soft", .systemPurple),
            ("Pure", "♪ Pure", .systemGreen)
        ]
        let tiles = entries.enumerated().map { index, entry in
            let tile = AppearanceSurfaceView()
            tile.wantsLayer = true
            tile.surfaceColor = AppearanceSurfaceColors.adaptive(
                light: NSColor(calibratedWhite: 0.14, alpha: 0.90),
                dark: NSColor(calibratedWhite: 1.0, alpha: 0.06)
            )
            tile.surfaceBorderColor = AppearanceSurfaceColors.border
            tile.layer?.borderWidth = 0.5
            tile.layer?.cornerRadius = 8
            tile.widthAnchor.constraint(greaterThanOrEqualToConstant: 108).isActive = true
            tile.heightAnchor.constraint(equalToConstant: 56).isActive = true
            let sampleLabel = NSTextField(labelWithString: entry.sample)
            sampleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            sampleLabel.textColor = entry.color
            let title = NSTextField(labelWithString: L10n.text(entry.title))
            title.font = .systemFont(ofSize: 10.5, weight: .regular)
            title.textColor = NSColor.white.withAlphaComponent(0.72)
            let content = NSStackView(views: [sampleLabel, title])
            content.orientation = .vertical
            content.alignment = .centerX
            content.spacing = 3
            tile.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                content.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                content.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
            ])
            let button = NSButton(title: "", target: self, action: #selector(presetButtonChanged))
            button.tag = index + 1
            button.isBordered = false
            button.setAccessibilityLabel(L10n.text(entry.title))
            tile.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
                button.topAnchor.constraint(equalTo: tile.topAnchor),
                button.bottomAnchor.constraint(equalTo: tile.bottomAnchor)
            ])
            return tile
        }
        let row = NSStackView(views: tiles)
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.setHuggingPriority(.defaultLow, for: .horizontal)
        row.spacing = 10
        let contents = NSStackView(views: [sectionTitle(L10n.text("Quick Presets")), row])
        contents.orientation = .vertical
        contents.alignment = .leading
        contents.spacing = 10
        contents.setHuggingPriority(.defaultLow, for: .horizontal)
        row.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true
        return card(content: contents)
    }

    private func label(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 18
        grid.columnSpacing = 20
        grid.column(at: 0).width = 145
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        return grid
    }

    private func valueRow(slider: NSSlider, value: NSTextField, unit: String) -> NSView {
        value.alignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)
        value.widthAnchor.constraint(equalToConstant: 58).isActive = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
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

    private func colorPalette() -> NSView {
        let presets = LyricsColorPreset.solidPresets + LyricsColorPreset.gradientPresets
        let buttons = presets.enumerated().map { index, preset in
            let colors = BrandStyle.gradientColors(for: preset)
            let button = NSButton(image: swatch(preset.isGradient ? colors : [colors[min(1, colors.count - 1)]]), target: self, action: #selector(colorChanged(_:)))
            button.isBordered = false
            button.tag = index
            button.toolTip = L10n.text(preset.rawValue)
            button.setAccessibilityLabel(L10n.text(preset.rawValue))
            button.wantsLayer = true
            button.layer?.cornerRadius = 18
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            return button
        }
        colorButtons = buttons
        lyricsColorWell.colorWellStyle = .minimal
        gradientStartWell.colorWellStyle = .minimal
        lyricsColorEndWell.colorWellStyle = .minimal
        lyricsColorWell.toolTip = L10n.text("Custom Color / Gradient Start")
        lyricsColorWell.widthAnchor.constraint(equalToConstant: 32).isActive = true
        gradientStartWell.toolTip = L10n.text("Custom Gradient Start")
        gradientStartWell.widthAnchor.constraint(equalToConstant: 32).isActive = true
        lyricsColorEndWell.toolTip = L10n.text("Custom Gradient End")
        lyricsColorEndWell.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let solidCurated: [NSView] = Array(buttons.prefix(8)) + [lyricsColorWell]
        let solidRow = NSStackView(views: solidCurated)
        solidRow.orientation = .horizontal
        solidRow.alignment = .centerY
        solidRow.spacing = 6
        solidPalette.orientation = .vertical
        solidPalette.alignment = .leading
        solidPalette.addArrangedSubview(solidRow)

        let gradStart = LyricsColorPreset.solidPresets.count
        let gradCurated: [NSView] = Array(buttons[gradStart..<min(gradStart + 8, buttons.count)]) + [gradientStartWell, lyricsColorEndWell]
        let gradRow = NSStackView(views: gradCurated)
        gradRow.orientation = .horizontal
        gradRow.alignment = .centerY
        gradRow.spacing = 6
        gradientPalette.orientation = .vertical
        gradientPalette.alignment = .leading
        gradientPalette.addArrangedSubview(gradRow)
        let palette = NSStackView(views: [colorModeControl, solidPalette, gradientPalette])
        palette.orientation = .vertical
        palette.alignment = .leading
        palette.spacing = 8
        return palette
    }

    private func backgroundColorControls() -> NSView {
        notchBackgroundPresetPopUp.widthAnchor.constraint(equalToConstant: 160).isActive = true
        notchBackgroundPresetPopUp.toolTip = L10n.text("Choose a preset or Custom")
        notchBackgroundColorWell.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let row = NSStackView(views: [notchBackgroundPresetPopUp, notchBackgroundColorWell])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.setAccessibilityLabel(L10n.text("Background Color"))
        return row
    }

    private func swatch(_ colors: [NSColor]) -> NSImage {
        let image = NSImage(size: NSSize(width: 30, height: 30))
        image.lockFocus()
        let circle = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 24, height: 24))
        circle.addClip()
        if colors.count > 1 {
            NSGradient(colors: colors)?.draw(in: NSRect(x: 3, y: 3, width: 24, height: 24), angle: 0)
        } else {
            (colors.first ?? .white).setFill()
            circle.fill()
        }
        NSColor.black.withAlphaComponent(0.12).setStroke()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 24, height: 24)).stroke()
        image.unlockFocus()
        return image
    }

    func refresh() { sync(); updatePreview() }

    private func sync() {
        displayModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: AppPreferences.displayMode) ?? 0
        previewModeControl.selectedSegment = displayModeControl.selectedSegment
        preview.mode = AppPreferences.displayMode
        freeOrientation.selectedSegment = FreeLyricsPreferences.vertical ? 1 : 0
        freeLock.state = UserDefaults.standard.bool(forKey: FreeLyricsPreferences.lockedKey) ? .on : .off
        freePassThrough.state = UserDefaults.standard.bool(forKey: FreeLyricsPreferences.passThroughKey) ? .on : .off
        positionControl.selectedSegment = LyricsPosition.allCases.firstIndex(of: AppPreferences.position) ?? 1
        notchStyleControl.selectedSegment = NotchStyle.allCases.firstIndex(of: AppPreferences.notchStyle) ?? 0
        notchPlacementControl.selectedSegment = NotchPlacement.allCases.firstIndex(of: AppPreferences.notchPlacement) ?? 0
        colorModeControl.selectedSegment = AppPreferences.colorPreset.isGradient ? 1 : 0
        displayTargetPopUp.selectItem(at: DisplayTarget.allCases.firstIndex(of: AppPreferences.displayTarget) ?? 0)
        widthControl.selectedSegment = DisplayWidth.allCases.firstIndex(of: AppPreferences.displayWidth) ?? 0
        customWidthSlider.doubleValue = Double(AppPreferences.customWidth)
        statusBarOffsetSlider.doubleValue = Double(AppPreferences.statusBarOffset)
        lyricsColorWell.color = AppPreferences.customLyricsColor
        gradientStartWell.color = AppPreferences.customLyricsColor
        lyricsColorEndWell.color = AppPreferences.customLyricsEndColor
        updateCustomColorSwatch()
        fontSizeSlider.doubleValue = Double(AppPreferences.fontSize)
        animationSpeedSlider.doubleValue = Double(AppPreferences.animationSpeed)
        opacitySlider.doubleValue = Double(AppPreferences.opacity)
        notchBackgroundSwitch.state = AppPreferences.notchBackgroundEnabled ? .on : .off
        notchBackgroundPresetPopUp.selectItem(at: NotchBackgroundPreset.allCases.firstIndex(of: AppPreferences.notchBackgroundPreset()) ?? 1)
        notchBackgroundColorWell.color = AppPreferences.notchBackgroundColor
        notchBackgroundPaddingSlider.doubleValue = Double(AppPreferences.notchBackgroundPadding)
        notchBackgroundPaddingValue.stringValue = String(format: "%.0f", notchBackgroundPaddingSlider.doubleValue)
        notchHideOnHoverSwitch.state = AppPreferences.notchHideOnHover ? .on : .off
        fontSizeValue.stringValue = String(format: "%.0f", fontSizeSlider.doubleValue)
        animationSpeedValue.stringValue = String(format: "%.1f", animationSpeedSlider.doubleValue)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        customWidthValue.stringValue = String(format: "%.0f", customWidthSlider.doubleValue)
        statusBarOffsetValue.stringValue = String(format: "%.0f", statusBarOffsetSlider.doubleValue)
        launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginSwitch.isEnabled = true
        appAppearanceControl.selectedSegment = AppAppearance.allCases.firstIndex(of: AppAppearanceController.selection)!
        sidebarQuickActions.updateThemeButton()
        showInDockSwitch.state = AppPreferences.showInDock ? .on : .off
        showMenuBarIconSwitch.state = AppPreferences.showMenuBarIcon ? .on : .off
        automaticUpdateSwitch.state = UpdateController.shared.automaticallyChecksForUpdates ? .on : .off
        automaticUpdateSwitch.isEnabled = UpdateController.shared.isAvailable
        automaticInstallSwitch.state = UpdateController.shared.automaticallyDownloadsUpdates ? .on : .off
        bilingualLyricsSwitch.state = AppPreferences.bilingualLyricsEnabled ? .on : .off
        automaticInstallSwitch.isEnabled = UpdateController.shared.isAvailable && UpdateController.shared.allowsAutomaticUpdates
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
        opacityLabel.font = .systemFont(ofSize: 13, weight: .medium)
        opacityLabel.stringValue = L10n.text(statusBarMode ? "Lyrics Opacity" : "Background Opacity")
        opacitySlider.minValue = statusBarMode ? 0.1 : 0
        opacitySlider.doubleValue = Double(statusBarMode ? AppPreferences.opacity : AppPreferences.notchBackgroundOpacity)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        positionRow?.isHidden = !statusBarMode
        statusBarOffsetRow?.isHidden = !statusBarMode
        notchStyleRow?.isHidden = statusBarMode
        notchPlacementRow?.isHidden = AppPreferences.displayMode != .notch
        freeCard?.isHidden = AppPreferences.displayMode != .free
        solidPalette.isHidden = colorModeControl.selectedSegment == 1
        gradientPalette.isHidden = colorModeControl.selectedSegment != 1
        customWidthRow?.isHidden = false
        customWidthSlider.isEnabled = AppPreferences.displayWidth == .custom
        customWidthValue.isEnabled = customWidthSlider.isEnabled
        notchBackgroundRow?.isHidden = false
        notchBackgroundColorRow?.isHidden = false
        notchBackgroundColorWell.isHidden = NotchBackgroundPreset.allCases.indices.contains(notchBackgroundPresetPopUp.indexOfSelectedItem)
            ? NotchBackgroundPreset.allCases[notchBackgroundPresetPopUp.indexOfSelectedItem] != .custom
            : true
        notchHideOnHoverRow?.isHidden = statusBarMode
    }

    @objc private func freeLockChanged() {
        freeOptionsChanged()
        onFreeLockChanged?()
    }

    @objc private func freeOptionsChanged() {
        UserDefaults.standard.set(freeOrientation.selectedSegment == 1, forKey: FreeLyricsPreferences.verticalKey)
        UserDefaults.standard.set(freeLock.state == .on, forKey: FreeLyricsPreferences.lockedKey)
        UserDefaults.standard.set(freePassThrough.state == .on, forKey: FreeLyricsPreferences.passThroughKey)
        onSettingsChange()
        updatePreview()
    }

    @objc private func editFreeLyrics() {
        NotificationCenter.default.post(name: FreeLyricsPreferences.editNotification, object: nil)
    }

    @objc private func resetFreeLyrics() {
        NotificationCenter.default.post(name: FreeLyricsPreferences.resetNotification, object: nil)
    }

    @objc private func displayModeChanged() {
        let modes = DisplayMode.allCases
        guard modes.indices.contains(previewModeControl.selectedSegment) else { return }
        let selected = modes[previewModeControl.selectedSegment]
        save(selected, key: AppPreferences.displayModeKey)
        onDisplayModeSelected?()
        displayModeControl.selectedSegment = previewModeControl.selectedSegment
        preview.mode = selected
        updateControlAvailability()
        window?.contentView?.layoutSubtreeIfNeeded()
        settingsScrollView?.layoutDocument()
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

    @objc private func notchPlacementChanged() {
        let placements = NotchPlacement.allCases
        guard placements.indices.contains(notchPlacementControl.selectedSegment) else { return }
        save(placements[notchPlacementControl.selectedSegment], key: AppPreferences.notchPlacementKey)
    }

    @objc private func colorModeChanged() {
        save(colorModeControl.selectedSegment == 1 ? LyricsColorPreset.mintGradient : .orange,
             key: AppPreferences.colorPresetKey)
        updateControlAvailability()
        updateCustomColorSwatch()
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

    @objc private func statusBarOffsetChanged() {
        UserDefaults.standard.set(statusBarOffsetSlider.doubleValue, forKey: AppPreferences.statusBarOffsetKey)
        statusBarOffsetValue.stringValue = String(format: "%.0f", statusBarOffsetSlider.doubleValue)
        onSettingsChange()
        updatePreview()
    }

    @objc private func statusBarOffsetEntered() {
        commit(statusBarOffsetValue, slider: statusBarOffsetSlider, key: AppPreferences.statusBarOffsetKey,
               minimum: -200, maximum: 200, format: "%.0f")
    }

    @objc private func colorChanged(_ sender: NSButton) {
        let presets = LyricsColorPreset.solidPresets + LyricsColorPreset.gradientPresets
        guard presets.indices.contains(sender.tag) else { return }
        save(presets[sender.tag], key: AppPreferences.colorPresetKey)
        updateCustomColorSwatch()
    }

    @objc private func lyricsColorChanged() {
        AppPreferences.setColor(lyricsColorWell.color, forKey: AppPreferences.customLyricsColorKey)
        updateCustomColorSwatch()
        UserDefaults.standard.set(LyricsColorPreset.custom.rawValue, forKey: AppPreferences.colorPresetKey)
        onSettingsChange()
        updatePreview()
        updateCustomColorSwatch()
    }

    @objc private func lyricsColorEndChanged() {
        AppPreferences.setColor(lyricsColorEndWell.color, forKey: AppPreferences.customLyricsEndColorKey)
        UserDefaults.standard.set(LyricsColorPreset.customGradient.rawValue, forKey: AppPreferences.colorPresetKey)
        updateCustomColorSwatch()
        onSettingsChange()
        updatePreview()
    }

    @objc private func gradientStartChanged() {
        AppPreferences.setColor(gradientStartWell.color, forKey: AppPreferences.customLyricsColorKey)
        UserDefaults.standard.set(LyricsColorPreset.customGradient.rawValue, forKey: AppPreferences.colorPresetKey)
        updateCustomColorSwatch()
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
        let key = AppPreferences.displayMode != .statusBar ? AppPreferences.notchBackgroundOpacityKey : AppPreferences.opacityKey
        UserDefaults.standard.set(opacitySlider.doubleValue, forKey: key)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        onSettingsChange()
        updatePreview()
    }

    @objc private func opacityEntered() {
        let minimum: Double = AppPreferences.displayMode != .statusBar ? 0 : 10
        guard let percent = NumericInput.parse(opacityValue.stringValue, minimum: minimum, maximum: 100) else {
            opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
            NSSound.beep()
            return
        }
        opacitySlider.doubleValue = percent / 100
        opacityChanged()
    }

    @objc private func notchBackgroundToggled() {
        UserDefaults.standard.set(notchBackgroundSwitch.state == .on, forKey: AppPreferences.notchBackgroundEnabledKey)
        updateControlAvailability()
        onSettingsChange()
        updatePreview()
    }

    @objc private func notchBackgroundPresetChanged() {
        let presets = NotchBackgroundPreset.allCases
        guard presets.indices.contains(notchBackgroundPresetPopUp.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(true, forKey: AppPreferences.notchBackgroundEnabledKey)
        notchBackgroundSwitch.state = .on
        if let color = presets[notchBackgroundPresetPopUp.indexOfSelectedItem].color {
            AppPreferences.setColor(color, forKey: AppPreferences.notchBackgroundColorKey)
        }
        notchBackgroundColorWell.color = AppPreferences.notchBackgroundColor
        updateControlAvailability()
        onSettingsChange()
        updatePreview()
    }

    @objc private func notchBackgroundColorChanged() {
        AppPreferences.setColor(notchBackgroundColorWell.color, forKey: AppPreferences.notchBackgroundColorKey)
        UserDefaults.standard.set(true, forKey: AppPreferences.notchBackgroundEnabledKey)
        notchBackgroundSwitch.state = .on
        notchBackgroundPresetPopUp.selectItem(at: NotchBackgroundPreset.allCases.firstIndex(of: .custom) ?? 0)
        updateControlAvailability()
        onSettingsChange()
        updatePreview()
    }

    @objc private func notchBackgroundPaddingChanged() {
        UserDefaults.standard.set(notchBackgroundPaddingSlider.doubleValue, forKey: AppPreferences.notchBackgroundPaddingKey)
        notchBackgroundPaddingValue.stringValue = String(format: "%.0f", notchBackgroundPaddingSlider.doubleValue)
        onSettingsChange()
        updatePreview()
    }

    @objc private func notchBackgroundPaddingEntered() {
        commit(notchBackgroundPaddingValue, slider: notchBackgroundPaddingSlider,
               key: AppPreferences.notchBackgroundPaddingKey, minimum: 0, maximum: 120, format: "%.0f")
    }

    private func updateCustomColorSwatch() {
        let presets = LyricsColorPreset.solidPresets + LyricsColorPreset.gradientPresets
        for (index, button) in colorButtons.enumerated() {
            let selected = presets[index] == AppPreferences.colorPreset
            button.layer?.borderWidth = selected ? 2 : 0
            button.layer?.borderColor = NSColor.systemBlue.cgColor
        }
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
        updatePreview()
    }

    @objc private func notchHideOnHoverChanged() {
        UserDefaults.standard.set(notchHideOnHoverSwitch.state == .on, forKey: AppPreferences.notchHideOnHoverKey)
        onSettingsChange()
    }

    @objc private func showInDockChanged() {
        UserDefaults.standard.set(showInDockSwitch.state == .on, forKey: AppPreferences.showInDockKey)
        onSettingsChange()
        warnIfControlsHidden()
    }

    @objc private func showMenuBarIconChanged() {
        UserDefaults.standard.set(showMenuBarIconSwitch.state == .on, forKey: AppPreferences.showMenuBarIconKey)
        onSettingsChange()
        warnIfControlsHidden()
    }

    private func warnIfControlsHidden() {
        guard !AppPreferences.showInDock, !AppPreferences.showMenuBarIcon,
              !UserDefaults.standard.bool(forKey: AppPreferences.hiddenControlsNoticeKey) else { return }
        let alert = NSAlert()
        alert.messageText = L10n.text("NotchMuse keeps running in the background")
        alert.informativeText = L10n.text("Open it again from Applications or Spotlight to show this window.")
        alert.runModal()
        UserDefaults.standard.set(true, forKey: AppPreferences.hiddenControlsNoticeKey)
    }

    @objc private func launchAtLoginChanged() {
        do {
            if launchAtLoginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            LoginAtLaunchPolicy.markUserChoice()
        } catch {
            launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
            let alert = NSAlert(error: error)
            alert.messageText = L10n.text("Could not update Launch at Login")
            alert.runModal()
        }
    }

    @objc private func automaticUpdateChanged() {
        UpdateController.shared.automaticallyChecksForUpdates = automaticUpdateSwitch.state == .on
    }

    @objc private func automaticInstallChanged() {
        UpdateController.shared.automaticallyDownloadsUpdates = automaticInstallSwitch.state == .on
    }

    @objc private func bilingualLyricsChanged() {
        UserDefaults.standard.set(bilingualLyricsSwitch.state == .on, forKey: AppPreferences.bilingualLyricsKey)
        onSettingsChange()
    }

    private func makeAnnouncementBanner() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.54, blue: 0.21, alpha: 0.42).cgColor
        box.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.54, blue: 0.21, alpha: 0.10).cgColor
        box.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.28, alpha: 1.0)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleButton = NSButton(title: "", target: self, action: #selector(openAnnouncement))
        titleButton.isBordered = false
        titleButton.alignment = .left
        titleButton.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        announcementTitleButton = titleButton

        let unreadDot = NSView()
        unreadDot.wantsLayer = true
        unreadDot.layer?.cornerRadius = 3.5
        unreadDot.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.14, alpha: 1.0).cgColor
        unreadDot.translatesAutoresizingMaskIntoConstraints = false
        announcementUnreadDot = unreadDot

        let chevron = NSImageView()
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.contentTintColor = .secondaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(icon)
        box.addSubview(titleButton)
        box.addSubview(unreadDot)
        box.addSubview(chevron)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            icon.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            titleButton.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            titleButton.trailingAnchor.constraint(lessThanOrEqualTo: unreadDot.leadingAnchor, constant: -8),
            titleButton.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
            titleButton.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
            unreadDot.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            unreadDot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            unreadDot.widthAnchor.constraint(equalToConstant: 7),
            unreadDot.heightAnchor.constraint(equalToConstant: 7),
            chevron.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12)
        ])
        return box
    }

    private func updateAnnouncementBanner() {
        guard let banner = announcementBanner, let button = announcementTitleButton else { return }
        if let active = AnnouncementManager.shared.activeAnnouncement {
            button.title = active.localizedTitle
            announcementUnreadDot?.isHidden = !AnnouncementManager.shared.hasUnread
            banner.isHidden = false
        } else {
            banner.isHidden = true
        }
    }

    @objc private func openAnnouncement() {
        AnnouncementManager.shared.openActive()
    }

    @objc private func checkForUpdates() {
        UpdateController.shared.checkForUpdates()
    }

    private func showSupport() {
        if supportWindow == nil { supportWindow = SupportWindowController() }
        supportWindow?.showWindow(nil)
        supportWindow?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeLiveStatusStrip() -> NSView {
        let box = AppearanceSurfaceView()
        box.wantsLayer = true
        box.surfaceColor = AppearanceSurfaceColors.card
        box.layer?.cornerRadius = 10
        box.layer?.borderWidth = 1
        box.translatesAutoresizingMaskIntoConstraints = false

        liveStatusDot.wantsLayer = true
        liveStatusDot.layer?.cornerRadius = 4
        liveStatusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        liveStatusDot.translatesAutoresizingMaskIntoConstraints = false

        liveStatusLabel.stringValue = L10n.text("Waiting for music…")
        liveStatusLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        liveStatusLabel.textColor = .secondaryLabelColor
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        permissionFixButton.title = L10n.text("Open Permission Settings")
        permissionFixButton.bezelStyle = .rounded
        permissionFixButton.controlSize = .small
        permissionFixButton.target = self
        permissionFixButton.action = #selector(openPermissionFix)
        permissionFixButton.isHidden = true
        permissionFixButton.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(liveStatusDot)
        box.addSubview(liveStatusLabel)
        box.addSubview(permissionFixButton)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            liveStatusDot.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            liveStatusDot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            liveStatusDot.widthAnchor.constraint(equalToConstant: 8),
            liveStatusDot.heightAnchor.constraint(equalToConstant: 8),
            liveStatusLabel.leadingAnchor.constraint(equalTo: liveStatusDot.trailingAnchor, constant: 10),
            liveStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: permissionFixButton.leadingAnchor, constant: -10),
            liveStatusLabel.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            permissionFixButton.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            permissionFixButton.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        return box
    }

    func updateLiveStatus(
        playerName: String,
        playerConnected: Bool,
        isPlaying: Bool,
        isPaused: Bool,
        trackTitle: String?,
        artistName: String?,
        trackText: String?,
        lyricsFeedback: LyricsFeedback,
        needsPermission: PermissionFixKind?,
        liveLyricLine: String?
    ) {
        activePermissionFix = needsPermission
        permissionFixButton.isHidden = needsPermission == nil
        if let needsPermission {
            liveStatusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            let hint = needsPermission == .accessibility
                ? L10n.text("Accessibility permission needed for Left status bar")
                : L10n.format("Automation permission needed for %@", playerName)
            liveStatusLabel.stringValue = hint
            liveStatusLabel.textColor = .labelColor
            permissionFixButton.title = L10n.text("Open Permission Settings")
        } else if playerConnected, let trackText, !trackText.isEmpty {
            let synced = lyricsFeedback == .available
            liveStatusDot.layer?.backgroundColor = (synced ? NSColor.systemGreen : NSColor.systemOrange).cgColor
            let lyricStatus = synced ? L10n.text("Lyrics synced") : lyricsFeedback.displayText
            liveStatusLabel.stringValue = "\(playerName) · \(trackText) · \(lyricStatus)"
            liveStatusLabel.textColor = .labelColor
        } else {
            liveStatusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            liveStatusLabel.stringValue = L10n.text("Waiting for music…")
            liveStatusLabel.textColor = .secondaryLabelColor
        }
        vinylDeck.update(
            isPlaying: isPlaying,
            isPaused: isPaused,
            trackTitle: trackTitle,
            artistName: artistName,
            playerName: playerConnected ? playerName : nil
        )
        updateLiveLyricLine(liveLyricLine)
    }

    func updateLiveLyricLine(_ line: String?) {
        let trimmed = line?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty == false) ? trimmed : nil
        if preview.liveLyricText != value {
            preview.liveLyricText = value
        }
    }

    @objc private func openPermissionFix() {
        switch activePermissionFix {
        case .accessibility:
            AccessibilityManager.openSystemSettings()
        case .automation:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        case nil:
            break
        }
    }

    @objc private func languageChanged() {
        let languages = AppLanguage.allCases
        guard languages.indices.contains(languagePopUp.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(languages[languagePopUp.indexOfSelectedItem].rawValue, forKey: AppPreferences.languageKey)
        let alert = NSAlert()
        alert.messageText = L10n.text("Language Change")
        alert.informativeText = L10n.text("Restart NotchMuse to apply the new language.")
        alert.addButton(withTitle: L10n.text("Restart Now"))
        alert.addButton(withTitle: L10n.text("Later"))
        if alert.runModal() == .alertFirstButtonReturn {
            let url = Bundle.main.bundleURL
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
        }
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
        window?.contentView?.layoutSubtreeIfNeeded()
        settingsScrollView?.layoutDocument()
        DispatchQueue.main.async {
            self.updateSidebarSelection()
            self.settingsScrollView?.hideIdleScroller()
        }
    }

    private func updateSidebarSelection() {
        guard let window else { return }
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            sidebarButtons.forEach { page, button in
                let selected = page == selectedPage
                button.state = selected ? .on : .off
                (button as? SidebarNavButton)?.setSelected(selected)
            }
        }
    }

    @objc private func appAppearanceChanged() {
        guard AppAppearance.allCases.indices.contains(appAppearanceControl.selectedSegment) else { return }
        selectAppAppearance(AppAppearance.allCases[appAppearanceControl.selectedSegment])
    }

    private func selectAppAppearance(_ appearance: AppAppearance) {
        AppAppearanceController.select(appearance)
        appAppearanceControl.selectedSegment = AppAppearance.allCases.firstIndex(of: appearance)!
        sidebarQuickActions.updateThemeButton()
        updateSidebarSelection()
    }

    @objc private func previewModeChanged() {
        displayModeControl.selectedSegment = previewModeControl.selectedSegment
        displayModeChanged()
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
            keys = [AppPreferences.displayModeKey, AppPreferences.positionKey, AppPreferences.statusBarOffsetKey, AppPreferences.notchStyleKey, AppPreferences.notchPlacementKey, AppPreferences.displayTargetKey, AppPreferences.displayWidthKey, AppPreferences.customWidthKey] + FreeLyricsPreferences.keys
        case .appearance:
            keys = [AppPreferences.colorPresetKey, AppPreferences.customLyricsColorKey, AppPreferences.customLyricsEndColorKey, AppPreferences.fontSizeKey, AppPreferences.animationSpeedKey, AppPreferences.opacityKey, AppPreferences.notchBackgroundEnabledKey, AppPreferences.notchBackgroundColorKey, AppPreferences.notchBackgroundOpacityKey, AppPreferences.notchBackgroundPaddingKey, AppPreferences.notchHideOnHoverKey]
        case .general:
            keys = [AppPreferences.playerSourceKey, AppPreferences.playerStopBehaviorKey, AppPreferences.languageKey,
                    AppPreferences.showInDockKey, AppPreferences.showMenuBarIconKey, AppAppearanceController.preferenceKey]
        }
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
        if page == .general {
            AppAppearanceController.apply()
            UserDefaults.standard.set(false, forKey: AppPreferences.showInDockKey)
            UserDefaults.standard.set(true, forKey: AppPreferences.showMenuBarIconKey)
        }
        sync()
        onSettingsChange()
    }

    private func updatePreview() {
        preview.apply(
            colors: BrandStyle.gradientColors(for: AppPreferences.colorPreset, customColor: AppPreferences.customLyricsColor, customEndColor: AppPreferences.customLyricsEndColor),
            usesGradient: AppPreferences.colorPreset.isGradient,
            fontSize: AppPreferences.fontSize,
            opacity: AppPreferences.opacity,
            backgroundOpacity: AppPreferences.notchBackgroundOpacity,
            width: AppPreferences.displayWidth,
            position: AppPreferences.position,
            notchStyle: AppPreferences.notchStyle,
            notchPlacement: AppPreferences.notchPlacement,
            notchBackground: AppPreferences.notchBackgroundEnabled,
            notchBackgroundColor: AppPreferences.notchBackgroundColor,
            notchBackgroundPadding: AppPreferences.notchBackgroundPadding,
            customWidth: AppPreferences.customWidth,
            statusBarOffset: AppPreferences.statusBarOffset
        )
    }
}

private final class SettingsBackdropView: AppearanceSurfaceView {
    override var wantsUpdateLayer: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            AppearanceSurfaceColors.windowBackground.setFill()
            dirtyRect.fill()
        }
    }
}

@MainActor
private final class HiFiSidebarView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let gradient = NSGradient(
                starting: AppearanceSurfaceColors.sidebarTop,
                ending: AppearanceSurfaceColors.sidebarBottom
            )
            gradient?.draw(in: bounds, angle: -90)
        }
    }
}

@MainActor
private final class VinylDeckCardView: AppearanceSurfaceView {
    private let turntableView = VinylTurntableView()
    private let statePill = NSView()
    private let stateLabel = NSTextField(labelWithString: "IDLE")
    private let eqBars = EqualizerBarsView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    private var isPlayingState = false
    private var isPausedState = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        surfaceColor = AppearanceSurfaceColors.deck
        surfaceBorderColor = AppearanceSurfaceColors.border
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5

        turntableView.translatesAutoresizingMaskIntoConstraints = false

        statePill.wantsLayer = true
        statePill.layer?.cornerRadius = 3.5
        statePill.layer?.cornerCurve = .continuous
        statePill.translatesAutoresizingMaskIntoConstraints = false

        stateLabel.font = .monospacedSystemFont(ofSize: 8.5, weight: .semibold)
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        statePill.addSubview(stateLabel)

        eqBars.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(turntableView)
        addSubview(statePill)
        addSubview(eqBars)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            turntableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            turntableView.centerYAnchor.constraint(equalTo: centerYAnchor),
            turntableView.widthAnchor.constraint(equalToConstant: 54),
            turntableView.heightAnchor.constraint(equalToConstant: 54),

            stateLabel.leadingAnchor.constraint(equalTo: statePill.leadingAnchor, constant: 5),
            stateLabel.trailingAnchor.constraint(equalTo: statePill.trailingAnchor, constant: -5),
            stateLabel.topAnchor.constraint(equalTo: statePill.topAnchor, constant: 1.5),
            stateLabel.bottomAnchor.constraint(equalTo: statePill.bottomAnchor, constant: -1.5),

            statePill.leadingAnchor.constraint(equalTo: turntableView.trailingAnchor, constant: 8),
            statePill.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            eqBars.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            eqBars.centerYAnchor.constraint(equalTo: statePill.centerYAnchor),
            eqBars.widthAnchor.constraint(equalToConstant: 12),
            eqBars.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: turntableView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: statePill.bottomAnchor, constant: 5),

            subtitleLabel.leadingAnchor.constraint(equalTo: turntableView.trailingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])

        update(isPlaying: false, isPaused: false, trackTitle: nil, artistName: nil, playerName: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshStateStyle()
    }

    func update(isPlaying: Bool, isPaused: Bool, trackTitle: String?, artistName: String?, playerName: String?) {
        isPlayingState = isPlaying
        isPausedState = isPaused

        let trimmedTitle = trackTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedArtist = artistName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPlayer = playerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedTitle.isEmpty {
            titleLabel.stringValue = trimmedTitle
            titleLabel.textColor = .labelColor
            if !trimmedArtist.isEmpty && !trimmedPlayer.isEmpty {
                subtitleLabel.stringValue = "\(trimmedArtist) · \(trimmedPlayer)"
            } else if !trimmedArtist.isEmpty {
                subtitleLabel.stringValue = trimmedArtist
            } else if !trimmedPlayer.isEmpty {
                subtitleLabel.stringValue = trimmedPlayer
            } else {
                subtitleLabel.stringValue = "NotchMuse Hi-Fi"
            }
        } else {
            titleLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "等待播放" : "Waiting for music"
            titleLabel.textColor = .secondaryLabelColor
            subtitleLabel.stringValue = trimmedPlayer.isEmpty ? "NotchMuse Hi-Fi" : trimmedPlayer
        }

        if isPlaying {
            stateLabel.stringValue = "PLAY"
        } else if isPaused {
            stateLabel.stringValue = "PAUSE"
        } else {
            stateLabel.stringValue = "IDLE"
        }

        turntableView.setPlaying(isPlaying)
        eqBars.setPlaying(isPlaying)
        refreshStateStyle()
    }

    private func refreshStateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isPlayingState {
                stateLabel.textColor = AppearanceSurfaceColors.accent
                statePill.layer?.backgroundColor = AppearanceSurfaceColors.accentSoft.cgColor
            } else {
                stateLabel.textColor = .tertiaryLabelColor
                statePill.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
            }
        }
    }
}

@MainActor
private final class VinylTurntableView: NSView {
    private let discLayer = CALayer()
    private let labelLayer = CAShapeLayer()
    private let tonearmContainer = CALayer()
    private let tonearmPathLayer = CAShapeLayer()
    private let cartridgeLayer = CAShapeLayer()
    private let pivotLayer = CAShapeLayer()
    private var isSpinning = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        setupLayers()
    }

    required init?(coder: NSCoder) { nil }

    private func setupLayers() {
        guard let root = layer else { return }

        // 48x48pt vinyl disc centered slightly left inside 54x54pt frame
        let discSize: CGFloat = 48
        discLayer.bounds = CGRect(x: 0, y: 0, width: discSize, height: discSize)
        discLayer.position = CGPoint(x: 24, y: 27)
        discLayer.cornerRadius = discSize / 2
        discLayer.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.095, alpha: 1).cgColor
        discLayer.borderWidth = 0.75
        discLayer.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor

        // Concentric grooves
        for radius: CGFloat in [21, 18, 15, 12] {
            let groove = CAShapeLayer()
            let rect = CGRect(x: discSize / 2 - radius, y: discSize / 2 - radius, width: radius * 2, height: radius * 2)
            groove.path = CGPath(ellipseIn: rect, transform: nil)
            groove.fillColor = nil
            groove.strokeColor = NSColor.white.withAlphaComponent(0.08).cgColor
            groove.lineWidth = 0.5
            discLayer.addSublayer(groove)
        }

        // Specular sheen wedges so rotation is visibly smooth
        let sheen = CAShapeLayer()
        let sheenPath = CGMutablePath()
        let center = CGPoint(x: discSize / 2, y: discSize / 2)
        sheenPath.move(to: center)
        sheenPath.addArc(center: center, radius: 22.5, startAngle: 0.25, endAngle: 0.85, clockwise: false)
        sheenPath.closeSubpath()
        sheenPath.move(to: center)
        sheenPath.addArc(center: center, radius: 22.5, startAngle: .pi + 0.25, endAngle: .pi + 0.85, clockwise: false)
        sheenPath.closeSubpath()
        sheen.path = sheenPath
        sheen.fillColor = NSColor.white.withAlphaComponent(0.09).cgColor
        discLayer.addSublayer(sheen)

        // Warm amber center label (16x16pt)
        let labelSize: CGFloat = 16
        labelLayer.path = CGPath(
            ellipseIn: CGRect(x: (discSize - labelSize) / 2, y: (discSize - labelSize) / 2, width: labelSize, height: labelSize),
            transform: nil
        )
        labelLayer.fillColor = NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1).cgColor
        discLayer.addSublayer(labelLayer)

        // Center spindle hole (4x4pt)
        let spindle = CAShapeLayer()
        spindle.path = CGPath(ellipseIn: CGRect(x: discSize / 2 - 2, y: discSize / 2 - 2, width: 4, height: 4), transform: nil)
        spindle.fillColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.095, alpha: 1).cgColor
        discLayer.addSublayer(spindle)

        root.addSublayer(discLayer)

        // Tonearm anchored at top-right pivot (48, 46) in AppKit bottom-left coordinates
        tonearmContainer.bounds = CGRect(x: 0, y: 0, width: 20, height: 34)
        tonearmContainer.anchorPoint = CGPoint(x: 0.8, y: 0.9)
        tonearmContainer.position = CGPoint(x: 49, y: 47)

        let armPath = CGMutablePath()
        armPath.move(to: CGPoint(x: 16, y: 30.6))
        armPath.addLine(to: CGPoint(x: 14, y: 12))
        armPath.addLine(to: CGPoint(x: 8, y: 5))
        tonearmPathLayer.path = armPath
        tonearmPathLayer.fillColor = nil
        tonearmPathLayer.strokeColor = NSColor(calibratedWhite: 0.72, alpha: 0.92).cgColor
        tonearmPathLayer.lineWidth = 1.6
        tonearmPathLayer.lineCap = .round
        tonearmPathLayer.lineJoin = .round
        tonearmContainer.addSublayer(tonearmPathLayer)

        cartridgeLayer.path = CGPath(roundedRect: CGRect(x: 5.5, y: 2.5, width: 4.5, height: 4.5), cornerWidth: 1, cornerHeight: 1, transform: nil)
        cartridgeLayer.fillColor = NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1).cgColor
        tonearmContainer.addSublayer(cartridgeLayer)

        root.addSublayer(tonearmContainer)

        pivotLayer.path = CGPath(ellipseIn: CGRect(x: 46, y: 44, width: 6, height: 6), transform: nil)
        pivotLayer.fillColor = NSColor(calibratedWhite: 0.62, alpha: 1).cgColor
        pivotLayer.strokeColor = NSColor.black.withAlphaComponent(0.35).cgColor
        pivotLayer.lineWidth = 0.75
        root.addSublayer(pivotLayer)

        tonearmContainer.transform = CATransform3DMakeRotation(0.26, 0, 0, 1)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            labelLayer.fillColor = AppearanceSurfaceColors.accent.cgColor
            cartridgeLayer.fillColor = AppearanceSurfaceColors.accent.cgColor
        }
    }

    func setPlaying(_ playing: Bool) {
        if playing {
            if !isSpinning {
                isSpinning = true
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = -CGFloat.pi * 2
                spin.duration = 8.0
                spin.repeatCount = .infinity
                spin.isRemovedOnCompletion = false
                discLayer.add(spin, forKey: "vinylSpin")
            }
            animateTonearm(toAngle: -0.14)
        } else {
            if isSpinning {
                isSpinning = false
                discLayer.removeAnimation(forKey: "vinylSpin")
            }
            animateTonearm(toAngle: 0.26)
        }
    }

    private func animateTonearm(toAngle angle: CGFloat) {
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.toValue = angle
        anim.duration = 0.32
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tonearmContainer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        tonearmContainer.add(anim, forKey: "tonearmSwing")
    }
}

@MainActor
private final class EqualizerBarsView: NSView {
    private var barLayers: [CALayer] = []
    private var isAnimating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for index in 0..<3 {
            let bar = CALayer()
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.bounds = CGRect(x: 0, y: 0, width: 2, height: 3)
            bar.position = CGPoint(x: CGFloat(index) * 4 + 1, y: 0)
            bar.cornerRadius = 1
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
        refreshColors()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    func setPlaying(_ playing: Bool) {
        guard playing != isAnimating else {
            refreshColors()
            return
        }
        isAnimating = playing
        refreshColors()
        let durations: [CFTimeInterval] = [0.42, 0.56, 0.36]
        let peaks: [CGFloat] = [9, 10, 7.5]
        for (index, bar) in barLayers.enumerated() {
            bar.removeAnimation(forKey: "eqPulse")
            if playing {
                let pulse = CABasicAnimation(keyPath: "bounds.size.height")
                pulse.fromValue = 2.5
                pulse.toValue = peaks[index]
                pulse.duration = durations[index]
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pulse.isRemovedOnCompletion = false
                bar.add(pulse, forKey: "eqPulse")
            } else {
                bar.bounds = CGRect(x: 0, y: 0, width: 2, height: 3)
            }
        }
    }

    private func refreshColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = isAnimating ? AppearanceSurfaceColors.accent.cgColor : AppearanceSurfaceColors.ledOff.cgColor
            barLayers.forEach { $0.backgroundColor = color }
        }
    }
}

private final class SettingsSidebarQuickActionsView: AppearanceSurfaceView {
    var onThemeToggle: ((NSAppearance) -> Void)?
    var onSupport: (() -> Void)?
    private let themeButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        themeButton.target = self
        themeButton.action = #selector(toggleTheme)
        themeButton.isBordered = false
        themeButton.imagePosition = .imageOnly
        themeButton.contentTintColor = .tertiaryLabelColor
        themeButton.setAccessibilityIdentifier("settings.themeQuickAction")
        themeButton.translatesAutoresizingMaskIntoConstraints = false

        let supportButton = NSButton(title: "", target: self, action: #selector(openSupport))
        supportButton.isBordered = false
        supportButton.image = NSImage(systemSymbolName: "heart", accessibilityDescription: L10n.text("Support NotchMuse"))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        supportButton.imagePosition = .imageOnly
        supportButton.contentTintColor = .tertiaryLabelColor
        supportButton.toolTip = L10n.text("Support NotchMuse")
        supportButton.setAccessibilityLabel(L10n.text("Support NotchMuse"))
        supportButton.translatesAutoresizingMaskIntoConstraints = false

        let githubButton = NSButton(title: "", target: self, action: #selector(openGitHub))
        githubButton.isBordered = false
        githubButton.image = NSImage(systemSymbolName: "star", accessibilityDescription: L10n.text("GitHub Star"))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        githubButton.imagePosition = .imageOnly
        githubButton.contentTintColor = .tertiaryLabelColor
        githubButton.toolTip = L10n.text("Open NotchMuse on GitHub to leave a star.")
        githubButton.setAccessibilityIdentifier("settings.githubQuickAction")
        githubButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [themeButton, supportButton, githubButton])
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        updateThemeButton()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateThemeButton()
    }

    func updateThemeButton() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let action = L10n.text(isDark ? "Switch to Light Mode" : "Switch to Dark Mode")
        themeButton.image = NSImage(systemSymbolName: isDark ? "moon.fill" : "sun.max.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        themeButton.toolTip = action
        themeButton.setAccessibilityLabel(action)
    }

    @objc private func toggleTheme() { onThemeToggle?(effectiveAppearance) }
    @objc private func openSupport() { onSupport?() }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Xiye88/NotchMuse")!)
    }
}

private final class SettingsScrollView: NSScrollView {
    private var hideTask: DispatchWorkItem?

    override func layout() {
        super.layout()
        layoutDocument()
    }

    func layoutDocument() {
        guard let documentView, let content = documentView.subviews.first else { return }
        // Document fitting changes scroll extent, never the window's content size.
        let size = NSSize(width: contentView.bounds.width,
                          height: max(contentView.bounds.height, content.fittingSize.height + 18))
        if documentView.frame.size != size { documentView.setFrameSize(size) }
    }

    func hideIdleScroller() {
        verticalScroller?.isHidden = true
    }

    override func scrollWheel(with event: NSEvent) {
        hideTask?.cancel()
        verticalScroller?.isHidden = false
        super.scrollWheel(with: event)
        let task = DispatchWorkItem { [weak self] in self?.hideIdleScroller() }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
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
        case .display: return "menubar.rectangle"
        case .appearance: return "paintpalette"
        case .general: return "slider.horizontal.3"
        }
    }
    var indexLabel: String {
        switch self {
        case .display: return "01"
        case .appearance: return "02"
        case .general: return "03"
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
private final class SidebarNavButton: NSButton {
    private let ledView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let indexLabel = NSTextField(labelWithString: "")
    private var tracking: NSTrackingArea?
    private var isHovered = false
    private var isRowSelected = false

    init(page: SettingsPage, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = ""
        self.target = target
        self.action = action
        self.isBordered = false
        self.setButtonType(.momentaryChange)
        self.setAccessibilityLabel(L10n.text(page.title))
        self.wantsLayer = true
        self.layer?.cornerRadius = 9
        self.layer?.cornerCurve = .continuous
        self.layer?.borderWidth = 0.5
        self.layer?.borderColor = NSColor.clear.cgColor

        ledView.wantsLayer = true
        ledView.layer?.cornerRadius = 1.5
        ledView.layer?.masksToBounds = false
        ledView.translatesAutoresizingMaskIntoConstraints = false

        let symbolImage = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13.5, weight: .medium))
        iconView.image = symbolImage
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = L10n.text(page.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        indexLabel.stringValue = page.indexLabel
        indexLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        indexLabel.textColor = .tertiaryLabelColor
        indexLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(ledView)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(indexLabel)
        NSLayoutConstraint.activate([
            ledView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            ledView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ledView.widthAnchor.constraint(equalToConstant: 3),
            ledView.heightAnchor.constraint(equalToConstant: 16),

            iconView.leadingAnchor.constraint(equalTo: ledView.trailingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: indexLabel.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            indexLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ selected: Bool) {
        isRowSelected = selected
        refreshAppearance()
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
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isRowSelected {
                layer?.backgroundColor = AppearanceSurfaceColors.accentSoft.cgColor
                layer?.borderColor = AppearanceSurfaceColors.accentBorder.cgColor
                ledView.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
                ledView.layer?.shadowColor = AppearanceSurfaceColors.accent.cgColor
                ledView.layer?.shadowRadius = 4
                ledView.layer?.shadowOpacity = 0.65
                ledView.layer?.shadowOffset = .zero
                iconView.contentTintColor = .labelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
                titleLabel.textColor = .labelColor
                indexLabel.textColor = AppearanceSurfaceColors.accent
            } else if isHovered {
                layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
                layer?.borderColor = NSColor.clear.cgColor
                ledView.layer?.backgroundColor = AppearanceSurfaceColors.ledOff.cgColor
                ledView.layer?.shadowOpacity = 0
                iconView.contentTintColor = .labelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
                titleLabel.textColor = .labelColor
                indexLabel.textColor = .secondaryLabelColor
            } else {
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderColor = NSColor.clear.cgColor
                ledView.layer?.backgroundColor = AppearanceSurfaceColors.ledOff.cgColor
                ledView.layer?.shadowOpacity = 0
                iconView.contentTintColor = .secondaryLabelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
                titleLabel.textColor = .secondaryLabelColor
                indexLabel.textColor = .tertiaryLabelColor
            }
        }
    }
}

@MainActor
private final class SettingsPreviewView: NSView {
    typealias Mode = DisplayMode
    var mode: Mode = .statusBar { didSet { needsDisplay = true } }
    var liveLyricText: String? { didSet { needsDisplay = true } }
    var onModeClick: ((Mode) -> Void)?
    private var hoveredMode: Mode? { didSet { if hoveredMode != oldValue { needsDisplay = true } } }
    private var hoverTrackingArea: NSTrackingArea?
    private var lyricColors = BrandStyle.gradientColors
    private var usesGradient = false
    private var lyricFontSize: CGFloat = 13
    private var lyricOpacity: CGFloat = 1
    private var backgroundOpacity: CGFloat = 0.82
    private var lyricWidth: DisplayWidth = .auto
    private var customWidth: CGFloat = 500
    private var statusBarOffset: CGFloat = 0
    private var position: LyricsPosition = .right
    private var notchStyle: NotchStyle = .lyricOnly
    private var notchPlacement: NotchPlacement = .top
    private var notchBackground = false
    private var notchBackgroundColor = NotchBackgroundPreset.softGray.color!
    private var notchBackgroundPadding: CGFloat = 40
    private lazy var wallpaper: NSImage? = Bundle.main.path(forResource: "SettingsPreviewWallpaper", ofType: "png")
        .flatMap(NSImage.init(contentsOfFile:))

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        hoverTrackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        hoveredMode = mode(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        hoveredMode = mode(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        hoveredMode = nil
    }

    override func mouseDown(with event: NSEvent) {
        if let clickedMode = mode(at: convert(event.locationInWindow, from: nil)) {
            onModeClick?(clickedMode)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func mode(at point: NSPoint) -> Mode? {
        guard bounds.contains(point) else { return nil }
        return Mode.allCases[min(2, max(0, Int(point.x / max(1, bounds.width / 3))))]
    }

    func apply(colors: [NSColor], usesGradient: Bool, fontSize: CGFloat, opacity: CGFloat, backgroundOpacity: CGFloat, width: DisplayWidth,
               position: LyricsPosition, notchStyle: NotchStyle, notchPlacement: NotchPlacement, notchBackground: Bool,
               notchBackgroundColor: NSColor, notchBackgroundPadding: CGFloat, customWidth: CGFloat, statusBarOffset: CGFloat) {
        lyricColors = colors
        self.usesGradient = usesGradient
        lyricFontSize = fontSize
        lyricOpacity = opacity
        self.backgroundOpacity = backgroundOpacity
        lyricWidth = width
        self.customWidth = customWidth
        self.statusBarOffset = statusBarOffset
        self.position = position
        self.notchStyle = notchStyle
        self.notchPlacement = notchPlacement
        self.notchBackground = notchBackground
        self.notchBackgroundColor = notchBackgroundColor
        self.notchBackgroundPadding = notchBackgroundPadding
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let gap: CGFloat = 12
        let panelWidth = (bounds.width - gap * 2) / 3
        for (index, mode) in Mode.allCases.enumerated() {
            drawPanel(NSRect(x: CGFloat(index) * (panelWidth + gap), y: 0, width: panelWidth, height: bounds.height), panelMode: mode)
        }
    }

    private func drawPanel(_ rect: NSRect, panelMode: Mode) {
        let notch = panelMode != .statusBar
        let selected = mode == panelMode
        let hovered = hoveredMode == panelMode
        (selected || hovered ? NSColor.controlAccentColor.withAlphaComponent(hovered ? 0.10 : 0.05) : NSColor.clear).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 11, yRadius: 11).fill()
        let title = L10n.text(panelMode == .free ? "Free Position" : (notch ? "Notch Preview" : "Status Bar Preview"))
        (title as NSString).draw(in: NSRect(x: rect.minX + 10, y: rect.minY + 2, width: rect.width - 20, height: 22),
                                 withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                                                  .foregroundColor: NSColor.secondaryLabelColor])
        let screen = NSRect(x: rect.minX + 2, y: rect.minY + 26, width: rect.width - 4, height: rect.height - 29)
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
            let previewScale = WidthGeometry.previewScale(screenWidth: screen.width)
            let cutout = NSRect(x: screen.midX - 54, y: screen.minY - 1, width: 108, height: 28)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: cutout, xRadius: 14, yRadius: 14).fill()
            let lineHeight = ceil(min(lyricFontSize, 17) * 1.3)
            let availableWidth = max(0, screen.width - 22)
            let overlayWidth = min(availableWidth, max(min(180 * previewScale, availableWidth), WidthGeometry.notchWidth(
                mode: lyricWidth, availableWidth: availableWidth, style: notchStyle, customWidth: customWidth * previewScale
            )))
            let overlayHeight: CGFloat
            switch notchStyle {
            case .lyricOnly: overlayHeight = lineHeight + 14
            case .songLyric: overlayHeight = lineHeight * 2 + 18
            case .expanded: overlayHeight = lineHeight * 4 + 22
            }
            let overlay: NSRect
            let notchPlacement: NotchPlacement = panelMode == .free ? (FreeLyricsPreferences.vertical ? .left : .bottom) : self.notchPlacement
            switch notchPlacement {
            case .top: overlay = NSRect(x: screen.midX - overlayWidth / 2, y: cutout.maxY + 6, width: overlayWidth, height: overlayHeight)
            case .bottom: overlay = NSRect(x: screen.midX - overlayWidth / 2, y: screen.maxY - overlayHeight - 8, width: overlayWidth, height: overlayHeight)
            case .left, .right:
                let sideWidth: CGFloat = 54
                let sideHeight = screen.height * 0.72
                overlay = NSRect(x: notchPlacement == .left ? screen.minX + 8 : screen.maxX - sideWidth - 8,
                                 y: screen.midY - sideHeight / 2, width: sideWidth, height: sideHeight)
            }
            let sampleLyric = liveLyricText ?? L10n.text("Preview lyric sample")
            let previewText = "♪ " + sampleLyric
            let previewFont = NSFont.systemFont(ofSize: min(lyricFontSize, 17), weight: .medium)
            let previewTextWidth = (previewText as NSString).size(withAttributes: [.font: previewFont]).width
            let previewMetadataWidth = notchStyle == .lyricOnly ? 0 : (L10n.text("Preview song · Preview artist") as NSString).size(withAttributes: [.font: previewFont]).width
            let background = (notchPlacement.isVertical ? NSRect(origin: .zero, size: overlay.size) : NotchGeometry.backgroundRect(in: overlay, contentWidth: max(previewTextWidth, previewMetadataWidth), padding: notchBackgroundPadding))
                .offsetBy(dx: overlay.minX, dy: overlay.minY)
            if notchBackground {
                notchBackgroundColor.withAlphaComponent(backgroundOpacity).setFill()
                NSBezierPath(roundedRect: background, xRadius: overlayHeight / 2, yRadius: overlayHeight / 2).fill()
            }
            if notchPlacement.isVertical {
                let sample = Array(liveLyricText ?? L10n.text("Preview lyric sample"))
                let cell: CGFloat = 16
                let rows = max(1, Int((overlay.height - 12) / cell))
                for (index, glyph) in sample.prefix(rows * 2).enumerated() {
                    let color = usesGradient ? lyricColors[min(index * lyricColors.count / max(1, sample.count), lyricColors.count - 1)] : lyricColors[min(1, lyricColors.count - 1)]
                    drawText(String(glyph), in: NSRect(x: overlay.minX + CGFloat(index / rows) * overlay.width / 2,
                                                       y: overlay.minY + 6 + CGFloat(index % rows) * cell,
                                                       width: overlay.width / 2, height: cell), color: color, size: 12, alignment: .center)
                }
            } else if notchStyle == .songLyric {
                drawText(L10n.text("Preview song · Preview artist"),
                         in: NSRect(x: overlay.minX + 12, y: overlay.minY + 4,
                                    width: overlay.width - 24, height: lineHeight),
                         color: notchPreviewForeground, size: max(10, min(lyricFontSize - 2, 13)), alignment: .center)
            } else if notchStyle == .expanded {
                drawText(L10n.text("Preview song"),
                         in: NSRect(x: overlay.minX + 12, y: overlay.minY + 4,
                                    width: overlay.width - 24, height: lineHeight),
                         color: notchPreviewForeground, size: max(10, min(lyricFontSize, 13)), alignment: .left)
                drawText(L10n.text("Preview artist"),
                         in: NSRect(x: overlay.minX + 12, y: overlay.minY + lineHeight + 4,
                                    width: overlay.width - 24, height: lineHeight),
                         color: notchPreviewForeground, size: max(10, min(lyricFontSize - 2, 12)), alignment: .left)
            }
            if !notchPlacement.isVertical {
                drawLyric(in: NSRect(x: overlay.minX + 12, y: overlay.maxY - lineHeight - 7,
                                    width: overlay.width - 24, height: lineHeight), notch: true,
                          backgroundColor: notchBackground ? notchBackgroundColor : nil)
            }
        } else {
            let bar = NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: 28)
            NSColor.white.withAlphaComponent(0.86).setFill()
            NSBezierPath(rect: bar).fill()
            NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil)?
                .draw(in: NSRect(x: bar.minX + 12, y: bar.minY + 6, width: 16, height: 16))
            let previewScale = WidthGeometry.previewScale(screenWidth: screen.width)
            let leftMinX = bar.minX + 328 * previewScale
            let rightMaxX = bar.maxX - 368 * previewScale
            let centerGap = 8 * previewScale
            let safeLane = position == .left
                ? NSRect(x: leftMinX, y: bar.minY + 5, width: max(0, bar.midX - leftMinX - centerGap), height: 20)
                : NSRect(x: bar.midX + centerGap, y: bar.minY + 5, width: max(0, rightMaxX - bar.midX - centerGap), height: 20)
            let width = WidthGeometry.statusBarWidth(mode: lyricWidth, availableWidth: safeLane.width, customWidth: customWidth * previewScale)
            let baseFrame = WidthGeometry.constrainedFrame(safeLane, width: width, alignToTrailingEdge: position == .left)
            let frame = OverlayLaneGeometry.offsetFrame(baseFrame, within: safeLane, by: statusBarOffset * previewScale)
            drawLyric(in: frame, notch: false)
            let symbols = ["wifi", "speaker.wave.2.fill", "battery.100percent"]
            for (index, symbol) in symbols.enumerated() {
                NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                    .draw(in: NSRect(x: bar.maxX - 48 + CGFloat(index) * 14,
                                     y: bar.minY + 8, width: 12, height: 12))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        (selected ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.85)).setStroke()
        let outline = NSBezierPath(roundedRect: screen.insetBy(dx: 0.5, dy: 0.5), xRadius: 11, yRadius: 11)
        outline.lineWidth = selected ? 2.5 : hovered ? 2 : 1.5
        outline.stroke()
        (selected ? NSColor.controlAccentColor : hovered ? NSColor.controlAccentColor.withAlphaComponent(0.7) : NSColor.clear).setStroke()
        let cardOutline = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        cardOutline.lineWidth = selected ? 2 : 1.5
        cardOutline.stroke()
    }

    private var notchPreviewForeground: NSColor {
        notchBackground ? NotchBackgroundContrast.foreground(on: notchBackgroundColor) : .white
    }

    private func drawLyric(in rect: NSRect, notch: Bool, backgroundColor: NSColor? = nil) {
        let text = "♪ " + (liveLyricText ?? L10n.text("Preview lyric sample"))
        let size = min(lyricFontSize, notch ? 17 : 15)
        let colors = lyricColors
        let base = colors[min(1, colors.count - 1)].withAlphaComponent(0.72)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        if usesGradient {
            BrandStyle.gradientLyric(text, colors: colors.map { $0.withAlphaComponent(0.58 * (notch ? 1 : lyricOpacity)) }, attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: .medium), .paragraphStyle: paragraph
            ]).draw(in: rect)
        } else {
            drawText(text, in: rect, color: base.withAlphaComponent(notch ? 0.7 : lyricOpacity), size: size,
                     alignment: .center, shadow: notch)
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: rect.width * 0.58, height: rect.height)).addClip()
        if usesGradient {
            BrandStyle.gradientLyric(text, colors: colors.map { $0.withAlphaComponent(notch ? 1 : lyricOpacity) }, attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: .medium), .paragraphStyle: paragraph
            ]).draw(in: rect)
        } else {
            drawText(text, in: rect, color: colors[min(1, colors.count - 1)].withAlphaComponent(notch ? 1 : lyricOpacity),
                     size: size, alignment: .center, shadow: notch)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawText(_ text: String, in rect: NSRect, color: NSColor, size: CGFloat,
                          alignment: NSTextAlignment, shadow: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if shadow {
            let textShadow = NSShadow()
            textShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
            textShadow.shadowBlurRadius = 2
            textShadow.shadowOffset = NSSize(width: 0, height: -1)
            attributes[.shadow] = textShadow
        }
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}
