#if DEBUG
import AppKit
import LyricsCore

@MainActor
enum FreeLyricsSelfTests {
    static func run() {
        _ = NSApplication.shared
        var checks = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        MenuBarController.testDisplayModeReopen()
        MenuBarController.testVocalGapPresentation()
        let visible = NSRect(x: -1920, y: 32, width: 1920, height: 1048)
        let size = NSSize(width: 440, height: 90)
        for x in [-0.5, 0, 0.5, 1, 1.5, Double.nan] {
            for y in [-1, 0, 0.3, 1, 2, Double.infinity] {
                let frame = FreeLyricsGeometry.frame(anchor: FreeLyricsAnchor(screenID: "external", x: x, y: y), size: size, visible: visible)
                check(visible.contains(frame), "invalid/changed/negative display bounds remain accessible")
                let saved = FreeLyricsGeometry.anchor(frame: frame, visible: visible, screenID: "external")
                check(FreeLyricsGeometry.frame(anchor: saved, size: size, visible: visible) == frame, "round trip")
            }
        }
        check(FreeLyricsGeometry.screenIndex(savedID: "external", screenIDs: ["internal", "external"], preferredIndex: 0) == 1, "saved display owns sizing despite pointer on other screen")
        check(FreeLyricsGeometry.screenIndex(savedID: "external", screenIDs: ["internal"], preferredIndex: 1) == 0, "disconnect uses valid fallback")
        check(FreeLyricsGeometry.screenIndex(savedID: "external", screenIDs: ["internal", "external"], preferredIndex: 0) == 1, "reconnect restores original display")
        check(FreeLyricsGeometry.screenIndex(savedID: nil, screenIDs: [], preferredIndex: 0) == nil, "no display handled")
        let oversized = FreeLyricsGeometry.frame(anchor: nil, size: NSSize(width: 3000, height: 2000), visible: visible)
        check(oversized == visible, "resolution shrink clamps full window")
        let normalized = FreeLyricsAnchor(screenID: "external", x: 0.7, y: 0.25)
        let retina = NSRect(x: 0, y: 25, width: 1470, height: 860)
        let recovered = FreeLyricsGeometry.frame(anchor: normalized, size: size, visible: retina)
        check(retina.contains(recovered), "disconnected screen falls back inside current display")
        for editing in [false, true] {
            for locked in [false, true] {
                for passThrough in [false, true] {
                    let state = FreeLyricsPolicy(editing: editing, locked: locked, passThrough: passThrough, hideOnHover: true)
                    check(state.ignoresMouseEvents == (passThrough && !editing), "passthrough is independent of lock")
                    check(state.canMove == (editing || (!locked && !passThrough)), "explicit edit always recoverable")
                    check(state.hidesLyrics(hovered: true) == !editing, "editing overrides hover hide")
                }
            }
        }
        check(!FreeLyricsPolicy().hidesLyrics(hovered: true), "hover preference off")
        let suite = "app.notchmuse.free-lyrics.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        FreeLyricsPreferences.save(normalized, vertical: false, defaults: defaults)
        FreeLyricsPreferences.save(FreeLyricsAnchor(screenID: "other", x: 0.2, y: 0.8), vertical: true, defaults: defaults)
        check(FreeLyricsPreferences.load(vertical: false, defaults: defaults) == normalized, "orientations remember independent anchors")
        check(FreeLyricsPreferences.load(vertical: true, defaults: defaults)?.screenID == "other", "vertical saved independently")
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 440, height: 90), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        let lyrics = NSView(frame: NSRect(x: 0, y: 38, width: 440, height: 52))
        container.addSubview(lyrics)
        window.contentView = container
        let interaction = FreeLyricsInteraction(window: window, container: container, lyricViews: [lyrics], defaults: defaults)
        defer { interaction.hide(); window.close() }
        _ = interaction.frame(size: size, vertical: false, fallback: NSScreen.main!)
        interaction.update(hideOnHover: false)
        window.orderFrontRegardless()
        let lock = interaction.testToolbar.subviews[4] as! NSButton
        let moveControl = interaction.testToolbar.subviews[0] as! NSButton
        defaults.set(true, forKey: FreeLyricsPreferences.lockedKey)
        interaction.update(hideOnHover: false)
        interaction.testHover(true)
        check(!lock.isHidden && !moveControl.isEnabled, "locked hover exposes unlock, with dragging disabled")
        check(window.ignoresMouseEvents, "locked lyric window passes clicks to the app underneath")
        check(interaction.testToolbar.subviews.filter { !$0.isHidden }.count == 1, "locked hover exposes only unlock")
        check(abs(lock.frame.midX - interaction.testToolbar.bounds.midX) < 0.01, "locked unlock button is centered")
        check(abs(window.convertFromScreen(interaction.testUnlockWindow.frame).midX - window.frame.width / 2) < 0.01, "unlock panel stays centered on the actual lyric window")
        check(!interaction.testUnlockWindow.ignoresMouseEvents && interaction.testUnlockWindow.frame.size == NSSize(width: 38, height: 32), "only the small unlock panel receives locked mouse input")
        check(interaction.testUnlockWindow.isVisible, "hover exposes the independent unlock panel")
        interaction.testHover(false)
        check(!interaction.testUnlockWindow.isVisible && window.ignoresMouseEvents, "leaving hides unlock panel without blocking background clicks")
        interaction.testHover(true)
        lock.performClick(nil)
        check(!defaults.bool(forKey: FreeLyricsPreferences.lockedKey) && moveControl.isEnabled && interaction.isEditing, "unlock enables moving and persists unlocked preference")
        check(!window.ignoresMouseEvents && !interaction.testUnlockWindow.isVisible, "unlock returns editing controls to the main lyric window")
        check(interaction.testToolbar.subviews.filter { !$0.isHidden }.count == 6, "unlock reveals all edit controls including orientation")
        let orientation = interaction.testToolbar.subviews[5] as! NSButton
        orientation.performClick(nil)
        check(defaults.bool(forKey: FreeLyricsPreferences.verticalKey), "orientation shortcut selects vertical")
        orientation.performClick(nil)
        check(!defaults.bool(forKey: FreeLyricsPreferences.verticalKey), "orientation shortcut returns horizontal")
        lock.performClick(nil)
        check(defaults.bool(forKey: FreeLyricsPreferences.lockedKey) && !moveControl.isEnabled && !interaction.isEditing, "relock ends moving and persists locked preference")
        interaction.beginEditing()
        check(!defaults.bool(forKey: FreeLyricsPreferences.lockedKey), "explicit Move Lyrics uses the same unlocked preference as the toolbar")
        lock.performClick(nil)
        defaults.set(false, forKey: FreeLyricsPreferences.lockedKey)
        interaction.update(hideOnHover: false)
        interaction.testHover(true)
        check(lyrics.alphaValue == 1 && interaction.testToolbar.alphaValue == 1, "hover shows toolbar without hiding lyrics")
        interaction.update(hideOnHover: true)
        interaction.testHover(true)
        check(lyrics.alphaValue == 0 && interaction.testToolbar.alphaValue == 1, "hide affects lyrics, keeps separate toolbar usable")
        interaction.beginEditing()
        check(lyrics.alphaValue == 1 && interaction.isEditing, "move never disappears")
        interaction.testHover(false)
        check(lyrics.alphaValue == 1 && interaction.testToolbar.alphaValue == 0, "moving lyrics stay visible but toolbar hides off-hover")
        interaction.testHover(true)
        check(interaction.testToolbar.alphaValue == 1, "hover restores toolbar while editing")
        defaults.set(true, forKey: FreeLyricsPreferences.lockedKey)
        defaults.set(true, forKey: FreeLyricsPreferences.passThroughKey)
        interaction.update(hideOnHover: true)
        check(!window.ignoresMouseEvents, "editing can recover from passthrough")
        (interaction.testToolbar.subviews[4] as! NSButton).performClick(nil)
        check(window.ignoresMouseEvents && !interaction.isEditing, "Locking restores pass-through and blocks movement")
        interaction.beginEditing()
        check(!window.ignoresMouseEvents, "menu/settings edit recovery")
        window.setFrame(NSRect(x: 120, y: 180, width: size.width, height: size.height), display: false)
        interaction.savePosition()
        let screen = window.screen!
        let expected = FreeLyricsGeometry.frame(anchor: FreeLyricsPreferences.load(vertical: false, defaults: defaults), size: size, visible: screen.visibleFrame)
        check(interaction.frame(size: size, vertical: false, fallback: screen) == expected, "native window position persisted after movement")
        let fresh = UserDefaults(suiteName: suite)!
        check(FreeLyricsPreferences.load(vertical: false, defaults: fresh) == FreeLyricsPreferences.load(vertical: false, defaults: defaults), "relaunch reads saved anchor")
        for button in interaction.testToolbar.subviews where !button.isHidden {
            check(button.frame.height >= 28 && interaction.testToolbar.bounds.contains(button.frame), "toolbar hit areas fit without lyrics overlap")
        }
        defaults.set(false, forKey: FreeLyricsPreferences.passThroughKey)
        interaction.update(hideOnHover: false)
        let move = interaction.testToolbar.subviews[0]
        let start = window.frame.origin
        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 20, y: 20), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        let drag = NSEvent.mouseEvent(with: .leftMouseDragged, location: NSPoint(x: 90, y: 60), modifierFlags: [], timestamp: 0.1, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        lock.performClick(nil)
        move.mouseDown(with: down)
        move.mouseDragged(with: drag)
        move.mouseUp(with: drag)
        check(window.frame.origin == start, "locked native mouse events cannot move lyrics")
        lock.performClick(nil)
        check(!UserDefaults(suiteName: suite)!.bool(forKey: FreeLyricsPreferences.lockedKey), "unlock survives a fresh preferences reader")
        interaction.testHover(false)
        move.mouseDown(with: down)
        check(interaction.testToolbar.alphaValue == 1, "active drag keeps controls visible outside hover")
        move.mouseDragged(with: drag)
        check(window.frame.origin == NSPoint(x: start.x + 70, y: start.y + 40), "native mouse responder changes window origin")
        move.mouseUp(with: drag)
        check(interaction.testToolbar.alphaValue == 0, "releasing outside hover hides editing controls")
        check(FreeLyricsPreferences.load(vertical: false, defaults: defaults) != nil, "mouse up persists position")
        let palette = interaction.testToolbar.subviews[1] as! NSPopUpButton
        palette.selectItem(at: 2)
        _ = NSApp.sendAction(palette.action!, to: palette.target, from: palette)
        check(defaults.string(forKey: AppPreferences.colorPresetKey) == LyricsColorPreset.orange.rawValue, "toolbar color shortcut uses existing palette preference")
        var opened = false
        interaction.onSettings = { opened = true }
        (interaction.testToolbar.subviews[2] as! NSButton).performClick(nil)
        check(opened, "settings button")
        var closed = false
        interaction.onClose = { closed = true }
        (interaction.testToolbar.subviews[3] as! NSButton).performClick(nil)
        check(closed && !interaction.isEditing, "close hides lyrics only through callback")
        check(interaction.testToolbar.alphaValue == 0, "closed toolbar cannot remain visible when reopened")
        // Exercise the actual shared overlay, not a separate test renderer.
        let standard = UserDefaults.standard
        let saved = FreeLyricsPreferences.keys.map { standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(FreeLyricsPreferences.keys, saved) {
                if let value { standard.set(value, forKey: key) } else { standard.removeObject(forKey: key) }
            }
        }
        FreeLyricsPreferences.keys.forEach { standard.removeObject(forKey: $0) }
        let overlay = OverlayLyricsWindow()
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { overlay.hide(); NSStatusBar.system.removeStatusItem(status) }
        func show(_ mode: DisplayMode, placement: NotchPlacement = .top, text: String = "Test lyric", progress: CGFloat = 0) {
            _ = overlay.show(text: text, progress: progress, mode: mode, position: .right,
                notchStyle: .lyricOnly, notchPlacement: placement, song: "Test", artist: "Test",
                statusItem: status, scroll: ScrollState(), fontSize: 17, animationSpeed: 1,
                colorPreset: .white, customLyricsColor: .white, customLyricsEndColor: .white, opacity: 1,
                notchBackgroundEnabled: true, notchBackgroundColor: .black, notchBackgroundOpacity: 0.3,
                notchBackgroundPadding: 40, notchHideOnHover: false, displayTarget: .auto,
                displayWidth: .normal, customWidth: 400, statusBarOffset: 0)
        }
        show(.free)
        let freeWindow = overlay.freeInteraction.window
        check(freeWindow.isVisible && !freeWindow.ignoresMouseEvents, "actual free renderer visible/interactive")
        check(freeWindow.collectionBehavior.contains(.canJoinAllSpaces) && freeWindow.collectionBehavior.contains(.fullScreenAuxiliary), "Space/fullscreen window policy")
        freeWindow.setFrameOrigin(NSPoint(x: 90, y: 150))
        overlay.freeInteraction.savePosition()
        let moved = freeWindow.frame
        let lines = [LyricLine(time: 10, text: "Test one"), LyricLine(time: 20, text: "Test two")]
        for position in [10.0, 15, 15, 15, 23, 11] {
            let moment = LyricClock.moment(at: position, in: lines)!
            show(.free, text: moment.text, progress: moment.progress)
            check(freeWindow.frame == moved, "content/progress/Pause/Resume/Seek/track text do not reset position")
        }
        (overlay.freeInteraction.testToolbar.subviews[5] as! NSButton).performClick(nil)
        check(FreeLyricsPreferences.vertical, "toolbar shortcut drives real vertical preference")
        show(.free)
        check(freeWindow.frame.height > freeWindow.frame.width, "actual vertical layout")
        overlay.freeInteraction.beginEditing()
        check(overlay.freeInteraction.testToolbar.frame.width <= freeWindow.frame.width, "lock controls fit vertical lyrics")
        overlay.freeInteraction.endEditing()
        (overlay.freeInteraction.testToolbar.subviews[5] as! NSButton).performClick(nil)
        check(!FreeLyricsPreferences.vertical, "toolbar shortcut drives real horizontal preference")
        show(.free)
        check(freeWindow.frame == moved, "horizontal anchor restored after orientation toggle")
        for placement in NotchPlacement.allCases {
            show(.notch, placement: placement)
            check(!freeWindow.isVisible, "preset modes do not leave Free Position visible")
        }
        show(.statusBar)
        check(!freeWindow.isVisible, "status bar preserved")
        show(.free)
        check(freeWindow.frame == moved, "hide/show preserves saved position")
        overlay.freeInteraction.beginEditing()
        overlay.hide()
        check(!freeWindow.isVisible && !overlay.isEditing, "close clears temporary edit state")
        print("PASS: \(checks) free-lyrics geometry/policy/native-window checks")
    }
}
#endif
