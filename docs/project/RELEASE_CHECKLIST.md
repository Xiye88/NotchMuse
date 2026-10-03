# NotchMuse Release Checklist

Target: v0.8.0 Build 47, accepted by Product Owner. Runtime matches the accepted
source; release source is `15e13fc2c23ff8f5530db7e5629de076dd9011c5`.
Official release published and verified on 2026-10-04. Earlier clean-Mac
coverage gaps below are non-blocking future work, not freshly repeated tests.

## Product

- [x] Product Owner final Preview acceptance
- [x] Sparkle staged discovery, notes, download, EdDSA verification, install, relaunch and latest-version result
- [x] Existing player/Settings evidence retained; no repeated long tests

## macOS

- [ ] Accessibility permission tested from a clean install
- [ ] Apple Events permission tested from a clean install
- [ ] Repeated Display Mode and Position changes do not loop permission prompts
- [ ] Repeated launch tested with `open -n`
- [ ] Quit and restart leave one NotchMuse process
- [x] Ad-hoc distribution/Gatekeeper status documented separately from version status
- [ ] Control-click Open flow tested
- [ ] System Settings > Privacy & Security > Open Anyway flow tested

## Packaging

- [x] Version `0.8.0`, Build `47`, stable bundle `app.notchmuse.mac`
- [x] `./scripts/build_release.sh 0.8.0 47` and packaged self-test completed
- [x] BUILD-INFO and SHA256SUMS match the source, app and DMG
- [ ] DMG opens and supports drag-to-Applications installation
- [x] DMG verifies with `hdiutil verify`; deep/strict ad-hoc signature verified
- [x] README/Chinese README, migration instructions, bilingual notes and CHANGELOG reviewed
- [x] Historical release notes/handoff content retained through exact moves; no deleted production files

## GitHub

- [x] main fast-forward/push and CI `37136789378` PASS at release source SHA
- [x] Release notes: English first, Chinese second
- [ ] Status Bar screenshot added
- [ ] Notch Mode screenshot added
- [ ] Settings screenshot added
- [ ] Status Bar and Notch Mode demo videos added
- [x] `NotchMuse.dmg`, SHA256SUMS, BUILD-INFO and update metadata uploaded
- [x] Official EdDSA appcast signed and verified against embedded public key
- [x] Published as a regular v0.8.0 Release, not a prerelease
- [x] Website-button download and official feed verified against published assets
- [x] Stable `/Applications/NotchMuse.app` deployed and running; separate Preview retained

Public release complete. New screenshot gallery and broader clean-Mac coverage
remain non-blocking. See `docs/reports/v0.8.0-release-verification.md`.
