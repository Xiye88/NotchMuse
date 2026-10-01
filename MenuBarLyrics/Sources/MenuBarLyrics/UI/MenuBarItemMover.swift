import AppKit
import ApplicationServices

struct MenuBarItemWindow {
    let id: CGWindowID
    let pid: pid_t
    let frame: CGRect

    static func snapshot() -> [MenuBarItemWindow] {
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.statusWindow)),
                  let id = window[kCGWindowNumber as String] as? UInt32,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds), frame.width > 0, frame.height > 0 else { return nil }
            return MenuBarItemWindow(id: id, pid: pid, frame: frame)
        }
    }

    static func matching(_ frame: CGRect, in windows: [MenuBarItemWindow]) -> MenuBarItemWindow? {
        windows.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) && $0.frame.width < frame.width + 40 }
    }
}

/// Sends a complete press/release transaction and waits for the addressed process to consume it.
/// Geometry comes from WindowServer, since AX bounds omit the status item's padding.
enum MenuBarItemMover {
    private static let windowFields: [CGEventField] = [
        .mouseEventWindowUnderMousePointer,
        .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
        CGEventField(rawValue: 0x33)!
    ]

    static func move(_ item: MenuBarItemWindow, beside anchor: MenuBarItemWindow, left: Bool) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let localSource = CGEventSource(stateID: .combinedSessionState) else { return false }
        localSource.localEventsSuppressionInterval = 0
        for state in [CGEventSuppressionState.eventSuppressionStateRemoteMouseDrag, .eventSuppressionStateSuppressionInterval] {
            localSource.setLocalEventsFilterDuringSuppressionState([
                .permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents
            ], state: state)
        }
        let point = CGPoint(x: left ? anchor.frame.minX - 1 : anchor.frame.maxX + 1, y: anchor.frame.minY)
        let originalPointer = CGEvent(source: nil)?.location
        let onScreen = CGDisplayBounds(CGMainDisplayID()).contains(point)
        if onScreen { CGWarpMouseCursorPosition(point); Thread.sleep(forTimeInterval: 0.02) }
        defer { if let originalPointer, onScreen { CGWarpMouseCursorPosition(originalPointer) } }
        let pressed = send(.leftMouseDown, point: point, window: item.id, pid: item.pid, source: source)
        let movementDeadline = ProcessInfo.processInfo.systemUptime + 0.5
        while ProcessInfo.processInfo.systemUptime < movementDeadline {
            if let moved = MenuBarItemWindow.snapshot().first(where: { $0.id == item.id }), moved.frame.origin != item.frame.origin { break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        // Always release, including a timed-out press. The second release clears AppKit's drag state.
        let released = send(.leftMouseUp, point: point, window: anchor.id, pid: item.pid, source: source)
        _ = send(.leftMouseUp, point: point, window: anchor.id, pid: item.pid, source: source)
        withExtendedLifetime(localSource) { }
        return pressed && released
    }

    private static func send(_ type: CGEventType, point: CGPoint, window: CGWindowID, pid: pid_t, source: CGEventSource) -> Bool {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return false }
        event.flags = type == .leftMouseDown ? .maskCommand : []
        for field in windowFields { event.setIntegerValueField(field, value: Int64(window)) }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        let delivery = Delivery(event: event, pid: pid, window: window)
        event.setIntegerValueField(.eventSourceUserData, value: delivery.token)
        let context = Unmanaged.passUnretained(delivery).toOpaque()
        let pidTap = CGEvent.tapCreateForPid(pid: pid, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: (1 << type.rawValue) | 1, callback: { _, type, received, context in
                guard let context else { return Unmanaged.passUnretained(received) }
                let delivery = Unmanaged<Delivery>.fromOpaque(context).takeUnretainedValue()
                let token = received.getIntegerValueField(.eventSourceUserData)
                if type == .null && token == delivery.token + 1 {
                    delivery.event.post(tap: .cgSessionEventTap)
                    return nil
                }
                if type == .null && token == delivery.token + 2 {
                    delivery.finished = true
                    return nil
                }
                if token == delivery.token && delivery.matches(received) && !delivery.received {
                    delivery.received = true
                    delivery.barrier(offset: 2)?.postToPid(delivery.pid)
                }
                return Unmanaged.passUnretained(received)
            }, userInfo: context)
        let sessionTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: 1 << type.rawValue, callback: { _, _, received, context in
                guard let context else { return Unmanaged.passUnretained(received) }
                let delivery = Unmanaged<Delivery>.fromOpaque(context).takeUnretainedValue()
                if received.getIntegerValueField(.eventSourceUserData) == delivery.token,
                   delivery.matches(received), !delivery.relayed {
                    delivery.relayed = true
                    delivery.event.postToPid(delivery.pid)
                }
                return Unmanaged.passUnretained(received)
            }, userInfo: context)
        let filter = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: 1 << type.rawValue, callback: { _, _, received, context in
                guard let context else { return Unmanaged.passUnretained(received) }
                let delivery = Unmanaged<Delivery>.fromOpaque(context).takeUnretainedValue()
                if received.getIntegerValueField(.eventSourceUserData) == delivery.token && !delivery.matches(received) { return nil }
                return Unmanaged.passUnretained(received)
            }, userInfo: context)
        let taps = [pidTap, sessionTap, filter].compactMap { $0 }
        defer { for tap in taps { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) } }
        guard taps.count == 3 else { return false }
        let loop = CFRunLoopGetCurrent()
        let sources = taps.compactMap { CFMachPortCreateRunLoopSource(nil, $0, 0) }
        for runSource in sources { CFRunLoopAddSource(loop, runSource, .defaultMode) }
        defer { for runSource in sources { CFRunLoopRemoveSource(loop, runSource, .defaultMode) } }
        for tap in taps { CGEvent.tapEnable(tap: tap, enable: true) }
        delivery.barrier(offset: 1)?.postToPid(pid)
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        while !delivery.finished && ProcessInfo.processInfo.systemUptime < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }
        return withExtendedLifetime(delivery) { delivery.finished }
    }

    private final class Delivery {
        let event: CGEvent
        let pid: pid_t
        let window: CGWindowID
        let token = Int64.random(in: 1...(Int64.max - 3))
        var relayed = false
        var received = false
        var finished = false
        init(event: CGEvent, pid: pid_t, window: CGWindowID) { self.event = event; self.pid = pid; self.window = window }
        func matches(_ event: CGEvent) -> Bool { windowFields.allSatisfy { event.getIntegerValueField($0) == Int64(window) } }
        func barrier(offset: Int64) -> CGEvent? {
            guard let event = CGEvent(source: nil) else { return nil }
            event.type = .null
            event.setIntegerValueField(.eventSourceUserData, value: token + offset)
            return event
        }
    }
}
