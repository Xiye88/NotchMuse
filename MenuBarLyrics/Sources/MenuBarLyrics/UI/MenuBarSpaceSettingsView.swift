import AppKit
import UniformTypeIdentifiers

private let menuBarSpaceDragType = NSPasteboard.PasteboardType("app.notchmuse.menu-bar-space-item")

@MainActor
final class MenuBarSpaceSettingsView: NSStackView {
    private let space: MenuBarSpaceController
    private let onChange: () -> Void
    private let enabledSwitch = NSSwitch()
    private let iconPicker = NSPopUpButton()
    private let permissionText = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton()
    private var zones: [MenuBarSpaceZone: MenuBarSpaceDropZone] = [:]

    init(space: MenuBarSpaceController, onChange: @escaping () -> Void) {
        self.space = space
        self.onChange = onChange
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 16

        let title = NSTextField(labelWithString: L10n.text("Menu Bar Space"))
        title.font = .systemFont(ofSize: 22, weight: .bold)
        addArrangedSubview(title)

        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)
        row(L10n.text("Enable Menu Bar Space"), enabledSwitch)

        permissionText.textColor = .secondaryLabelColor
        permissionText.maximumNumberOfLines = 3
        addArrangedSubview(permissionText)
        permissionButton.title = L10n.text("Open Accessibility Settings")
        permissionButton.target = self
        permissionButton.action = #selector(openPermission)
        addArrangedSubview(permissionButton)

        for preset in MenuBarSpaceIcon.allCases {
            iconPicker.addItem(withTitle: L10n.text(preset.rawValue))
        }
        iconPicker.target = self
        iconPicker.action = #selector(iconChanged)
        row(L10n.text("Menu Bar Icon"), iconPicker)

        let imageButton = NSButton(title: L10n.text("Choose Image…"), target: self, action: #selector(chooseImage))
        addArrangedSubview(imageButton)

        for zone in MenuBarSpaceZone.allCases {
            let view = MenuBarSpaceDropZone(zone: zone) { [weak self] id, destination in
                guard let self else { return }
                Task { @MainActor in
                    if await self.space.setZone(destination, for: id) == false {
                        self.showError(L10n.text("This menu bar item could not be moved."))
                    }
                    self.reload()
                    self.onChange()
                }
            }
            zones[zone] = view
            addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }

        let resetButton = NSButton(title: L10n.text("Reset Menu Bar Layout"), target: self, action: #selector(reset))
        addArrangedSubview(resetButton)
        reload()
    }

    required init?(coder: NSCoder) { nil }

    func reload() {
        enabledSwitch.state = space.isEnabled ? .on : .off
        iconPicker.selectItem(at: MenuBarSpaceIcon.allCases.firstIndex(of: space.icon) ?? 0)
        let conflict = space.isEnabled ? space.conflictingManagerName : nil
        let needsPermission = space.needsPermission
        permissionText.stringValue = conflict != nil
            ? L10n.text("Quit Thaw, then retry Menu Bar Space.")
            : needsPermission ? L10n.text("NotchMuse needs Accessibility access to organize menu bar icons and make room for lyrics.") : ""
        permissionButton.title = conflict != nil ? L10n.text("Retry") : L10n.text("Open Accessibility Settings")
        permissionText.isHidden = conflict == nil && !needsPermission
        permissionButton.isHidden = conflict == nil && !needsPermission
        zones.forEach { zone, view in
            view.isHidden = !space.isActive
            view.setItems(space.items.filter { $0.zone == zone })
        }
    }

    private func row(_ title: String, _ control: NSView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .centerY
        addArrangedSubview(stack)
        stack.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    @objc private func enabledChanged() {
        space.setEnabled(enabledSwitch.state == .on)
        reload()
        onChange()
    }

    @objc private func openPermission() {
        if space.conflictingManagerName == nil { AccessibilityManager.openSystemSettings() }
        space.start()
        reload()
    }

    @objc private func iconChanged() {
        guard MenuBarSpaceIcon.allCases.indices.contains(iconPicker.indexOfSelectedItem) else { return }
        space.setIcon(MenuBarSpaceIcon.allCases[iconPicker.indexOfSelectedItem])
        onChange()
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url), space.setCustomIcon(data) else {
            return
        }
        reload()
        onChange()
    }

    @objc private func reset() {
        let alert = NSAlert()
        alert.messageText = L10n.text("Reset Menu Bar Layout")
        alert.informativeText = L10n.text("NotchMuse will restore the menu bar items it manages.")
        alert.addButton(withTitle: L10n.text("Reset"))
        alert.addButton(withTitle: L10n.text("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { @MainActor in
            if await space.reset() == false {
                showError(L10n.text("Some menu bar items could not be restored."))
            }
            reload()
            onChange()
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }
}

private final class MenuBarSpaceDropZone: NSStackView {
    private let zone: MenuBarSpaceZone
    private let onDrop: (String, MenuBarSpaceZone) -> Void
    private let list = NSStackView()
    private let strip = NSScrollView()

    init(zone: MenuBarSpaceZone, onDrop: @escaping (String, MenuBarSpaceZone) -> Void) {
        self.zone = zone
        self.onDrop = onDrop
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 8
        let heading = NSTextField(labelWithString: L10n.text(zone.rawValue))
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        addArrangedSubview(heading)
        strip.drawsBackground = true
        strip.backgroundColor = NSColor(calibratedRed: 0.54, green: 0.61, blue: 0.71, alpha: 0.9)
        strip.wantsLayer = true
        strip.layer?.cornerRadius = 10
        strip.hasHorizontalScroller = true
        strip.autohidesScrollers = true
        strip.hasVerticalScroller = false
        list.orientation = .horizontal
        list.alignment = .centerY
        list.spacing = 4
        list.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        strip.documentView = list
        addArrangedSubview(strip)
        list.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            strip.widthAnchor.constraint(equalTo: widthAnchor),
            strip.heightAnchor.constraint(equalToConstant: 58),
            list.heightAnchor.constraint(equalToConstant: 54)
        ])
        registerForDraggedTypes([menuBarSpaceDragType])
    }

    required init?(coder: NSCoder) { nil }

    func setItems(_ items: [MenuBarSpaceItem]) {
        for row in list.arrangedSubviews { list.removeArrangedSubview(row); row.removeFromSuperview() }
        if items.isEmpty {
            let hint = NSTextField(labelWithString: L10n.text("Drag menu bar icons here"))
            hint.textColor = .white.withAlphaComponent(0.8)
            list.addArrangedSubview(hint)
        } else {
            for item in items { list.addArrangedSubview(MenuBarSpaceDragRow(item: item)) }
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = sender.draggingPasteboard.string(forType: menuBarSpaceDragType) != nil
        strip.layer?.borderWidth = accepted ? 2 : 0
        strip.layer?.borderColor = NSColor.controlAccentColor.cgColor
        return accepted ? .move : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { strip.layer?.borderWidth = 0 }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { strip.layer?.borderWidth = 0 }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        strip.layer?.borderWidth = 0
        guard let id = sender.draggingPasteboard.string(forType: menuBarSpaceDragType) else { return false }
        // Let the native drag session release its mouse capture before moving the real item.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onDrop(id, self.zone)
        }
        return true
    }
}

private final class MenuBarSpaceDragRow: NSView, NSDraggingSource {
    private let item: MenuBarSpaceItem

    init(item: MenuBarSpaceItem) {
        self.item = item
        super.init(frame: NSRect(x: 0, y: 0, width: 26, height: 34))
        let icon = NSImageView(image: item.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage())
        icon.imageScaling = .scaleProportionallyDown
        icon.alphaValue = item.movable ? 1 : 0.5
        toolTip = item.name + (item.movable ? "" : " · " + L10n.text("System Managed"))
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(toolTip)
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 26), heightAnchor.constraint(equalToConstant: 34),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor), icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20), icon.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { }
    override func mouseDragged(with event: NSEvent) {
        guard item.movable else { return }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.id, forType: menuBarSpaceDragType)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: item.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage())
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
}
