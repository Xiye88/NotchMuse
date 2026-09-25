import AppKit
import ApplicationServices

@MainActor
enum MenuBarSafety {
    private static var cachedProcessID: pid_t?
    private static var cachedAt: TimeInterval = 0
    private static var cachedMaxX: CGFloat?

    static func isExplicitlyHidden(_ value: CFTypeRef?) -> Bool {
        value as? Bool == true
    }

    static func shouldUseCachedMenuGeometry(processID: pid_t, cachedProcessID: pid_t?, age: TimeInterval) -> Bool {
        processID == cachedProcessID && age < 0.5
    }

    static func foregroundMenuMaxX() -> CGFloat? {
        guard AccessibilityManager.isTrusted,
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

        let now = ProcessInfo.processInfo.systemUptime
        if shouldUseCachedMenuGeometry(processID: processID, cachedProcessID: cachedProcessID, age: now - cachedAt) {
            return cachedMaxX
        }

        let maxX = readForegroundMenuMaxX(processID: processID)
        cachedProcessID = processID
        cachedAt = now
        cachedMaxX = maxX
        return maxX
    }

    private static func readForegroundMenuMaxX(processID: pid_t) -> CGFloat? {
        let application = AXUIElementCreateApplication(processID)
        var menuBarValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXMenuBarAttribute as CFString, &menuBarValue) == .success,
              let menuBarValue,
              CFGetTypeID(menuBarValue) == AXUIElementGetTypeID() else {
            return nil
        }
        let menuBar = menuBarValue as! AXUIElement

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        var maxX: CGFloat?
        for child in children {
            var hiddenValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXHiddenAttribute as CFString, &hiddenValue) == .success,
               isExplicitlyHidden(hiddenValue) {
                continue
            }

            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeValue) == .success,
                  let positionValue,
                  let sizeValue,
                  CFGetTypeID(positionValue) == AXValueGetTypeID(),
                  CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
                return nil
            }
            let position = positionValue as! AXValue
            let elementSize = sizeValue as! AXValue

            var point = CGPoint.zero
            var dimensions = CGSize.zero
            guard AXValueGetValue(position, .cgPoint, &point),
                  AXValueGetValue(elementSize, .cgSize, &dimensions) else {
                return nil
            }
            maxX = max(maxX ?? -.infinity, point.x + dimensions.width)
        }
        return maxX
    }
}
