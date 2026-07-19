# NotchMuse Beta RC Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare NotchMuse as a GitHub Beta Release Candidate without changing lyrics providers, Spotify reading, or matching.

**Architecture:** Keep the existing Swift + AppKit app. Make surgical cleanup changes in settings, preferences, docs, and release scripts, then verify with Debug, Release, DMG, install, and launch checks.

**Tech Stack:** Swift Package Manager, AppKit, macOS app bundle shell scripts.

## Global Constraints

- Do not add large features.
- Do not modify lyrics Provider architecture.
- Do not modify Spotify reading logic.
- Do not modify lyrics matching algorithm.
- Bundle Identifier remains `app.notchmuse.mac`.
- Version target is `v0.3.0-beta`.

---

### Task 1: Both Residual Cleanup

**Files:**
- Inspect: `MenuBarLyrics/Sources/MenuBarLyrics/*.swift`
- Modify: `CHANGELOG.md`

- [ ] Search for `Both`/`both` in source, tests, README, and CHANGELOG.
- [ ] Remove only stale public-release references to removed Both mode.
- [ ] Verify `LyricsPosition` exposes only `Left` and `Right`.
- [ ] Verify old `Both` UserDefaults falls back to `Right`.

### Task 2: Settings UX and Naming Audit

**Files:**
- Inspect/modify if needed: `MenuBarLyrics/Sources/MenuBarLyrics/SettingsWindowController.swift`
- Inspect: `MenuBarLyrics/Resources/*/Localizable.strings`

- [ ] Verify Status Bar mode shows Position and Lyrics Width, hides Notch Style and Hide on Hover.
- [ ] Verify Notch Mode shows Notch Style, Lyrics Width, and Hide on Hover, hides Position.
- [ ] Verify labels say `Lyrics Width` and `Display Screen`.

### Task 3: Accessibility and Lifecycle Audit

**Files:**
- Inspect/modify if needed: `MenuBarLyrics/Sources/MenuBarLyrics/AccessibilityManager.swift`
- Inspect/modify if needed: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`
- Inspect/modify if needed: `MenuBarLyrics/Sources/MenuBarLyrics/AppDelegate.swift`

- [ ] Verify only `AccessibilityManager` calls `AXIsProcessTrusted*`.
- [ ] Verify permission prompting is gated through `requestIfNeeded`.
- [ ] Verify repeat launch does not create a second process or status item.

### Task 4: Release Docs and Build Target

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `RELEASE_CHECKLIST.md`

- [ ] Ensure README covers product intro, features, DMG install, Gatekeeper, Apple Silicon only, Intel unsupported, Universal Binary future, screenshots placeholders.
- [ ] Record `v0.3.0-beta` in CHANGELOG.
- [ ] Ensure release checklist mentions version/build, signing, notarization, and DMG validation.

### Task 5: Release Validation

**Files:**
- Run scripts only.

- [ ] Run Debug self-test.
- [ ] Run Release build for `0.3.0-beta`.
- [ ] Build and verify DMG.
- [ ] Install from DMG to Applications.
- [ ] Launch, repeated launch, quit, and restart checks.
