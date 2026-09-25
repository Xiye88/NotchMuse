import AppKit
import ApplicationServices

@MainActor
enum AccessibilityManager {
    private static var hasPromptedThisLaunch = false

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func shouldPrompt(isTrusted: Bool, hasPrompted: Bool) -> Bool {
        !isTrusted && !hasPrompted
    }

    static func requiresAccess(mode: DisplayMode, position: LyricsPosition) -> Bool {
        mode == .statusBar && position == .left
    }

    static func requestIfNeeded(mode: DisplayMode, position: LyricsPosition) {
        guard requiresAccess(mode: mode, position: position) else { return }
        guard shouldPrompt(isTrusted: isTrusted, hasPrompted: hasPromptedThisLaunch) else { return }
        hasPromptedThisLaunch = true
        _ = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
