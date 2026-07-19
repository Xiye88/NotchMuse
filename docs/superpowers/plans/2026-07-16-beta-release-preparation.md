# NotchMuse Beta Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current NotchMuse build into a verified GitHub Beta release candidate without changing Spotify, lyrics provider, or matching behavior.

**Architecture:** Keep the existing Swift/AppKit application and scripts. Centralize Accessibility API calls in one small manager, retain the existing overlay renderer, and add one release orchestration script around the existing app and DMG builders.

**Tech Stack:** Swift 6, AppKit, ApplicationServices, ServiceManagement, zsh, macOS codesign/hdiutil/spctl.

## Global Constraints

- Do not change Spotify reading logic.
- Do not change lyrics provider architecture or matching behavior.
- Do not add Intel, Windows, server, account, cloud, AI lyrics, App Store, or new provider work.
- Bundle identifier remains `app.notchmuse.mac`; minimum system remains macOS 14; Beta remains Apple Silicon only.

---

### Task 1: Permission and onboarding regression coverage

**Files:**
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/AccessibilityManager.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarSafety.swift`

**Interfaces:**
- Produces: `AccessibilityManager.isTrusted`, `requiresAccess(mode:position:)`, and `requestIfNeeded(mode:position:)`.
- Keeps: `MenuBarSafety.foregroundMenuMaxX()` for menu geometry only.

- [ ] Add self-checks proving only Status Bar Left requires Accessibility and trusted or already-prompted states never prompt.
- [ ] Run `swift run --package-path MenuBarLyrics NotchMuse --self-test` and confirm the new manager references fail before implementation.
- [ ] Move all AX permission checks and prompts into `AccessibilityManager`; update the two existing callers.
- [ ] Run the self-tests and confirm they pass.

### Task 2: First-launch and Settings UX

**Files:**
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SettingsWindowController.swift`
- Modify: `MenuBarLyrics/Resources/en.lproj/Localizable.strings`
- Modify: `MenuBarLyrics/Resources/zh-Hans.lproj/Localizable.strings`

**Interfaces:**
- Consumes: existing `HasShownFirstLaunchGuide` UserDefaults key.
- Produces: one-time localized welcome copy and the `Lyrics Width` label.

- [ ] Update the first-launch alert to explain Spotify, Left-only Accessibility, display modes, appearance, and the Settings entry; use a Continue button.
- [ ] Rename Width to Lyrics Width and keep Custom Width visible only for Custom.
- [ ] Confirm Status Bar hides Notch Style and Notch Mode hides Status Bar Position.
- [ ] Run self-tests after localization changes.

### Task 3: Release build and documentation

**Files:**
- Create: `scripts/build_release.sh`
- Modify: `scripts/build_app.sh`
- Modify: `scripts/build_dmg.sh`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Create: `RELEASE_CHECKLIST.md`

**Interfaces:**
- Consumes: `NOTCHMUSE_VERSION`, `NOTCHMUSE_BUILD_NUMBER`, and optional `NOTCHMUSE_SIGN_IDENTITY`.
- Produces: `dist.noindex/NotchMuse.app` and `dist.noindex/NotchMuse.dmg` plus verification output.

- [ ] Add a release wrapper that cleans generated output, validates version/build values, builds the DMG, verifies metadata, architecture, signature structure, and DMG checksum.
- [ ] Keep Developer ID signing optional but fail clearly if a supplied identity is invalid.
- [ ] Update README and changelog with exact Beta features, requirements, permissions, privacy, installation, and limitations.
- [ ] Add the requested release checklist with unchecked external/manual gates.

### Task 4: End-to-end verification

**Files:**
- Test only; do not change core lyrics files.

**Interfaces:**
- Consumes: generated DMG and installed `/Applications/NotchMuse.app`.
- Produces: audit evidence for the final report.

- [ ] Run Debug self-tests and the full release builder.
- [ ] Mount the DMG, verify the Applications alias, install the app, and compare executable hashes.
- [ ] Verify one process across repeated launches, menu/Settings mode switching, Quit, and restart.
- [ ] Check Spotify automation availability, Accessibility trust state, Login Item/LaunchAgent duplicates, and Gatekeeper acceptance.
- [ ] Report passed checks, untestable checks, and blocking failures without claiming public readiness when Gatekeeper rejects.
