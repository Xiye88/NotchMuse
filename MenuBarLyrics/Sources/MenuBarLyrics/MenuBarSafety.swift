import AppKit
import ApplicationServices

@MainActor
enum MenuBarSafety {
    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary)
    }

    static func foregroundMenuMaxX() -> CGFloat? {
        guard AXIsProcessTrusted(),
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

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
            guard AXUIElementCopyAttributeValue(child, kAXHiddenAttribute as CFString, &hiddenValue) == .success,
                  let isHidden = hiddenValue as? Bool else {
                return nil
            }
            guard !isHidden else { continue }

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
