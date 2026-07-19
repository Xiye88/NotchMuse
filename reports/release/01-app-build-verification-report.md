# Task Completion Report

Task: 01_APP Build Verification Report

Status: Completed with P0 release blockers

Priority: P0

## Findings

- Build dependencies are minimal:
  - macOS 14+
  - Apple Silicon Mac
  - Swift Package Manager / Apple Command Line Tools
  - No third-party Swift package dependencies in `MenuBarLyrics/Package.swift`
- Current working tree build can pass when SwiftPM is allowed to use its normal macOS build sandbox/cache:
  - Command run earlier: `swift run --package-path MenuBarLyrics NotchMuse --self-test`
  - Result: `Self-tests passed`
- Current app package scripts exist in the working tree:
  - `scripts/build_app.sh`
  - `scripts/build_dmg.sh`
  - `scripts/build_release.sh`
- Release script target is currently `0.3.0-beta`, build `3`, Bundle Identifier `app.notchmuse.mac`.
- Fresh checkout simulation was created with:
  - `git archive HEAD | tar -x -C /tmp/notchmuse-fresh-check`
- The simulated fresh checkout only contains the files currently tracked by Git. It does not contain several current RC files that exist only as untracked files in the working tree.
- First-run flow exists in current working tree code via the first launch guide and menu bar controller, but it was not re-validated from a clean installed app in this delegated pass because PM instructed completion under current available permissions.

## Problems Found

- P0: Fresh clone / clean checkout is not release-ready because the Git index does not contain the full current beta source state.
- Missing from tracked `HEAD` in the fresh checkout:
  - `CHANGELOG.md`
  - `RELEASE_CHECKLIST.md`
  - `scripts/build_dmg.sh`
  - `scripts/build_release.sh`
  - `MenuBarLyrics/Resources/NotchMuse.entitlements`
  - `MenuBarLyrics/Resources/en.lproj/*`
  - `MenuBarLyrics/Resources/zh-Hans.lproj/*`
  - `MenuBarLyrics/Sources/MenuBarLyrics/AccessibilityManager.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/AppLocalization.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/DebugLog.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/SettingsWindowController.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/SodaMusicLyricsSource.swift`
  - `reports/release/01-app-build-verification-report.md`
- Current-permission clean build verification could not complete inside this delegated thread:
  - Command: `swift run --package-path MenuBarLyrics NotchMuse --self-test`
  - Failure: SwiftPM manifest compilation failed with `sandbox-exec: sandbox_apply: Operation not permitted`
  - This appears to be an execution-environment permission issue, not an app logic failure.
- Fresh checkout build could not be fully evaluated under current permissions for the same SwiftPM sandbox issue.
- The current local working tree has many modified and untracked files, so it is not yet a clean release source state.

## Recommended Actions

- Create a release commit that includes all intended NotchMuse source, resources, scripts, docs, and release reports.
- After that commit, run a true clean checkout verification:
  - `git clone <repo> /tmp/notchmuse-clean`
  - `swift run --package-path /tmp/notchmuse-clean/MenuBarLyrics NotchMuse --self-test`
  - `/tmp/notchmuse-clean/scripts/build_release.sh 0.3.0-beta <final-build>`
- Keep `.build/`, `.DS_Store`, and `dist.noindex/` ignored; do not publish generated build artifacts as source.
- Run the clean verification outside this restricted Codex sandbox or in a local terminal with normal SwiftPM permissions.

## Need PM Decision

- Decide whether all current untracked RC files should be included in the GitHub beta release commit.
- Decide whether `lyrics-provider-benchmark/` belongs in the same open source release or should remain a separate lab/tooling area.
- Confirm final build number for `0.3.0-beta` before generating the public GitHub release artifact.
- Confirm whether to proceed with an unsigned/ad-hoc GitHub beta artifact or require Developer ID signing and notarization before public release.
