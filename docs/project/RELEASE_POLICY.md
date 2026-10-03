# Release Policy

- `/Applications/NotchMuse.app` is the stable installation. `/Applications/NotchMuse Preview.app` has a separate bundle ID and preferences and is never distributed publicly.
- Build numbers increase across candidates. Preview builds do not replace the installed stable app.
- A public release needs Product Owner Preview acceptance, build and self-test results, player and Settings checks, a verified DMG, and an explicit publication decision.
- Publish a release atomically: tag and GitHub Release with the DMG, matching signed `appcast.xml`, website download link, release notes, and checksum. Verify each public URL before announcing it. Do not publish the feed ahead of its asset.
- Sparkle checks are optional and user-controlled. Updates require an EdDSA signature. The private key remains in the macOS Keychain or a protected release environment; only the public key belongs in the app.
- Beta 3 and earlier lack Sparkle. They cannot update themselves and require a one-time manual install of v0.8.0 or later.
- Current ad-hoc signing is not notarization. Keep Gatekeeper instructions visible; never suggest disabling system-wide security. Developer ID signing and notarization are a separate future decision.

See [UPDATE_RELEASE_AUTOMATION.md](UPDATE_RELEASE_AUTOMATION.md) for commands and rollback checks.
