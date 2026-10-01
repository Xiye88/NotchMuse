import AppKit
import ApplicationServices
import ImageIO

enum MenuBarSpaceZone: String, CaseIterable {
    case visible, hidden, alwaysHidden
}

enum MenuBarSpaceIcon: String, CaseIterable {
    case waveform, arrow, chevron, dot, ellipsis, custom

    var symbol: String {
        switch self {
        case .waveform: "waveform"
        case .arrow: "arrow.left"
        case .chevron: "chevron.down"
        case .dot: "circle.fill"
        case .ellipsis: "ellipsis"
        case .custom: "photo"
        }
    }
}

struct MenuBarSpaceItem {
    let id: String
    let name: String
    let icon: NSImage?
    let movable: Bool
    var zone: MenuBarSpaceZone
    let element: AXUIElement
}

@MainActor
final class MenuBarSpaceController: NSObject {
    nonisolated static let enabledKey = "MenuBarSpaceEnabled"
    static let zonesKey = "MenuBarSpaceZones"
    static let iconKey = "MenuBarSpaceIcon"
    static let customIconKey = "MenuBarSpaceCustomIcon"
    private static let controlID = "notchmuse.space.control"
    private static let hiddenID = "notchmuse.space.hidden"
    private static let alwaysID = "notchmuse.space.always"

    var onChange: (() -> Void)?
    private(set) var items: [MenuBarSpaceItem] = []
    private(set) var isRevealed = false
    private var isMoving = false
    private var control: NSStatusItem?
    private var hiddenDivider: NSStatusItem?
    private var alwaysDivider: NSStatusItem?
    private var cachedBoundary: CGFloat?
    private var boundaryCheckedAt: TimeInterval = 0
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?

    var isEnabled: Bool { Self.isEnabled(in: .standard) }
    nonisolated static func isEnabled(in defaults: UserDefaults) -> Bool { defaults.bool(forKey: enabledKey) }
    nonisolated static func canStart(enabled: Bool, trusted: Bool, hasConflict: Bool) -> Bool {
        enabled && trusted && !hasConflict
    }
    var isActive: Bool { control != nil }
    var conflictingManagerName: String? {
        NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.stonerl.Thaw" })?.localizedName
    }
    func safeBoundary(on screen: NSScreen?) -> CGFloat? {
        guard let screen, control?.button?.window?.screen == screen else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
        if now - boundaryCheckedAt < 0.5 { return cachedBoundary }
        let id = isRevealed ? Self.alwaysID : Self.hiddenID
        cachedBoundary = Self.ownFrame(id)?.maxX
        boundaryCheckedAt = now
        return cachedBoundary
    }
    var needsPermission: Bool { isEnabled && !AXIsProcessTrusted() }
    var icon: MenuBarSpaceIcon {
        MenuBarSpaceIcon(rawValue: UserDefaults.standard.string(forKey: Self.iconKey) ?? "") ?? .waveform
    }

    nonisolated static func resolvedZone(id: String, protected: Bool, saved: [String: String]) -> MenuBarSpaceZone {
        protected ? .visible : MenuBarSpaceZone(rawValue: saved[id] ?? "") ?? .visible
    }

    nonisolated static func savedZones(_ current: [String: String], id: String, zone: MenuBarSpaceZone) -> [String: String] {
        var result = current
        if zone == .visible { result.removeValue(forKey: id) } else { result[id] = zone.rawValue }
        return result
    }

    func start() {
        guard Self.canStart(enabled: isEnabled, trusted: AXIsProcessTrusted(), hasConflict: conflictingManagerName != nil) else { return }
        guard control == nil else { refresh(); return }
        let bar = NSStatusBar.system
        control = bar.statusItem(withLength: NSStatusItem.squareLength)
        control?.autosaveName = "NotchMuseSpaceControl"
        control?.button?.setAccessibilityIdentifier(Self.controlID)
        control?.button?.toolTip = L10n.text("Reveal hidden menu bar items")
        control?.button?.target = self
        control?.button?.action = #selector(toggleReveal)
        hiddenDivider = bar.statusItem(withLength: 18)
        hiddenDivider?.autosaveName = "NotchMuseSpaceHidden"
        hiddenDivider?.button?.setAccessibilityIdentifier(Self.hiddenID)
        alwaysDivider = bar.statusItem(withLength: 18)
        alwaysDivider?.autosaveName = "NotchMuseSpaceAlways"
        alwaysDivider?.button?.setAccessibilityIdentifier(Self.alwaysID)
        updateIcon()
        refresh()
        applyVisibility()
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let observer = NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh(); await self?.reconcileSavedZones() }
            }
            workspaceObservers.append(observer)
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.applyVisibility(); self?.onChange?() }
        }
        Task { await reconcileSavedZones() }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled {
            if !AXIsProcessTrusted() {
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
            start()
        } else {
            stop()
        }
        onChange?()
    }

    func stop() {
        guard control != nil else { return }
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        hiddenDivider?.length = 18
        alwaysDivider?.length = 18
        let bar = NSStatusBar.system
        for item in [alwaysDivider, hiddenDivider, control].compactMap({ $0 }) {
            bar.removeStatusItem(item)
        }
        control = nil
        hiddenDivider = nil
        alwaysDivider = nil
        isRevealed = false
        items = []
        onChange?()
    }

    @objc private func toggleReveal() {
        isRevealed.toggle()
        applyVisibility()
        onChange?()
    }

    private func applyVisibility() {
        guard !isMoving, let control, let screen = control.button?.window?.screen else { return }
        let width = min(10_000, max(2_000, screen.frame.width * 2))
        alwaysDivider?.length = width
        hiddenDivider?.length = isRevealed ? 18 : width
        boundaryCheckedAt = 0
    }

    func refresh() {
        guard isActive, !isMoving, AXIsProcessTrusted() else { return }
        let zones = UserDefaults.standard.dictionary(forKey: Self.zonesKey) as? [String: String] ?? [:]
        var found: [MenuBarSpaceItem] = []
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier > 0 {
            let bundle = app.bundleIdentifier ?? ""
            guard !bundle.isEmpty,
                  let barValue = Self.attribute(AXUIElementCreateApplication(app.processIdentifier), kAXExtrasMenuBarAttribute as CFString),
                  CFGetTypeID(barValue) == AXUIElementGetTypeID(),
                  let children = Self.attribute(barValue as! AXUIElement, kAXChildrenAttribute as CFString) as? [AXUIElement] else { continue }
            for child in children {
                guard Self.string(child, kAXRoleAttribute as CFString) == "AXMenuBarItem" else { continue }
                let identifier = Self.string(child, kAXIdentifierAttribute as CFString)
                if identifier.hasPrefix("notchmuse.space.") || bundle == Bundle.main.bundleIdentifier { continue }
                if bundle == "com.apple.controlcenter" && identifier.isEmpty { continue }
                let hasStableIdentity = !identifier.isEmpty || children.count == 1
                let id = bundle + ":" + (identifier.isEmpty ? "single" : identifier)
                let description = Self.string(child, kAXDescriptionAttribute as CFString)
                let name = description.isEmpty ? (app.localizedName ?? bundle) : description
                let protected = bundle.hasPrefix("com.apple.") || !hasStableIdentity
                let zone = Self.resolvedZone(id: id, protected: protected, saved: zones)
                found.append(MenuBarSpaceItem(id: id, name: name, icon: app.icon, movable: !protected, zone: zone, element: child))
            }
        }
        items = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        onChange?()
    }

    func setZone(_ zone: MenuBarSpaceZone, for id: String) async -> Bool {
        guard isActive, let index = items.firstIndex(where: { $0.id == id }), items[index].movable else { return false }
        guard await move(items[index].element, to: zone) else { return false }
        guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return false }
        items[currentIndex].zone = zone
        let zones = Self.savedZones(UserDefaults.standard.dictionary(forKey: Self.zonesKey) as? [String: String] ?? [:], id: id, zone: zone)
        UserDefaults.standard.set(zones, forKey: Self.zonesKey)
        if zone == .visible {
            for other in items where other.id != id && other.movable && other.zone != .visible {
                _ = await move(other.element, to: other.zone)
            }
        }
        onChange?()
        return true
    }

    private func reconcileSavedZones() async {
        guard isActive else { return }
        for item in items where item.movable && item.zone != .visible {
            _ = await move(item.element, to: item.zone)
        }
        onChange?()
    }

    private func move(_ element: AXUIElement, to zone: MenuBarSpaceZone) async -> Bool {
        guard !isMoving else { return false }
        isMoving = true
        let wasRevealed = isRevealed
        hiddenDivider?.length = 18
        alwaysDivider?.length = 18
        defer { isMoving = false; isRevealed = wasRevealed; applyVisibility() }
        try? await Task.sleep(for: .milliseconds(150))
        guard let sourceFrame = Self.frame(element),
              let hiddenFrame = Self.ownFrame(Self.hiddenID),
              let alwaysFrame = Self.ownFrame(Self.alwaysID) else { return false }
        var windows = MenuBarItemWindow.snapshot()
        guard let source = MenuBarItemWindow.matching(sourceFrame, in: windows),
              let hidden = MenuBarItemWindow.matching(hiddenFrame, in: windows),
              let always = MenuBarItemWindow.matching(alwaysFrame, in: windows),
              always.frame.midX < hidden.frame.midX else { return false }
        for _ in 0..<4 {
            guard let item = windows.first(where: { $0.id == source.id }),
                  let h = windows.first(where: { $0.id == hidden.id }),
                  let a = windows.first(where: { $0.id == always.id }) else { return false }
            if Self.physicalZone(item: item.frame, hidden: h.frame, always: a.frame) == zone { return true }
            let anchor = zone == .visible ? item : a
            let moved = zone == .visible ? h : item
            let left = zone == .visible || zone == .alwaysHidden
            _ = await Task.detached(priority: .userInitiated) {
                MenuBarItemMover.move(moved, beside: anchor, left: left)
            }.value
            try? await Task.sleep(for: .milliseconds(150))
            windows = MenuBarItemWindow.snapshot()
            if zone == .visible,
               let boundary = windows.first(where: { $0.id == hidden.id }),
               let permanent = windows.first(where: { $0.id == always.id }),
               permanent.frame.midX >= boundary.frame.midX {
                _ = await Task.detached(priority: .userInitiated) {
                    MenuBarItemMover.move(permanent, beside: boundary, left: true)
                }.value
                try? await Task.sleep(for: .milliseconds(150))
                windows = MenuBarItemWindow.snapshot()
            }
            if zone == .hidden,
               let moved = windows.first(where: { $0.id == source.id }),
               let boundary = windows.first(where: { $0.id == always.id }),
               moved.frame.midX < boundary.frame.midX {
                _ = await Task.detached(priority: .userInitiated) {
                    MenuBarItemMover.move(boundary, beside: moved, left: true)
                }.value
                try? await Task.sleep(for: .milliseconds(150))
                windows = MenuBarItemWindow.snapshot()
            }
        }
        guard let result = windows.first(where: { $0.id == source.id }),
              let h = windows.first(where: { $0.id == hidden.id }),
              let a = windows.first(where: { $0.id == always.id }) else { return false }
        return Self.physicalZone(item: result.frame, hidden: h.frame, always: a.frame) == zone
    }

    nonisolated static func physicalZone(item: CGRect, hidden: CGRect, always: CGRect) -> MenuBarSpaceZone {
        item.midX < always.midX ? .alwaysHidden : item.midX < hidden.midX ? .hidden : .visible
    }

    func reset() async -> Bool {
        guard isActive, !isMoving else { return false }
        isMoving = true
        hiddenDivider?.length = 18
        alwaysDivider?.length = 18
        isRevealed = true
        defer { isMoving = false; applyVisibility(); refresh() }
        let managed = items.filter { $0.movable && $0.zone != .visible }
        if managed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.zonesKey)
            return true
        }
        try? await Task.sleep(for: .milliseconds(150))
        guard let hiddenFrame = Self.ownFrame(Self.hiddenID),
              let alwaysFrame = Self.ownFrame(Self.alwaysID) else { return false }
        var windows = MenuBarItemWindow.snapshot()
        guard let hidden = MenuBarItemWindow.matching(hiddenFrame, in: windows),
              let always = MenuBarItemWindow.matching(alwaysFrame, in: windows) else { return false }
        let ids = managed.compactMap { item -> CGWindowID? in
            guard let frame = Self.frame(item.element) else { return nil }
            return MenuBarItemWindow.matching(frame, in: windows)?.id
        }
        guard ids.count == managed.count else { return false }
        for _ in 0..<4 {
            guard let h = windows.first(where: { $0.id == hidden.id }),
                  let a = windows.first(where: { $0.id == always.id }) else { return false }
            let targets = ids.compactMap { id in windows.first(where: { $0.id == id }) }
            guard targets.count == ids.count, let leftmost = targets.min(by: { $0.frame.midX < $1.frame.midX }) else { return false }
            if a.frame.midX < h.frame.midX && targets.allSatisfy({ $0.frame.midX > h.frame.midX }) {
                UserDefaults.standard.removeObject(forKey: Self.zonesKey)
                return true
            }
            if h.frame.midX > leftmost.frame.midX {
                _ = await Task.detached(priority: .userInitiated) {
                    MenuBarItemMover.move(h, beside: leftmost, left: true)
                }.value
                try? await Task.sleep(for: .milliseconds(150))
                windows = MenuBarItemWindow.snapshot()
            }
            guard let currentHidden = windows.first(where: { $0.id == hidden.id }),
                  let currentAlways = windows.first(where: { $0.id == always.id }) else { return false }
            if currentAlways.frame.midX >= currentHidden.frame.midX {
                _ = await Task.detached(priority: .userInitiated) {
                    MenuBarItemMover.move(currentAlways, beside: currentHidden, left: true)
                }.value
                try? await Task.sleep(for: .milliseconds(150))
                windows = MenuBarItemWindow.snapshot()
            }
        }
        return false
    }

    func setIcon(_ value: MenuBarSpaceIcon) {
        UserDefaults.standard.set(value.rawValue, forKey: Self.iconKey)
        updateIcon()
        onChange?()
    }

    func setCustomIcon(_ data: Data) -> Bool {
        guard data.count <= 10_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary),
              let png = NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:]) else { return false }
        UserDefaults.standard.set(png, forKey: Self.customIconKey)
        setIcon(.custom)
        return true
    }

    private func updateIcon() {
        let image: NSImage?
        if icon == .custom, let data = UserDefaults.standard.data(forKey: Self.customIconKey) {
            image = NSImage(data: data)
        } else {
            image = NSImage(systemSymbolName: icon.symbol, accessibilityDescription: nil)
        }
        let resolved = image ?? NSImage(systemSymbolName: MenuBarSpaceIcon.waveform.symbol, accessibilityDescription: nil)
        resolved?.size = NSSize(width: 17, height: 17)
        resolved?.isTemplate = icon != .custom
        control?.button?.image = resolved
        control?.button?.imagePosition = .imageOnly
    }

    private static func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }

    private static func string(_ element: AXUIElement, _ name: CFString) -> String {
        attribute(element, name) as? String ?? ""
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute as CFString),
              let size = attribute(element, kAXSizeAttribute as CFString),
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private static func ownFrame(_ id: String) -> CGRect? {
        let app = AXUIElementCreateApplication(getpid())
        guard let bar = attribute(app, kAXExtrasMenuBarAttribute as CFString),
              CFGetTypeID(bar) == AXUIElementGetTypeID(),
              let children = attribute(bar as! AXUIElement, kAXChildrenAttribute as CFString) as? [AXUIElement],
              let item = children.first(where: { string($0, kAXIdentifierAttribute as CFString) == id }) else { return nil }
        return frame(item)
    }

}
