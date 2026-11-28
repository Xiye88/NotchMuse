import AppKit
import LyricsCore
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
    static let missingLyricsAnimationStyleKey = "MissingLyricsAnimationStyle"
    static let interactionSoundsEnabledKey = "InteractionSoundsEnabled"
    static let immersiveThemePresetKey = "ImmersiveLyricsThemePreset"
    static let preferredLaunchPlayerKey = "PreferredLaunchPlayer"
    static var missingLyricsAnimationStyle: MissingLyricsAnimationStyle {
        MissingLyricsAnimationStyle(rawValue: UserDefaults.standard.string(forKey: missingLyricsAnimationStyleKey) ?? "") ?? .vinylSeek
    }
    static var immersiveThemePreset: ImmersiveLyricsThemePreset {
        ImmersiveLyricsThemePreset(rawValue: UserDefaults.standard.string(forKey: immersiveThemePresetKey) ?? "") ?? .followTheme
    }
    static var preferredLaunchPlayer: PreferredLaunchPlayer {
        preferredLaunchPlayer(in: .standard)
    }
    static func preferredLaunchPlayer(in defaults: UserDefaults) -> PreferredLaunchPlayer {
        PreferredLaunchPlayer.fromStored(defaults.string(forKey: preferredLaunchPlayerKey))
    }
    static func setPreferredLaunchPlayer(_ value: PreferredLaunchPlayer, in defaults: UserDefaults = .standard) {
        defaults.set(value.storedValue, forKey: preferredLaunchPlayerKey)
    }
    static var bilingualLyricsEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true &&
        UserDefaults.standard.bool(forKey: bilingualLyricsKey)
    }

    static func interactionSoundsEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: interactionSoundsEnabledKey) as? Bool ?? true
    }

    static func setInteractionSoundsEnabled(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: interactionSoundsEnabledKey)
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

enum PreferredLaunchPlayer: Equatable, Sendable {
    case auto
    case none
    case player(PlayerSource)

    var storedValue: String {
        switch self {
        case .auto: return "auto"
        case .none: return "none"
        case .player(let source): return source.rawValue
        }
    }

    static func fromStored(_ raw: String?) -> PreferredLaunchPlayer {
        guard let raw, !raw.isEmpty, raw != "auto" else { return .auto }
        if raw == "none" { return .none }
        if let source = PlayerSource(rawValue: raw) {
            return .player(source)
        }
        return .auto
    }

    @MainActor
    static func installedPlayers() -> [PlayerSource] {
        let priority: [PlayerSource] = [
            .spotify, .sodaMusic, .netEaseMusic, .qqMusic, .kugouMusic, .youtubeMusic,
            .lxMusic, .yesPlayMusic, .appleMusic
        ]
        let rest = PlayerSource.detectable.filter { !priority.contains($0) }
        return (priority + rest).filter { source in
            source.bundleIdentifiers.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        }
    }

    @MainActor
    func resolveApplicationURL() -> (url: URL, source: PlayerSource)? {
        switch self {
        case .none:
            return nil
        case .player(let source):
            for bid in source.bundleIdentifiers {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                    return (url, source)
                }
            }
            return nil
        case .auto:
            for source in Self.installedPlayers() {
                for bid in source.bundleIdentifiers {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                        return (url, source)
                    }
                }
            }
            return nil
        }
    }
}

enum NotchBackgroundPreset: String, CaseIterable {
    case orange = "Orange"
    case black = "Black"
    case white = "White"
    case softGray = "Soft Gray"
    case frostedCream = "Frosted Cream"
    case deepSeaMist = "Deep Sea Mist"
    case blue = "Blue"
    case custom = "Custom"

    var color: NSColor? {
        switch self {
        case .orange: NSColor(calibratedRed: 0.94, green: 0.58, blue: 0.38, alpha: 1)
        case .black: NSColor(calibratedWhite: 0.22, alpha: 1)
        case .white: NSColor(calibratedWhite: 0.94, alpha: 1)
        case .softGray: NSColor(calibratedWhite: 0.27, alpha: 1)
        case .frostedCream: NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.92, alpha: 1)
        case .deepSeaMist: NSColor(calibratedRed: 0.14, green: 0.24, blue: 0.36, alpha: 1)
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
    private let fontSizeValue = NSTextField(string: "")
    private let animationSpeedValue = NSTextField(string: "")
    private let opacityValue = NSTextField(string: "")
    private let customWidthValue = NSTextField(string: "")
    private let statusBarOffsetValue = NSTextField(string: "")
    private let launchAtLoginSwitch = NSSwitch()
    private let interactionSoundsSwitch = NSSwitch()
    private let showInDockSwitch = NSSwitch()
    private let showMenuBarIconSwitch = NSSwitch()
    private let automaticUpdateSwitch = NSSwitch()
    private let automaticUpdateHelp = NSTextField(labelWithString: "")
    private var announcementBanner: NSView?
    private var announcementTitleButton: NSButton?
    private var announcementUnreadDot: NSView?
    private var announcementObserver: NSObjectProtocol?
    private let bilingualLyricsSwitch = NSSwitch()
    private let languagePopUp = NSPopUpButton()
    private let appAppearanceControl = NSSegmentedControl(labels: AppAppearance.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let playerPopUp = NSPopUpButton()
    private let preferredLaunchPlayerPopUp = NSPopUpButton()
    private let playerStopBehaviorPopUp = NSPopUpButton()
    private let missingLyricsStylePopUp = NSPopUpButton()
    private let notchBackgroundSwitch = NSSwitch()
    private let notchBackgroundPresetPopUp = NSPopUpButton()
    private let notchBackgroundColorWell = NSColorWell()
    private let notchBackgroundOpacitySlider = NSSlider(value: 82, minValue: 30, maxValue: 100, target: nil, action: nil)
    private let notchBackgroundOpacityValue = NSTextField(string: "")
    private let notchBackgroundPaddingSlider = NSSlider(value: 40, minValue: 0, maxValue: 120, target: nil, action: nil)
    private let notchBackgroundPaddingValue = NSTextField(string: "")
    private let notchHideOnHoverSwitch = NSSwitch()
    private let contentStack = NSStackView()
    private var cards: [NSView] = []
    private let preview = SettingsPreviewView()
    private var previewCard: NSView?
    private let previewModeControl = NSSegmentedControl(labels: DisplayMode.allCases.map { L10n.text($0.rawValue) }, trackingMode: .selectOne, target: nil, action: nil)
    private let displayPage = NSStackView()
    private let appearancePage = NSStackView()
    private let generalPage = NSStackView()
    private let immersiveLyricsView = ImmersiveLyricsView()
    private var liveStatusStripView: NSView?
    private var selectedPage: SettingsPage = .lyrics
    private weak var settingsScrollView: SettingsScrollView?
    private var sidebarPanelView: NSView?
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private let sidebarExpandButton = NSButton()
    private(set) var isSidebarCollapsed = false
    private var sidebarButtons: [SettingsPage: NSButton] = [:]
    private let sidebarNavDeck = SidebarNavDeckView()
    private let vinylDeck = VinylDeckCardView()
    private let sidebarQuickActions = SettingsSidebarQuickActionsView()
    var onRetryLyricsMatch: (() -> Void)?
    var onMediaCommand: ((MediaTransportCommand) -> Void)?
    var onMediaSeek: ((TimeInterval) -> Void)?
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
    private let freeLineModeControl = NSSegmentedControl(labels: [L10n.text("Single Line"), L10n.text("Double Line")], trackingMode: .selectOne, target: nil, action: nil)
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

    func show(page: SettingsPage? = nil) {
        sync()
        if let page, let button = sidebarButtons[page] {
            pageChanged(button)
        }
        AnnouncementManager.shared.refreshIfStale()
        updateAnnouncementBanner()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func restoreFocusAfterDisplayModeChange() {
        guard let window, !window.isMiniaturized else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    #if DEBUG
    static func testPreviewCardLayout() {
        let preview = SettingsPreviewView(frame: NSRect(x: 0, y: 0, width: 600, height: 218))
        for width in [600.0, 720.0] {
            preview.setFrameSize(NSSize(width: width, height: 218))
            preview.layoutSubtreeIfNeeded()
            let cardWidth = (width - 24) / 3
            let expected = (0..<3).map {
                NSRect(x: Double($0) * (cardWidth + 12), y: 0, width: cardWidth, height: 218)
            }
            precondition(preview.subviews.map(\.frame) == expected, "Each preview card must retain its own frame after resizing")
            precondition(preview.subviews.allSatisfy { $0.layer != nil }, "Each preview card must have its own animation layer")
        }
    }

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
        precondition(SettingsPage.allCases == [.lyrics, .display, .appearance, .general], "Navigation order must be Lyrics -> Display -> Appearance -> General")
        controller.setSidebarCollapsed(true, animated: false)
        precondition(controller.isSidebarCollapsed && controller.sidebarWidthConstraint?.constant == 0 && !controller.sidebarExpandButton.isHidden, "Sidebar collapse hides sidebar and shows expand button")
        controller.setSidebarCollapsed(false, animated: false)
        precondition(!controller.isSidebarCollapsed && controller.sidebarWidthConstraint?.constant == 224 && controller.sidebarExpandButton.isHidden, "Sidebar expand restores 224pt sidebar")
        let savedAnim = defaults.object(forKey: AppPreferences.missingLyricsAnimationStyleKey)
        defer {
            if let savedAnim { defaults.set(savedAnim, forKey: AppPreferences.missingLyricsAnimationStyleKey) }
            else { defaults.removeObject(forKey: AppPreferences.missingLyricsAnimationStyleKey) }
        }
        precondition(MissingLyricsAnimationStyle.allCases.count == 6, "Must expose all 6 missing-lyrics micro-animations")
        for (idx, style) in MissingLyricsAnimationStyle.allCases.enumerated() {
            controller.missingLyricsStylePopUp.selectItem(at: idx)
            controller.missingLyricsStyleChanged()
            precondition(AppPreferences.missingLyricsAnimationStyle == style && controller.immersiveLyricsView.animationStyle == style, "Missing lyrics animation style must persist")
            for lang in AppLanguage.allCases {
                precondition(!style.playfulCaption(language: lang).contains("404"), "Caption must never contain 404")
                precondition(!style.shortBarCaption(language: lang).contains("404"), "Short bar caption must never contain 404")
            }
        }
        // E22/E23 checks: idle preview of 3-style animation, 404 state, exact vertical centering (<2pt), MediaRemote codes, and palette preferences
        controller.updateImmersiveLyrics(lines: [], activeIndex: -1, lineProgress: 0, trackTitle: nil, artistName: nil, isPlaying: false, isPaused: false, position: 0, duration: 0, lyricsFeedback: .waiting)
        precondition(!controller.immersiveLyricsView.missingView.isHidden && controller.immersiveLyricsView.missingView.isIdlePreview, "Idle state previews selected 3-style animation")
        controller.updateImmersiveLyrics(lines: [], activeIndex: -1, lineProgress: 0, trackTitle: "Instrumental Track", artistName: "Artist", isPlaying: true, isPaused: false, position: 12, duration: 180, lyricsFeedback: .notFound)
        precondition(!controller.immersiveLyricsView.missingView.isHidden && !controller.immersiveLyricsView.missingView.isIdlePreview, "Missing lyrics state shows 404 animation with retry")
        // Verify flipped coordinate centering on line 0, line 2, middle line, and last line (never jumps to tail)
        let sampleLines = (0..<24).map { LyricLine(time: Double($0) * 5, text: "Sample lyric line number \($0)") }
        controller.pageChanged(controller.sidebarButtons[.lyrics]!)
        controller.updateImmersiveLyrics(lines: sampleLines, activeIndex: 0, lineProgress: 0.2, trackTitle: "Song", artistName: "Artist", isPlaying: true, isPaused: false, position: 1, duration: 130, lyricsFeedback: .available)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        for checkIdx in [0, 2, 12, 23] {
            let pair = controller.immersiveLyricsView.debugLineCenterAndVisibleMidY(for: checkIdx)!
            precondition(abs(pair.lineMidY - pair.visibleMidY) < 2.0, "Line \(checkIdx) must stay vertically centered: lineMidY=\(pair.lineMidY) visibleMidY=\(pair.visibleMidY)")
        }
        precondition(MediaTransportCommand.playPause.mediaRemoteCode == 2 && MediaTransportCommand.next.mediaRemoteCode == 4 && MediaTransportCommand.previous.mediaRemoteCode == 5, "MediaRemote command codes match macOS MediaRemote")
        let savedThemePreset = defaults.object(forKey: AppPreferences.immersiveThemePresetKey)
        defer {
            if let savedThemePreset { defaults.set(savedThemePreset, forKey: AppPreferences.immersiveThemePresetKey) }
            else { defaults.removeObject(forKey: AppPreferences.immersiveThemePresetKey) }
        }
        for preset in ImmersiveLyricsThemePreset.allCases {
            defaults.set(preset.rawValue, forKey: AppPreferences.immersiveThemePresetKey)
            precondition(AppPreferences.immersiveThemePreset == preset, "Immersive theme preset \(preset.rawValue) must persist")
        }
        // E25: liveStatusStripView visible ONLY on .display (compact ~42pt), hidden on .appearance, .general, .lyrics
        controller.pageChanged(controller.sidebarButtons[.display]!)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        precondition(controller.liveStatusStripView?.isHidden == false, "Live status strip must be visible on Display tab")
        let stripH = controller.liveStatusStripView?.frame.height ?? 0
        precondition(abs(stripH - 42) <= 2, "Live status strip must stay compact (~42pt), got \(stripH)")
        for hiddenPage in [SettingsPage.appearance, .general, .lyrics] {
            controller.pageChanged(controller.sidebarButtons[hiddenPage]!)
            controller.window?.contentView?.layoutSubtreeIfNeeded()
            precondition(controller.liveStatusStripView?.isHidden == true, "Live status strip must be hidden on \(hiddenPage.rawValue) tab")
        }
        // E28: borderless open-canvas sections (zero outer card frame/border)
        precondition(!controller.cards.isEmpty, "Settings sections must exist")
        for section in controller.cards {
            precondition((section.layer?.borderWidth ?? 0) == 0, "Open-canvas sections must have zero outer border")
            if let surface = section as? AppearanceSurfaceView {
                precondition(surface.surfaceColor == .clear, "Open-canvas sections must have transparent background")
            }
        }
        if let statusSurface = controller.liveStatusStripView as? AppearanceSurfaceView {
            precondition(statusSurface.surfaceColor == .clear && (statusSurface.layer?.borderWidth ?? 0) == 0, "Live status strip must be borderless open-canvas")
        }
        // E29: SlimOverlayScroller + LyricShareCardRenderer @2x PNG rendering across all 3 templates
        precondition(controller.settingsScrollView?.verticalScroller is SlimOverlayScroller, "Settings scroll view must use SlimOverlayScroller")
        precondition(SlimOverlayScroller.isCompatibleWithOverlayScrollers, "SlimOverlayScroller must support overlay style")
        precondition(LyricShareTemplate.allCases.count == 3, "Must expose 3 editorial lyric share card templates")
        for template in LyricShareTemplate.allCases {
            let rendered = LyricShareCardRenderer.renderPNG(
                lines: ["Lantern light across the quiet bay", "Every chorus finds its steady pace", "Softly glowing while you work right here"],
                trackTitle: "Midnight Harbor",
                artistName: "NotchMuse Studio",
                template: template
            )
            precondition(rendered != nil, "Lyric share card must render for \(template.rawValue)")
            precondition(rendered!.pngData.count > 1000, "Rendered PNG data must be non-empty for \(template.rawValue)")
            precondition(rendered!.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]), "Rendered bytes must have valid PNG signature")
            precondition(rendered!.image.size.width == LyricShareCardRenderer.logicalWidth && rendered!.image.size.height >= 500, "Rendered card dimensions must be valid")
        }
        // E30: preferredLaunchPlayer persistence, live share card popover preview image, custom capsule background color + opacity
        let savedLaunch = defaults.object(forKey: AppPreferences.preferredLaunchPlayerKey)
        defer {
            if let savedLaunch { defaults.set(savedLaunch, forKey: AppPreferences.preferredLaunchPlayerKey) }
            else { defaults.removeObject(forKey: AppPreferences.preferredLaunchPlayerKey) }
        }
        AppPreferences.setPreferredLaunchPlayer(.none)
        precondition(AppPreferences.preferredLaunchPlayer == .none, "Do Not Auto-Launch must persist")
        AppPreferences.setPreferredLaunchPlayer(.player(.spotify))
        precondition(AppPreferences.preferredLaunchPlayer == .player(.spotify), "Explicit launch player must persist")
        AppPreferences.setPreferredLaunchPlayer(.auto)
        precondition(AppPreferences.preferredLaunchPlayer == .auto, "Auto launch player must persist")

        let shareVC = LyricSharePopoverController(
            lines: sampleLines,
            activeIndex: 2,
            trackTitle: "Midnight Harbor",
            artistName: "NotchMuse Studio"
        )
        _ = shareVC.view
        precondition(shareVC.debugPreviewImage != nil, "Share popover must render live preview image on load")
        shareVC.debugSelectTemplate(.mistySage)
        precondition(shareVC.debugPreviewImage != nil, "Share popover must refresh live preview image on template switch")

        let savedBgEnabled = defaults.object(forKey: AppPreferences.notchBackgroundEnabledKey)
        let savedBgColor = defaults.object(forKey: AppPreferences.notchBackgroundColorKey)
        let savedBgOpacity = defaults.object(forKey: AppPreferences.notchBackgroundOpacityKey)
        defer {
            if let savedBgEnabled { defaults.set(savedBgEnabled, forKey: AppPreferences.notchBackgroundEnabledKey) }
            else { defaults.removeObject(forKey: AppPreferences.notchBackgroundEnabledKey) }
            if let savedBgColor { defaults.set(savedBgColor, forKey: AppPreferences.notchBackgroundColorKey) }
            else { defaults.removeObject(forKey: AppPreferences.notchBackgroundColorKey) }
            if let savedBgOpacity { defaults.set(savedBgOpacity, forKey: AppPreferences.notchBackgroundOpacityKey) }
            else { defaults.removeObject(forKey: AppPreferences.notchBackgroundOpacityKey) }
        }
        precondition(NotchBackgroundPreset.frostedCream.color != nil && NotchBackgroundPreset.deepSeaMist.color != nil, "New background presets must have valid colors")
        let customTeal = NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.52, alpha: 1)
        AppPreferences.setColor(customTeal, forKey: AppPreferences.notchBackgroundColorKey)
        precondition(AppPreferences.notchBackgroundPreset() == .custom, "Custom capsule background color must persist as custom")
        defaults.set(0.65, forKey: AppPreferences.notchBackgroundOpacityKey)
        precondition(abs(AppPreferences.notchBackgroundOpacity - 0.65) < 0.001, "Capsule background opacity must persist")
        // E31: Sequential multi-line sweep (line 1 0->100%, then line 2 0->100%) + single exclusive hover invariant
        let wrapStyle = NSMutableParagraphStyle()
        wrapStyle.alignment = .center
        wrapStyle.lineBreakMode = .byWordWrapping
        let longWrappedLyric = "This is a deliberately long wrapped lyric line designed to span two visual lines cleanly"
        let wrapFont = NSFont.systemFont(ofSize: 21, weight: .bold)
        let wrapRect = NSRect(x: 42, y: 6, width: 320, height: 120)
        let slices25 = SweepLyricLineView.sequentialSweepLineSlices(
            text: longWrappedLyric,
            font: wrapFont,
            paragraphStyle: wrapStyle,
            in: wrapRect,
            progress: 0.25
        )
        precondition(slices25.count >= 2, "Wrapped test lyric must span at least 2 visual lines")
        precondition(slices25[0].clipWidth > 0 && slices25[0].clipWidth < slices25[0].lineRect.width, "At 25%, line 1 must be partially swept")
        precondition(slices25[1].clipWidth == 0, "At 25%, line 2 clip width must be strictly 0")
        let slices75 = SweepLyricLineView.sequentialSweepLineSlices(
            text: longWrappedLyric,
            font: wrapFont,
            paragraphStyle: wrapStyle,
            in: wrapRect,
            progress: 0.75
        )
        precondition(abs(slices75[0].clipWidth - slices75[0].lineRect.width) < 0.01, "At 75%, line 1 must be 100% swept")
        precondition(slices75[1].clipWidth > 0, "At 75%, line 2 must be partially swept")

        controller.immersiveLyricsView.debugSimulateHover(at: 1)
        precondition(controller.immersiveLyricsView.debugHoveredLineCount == 1 && controller.immersiveLyricsView.hoveredLineIndex == 1, "Single line hovered")
        controller.immersiveLyricsView.debugSimulateHover(at: 5)
        precondition(controller.immersiveLyricsView.debugHoveredLineCount == 1 && controller.immersiveLyricsView.hoveredLineIndex == 5, "Hovering a second line must clear previous line (never 2 hovered)")
        controller.immersiveLyricsView.debugSimulateHover(at: nil)
        precondition(controller.immersiveLyricsView.debugHoveredLineCount == 0, "Clearing hover leaves 0 hovered lines")

        // E35: Spinning album artwork on vinyl deck + share card rendering with & without artwork/album
        let dummyArt = NSImage(size: NSSize(width: 64, height: 64))
        dummyArt.lockFocus()
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        dummyArt.unlockFocus()
        controller.vinylDeck.update(isPlaying: true, isPaused: false, trackTitle: "Midnight Harbor", artistName: "NotchMuse", playerName: "Spotify", artwork: dummyArt)
        precondition(controller.vinylDeck.debugHasArtwork, "Vinyl deck must display spinning album artwork when provided")
        controller.vinylDeck.update(isPlaying: false, isPaused: false, trackTitle: nil, artistName: nil, playerName: nil, artwork: nil)
        precondition(!controller.vinylDeck.debugHasArtwork, "Vinyl deck must fall back to amber label when artwork cleared or idle")
        for template in LyricShareTemplate.allCases {
            let withArt = LyricShareCardRenderer.renderPNG(
                lines: ["Lantern light across the quiet bay", "Every chorus finds its steady pace"],
                trackTitle: "Midnight Harbor",
                artistName: "NotchMuse Studio",
                albumName: "Harbor Sessions",
                artworkImage: dummyArt,
                template: template
            )
            let withoutArt = LyricShareCardRenderer.renderPNG(
                lines: ["Lantern light across the quiet bay"],
                trackTitle: "Midnight Harbor",
                artistName: "NotchMuse Studio",
                albumName: "Harbor Sessions",
                artworkImage: nil,
                template: template
            )
            precondition(withArt != nil && withArt!.pngData.count > 1000 && withArt!.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]), "Share card with artwork must render valid @2x PNG")
            precondition(withoutArt != nil && withoutArt!.pngData.count > 1000 && withoutArt!.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]), "Share card without artwork must render valid fallback @2x PNG")
        }
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
        interactionSoundsSwitch.target = self
        interactionSoundsSwitch.action = #selector(interactionSoundsChanged)
        interactionSoundsSwitch.setAccessibilityLabel(L10n.text("Interaction Sounds"))

        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)
        showInDockSwitch.target = self
        showInDockSwitch.action = #selector(showInDockChanged)
        showMenuBarIconSwitch.target = self
        showMenuBarIconSwitch.action = #selector(showMenuBarIconChanged)
        automaticUpdateSwitch.target = self
        automaticUpdateSwitch.action = #selector(automaticUpdateChanged)
        bilingualLyricsSwitch.target = self
        bilingualLyricsSwitch.action = #selector(bilingualLyricsChanged)
        for language in AppLanguage.allCases {
            languagePopUp.addItem(withTitle: language.displayName)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        appAppearanceControl.target = self
        appAppearanceControl.action = #selector(appAppearanceChanged)
        playerPopUp.autoenablesItems = false
        for (groupIndex, group) in PlayerSource.menuGroups.enumerated() {
            if groupIndex > 0 {
                playerPopUp.menu?.addItem(.separator())
            }
            if let headerTitle = group.title {
                let header = NSMenuItem(title: L10n.text(headerTitle), action: nil, keyEquivalent: "")
                header.isEnabled = false
                playerPopUp.menu?.addItem(header)
            }
            for source in group.sources {
                let item = NSMenuItem(title: source.displayName(), action: nil, keyEquivalent: "")
                item.representedObject = source
                playerPopUp.menu?.addItem(item)
            }
        }
        playerPopUp.target = self
        playerPopUp.action = #selector(playerChanged)
        populatePreferredLaunchPlayerPopUp()
        preferredLaunchPlayerPopUp.target = self
        preferredLaunchPlayerPopUp.action = #selector(preferredLaunchPlayerChanged)
        notchBackgroundOpacitySlider.target = self
        notchBackgroundOpacitySlider.action = #selector(notchBackgroundOpacityChanged)
        configureNumericField(notchBackgroundOpacityValue, action: #selector(notchBackgroundOpacityEntered))
        for behavior in PlayerStopBehavior.allCases {
            playerStopBehaviorPopUp.addItem(withTitle: L10n.text(behavior.rawValue))
        }
        playerStopBehaviorPopUp.target = self
        playerStopBehaviorPopUp.action = #selector(playerStopBehaviorChanged)
        for style in MissingLyricsAnimationStyle.allCases {
            missingLyricsStylePopUp.addItem(withTitle: style.displayName())
        }
        missingLyricsStylePopUp.target = self
        missingLyricsStylePopUp.action = #selector(missingLyricsStyleChanged)

        previewModeControl.target = self
        previewModeControl.action = #selector(displayModeChanged)
        previewModeControl.selectedSegment = 0
        previewModeControl.isHidden = true
        preview.onModeClick = { [weak self] mode in
            guard let self else { return }
            if AppPreferences.displayMode != mode {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
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
            [label(L10n.text("Lyrics Opacity")), valueRow(slider: opacitySlider, value: opacityValue, unit: "%")],
            [label(L10n.text("Show Background Capsule")), notchBackgroundSwitch],
            [label(L10n.text("Background Color")), backgroundColorControls()],
            [label(L10n.text("Background Opacity")), valueRow(slider: notchBackgroundOpacitySlider, value: notchBackgroundOpacityValue, unit: "%")],
            [label(L10n.text("Background Side Padding")), valueRow(slider: notchBackgroundPaddingSlider, value: notchBackgroundPaddingValue, unit: "pt")],
            [label(L10n.text("Hide on Hover")), notchHideOnHoverSwitch]
        ])
        notchBackgroundRow = appearanceGrid.row(at: 4)
        notchBackgroundColorRow = appearanceGrid.row(at: 5)
        notchHideOnHoverRow = appearanceGrid.row(at: 8)
        appearancePage.addArrangedSubview(card(content: cardBody(title: "Appearance", subtitle: "Customize the look of your lyrics.", grid: appearanceGrid, trailing: resetButton(for: .appearance)), showTopDivider: false))
        appearancePage.addArrangedSubview(quickPresetsCard())
        configure(page: generalPage)
        var generalRows: [[NSView]] = [
            [label(L10n.text("Music Player")), playerPopUp],
            [label(L10n.text("Default Launch Player")), preferredLaunchPlayerPopUp],
            [label(L10n.text("When Player Stops")), playerStopBehaviorPopUp],
            [label(L10n.text("Launch at Login")), launchAtLoginSwitch],
            [label(L10n.text("Interaction Sounds")), interactionSoundsSwitch],
            [label(L10n.text("Show in Dock")), showInDockSwitch],
            [label(L10n.text("Show Menu Bar Icon")), showMenuBarIconSwitch],
            [label(L10n.text("Appearance Mode")), appAppearanceControl],
            [label(L10n.text("Missing Lyrics Animation")), missingLyricsStylePopUp],
            [label(L10n.text("Language")), languagePopUp]
        ]
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            generalRows.append([label(L10n.text("Bilingual Lyrics")), bilingualLyricsSwitch])
        }
        let generalGrid = grid(generalRows)
        generalPage.addArrangedSubview(card(content: cardBody(title: "General", subtitle: "Player and system behavior.", grid: generalGrid, trailing: resetButton(for: .general)), showTopDivider: false))
        let updateTitle = L10n.text("Automatic Updates (Recommended)")
        automaticUpdateSwitch.setAccessibilityLabel(updateTitle)
        let updateSwitchRow = NSStackView(views: [label(updateTitle), automaticUpdateSwitch])
        updateSwitchRow.orientation = .horizontal
        updateSwitchRow.alignment = .centerY
        updateSwitchRow.spacing = 12
        automaticUpdateHelp.font = .systemFont(ofSize: 11.5)
        automaticUpdateHelp.textColor = .secondaryLabelColor
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
        let updateSection = NSStackView(views: [updateSwitchRow, automaticUpdateHelp, updateActionRow])
        updateSection.orientation = .vertical
        updateSection.alignment = .leading
        updateSection.spacing = 12
        generalPage.addArrangedSubview(card(content: updateSection, showTopDivider: true))

        displayPage.addArrangedSubview(card(content: cardBody(title: "Display", subtitle: L10n.text("Choose how and where lyrics appear."), grid: displayGrid, trailing: resetButton(for: .display)), showTopDivider: true))
        freeOrientation.target = self
        freeOrientation.action = #selector(freeOptionsChanged)
        freeLineModeControl.target = self
        freeLineModeControl.action = #selector(freeOptionsChanged)
        freeLock.target = self
        freeLock.action = #selector(freeLockChanged)
        freePassThrough.target = self
        freePassThrough.action = #selector(freeOptionsChanged)
        let freeGrid = grid([
            [label(L10n.text("Orientation")), freeOrientation],
            [label(L10n.text("Floating Lines")), freeLineModeControl],
            [label(L10n.text("Lock Position")), freeLock],
            [label(L10n.text("Click Through")), freePassThrough],
            [NSView(), NSButton(title: L10n.text("Reset Position"), target: self, action: #selector(resetFreeLyrics))]
        ])
        let freeCard = card(content: cardBody(title: "Free Position", subtitle: "Hover over locked lyrics to unlock them on your desktop.", grid: freeGrid, trailing: NSView()))
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

        sidebarNavDeck.translatesAutoresizingMaskIntoConstraints = false
        sidebarNavDeck.widthAnchor.constraint(equalToConstant: 200).isActive = true
        sidebarNavDeck.heightAnchor.constraint(equalToConstant: SidebarNavDeckView.totalHeight).isActive = true
        let navButtons = SettingsPage.allCases.map { page -> SidebarNavButton in
            let button = sidebarButton(for: page)
            sidebarButtons[page] = button
            return button
        }
        sidebarNavDeck.configure(buttons: navButtons)
        sidebar.addArrangedSubview(sidebarNavDeck)
        updateSidebarSelection()
        let sidebarPanel = HiFiSidebarView()
        sidebarPanelView = sidebarPanel
        sidebarPanel.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebar)
        let sidebarDivider = SidebarResizeDividerView()
        sidebarDivider.onDragDelta = { [weak self] delta in
            guard let self, let constraint = self.sidebarWidthConstraint else { return }
            let base: CGFloat = self.isSidebarCollapsed ? 0 : 224
            let target = min(224, max(0, base + delta))
            constraint.constant = target
            self.sidebarPanelView?.isHidden = target < 8
        }
        sidebarDivider.onDragEnd = { [weak self] _ in
            guard let self, let current = self.sidebarWidthConstraint?.constant else { return }
            let shouldCollapse = self.isSidebarCollapsed ? current < 72 : current < 130
            self.setSidebarCollapsed(shouldCollapse, animated: true)
        }
        sidebarQuickActions.onThemeToggle = { [weak self] appearance in
            self?.selectAppAppearance(AppAppearanceController.selection.toggled(for: appearance))
        }
        sidebarQuickActions.onSupport = { [weak self] in self?.showSupport() }
        sidebarQuickActions.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebarQuickActions)

        let compactBanner = makeAnnouncementBanner()
        announcementBanner = compactBanner
        sidebarPanel.addSubview(compactBanner)
        updateAnnouncementBanner()
        announcementObserver = NotificationCenter.default.addObserver(forName: AnnouncementManager.notification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAnnouncementBanner() }
        }

        sidebarExpandButton.title = ""
        sidebarExpandButton.isBordered = false
        sidebarExpandButton.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: L10n.text("Toggle Sidebar"))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        sidebarExpandButton.contentTintColor = .secondaryLabelColor
        sidebarExpandButton.target = self
        sidebarExpandButton.action = #selector(toggleSidebar)
        sidebarExpandButton.keyEquivalent = "s"
        sidebarExpandButton.keyEquivalentModifierMask = [.command, .option]
        sidebarExpandButton.toolTip = L10n.text("Show Sidebar")
        sidebarExpandButton.isHidden = true
        sidebarExpandButton.translatesAutoresizingMaskIntoConstraints = false

        let previewHeader = NSStackView(views: [sectionTitle(L10n.text("Live Preview")), previewModeControl])
        previewHeader.orientation = .horizontal
        previewHeader.distribution = .equalSpacing
        previewHeader.alignment = .centerY
        let previewContents = NSStackView(views: [previewHeader, preview])
        previewContents.orientation = .vertical
        previewContents.spacing = 12
        let previewCard = card(content: previewContents, showTopDivider: false)
        self.previewCard = previewCard
        previewCard.isHidden = selectedPage != .display
        preview.widthAnchor.constraint(equalTo: previewCard.widthAnchor).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 218).isActive = true
        previewHeader.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let statusStrip = makeLiveStatusStrip()
        liveStatusStripView = statusStrip
        statusStrip.isHidden = selectedPage != .display
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
        displayPage.isHidden = selectedPage != .display
        appearancePage.isHidden = selectedPage != .appearance
        generalPage.isHidden = selectedPage != .general
        let scrollView = SettingsScrollView()
        settingsScrollView = scrollView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = SlimOverlayScroller()
        scrollView.hasHorizontalScroller = false
        scrollView.isHidden = selectedPage == .lyrics
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedSettingsDocumentView()
        document.addSubview(contentStack)
        scrollView.documentView = document

        immersiveLyricsView.onRetryMatch = { [weak self] in self?.onRetryLyricsMatch?() }
        immersiveLyricsView.onTransportCommand = { [weak self] cmd in self?.onMediaCommand?(cmd) }
        immersiveLyricsView.onSeek = { [weak self] seconds in self?.onMediaSeek?(seconds) }
        immersiveLyricsView.animationStyle = AppPreferences.missingLyricsAnimationStyle
        immersiveLyricsView.setStageVisible(selectedPage == .lyrics)

        contentView.addSubview(sidebarPanel)
        contentView.addSubview(sidebarDivider)
        contentView.addSubview(scrollView)
        contentView.addSubview(immersiveLyricsView)
        contentView.addSubview(sidebarExpandButton)

        let widthConstraint = sidebarPanel.widthAnchor.constraint(equalToConstant: 224)
        sidebarWidthConstraint = widthConstraint

        NSLayoutConstraint.activate(cards.map { $0.widthAnchor.constraint(equalTo: contentStack.widthAnchor) } + [
            sidebarPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebarPanel.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            widthConstraint,
            sidebarDivider.leadingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor),
            sidebarDivider.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarDivider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarDivider.widthAnchor.constraint(equalToConstant: 7),
            sidebar.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 12),
            sidebar.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -12),
            sidebar.topAnchor.constraint(equalTo: sidebarPanel.topAnchor, constant: 40),
            compactBanner.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 12),
            compactBanner.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -12),
            compactBanner.bottomAnchor.constraint(equalTo: sidebarQuickActions.topAnchor, constant: -8),
            compactBanner.heightAnchor.constraint(equalToConstant: 30),
            sidebarQuickActions.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 12),
            sidebarQuickActions.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -12),
            sidebarQuickActions.bottomAnchor.constraint(equalTo: sidebarPanel.bottomAnchor, constant: -12),
            sidebarQuickActions.heightAnchor.constraint(equalToConstant: 36),
            sidebarExpandButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 76),
            sidebarExpandButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            sidebarExpandButton.widthAnchor.constraint(equalToConstant: 24),
            sidebarExpandButton.heightAnchor.constraint(equalToConstant: 24),
            scrollView.leadingAnchor.constraint(equalTo: sidebarDivider.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            immersiveLyricsView.leadingAnchor.constraint(equalTo: sidebarDivider.trailingAnchor, constant: 12),
            immersiveLyricsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            immersiveLyricsView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            immersiveLyricsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            contentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 6),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor, constant: -24)
        ])
        DispatchQueue.main.async { scrollView.hideIdleScroller() }
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func configure(page: NSStackView) {
        page.orientation = .vertical
        page.alignment = .leading
        page.spacing = 0
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

        let collapseButton = NSButton(title: "", target: self, action: #selector(toggleSidebar))
        collapseButton.isBordered = false
        collapseButton.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: L10n.text("Toggle Sidebar"))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        collapseButton.contentTintColor = .secondaryLabelColor
        collapseButton.toolTip = L10n.text("Hide Sidebar")
        collapseButton.keyEquivalent = "s"
        collapseButton.keyEquivalentModifierMask = [.command, .option]
        collapseButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        collapseButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let row = NSStackView(views: [leftStack, collapseButton])
        row.orientation = .horizontal
        row.distribution = .equalSpacing
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        return row
    }

    private func sidebarButton(for page: SettingsPage) -> SidebarNavButton {
        let button = SidebarNavButton(page: page, target: self, action: #selector(pageChanged))
        button.identifier = NSUserInterfaceItemIdentifier(page.rawValue)
        button.toolTip = L10n.text(page.help)
        return button
    }

    private func makeHairlineDivider() -> NSView {
        let line = AppearanceSurfaceView()
        line.wantsLayer = true
        line.surfaceColor = AppearanceSurfaceColors.hairline
        line.surfaceBorderColor = .clear
        line.layer?.borderWidth = 0
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func card(content: NSView, showTopDivider: Bool = true) -> NSView {
        let box = AppearanceSurfaceView()
        box.wantsLayer = true
        box.surfaceColor = .clear
        box.surfaceBorderColor = .clear
        box.layer?.borderWidth = 0
        box.layer?.cornerRadius = 0
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = [
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: showTopDivider ? 22 : 16),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -22)
        ]
        if showTopDivider {
            let divider = makeHairlineDivider()
            box.addSubview(divider)
            constraints.append(contentsOf: [
                divider.leadingAnchor.constraint(equalTo: box.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: box.trailingAnchor),
                divider.topAnchor.constraint(equalTo: box.topAnchor)
            ])
        }
        NSLayoutConstraint.activate(constraints)
        box.translatesAutoresizingMaskIntoConstraints = false
        cards.append(box)
        return box
    }

    private func cardBody(title: String, subtitle: String, grid: NSGridView, trailing: NSView) -> NSStackView {
        let header = cardHeader(title: title, subtitle: subtitle, trailing: trailing)
        let body = NSStackView(views: [header, grid])
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 16
        header.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        grid.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        return body
    }

    private func cardHeader(title: String, subtitle: String, trailing: NSView) -> NSStackView {
        let heading = NSTextField(labelWithString: L10n.text(title))
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
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
        value.heightAnchor.constraint(equalToConstant: 24).isActive = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [slider, value, unitLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        return stack
    }

    private func configureNumericField(_ field: NSTextField, action: Selector) {
        field.target = self
        field.action = action
        field.alignment = .right
        field.cell?.usesSingleLineMode = true
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
        let swatchDiameter: CGFloat = 22
        let presets = LyricsColorPreset.solidPresets + LyricsColorPreset.gradientPresets
        let buttons = presets.enumerated().map { index, preset in
            let colors = BrandStyle.gradientColors(for: preset)
            let button = NSButton(image: swatch(preset.isGradient ? colors : [colors[min(1, colors.count - 1)]], diameter: swatchDiameter), target: self, action: #selector(colorChanged(_:)))
            button.isBordered = false
            button.tag = index
            button.toolTip = L10n.text(preset.rawValue)
            button.setAccessibilityLabel(L10n.text(preset.rawValue))
            button.wantsLayer = true
            button.layer?.cornerRadius = swatchDiameter / 2
            button.widthAnchor.constraint(equalToConstant: swatchDiameter).isActive = true
            button.heightAnchor.constraint(equalToConstant: swatchDiameter).isActive = true
            return button
        }
        colorButtons = buttons
        lyricsColorWell.colorWellStyle = .minimal
        gradientStartWell.colorWellStyle = .minimal
        lyricsColorEndWell.colorWellStyle = .minimal
        lyricsColorWell.toolTip = L10n.text("Custom Color / Gradient Start")
        lyricsColorWell.widthAnchor.constraint(equalToConstant: 30).isActive = true
        gradientStartWell.toolTip = L10n.text("Custom Gradient Start")
        gradientStartWell.widthAnchor.constraint(equalToConstant: 30).isActive = true
        lyricsColorEndWell.toolTip = L10n.text("Custom Gradient End")
        lyricsColorEndWell.widthAnchor.constraint(equalToConstant: 30).isActive = true

        let solidCurated: [NSView] = Array(buttons.prefix(8)) + [lyricsColorWell]
        let solidRow = NSStackView(views: solidCurated)
        solidRow.orientation = .horizontal
        solidRow.alignment = .centerY
        solidRow.spacing = 3
        solidPalette.orientation = .vertical
        solidPalette.alignment = .leading
        solidPalette.addArrangedSubview(solidRow)

        let gradStart = LyricsColorPreset.solidPresets.count
        let gradCurated: [NSView] = Array(buttons[gradStart..<min(gradStart + 8, buttons.count)]) + [gradientStartWell, lyricsColorEndWell]
        let gradRow = NSStackView(views: gradCurated)
        gradRow.orientation = .horizontal
        gradRow.alignment = .centerY
        gradRow.spacing = 3
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

    private func swatch(_ colors: [NSColor], diameter: CGFloat) -> NSImage {
        let bounds = NSRect(x: 0, y: 0, width: diameter, height: diameter)
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        circle.addClip()
        if colors.count > 1 {
            NSGradient(colors: colors)?.draw(in: circle.bounds, angle: 0)
        } else {
            (colors.first ?? .white).setFill()
            circle.fill()
        }
        NSColor.black.withAlphaComponent(0.12).setStroke()
        circle.stroke()
        image.unlockFocus()
        return image
    }

    func refresh() { sync(); updatePreview() }

    private func sync() {
        displayModeControl.selectedSegment = DisplayMode.allCases.firstIndex(of: AppPreferences.displayMode) ?? 0
        previewModeControl.selectedSegment = displayModeControl.selectedSegment
        preview.mode = AppPreferences.displayMode
        freeOrientation.selectedSegment = FreeLyricsPreferences.vertical ? 1 : 0
        freeLineModeControl.selectedSegment = FreeLyricsPreferences.lineMode == .double ? 1 : 0
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
        let bgOpacityPct = min(100, max(30, round(Double(AppPreferences.notchBackgroundOpacity) * 100)))
        notchBackgroundOpacitySlider.doubleValue = bgOpacityPct
        notchBackgroundOpacityValue.stringValue = String(format: "%.0f", bgOpacityPct)
        notchBackgroundPaddingSlider.doubleValue = Double(AppPreferences.notchBackgroundPadding)
        notchBackgroundPaddingValue.stringValue = String(format: "%.0f", notchBackgroundPaddingSlider.doubleValue)
        notchHideOnHoverSwitch.state = AppPreferences.notchHideOnHover ? .on : .off
        fontSizeValue.stringValue = String(format: "%.0f", fontSizeSlider.doubleValue)
        animationSpeedValue.stringValue = String(format: "%.1f", animationSpeedSlider.doubleValue)
        opacityValue.stringValue = String(format: "%.0f", opacitySlider.doubleValue * 100)
        customWidthValue.stringValue = String(format: "%.0f", customWidthSlider.doubleValue)
        statusBarOffsetValue.stringValue = String(format: "%.0f", statusBarOffsetSlider.doubleValue)
        interactionSoundsSwitch.state = AppPreferences.interactionSoundsEnabled() ? .on : .off
        launchAtLoginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginSwitch.isEnabled = true
        appAppearanceControl.selectedSegment = AppAppearance.allCases.firstIndex(of: AppAppearanceController.selection)!
        sidebarQuickActions.updateThemeButton()
        showInDockSwitch.state = AppPreferences.showInDock ? .on : .off
        showMenuBarIconSwitch.state = AppPreferences.showMenuBarIcon ? .on : .off
        refreshAutomaticUpdates()
        bilingualLyricsSwitch.state = AppPreferences.bilingualLyricsEnabled ? .on : .off
        if let idx = playerPopUp.itemArray.firstIndex(where: { ($0.representedObject as? PlayerSource) == AppPreferences.playerSource }) {
            playerPopUp.selectItem(at: idx)
        } else {
            playerPopUp.selectItem(at: 0)
        }
        let storedLaunch = AppPreferences.preferredLaunchPlayer.storedValue
        if let idx = preferredLaunchPlayerPopUp.itemArray.firstIndex(where: { ($0.representedObject as? String) == storedLaunch }) {
            preferredLaunchPlayerPopUp.selectItem(at: idx)
        } else {
            preferredLaunchPlayerPopUp.selectItem(at: 0)
        }
        playerStopBehaviorPopUp.selectItem(at: PlayerStopBehavior.allCases.firstIndex(of: AppPreferences.playerStopBehavior) ?? 0)
        missingLyricsStylePopUp.selectItem(at: MissingLyricsAnimationStyle.allCases.firstIndex(of: AppPreferences.missingLyricsAnimationStyle) ?? 0)
        immersiveLyricsView.animationStyle = AppPreferences.missingLyricsAnimationStyle
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
        notchBackgroundColorWell.isHidden = false
        let bgOn = AppPreferences.notchBackgroundEnabled
        notchBackgroundPresetPopUp.isEnabled = bgOn
        notchBackgroundColorWell.isEnabled = bgOn
        notchBackgroundOpacitySlider.isEnabled = bgOn
        notchBackgroundOpacityValue.isEnabled = bgOn
        notchHideOnHoverRow?.isHidden = statusBarMode
    }

    @objc private func freeLockChanged() {
        let locked = freeLock.state == .on
        UserDefaults.standard.set(locked, forKey: FreeLyricsPreferences.lockedKey)
        if !locked {
            freePassThrough.state = .off
            UserDefaults.standard.set(false, forKey: FreeLyricsPreferences.passThroughKey)
        }
        onFreeLockChanged?()
        onSettingsChange()
        updatePreview()
    }

    @objc private func freeOptionsChanged() {
        UserDefaults.standard.set(freeOrientation.selectedSegment == 1, forKey: FreeLyricsPreferences.verticalKey)
        let lineMode: FreeLyricsLineMode = freeLineModeControl.selectedSegment == 1 ? .double : .single
        UserDefaults.standard.set(lineMode.rawValue, forKey: FreeLyricsPreferences.lineModeKey)
        UserDefaults.standard.set(freeLock.state == .on, forKey: FreeLyricsPreferences.lockedKey)
        UserDefaults.standard.set(freePassThrough.state == .on, forKey: FreeLyricsPreferences.passThroughKey)
        onSettingsChange()
        updatePreview()
    }

    @objc private func resetFreeLyrics() {
        NotificationCenter.default.post(name: FreeLyricsPreferences.resetNotification, object: nil)
    }

    @objc private func displayModeChanged() {
        let modes = DisplayMode.allCases
        guard modes.indices.contains(previewModeControl.selectedSegment) else { return }
        let selected = modes[previewModeControl.selectedSegment]
        onDisplayModeSelected?()
        save(selected, key: AppPreferences.displayModeKey)
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

    @objc private func notchBackgroundOpacityChanged() {
        let pct = min(100, max(30, round(notchBackgroundOpacitySlider.doubleValue)))
        UserDefaults.standard.set(pct / 100.0, forKey: AppPreferences.notchBackgroundOpacityKey)
        notchBackgroundOpacityValue.stringValue = String(format: "%.0f", pct)
        onSettingsChange()
        updatePreview()
    }

    @objc private func notchBackgroundOpacityEntered() {
        guard let pct = NumericInput.parse(notchBackgroundOpacityValue.stringValue, minimum: 30, maximum: 100) else {
            notchBackgroundOpacityValue.stringValue = String(format: "%.0f", notchBackgroundOpacitySlider.doubleValue)
            NSSound.beep()
            return
        }
        notchBackgroundOpacitySlider.doubleValue = pct
        notchBackgroundOpacityValue.stringValue = String(format: "%.0f", pct)
        UserDefaults.standard.set(pct / 100.0, forKey: AppPreferences.notchBackgroundOpacityKey)
        onSettingsChange()
        updatePreview()
    }

    private func populatePreferredLaunchPlayerPopUp() {
        preferredLaunchPlayerPopUp.removeAllItems()
        let autoItem = NSMenuItem(title: L10n.text("Auto (Installed Music App)"), action: nil, keyEquivalent: "")
        autoItem.representedObject = PreferredLaunchPlayer.auto.storedValue
        preferredLaunchPlayerPopUp.menu?.addItem(autoItem)

        let noneItem = NSMenuItem(title: L10n.text("Do Not Auto-Launch"), action: nil, keyEquivalent: "")
        noneItem.representedObject = PreferredLaunchPlayer.none.storedValue
        preferredLaunchPlayerPopUp.menu?.addItem(noneItem)

        let installed = PreferredLaunchPlayer.installedPlayers()
        if !installed.isEmpty {
            preferredLaunchPlayerPopUp.menu?.addItem(.separator())
            for source in installed {
                let item = NSMenuItem(title: "\(L10n.text(source.rawValue))", action: nil, keyEquivalent: "")
                item.representedObject = PreferredLaunchPlayer.player(source).storedValue
                preferredLaunchPlayerPopUp.menu?.addItem(item)
            }
        }
        let others = PlayerSource.detectable.filter { !installed.contains($0) }
        if !others.isEmpty {
            preferredLaunchPlayerPopUp.menu?.addItem(.separator())
            for source in others {
                let item = NSMenuItem(title: L10n.text(source.rawValue), action: nil, keyEquivalent: "")
                item.representedObject = PreferredLaunchPlayer.player(source).storedValue
                preferredLaunchPlayerPopUp.menu?.addItem(item)
            }
        }
    }

    @objc private func preferredLaunchPlayerChanged() {
        guard let raw = preferredLaunchPlayerPopUp.selectedItem?.representedObject as? String else { return }
        AppPreferences.setPreferredLaunchPlayer(PreferredLaunchPlayer.fromStored(raw))
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

    @objc private func interactionSoundsChanged() {
        InteractionSoundEngine.shared.setEnabled(interactionSoundsSwitch.state == .on)
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

    private func refreshAutomaticUpdates() {
        let updater = UpdateController.shared
        automaticUpdateSwitch.state = updater.automaticUpdatesEnabled ? .on : .off
        automaticUpdateSwitch.isEnabled = updater.allowsAutomaticUpdates
        if !updater.isAvailable {
            automaticUpdateHelp.stringValue = L10n.text("Updates are unavailable in this build.")
        } else if updater.automaticallyChecksWithoutDownloading {
            automaticUpdateHelp.stringValue = L10n.text("Automatic checks only (previous setting).")
        } else {
            automaticUpdateHelp.stringValue = L10n.text("Checks for updates and downloads them in the background.")
        }
    }

    @objc private func automaticUpdateChanged() {
        UpdateController.shared.automaticUpdatesEnabled = automaticUpdateSwitch.state == .on
        refreshAutomaticUpdates()
    }

    @objc private func bilingualLyricsChanged() {
        UserDefaults.standard.set(bilingualLyricsSwitch.state == .on, forKey: AppPreferences.bilingualLyricsKey)
        onSettingsChange()
    }

    private func makeAnnouncementBanner() -> NSView {
        let box = AppearanceSurfaceView()
        box.wantsLayer = true
        box.surfaceColor = AppearanceSurfaceColors.accentSoft
        box.surfaceBorderColor = AppearanceSurfaceColors.accentBorder
        box.layer?.cornerRadius = 8
        box.layer?.cornerCurve = .continuous
        box.layer?.borderWidth = 0.5
        box.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        icon.contentTintColor = AppearanceSurfaceColors.accent
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleButton = NSButton(title: "", target: self, action: #selector(openAnnouncement))
        titleButton.isBordered = false
        titleButton.alignment = .left
        titleButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        announcementTitleButton = titleButton

        let unreadDot = NSView()
        unreadDot.wantsLayer = true
        unreadDot.layer?.cornerRadius = 3
        unreadDot.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.14, alpha: 1.0).cgColor
        unreadDot.translatesAutoresizingMaskIntoConstraints = false
        announcementUnreadDot = unreadDot

        let chevron = NSImageView()
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(icon)
        box.addSubview(titleButton)
        box.addSubview(unreadDot)
        box.addSubview(chevron)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 9),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 13),
            icon.heightAnchor.constraint(equalToConstant: 13),
            titleButton.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            titleButton.trailingAnchor.constraint(lessThanOrEqualTo: unreadDot.leadingAnchor, constant: -6),
            titleButton.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            unreadDot.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            unreadDot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            unreadDot.widthAnchor.constraint(equalToConstant: 6),
            unreadDot.heightAnchor.constraint(equalToConstant: 6),
            chevron.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            chevron.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 10)
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
        box.surfaceColor = .clear
        box.surfaceBorderColor = .clear
        box.layer?.cornerRadius = 0
        box.layer?.borderWidth = 0
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

        let bottomDivider = makeHairlineDivider()

        box.addSubview(liveStatusDot)
        box.addSubview(liveStatusLabel)
        box.addSubview(permissionFixButton)
        box.addSubview(bottomDivider)
        box.setContentHuggingPriority(.required, for: .vertical)
        box.setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 42),
            liveStatusDot.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            liveStatusDot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            liveStatusDot.widthAnchor.constraint(equalToConstant: 8),
            liveStatusDot.heightAnchor.constraint(equalToConstant: 8),
            liveStatusLabel.leadingAnchor.constraint(equalTo: liveStatusDot.trailingAnchor, constant: 10),
            liveStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: permissionFixButton.leadingAnchor, constant: -10),
            liveStatusLabel.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            permissionFixButton.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            permissionFixButton.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            bottomDivider.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            bottomDivider.bottomAnchor.constraint(equalTo: box.bottomAnchor)
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
        liveLyricLine: String?,
        artworkImage: NSImage? = nil
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
            playerName: playerConnected ? playerName : nil,
            artwork: (isPlaying || isPaused) ? artworkImage : nil
        )
        sidebarNavDeck.updateGeneralActive(playerConnected && (isPlaying || isPaused))
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
        guard let source = playerPopUp.selectedItem?.representedObject as? PlayerSource else { return }
        AppPreferences.setPlayerSource(source)
        onSettingsChange()
    }

    @objc private func playerStopBehaviorChanged() {
        let behaviors = PlayerStopBehavior.allCases
        guard behaviors.indices.contains(playerStopBehaviorPopUp.indexOfSelectedItem) else { return }
        save(behaviors[playerStopBehaviorPopUp.indexOfSelectedItem], key: AppPreferences.playerStopBehaviorKey)
    }

    @objc private func missingLyricsStyleChanged() {
        let styles = MissingLyricsAnimationStyle.allCases
        guard styles.indices.contains(missingLyricsStylePopUp.indexOfSelectedItem) else { return }
        let chosen = styles[missingLyricsStylePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(chosen.rawValue, forKey: AppPreferences.missingLyricsAnimationStyleKey)
        immersiveLyricsView.animationStyle = chosen
    }

    @objc func toggleSidebar() {
        setSidebarCollapsed(!isSidebarCollapsed, animated: true)
    }

    func setSidebarCollapsed(_ collapsed: Bool, animated: Bool) {
        let didChange = collapsed != isSidebarCollapsed
        isSidebarCollapsed = collapsed
        if didChange {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        let targetWidth: CGFloat = collapsed ? 0 : 224
        if !collapsed {
            sidebarPanelView?.isHidden = false
        }
        sidebarExpandButton.isHidden = !collapsed
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.sidebarWidthConstraint?.animator().constant = targetWidth
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.sidebarPanelView?.isHidden = self.isSidebarCollapsed
                }
            })
        } else {
            sidebarWidthConstraint?.constant = targetWidth
            sidebarPanelView?.isHidden = collapsed
        }
    }

    func updateImmersiveLyrics(
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
        lyricsFeedback: LyricsFeedback,
        trackIdentity: String? = nil
    ) {
        let synced = !lines.isEmpty && lyricsFeedback == .available
        let missing = lyricsFeedback == .notFound || lyricsFeedback == .timeout || lyricsFeedback == .networkFailure
        sidebarNavDeck.updateLyricsStatus(isPlaying: isPlaying, synced: synced)
        immersiveLyricsView.update(
            lines: lines,
            activeIndex: activeIndex,
            lineProgress: lineProgress,
            trackTitle: trackTitle,
            artistName: artistName,
            albumName: albumName,
            artworkImage: artworkImage,
            isPlaying: isPlaying,
            isPaused: isPaused,
            position: position,
            duration: duration,
            lyricsMissing: missing,
            trackIdentity: trackIdentity
        )
    }

    @objc private func pageChanged(_ sender: NSButton) {
        guard let page = SettingsPage(rawValue: sender.identifier?.rawValue ?? "") else { return }
        let didChange = page != selectedPage
        if didChange {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        selectedPage = page
        let isLyrics = page == .lyrics
        settingsScrollView?.isHidden = isLyrics
        immersiveLyricsView.setStageVisible(isLyrics)
        liveStatusStripView?.isHidden = page != .display
        previewCard?.isHidden = page != .display
        displayPage.isHidden = page != .display
        appearancePage.isHidden = page != .appearance
        generalPage.isHidden = page != .general
        sidebarNavDeck.select(page, animated: didChange)
        window?.contentView?.layoutSubtreeIfNeeded()
        settingsScrollView?.layoutDocument()
        DispatchQueue.main.async {
            self.updateSidebarSelection(animated: false)
            self.settingsScrollView?.hideIdleScroller()
        }
    }

    private func updateSidebarSelection(animated: Bool = false) {
        guard let window else { return }
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            sidebarButtons.forEach { page, button in
                button.state = page == selectedPage ? .on : .off
            }
            sidebarNavDeck.select(selectedPage, animated: animated)
            sidebarNavDeck.refreshAppearance()
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
        case .lyrics:
            keys = []
        case .display:
            keys = [AppPreferences.displayModeKey, AppPreferences.positionKey, AppPreferences.statusBarOffsetKey, AppPreferences.notchStyleKey, AppPreferences.notchPlacementKey, AppPreferences.displayTargetKey, AppPreferences.displayWidthKey, AppPreferences.customWidthKey] + FreeLyricsPreferences.keys
        case .appearance:
            keys = [AppPreferences.colorPresetKey, AppPreferences.customLyricsColorKey, AppPreferences.customLyricsEndColorKey, AppPreferences.fontSizeKey, AppPreferences.animationSpeedKey, AppPreferences.opacityKey, AppPreferences.notchBackgroundEnabledKey, AppPreferences.notchBackgroundColorKey, AppPreferences.notchBackgroundOpacityKey, AppPreferences.notchBackgroundPaddingKey, AppPreferences.notchHideOnHoverKey]
        case .general:
            keys = [AppPreferences.playerSourceKey, AppPreferences.playerStopBehaviorKey, AppPreferences.languageKey,
                    AppPreferences.showInDockKey, AppPreferences.showMenuBarIconKey, AppAppearanceController.preferenceKey,
                    AppPreferences.interactionSoundsEnabledKey]
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
        let colors = BrandStyle.gradientColors(for: AppPreferences.colorPreset, customColor: AppPreferences.customLyricsColor, customEndColor: AppPreferences.customLyricsEndColor)
        preview.apply(
            colors: colors,
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
        sidebarNavDeck.updateDisplayMode(AppPreferences.displayMode)
        sidebarNavDeck.updateAppearanceColor(colors.first ?? AppearanceSurfaceColors.accent)
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

    var debugHasArtwork: Bool { turntableView.hasArtwork }

    func update(isPlaying: Bool, isPaused: Bool, trackTitle: String?, artistName: String?, playerName: String?, artwork: NSImage? = nil) {
        isPlayingState = isPlaying
        isPausedState = isPaused
        turntableView.setArtwork((isPlaying || isPaused) ? artwork : nil)

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
    private let artworkLayer = CALayer()
    private let labelLayer = CAShapeLayer()
    private let tonearmContainer = CALayer()
    private let tonearmPathLayer = CAShapeLayer()
    private let cartridgeLayer = CAShapeLayer()
    private let pivotLayer = CAShapeLayer()
    private var isSpinning = false

    var hasArtwork: Bool { !artworkLayer.isHidden && artworkLayer.contents != nil }

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

        // Warm amber center label (16x16pt, shown when no artwork)
        let labelSize: CGFloat = 16
        labelLayer.path = CGPath(
            ellipseIn: CGRect(x: (discSize - labelSize) / 2, y: (discSize - labelSize) / 2, width: labelSize, height: labelSize),
            transform: nil
        )
        labelLayer.fillColor = NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1).cgColor
        discLayer.addSublayer(labelLayer)

        // Circular album artwork embedded at center of spinning vinyl (~65% of 48pt disc = 31pt)
        let artSize: CGFloat = 31
        artworkLayer.frame = CGRect(x: (discSize - artSize) / 2, y: (discSize - artSize) / 2, width: artSize, height: artSize)
        artworkLayer.cornerRadius = artSize / 2
        artworkLayer.masksToBounds = true
        artworkLayer.contentsGravity = .resizeAspectFill
        artworkLayer.borderWidth = 0.75
        artworkLayer.borderColor = NSColor.white.withAlphaComponent(0.26).cgColor
        artworkLayer.isHidden = true
        discLayer.addSublayer(artworkLayer)

        // Center spindle hole (4x4pt)
        let spindle = CAShapeLayer()
        spindle.path = CGPath(ellipseIn: CGRect(x: discSize / 2 - 2, y: discSize / 2 - 2, width: 4, height: 4), transform: nil)
        spindle.fillColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.095, alpha: 1).cgColor
        spindle.strokeColor = NSColor.white.withAlphaComponent(0.24).cgColor
        spindle.lineWidth = 0.5
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

    func setArtwork(_ image: NSImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let image {
            artworkLayer.contents = image
            artworkLayer.isHidden = false
            labelLayer.isHidden = true
        } else {
            artworkLayer.contents = nil
            artworkLayer.isHidden = true
            labelLayer.isHidden = false
        }
        CATransaction.commit()
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

enum SettingsPage: String, CaseIterable {
    case lyrics, display, appearance, general

    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .lyrics: return "music.note.list"
        case .display: return "menubar.rectangle"
        case .appearance: return "paintpalette"
        case .general: return "slider.horizontal.3"
        }
    }
    var help: String {
        switch self {
        case .lyrics: return "Full synchronized lyrics and playback controls."
        case .display: return "Lyrics display mode, position, and screen."
        case .appearance: return "Lyrics color, typography, and motion."
        case .general: return "Player selection and system behavior."
        }
    }
}

@MainActor
private final class SidebarNavDeckView: NSView {
    static let rowHeight: CGFloat = 38
    static let rowSpacing: CGFloat = 4
    static var totalHeight: CGFloat {
        CGFloat(SettingsPage.allCases.count) * rowHeight + CGFloat(max(0, SettingsPage.allCases.count - 1)) * rowSpacing
    }

    override var isFlipped: Bool { true }

    private let selectionBackdrop = NSView()
    private let selectionLed = NSView()
    private var buttons: [SettingsPage: SidebarNavButton] = [:]
    private var currentPage: SettingsPage = .lyrics

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false

        selectionBackdrop.wantsLayer = true
        selectionBackdrop.layer?.cornerRadius = 9
        selectionBackdrop.layer?.cornerCurve = .continuous
        selectionBackdrop.layer?.borderWidth = 0.5
        selectionBackdrop.frame = NSRect(x: 0, y: 0, width: 200, height: Self.rowHeight)

        selectionLed.wantsLayer = true
        selectionLed.layer?.cornerRadius = 1.5
        selectionLed.layer?.masksToBounds = false
        selectionLed.frame = NSRect(x: 8, y: (Self.rowHeight - 16) / 2, width: 3, height: 16)
        selectionBackdrop.addSubview(selectionLed)

        addSubview(selectionBackdrop)
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    func configure(buttons orderedButtons: [SidebarNavButton]) {
        for (index, button) in orderedButtons.enumerated() {
            let y = CGFloat(index) * (Self.rowHeight + Self.rowSpacing)
            button.frame = NSRect(x: 0, y: y, width: 200, height: Self.rowHeight)
            addSubview(button)
            buttons[button.page] = button
        }
        select(currentPage, animated: false)
    }

    func select(_ page: SettingsPage, animated: Bool) {
        let didChange = page != currentPage
        currentPage = page
        let index = SettingsPage.allCases.firstIndex(of: page) ?? 0
        let targetY = CGFloat(index) * (Self.rowHeight + Self.rowSpacing)
        let targetFrame = NSRect(x: 0, y: targetY, width: 200, height: Self.rowHeight)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                selectionBackdrop.animator().frame = targetFrame
            }
        } else {
            selectionBackdrop.frame = targetFrame
        }

        for (buttonPage, button) in buttons {
            button.setSelected(buttonPage == page, animated: animated && didChange && buttonPage == page)
        }
        refreshAppearance()
    }

    func updateDisplayMode(_ mode: DisplayMode) {
        let isZh = AppPreferences.language == .simplifiedChinese
        let badge: String
        switch mode {
        case .notch: badge = isZh ? "刘海" : "Notch"
        case .statusBar: badge = isZh ? "状态栏" : "Bar"
        case .free: badge = isZh ? "悬浮" : "Float"
        }
        buttons[.display]?.updateDisplayModeBadge(badge)
    }

    func updateAppearanceColor(_ color: NSColor) {
        buttons[.appearance]?.updateAppearanceDotColor(color)
    }

    func updateGeneralActive(_ active: Bool) {
        buttons[.general]?.updateGeneralStatus(active: active)
    }

    func updateLyricsStatus(isPlaying: Bool, synced: Bool) {
        buttons[.lyrics]?.updateLyricsStatus(isPlaying: isPlaying, synced: synced)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            selectionBackdrop.layer?.backgroundColor = AppearanceSurfaceColors.accentSoft.cgColor
            selectionBackdrop.layer?.borderColor = AppearanceSurfaceColors.accentBorder.cgColor
            selectionLed.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
            selectionLed.layer?.shadowColor = AppearanceSurfaceColors.accent.cgColor
            selectionLed.layer?.shadowRadius = 4
            selectionLed.layer?.shadowOpacity = 0.65
            selectionLed.layer?.shadowOffset = .zero
        }
        buttons.values.forEach { $0.refreshAppearance() }
    }
}

@MainActor
private final class SidebarNavButton: NSButton {
    let page: SettingsPage
    private let ledSlotView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var iconLeadingConstraint: NSLayoutConstraint?

    // Live micro-indicators (one per page)
    private let modePill = NSView()
    private let modePillLabel = NSTextField(labelWithString: "")
    private let colorDot = NSView()
    private var currentLyricColor: NSColor = AppearanceSurfaceColors.accent
    private let statusDot = NSView()
    private var isPlayerActive = false
    private let lyricsDot = NSView()
    private var isLyricsPlaying = false
    private var isLyricsSynced = false

    private var tracking: NSTrackingArea?
    private var isHovered = false
    private var isRowSelected = false

    init(page: SettingsPage, target: AnyObject?, action: Selector?) {
        self.page = page
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

        ledSlotView.wantsLayer = true
        ledSlotView.layer?.cornerRadius = 1.5
        ledSlotView.translatesAutoresizingMaskIntoConstraints = false

        let symbolImage = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13.5, weight: .medium))
        iconView.image = symbolImage
        iconView.wantsLayer = true
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = L10n.text(page.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(ledSlotView)
        addSubview(iconView)
        addSubview(titleLabel)

        let iconLeading = iconView.leadingAnchor.constraint(equalTo: ledSlotView.trailingAnchor, constant: 10)
        iconLeadingConstraint = iconLeading

        var constraints: [NSLayoutConstraint] = [
            ledSlotView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            ledSlotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ledSlotView.widthAnchor.constraint(equalToConstant: 3),
            ledSlotView.heightAnchor.constraint(equalToConstant: 16),

            iconLeading,
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]

        switch page {
        case .lyrics:
            lyricsDot.wantsLayer = true
            lyricsDot.layer?.cornerRadius = 3
            lyricsDot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(lyricsDot)

            constraints += [
                lyricsDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
                lyricsDot.centerYAnchor.constraint(equalTo: centerYAnchor),
                lyricsDot.widthAnchor.constraint(equalToConstant: 6),
                lyricsDot.heightAnchor.constraint(equalToConstant: 6),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: lyricsDot.leadingAnchor, constant: -8)
            ]

        case .display:
            modePill.wantsLayer = true
            modePill.layer?.cornerRadius = 4.5
            modePill.layer?.cornerCurve = .continuous
            modePill.translatesAutoresizingMaskIntoConstraints = false

            modePillLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
            modePillLabel.textColor = .tertiaryLabelColor
            modePillLabel.translatesAutoresizingMaskIntoConstraints = false
            modePill.addSubview(modePillLabel)
            addSubview(modePill)

            constraints += [
                modePillLabel.leadingAnchor.constraint(equalTo: modePill.leadingAnchor, constant: 6),
                modePillLabel.trailingAnchor.constraint(equalTo: modePill.trailingAnchor, constant: -6),
                modePillLabel.topAnchor.constraint(equalTo: modePill.topAnchor, constant: 2),
                modePillLabel.bottomAnchor.constraint(equalTo: modePill.bottomAnchor, constant: -2),
                modePill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                modePill.centerYAnchor.constraint(equalTo: centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: modePill.leadingAnchor, constant: -6)
            ]

        case .appearance:
            colorDot.wantsLayer = true
            colorDot.layer?.cornerRadius = 4
            colorDot.layer?.borderWidth = 0.5
            colorDot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(colorDot)

            constraints += [
                colorDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                colorDot.centerYAnchor.constraint(equalTo: centerYAnchor),
                colorDot.widthAnchor.constraint(equalToConstant: 8),
                colorDot.heightAnchor.constraint(equalToConstant: 8),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: colorDot.leadingAnchor, constant: -8)
            ]

        case .general:
            statusDot.wantsLayer = true
            statusDot.layer?.cornerRadius = 3
            statusDot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(statusDot)

            constraints += [
                statusDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
                statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
                statusDot.widthAnchor.constraint(equalToConstant: 6),
                statusDot.heightAnchor.constraint(equalToConstant: 6),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusDot.leadingAnchor, constant: -8)
            ]
        }

        NSLayoutConstraint.activate(constraints)
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ selected: Bool, animated: Bool = false) {
        isRowSelected = selected
        updateHoverNudge(animated: animated)
        refreshAppearance()
    }

    func updateDisplayModeBadge(_ text: String) {
        modePillLabel.stringValue = text
    }

    func updateAppearanceDotColor(_ color: NSColor) {
        currentLyricColor = color
        refreshAppearance()
    }

    func updateGeneralStatus(active: Bool) {
        isPlayerActive = active
        refreshAppearance()
    }

    func updateLyricsStatus(isPlaying: Bool, synced: Bool) {
        isLyricsPlaying = isPlaying
        isLyricsSynced = synced
        refreshAppearance()
    }

    private func updateHoverNudge(animated: Bool) {
        let targetOffset: CGFloat = (isHovered && !isRowSelected) ? 12 : 10
        guard iconLeadingConstraint?.constant != targetOffset else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                iconLeadingConstraint?.animator().constant = targetOffset
            }
        } else {
            iconLeadingConstraint?.constant = targetOffset
        }
    }

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        InteractionMotion.rebound(layer, from: 0.97)
        InteractionSoundEngine.shared.play(.tick)
        return super.sendAction(action, to: target)
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
        updateHoverNudge(animated: true)
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateHoverNudge(animated: true)
        refreshAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            ledSlotView.isHidden = isRowSelected
            ledSlotView.layer?.backgroundColor = AppearanceSurfaceColors.ledOff.cgColor

            if isRowSelected {
                layer?.backgroundColor = NSColor.clear.cgColor
                iconView.contentTintColor = .labelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
                titleLabel.textColor = .labelColor
            } else if isHovered {
                layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
                iconView.contentTintColor = .labelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
                titleLabel.textColor = .labelColor
            } else {
                layer?.backgroundColor = NSColor.clear.cgColor
                iconView.contentTintColor = .secondaryLabelColor
                titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
                titleLabel.textColor = .secondaryLabelColor
            }

            switch page {
            case .lyrics:
                if isLyricsPlaying && isLyricsSynced {
                    lyricsDot.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
                } else if isLyricsSynced {
                    lyricsDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
                } else {
                    lyricsDot.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.55).cgColor
                }
            case .display:
                modePill.layer?.backgroundColor = isRowSelected
                    ? AppearanceSurfaceColors.accentSoft.cgColor
                    : NSColor.labelColor.withAlphaComponent(0.06).cgColor
                modePillLabel.textColor = isRowSelected ? AppearanceSurfaceColors.accent : .tertiaryLabelColor
            case .appearance:
                colorDot.layer?.backgroundColor = currentLyricColor.cgColor
                colorDot.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.24).cgColor
            case .general:
                statusDot.layer?.backgroundColor = isPlayerActive
                    ? NSColor.systemGreen.cgColor
                    : NSColor.tertiaryLabelColor.withAlphaComponent(0.55).cgColor
            }
        }
    }
}

@MainActor
private final class SettingsPreviewModeCard: NSView {
    private let drawCard: (NSRect) -> Void

    init(drawCard: @escaping (NSRect) -> Void) {
        self.drawCard = drawCard
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            drawCard(bounds)
        }
    }
}

@MainActor
private final class SettingsPreviewView: NSView {
    typealias Mode = DisplayMode
    var mode: Mode = .statusBar { didSet { redrawCards() } }
    var liveLyricText: String? { didSet { redrawCards() } }
    var onModeClick: ((Mode) -> Void)?
    private var hoveredMode: Mode? { didSet { if hoveredMode != oldValue { redrawCards() } } }
    private var hoverTrackingArea: NSTrackingArea?
    private var cards: [Mode: SettingsPreviewModeCard] = [:]
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for mode in Mode.allCases {
            let card = SettingsPreviewModeCard { [weak self] rect in
                self?.drawPanel(rect, panelMode: mode)
            }
            cards[mode] = card
            addSubview(card)
        }
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let gap: CGFloat = 12
        let panelWidth = max(0, (bounds.width - gap * 2) / 3)
        for (index, mode) in Mode.allCases.enumerated() {
            cards[mode]?.frame = NSRect(
                x: CGFloat(index) * (panelWidth + gap), y: 0, width: panelWidth, height: bounds.height
            )
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        redrawCards()
    }

    private func redrawCards() {
        cards.values.forEach { $0.needsDisplay = true }
    }

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
            InteractionMotion.rebound(cards[clickedMode]?.layer, from: 0.97)
            InteractionSoundEngine.shared.play(.tick)
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
        redrawCards()
    }

    private func drawPanel(_ rect: NSRect, panelMode: Mode) {
        let selected = mode == panelMode
        let hovered = hoveredMode == panelMode
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        // 1. Card background & selection/hover chrome
        let cardPath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 11, yRadius: 11)
        if selected {
            AppearanceSurfaceColors.accentSoft.withAlphaComponent(isDark ? 0.14 : 0.10).setFill()
            cardPath.fill()
        } else if hovered {
            NSColor.labelColor.withAlphaComponent(0.04).setFill()
            cardPath.fill()
        } else {
            (isDark ? NSColor.white.withAlphaComponent(0.02) : NSColor.black.withAlphaComponent(0.015)).setFill()
            cardPath.fill()
        }

        // 2. Miniature 16:10 MacBook Desktop Screen (~72% of card height)
        let screenInset: CGFloat = 8
        let footerHeight: CGFloat = 56
        let screen = NSRect(
            x: rect.minX + screenInset,
            y: rect.minY + screenInset + (hovered && !selected ? -1 : 0),
            width: rect.width - screenInset * 2,
            height: max(84, rect.height - screenInset - footerHeight)
        )

        NSGraphicsContext.saveGraphicsState()
        let screenClip = NSBezierPath(roundedRect: screen, xRadius: 8, yRadius: 8)
        screenClip.addClip()

        // Adaptive macOS desktop wallpaper gradient
        let wallpaperGradient: NSGradient?
        if isDark {
            wallpaperGradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.17, alpha: 1),
                NSColor(calibratedRed: 0.13, green: 0.11, blue: 0.20, alpha: 1),
                NSColor(calibratedRed: 0.18, green: 0.12, blue: 0.15, alpha: 1)
            ])
        } else {
            wallpaperGradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.77, green: 0.84, blue: 0.92, alpha: 1),
                NSColor(calibratedRed: 0.89, green: 0.87, blue: 0.83, alpha: 1),
                NSColor(calibratedRed: 0.94, green: 0.88, blue: 0.81, alpha: 1)
            ])
        }
        wallpaperGradient?.draw(in: screen, angle: -25)

        // Subtle warm ambient radial wash
        let glowRect = NSRect(x: screen.midX - screen.width * 0.45, y: screen.minY + 12, width: screen.width * 0.9, height: screen.height * 0.75)
        let glowColor = AppearanceSurfaceColors.accent.withAlphaComponent(isDark ? 0.10 : 0.08)
        NSGradient(starting: glowColor, ending: .clear)?.draw(in: glowRect, relativeCenterPosition: .zero)

        // Top translucent macOS menu bar strip (15pt tall)
        let menuBarHeight: CGFloat = 15
        let menuBar = NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: menuBarHeight)
        (isDark ? NSColor.black.withAlphaComponent(0.50) : NSColor.white.withAlphaComponent(0.76)).setFill()
        NSBezierPath(rect: menuBar).fill()
        (isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08)).setFill()
        NSBezierPath(rect: NSRect(x: menuBar.minX, y: menuBar.maxY - 0.5, width: menuBar.width, height: 0.5)).fill()

        // Menu bar left dots & skeleton items
        let menuInk = isDark ? NSColor.white.withAlphaComponent(0.55) : NSColor.black.withAlphaComponent(0.45)
        menuInk.setFill()
        NSBezierPath(ovalIn: NSRect(x: menuBar.minX + 6, y: menuBar.midY - 2, width: 4, height: 4)).fill()
        NSBezierPath(roundedRect: NSRect(x: menuBar.minX + 13, y: menuBar.midY - 1, width: 10, height: 2), xRadius: 1, yRadius: 1).fill()
        NSBezierPath(roundedRect: NSRect(x: menuBar.minX + 26, y: menuBar.midY - 1, width: 12, height: 2), xRadius: 1, yRadius: 1).fill()

        // Menu bar right micro status dots
        for i in 0..<3 {
            let dotX = menuBar.maxX - 7 - CGFloat(i) * 5.5
            NSBezierPath(ovalIn: NSRect(x: dotX - 1.25, y: menuBar.midY - 1.25, width: 2.5, height: 2.5)).fill()
        }

        // Physical black MacBook notch cutout (top-center, rounded bottom corners)
        let notchWidth: CGFloat = min(44, screen.width * 0.28)
        let notchHeight: CGFloat = 11
        let notchRect = NSRect(x: screen.midX - notchWidth / 2, y: screen.minY - 3, width: notchWidth, height: notchHeight + 3)

        // Subtle miniature workspace window in desktop center ("my open app")
        let winWidth = screen.width * 0.64
        let winHeight = max(46, (screen.height - menuBarHeight - 24) * 0.68)
        let winRect = NSRect(
            x: screen.midX - winWidth / 2,
            y: menuBar.maxY + (screen.height - menuBarHeight - 20 - winHeight) * 0.45,
            width: winWidth,
            height: winHeight
        )
        drawMiniatureWorkspaceWindow(in: winRect, isDark: isDark)

        // Tiny frosted bottom Dock pill with 5 micro app dots
        let dockWidth: CGFloat = min(58, screen.width * 0.36)
        let dockHeight: CGFloat = 11
        let dockRect = NSRect(
            x: screen.midX - dockWidth / 2,
            y: screen.maxY - dockHeight - 5,
            width: dockWidth,
            height: dockHeight
        )
        drawMiniatureDock(in: dockRect, isDark: isDark)

        // Mode-specific unmistakable lyric overlay
        let sampleLyric = shortPreviewLyric()
        switch panelMode {
        case .statusBar:
            // Draw notch first, then highlight lyric lane right inside top menu bar
            drawNotchCutout(notchRect)
            drawStatusBarOverlay(menuBar: menuBar, notchRect: notchRect, text: sampleLyric, isDark: isDark)
        case .notch:
            // Frosted dark rounded-bottom capsule hugging/extending cleanly around top-center notch
            drawNotchModeOverlay(screen: screen, notchRect: notchRect, text: sampleLyric)
        case .free:
            // Draw notch, then dashed vertical snap guide + floating lyric capsule over the workspace window
            drawNotchCutout(notchRect)
            drawFreeFloatingOverlay(screen: screen, winRect: winRect, text: sampleLyric, isDark: isDark)
        }

        NSGraphicsContext.restoreGraphicsState()

        // Miniature MacBook bezel frame
        let bezelColor = isDark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.16)
        bezelColor.setStroke()
        let bezel = NSBezierPath(roundedRect: screen.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        bezel.lineWidth = 0.75
        bezel.stroke()

        // 3. Clean Card Footer (Title + Active Pill + Concise Caption)
        let isZh = AppPreferences.language == .simplifiedChinese
        let titleText: String
        let captionText: String
        switch panelMode {
        case .statusBar:
            titleText = isZh ? "菜单栏" : "Status Bar"
            captionText = isZh ? "融入顶部菜单栏，极简常驻" : "Quietly docked in the menu bar"
        case .notch:
            titleText = isZh ? "刘海环绕" : "Notch"
            captionText = isZh ? "贴合屏幕刘海，不占工作区" : "Hugs your MacBook notch cleanly"
        case .free:
            titleText = isZh ? "自由悬浮" : "Free Floating"
            captionText = isZh ? "任意位置拖动，支持穿透" : "Drag anywhere, click-through ready"
        }

        let footerTop = screen.maxY + 9
        let titleFont = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let titleColor: NSColor = (selected || hovered) ? .labelColor : .secondaryLabelColor
        let activeBadgeWidth: CGFloat = selected ? (isZh ? 34 : 42) : 0
        (titleText as NSString).draw(
            in: NSRect(x: rect.minX + 10, y: footerTop, width: rect.width - 20 - activeBadgeWidth, height: 17),
            withAttributes: [.font: titleFont, .foregroundColor: titleColor]
        )

        if selected {
            let badgeText = isZh ? "当前" : "Active"
            let badgeRect = NSRect(x: rect.maxX - 10 - activeBadgeWidth, y: footerTop + 1, width: activeBadgeWidth, height: 15)
            AppearanceSurfaceColors.accentSoft.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
            let badgeStyle = NSMutableParagraphStyle()
            badgeStyle.alignment = .center
            (badgeText as NSString).draw(
                in: NSRect(x: badgeRect.minX, y: badgeRect.minY + 1, width: badgeRect.width, height: 13),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 9.5, weight: .semibold),
                    .foregroundColor: AppearanceSurfaceColors.accent,
                    .paragraphStyle: badgeStyle
                ]
            )
        }

        let captionStyle = NSMutableParagraphStyle()
        captionStyle.lineBreakMode = .byTruncatingTail
        (captionText as NSString).draw(
            in: NSRect(x: rect.minX + 10, y: footerTop + 20, width: rect.width - 20, height: 15),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: selected ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor,
                .paragraphStyle: captionStyle
            ]
        )

        // 4. Outer Card Border (1.5pt warm amber when selected, 0.5pt quiet border when idle)
        if selected {
            AppearanceSurfaceColors.accent.setStroke()
            cardPath.lineWidth = 1.5
            cardPath.stroke()
        } else if hovered {
            AppearanceSurfaceColors.accent.withAlphaComponent(0.45).setStroke()
            cardPath.lineWidth = 1.0
            cardPath.stroke()
        } else {
            AppearanceSurfaceColors.border.setStroke()
            cardPath.lineWidth = 0.5
            cardPath.stroke()
        }
    }

    private func shortPreviewLyric() -> String {
        let raw = liveLyricText ?? L10n.text("Preview lyric sample")
        return "♪ " + raw
    }

    private func drawNotchCutout(_ notchRect: NSRect) {
        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(roundedRect: notchRect, xRadius: 4, yRadius: 4).fill()
    }

    private func drawMiniatureWorkspaceWindow(in rect: NSRect, isDark: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(isDark ? 0.35 : 0.14)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        let windowBg = isDark
            ? NSColor(calibratedRed: 0.14, green: 0.145, blue: 0.17, alpha: 0.90)
            : NSColor.white.withAlphaComponent(0.86)
        windowBg.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        (isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08)).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Traffic lights
        let lights: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.37, blue: 0.34, alpha: 0.9),
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.18, alpha: 0.9),
            NSColor(calibratedRed: 0.15, green: 0.79, blue: 0.25, alpha: 0.9)
        ]
        for (i, color) in lights.enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX + 6 + CGFloat(i) * 5.5, y: rect.minY + 4.5, width: 3, height: 3)).fill()
        }

        // Subtle titlebar hairline
        (isDark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.05)).setFill()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY + 11, width: rect.width, height: 0.5)).fill()

        // 3 faint horizontal skeleton content lines
        let lineInk = isDark ? NSColor.white.withAlphaComponent(0.11) : NSColor.black.withAlphaComponent(0.08)
        lineInk.setFill()
        let ratios: [CGFloat] = [0.56, 0.74, 0.42]
        for (i, ratio) in ratios.enumerated() {
            let lineRect = NSRect(
                x: rect.minX + 7,
                y: rect.minY + 17 + CGFloat(i) * 7,
                width: (rect.width - 14) * ratio,
                height: 2.5
            )
            NSBezierPath(roundedRect: lineRect, xRadius: 1.25, yRadius: 1.25).fill()
        }
    }

    private func drawMiniatureDock(in rect: NSRect, isDark: Bool) {
        (isDark ? NSColor.white.withAlphaComponent(0.13) : NSColor.white.withAlphaComponent(0.68)).setFill()
        let pill = NSBezierPath(roundedRect: rect, xRadius: 4.5, yRadius: 4.5)
        pill.fill()
        (isDark ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.10)).setStroke()
        pill.lineWidth = 0.5
        pill.stroke()

        let dotColors: [NSColor] = [
            NSColor(calibratedRed: 0.24, green: 0.62, blue: 1.0, alpha: 0.85),
            NSColor(calibratedRed: 0.30, green: 0.82, blue: 0.46, alpha: 0.85),
            AppearanceSurfaceColors.accent.withAlphaComponent(0.9),
            NSColor(calibratedRed: 0.68, green: 0.44, blue: 0.96, alpha: 0.85),
            NSColor(calibratedRed: 0.96, green: 0.36, blue: 0.48, alpha: 0.85)
        ]
        let dotSize: CGFloat = 5.5
        let spacing: CGFloat = 3.5
        let total = CGFloat(dotColors.count) * dotSize + CGFloat(dotColors.count - 1) * spacing
        let startX = rect.midX - total / 2
        for (i, color) in dotColors.enumerated() {
            color.setFill()
            let dotRect = NSRect(x: startX + CGFloat(i) * (dotSize + spacing), y: rect.midY - dotSize / 2, width: dotSize, height: dotSize)
            NSBezierPath(roundedRect: dotRect, xRadius: 1.5, yRadius: 1.5).fill()
        }
    }

    private func drawStatusBarOverlay(menuBar: NSRect, notchRect: NSRect, text: String, isDark: Bool) {
        let isLeft = position == .left
        let laneX = isLeft ? menuBar.minX + 18 : notchRect.maxX + 4
        let laneMaxX = isLeft ? notchRect.minX - 4 : menuBar.maxX - 22
        let laneWidth = max(36, laneMaxX - laneX)
        let highlightRect = NSRect(x: laneX, y: menuBar.minY + 1.5, width: laneWidth, height: menuBar.height - 3)

        // Warm amber glow pill right inside the top menu bar
        AppearanceSurfaceColors.accent.withAlphaComponent(isDark ? 0.24 : 0.18).setFill()
        let glowPath = NSBezierPath(roundedRect: highlightRect, xRadius: 3, yRadius: 3)
        glowPath.fill()
        AppearanceSurfaceColors.accent.withAlphaComponent(0.65).setStroke()
        glowPath.lineWidth = 0.6
        glowPath.stroke()

        drawMiniLyric(text, in: highlightRect.insetBy(dx: 3, dy: 0), fontSize: 7.5, alignment: .center, shadow: false)
    }

    private func drawNotchModeOverlay(screen: NSRect, notchRect: NSRect, text: String) {
        let capsuleWidth = min(screen.width - 20, max(notchRect.width + 52, screen.width * 0.66))
        let capsuleHeight: CGFloat = 25
        let capsuleRect = NSRect(
            x: screen.midX - capsuleWidth / 2,
            y: screen.minY - 4,
            width: capsuleWidth,
            height: capsuleHeight + 4
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        let fillColor = notchBackground
            ? notchBackgroundColor.withAlphaComponent(max(0.78, backgroundOpacity))
            : NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.065, alpha: 0.96)
        fillColor.setFill()
        let capsule = NSBezierPath(roundedRect: capsuleRect, xRadius: 8, yRadius: 8)
        capsule.fill()
        NSGraphicsContext.restoreGraphicsState()

        AppearanceSurfaceColors.accent.withAlphaComponent(0.45).setStroke()
        capsule.lineWidth = 0.75
        capsule.stroke()

        // Physical notch camera silhouette seamlessly merged at top center
        drawNotchCutout(notchRect)

        // Glowing lyric text right below the notch cutout
        let textRect = NSRect(x: capsuleRect.minX + 6, y: notchRect.maxY + 1, width: capsuleRect.width - 12, height: 12)
        drawMiniLyric(text, in: textRect, fontSize: 8.5, alignment: .center, shadow: true)
    }

    private func drawFreeFloatingOverlay(screen: NSRect, winRect: NSRect, text: String, isDark: Bool) {
        // Subtle 1pt dashed vertical magnetic snap guide
        NSGraphicsContext.saveGraphicsState()
        let guide = NSBezierPath()
        guide.move(to: NSPoint(x: screen.midX, y: screen.minY + 16))
        guide.line(to: NSPoint(x: screen.midX, y: screen.maxY - 18))
        let pattern: [CGFloat] = [2.5, 2.5]
        guide.setLineDash(pattern, count: 2, phase: 0)
        AppearanceSurfaceColors.accent.withAlphaComponent(0.45).setStroke()
        guide.lineWidth = 0.85
        guide.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Independent frosted dark capsule floating over the miniature workspace window
        let pillWidth = min(screen.width - 20, max(92, screen.width * 0.68))
        let pillHeight: CGFloat = 21
        let pillRect = NSRect(
            x: screen.midX - pillWidth / 2,
            y: winRect.midY - pillHeight / 2 + 6,
            width: pillWidth,
            height: pillHeight
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(isDark ? 0.55 : 0.28)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()

        let fillColor = notchBackground
            ? notchBackgroundColor.withAlphaComponent(max(0.82, backgroundOpacity))
            : NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 0.92)
        fillColor.setFill()
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        pillPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        pillPath.lineWidth = 0.75
        pillPath.stroke()

        // Tiny subtle 6-dot drag grip on left edge
        NSColor.white.withAlphaComponent(0.38).setFill()
        for col in 0..<2 {
            for row in 0..<3 {
                let gx = pillRect.minX + 7 + CGFloat(col) * 2.5
                let gy = pillRect.midY - 3.25 + CGFloat(row) * 2.5
                NSBezierPath(ovalIn: NSRect(x: gx, y: gy, width: 1.5, height: 1.5)).fill()
            }
        }

        let textRect = NSRect(x: pillRect.minX + 14, y: pillRect.midY - 5.5, width: pillRect.width - 20, height: 12)
        drawMiniLyric(text, in: textRect, fontSize: 8.5, alignment: .center, shadow: true)
    }

    private func drawMiniLyric(_ text: String, in rect: NSRect, fontSize: CGFloat, alignment: NSTextAlignment, shadow: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        if usesGradient {
            BrandStyle.gradientLyric(
                text,
                colors: lyricColors.map { $0.withAlphaComponent(max(0.75, lyricOpacity)) },
                attributes: [.font: font, .paragraphStyle: paragraph]
            ).draw(in: rect)
        } else {
            let color = lyricColors[min(1, lyricColors.count - 1)].withAlphaComponent(max(0.85, lyricOpacity))
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            if shadow {
                let textShadow = NSShadow()
                textShadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
                textShadow.shadowBlurRadius = 2
                textShadow.shadowOffset = NSSize(width: 0, height: -0.5)
                attributes[.shadow] = textShadow
            }
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
}
