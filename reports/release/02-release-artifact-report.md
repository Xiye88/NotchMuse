# Task Completion Report

Task: 02_RELEASE Artifact Report

Status: Ready for unsigned GitHub beta artifact; pending PM release wording and clean download proof

Priority: P0

## Findings

- Target is GitHub Open Source Beta Release, not App Store, commercial distribution, Developer ID distribution, or notarized macOS distribution.
- Developer ID signing and Apple notarization are deferred to a future Distribution Phase and are not current P0 blockers.
- DMG flow is present:
  - `scripts/build_release.sh` cleans `dist.noindex`, runs Swift package clean, calls `scripts/build_dmg.sh`, verifies app metadata, verifies codesign structure, and verifies the DMG.
  - `scripts/build_dmg.sh` builds the app, stages `NotchMuse.app`, adds an `Applications` symlink, creates `dist.noindex/NotchMuse.dmg`, and verifies the DMG.
- Current artifact path: `dist.noindex/NotchMuse.dmg`.
- Current app metadata:
  - Bundle ID: `app.notchmuse.mac`
  - Version: `0.3.0-beta`
  - Build: `3`
  - Architecture: arm64-only beta.
- Current signing state is correct for unsigned beta:
  - `dist.noindex/NotchMuse.app` is ad-hoc signed.
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.app` reports `Signature=adhoc` and `TeamIdentifier=not set`.
  - `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app` passes local integrity verification.
  - `dist.noindex/NotchMuse.dmg` is unsigned; `codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg` reports `code object is not signed at all`.
- DMG checksum verification passes with `hdiutil verify dist.noindex/NotchMuse.dmg`.
- Current DMG SHA-256: `30c54ed542ab6a0e8f6ebefff3c931a4da5f94fdf81108a549b156ca84320e4c`.
- DMG mounted layout was verified when system-level DMG attach was available:
  - `/Volumes/NotchMuse/NotchMuse.app`
  - `/Volumes/NotchMuse/Applications -> /Applications`
- Gatekeeper rejection is expected for this phase:
  - `spctl --assess --type execute --verbose=4 dist.noindex/NotchMuse.app` reports `rejected` when system assessment is available.
- README now documents the unsigned beta launch path:
  - Download `NotchMuse.dmg`.
  - Drag `NotchMuse.app` to Applications.
  - Control-click `NotchMuse.app`, choose Open, and confirm.
  - If still blocked, use `System Settings > Privacy & Security > Open Anyway`.
- Release checklist now tracks unsigned beta warning, Control-click Open, and Open Anyway verification instead of treating Developer ID/notarization as current blockers.
- Final GitHub Release artifact should include:
  - `NotchMuse.dmg`
  - SHA-256 checksum
  - Version/build
  - Apple Silicon / arm64-only note
  - Unsigned open-source beta warning
  - Install and Open Anyway instructions
  - Known limitation that Developer ID signing/notarization is future Distribution Phase work.

## Problems Found

- No current artifact blocker found for unsigned GitHub beta packaging.
- Expected user friction: macOS will warn or reject on first launch because the app is unsigned/ad-hoc and the DMG is unsigned.
- Clean first-launch proof from an actual GitHub Releases download is still missing. Local `dist.noindex` verification does not prove quarantine behavior after browser download.
- System-level checks can be limited by the current execution environment:
  - DMG attach may fail with `hdiutil: attach failed - 设备未配置` under restricted permissions.
  - Gatekeeper assessment may fail with `internal error in Code Signing subsystem` under restricted permissions.
  - When those system interfaces are available, DMG layout verifies and Gatekeeper rejects as expected.
- README still mentions future Developer ID/notary commands in the source build section. This is acceptable because it is explicitly labeled as future Distribution Phase, but PM may prefer removing it from beta-facing release notes.

## Recommended Actions

- Publish `dist.noindex/NotchMuse.dmg` as the GitHub beta artifact.
- Include SHA-256 in the release body:
  - `30c54ed542ab6a0e8f6ebefff3c931a4da5f94fdf81108a549b156ca84320e4c`
- Use clean verification commands before upload:
  - `./scripts/build_release.sh 0.3.0-beta 3`
  - `plutil -extract CFBundleIdentifier raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `plutil -extract CFBundleShortVersionString raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `plutil -extract CFBundleVersion raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app`
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.app`
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg`
  - `hdiutil verify dist.noindex/NotchMuse.dmg`
  - `shasum -a 256 dist.noindex/NotchMuse.dmg`
- Use clean verification commands after GitHub upload:
  - Download the release asset from GitHub Releases.
  - Run `shasum -a 256 NotchMuse.dmg` and compare with release notes.
  - Mount the DMG in Finder.
  - Confirm the DMG contains `NotchMuse.app` and an Applications shortcut.
  - Drag `NotchMuse.app` to Applications.
  - Launch with Control-click Open.
  - If blocked, verify `System Settings > Privacy & Security > Open Anyway`.
  - Confirm Spotify Automation permission prompt appears during first Spotify access.
- Keep Developer ID signing, notarization, stapling, and Gatekeeper acceptance out of current beta blockers and track them in Distribution Phase.

## Need PM Decision

- Confirm final GitHub tag and build number. Current verified artifact is `0.3.0-beta` build `3`.
- Confirm release wording: `unsigned GitHub beta` vs `open-source beta`.
- Confirm whether the GitHub release body should include the future Developer ID/notarization note or keep that only in README.
- Assign owner for clean GitHub-download first-launch proof, including Open Anyway screenshots or written confirmation.
- Decide whether screenshots are required before publishing or can follow after the beta artifact is uploaded.
