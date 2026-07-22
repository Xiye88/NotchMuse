# NotchMuse Project Status

Last Updated: 2026-07-19

## Current Phase

Phase 1: Beta Release Preparation

## Current Goal

GitHub Open Source Beta Release without expanding product scope.

## Release Status

Status: Ready for GitHub Pre-release

Readiness Score: `96/100`

Current candidate:
- Version: `0.3.0-beta`
- Build Number: `3`
- Bundle Identifier: `app.notchmuse.mac`
- Architecture: Apple Silicon / `arm64`

Verified:
- Release build completed.
- DMG generated at `dist.noindex/NotchMuse.dmg`.
- DMG verification passed.
- App self-tests passed.
- Runtime single-instance behavior passed in QA.
- 100-song live matrix passed at `98/100`.
- DMG install layout is correct: `NotchMuse.app` plus `Applications` symlink.
- Existing `/Applications/NotchMuse.app` matches the DMG app hash in UX QA.
- NotchMuse launches as a single menu bar process.
- Spotify was readable in the QA environment.
- Menu bar lyrics display was visually confirmed in the QA environment.
- Settings opened and showed core controls.
- Latest VPS 1000-song Benchmark report is available: run `6`, `636/1000`, coverage `63.6%`.
- Clean User Journey Checklist is prepared for the final unsigned GitHub beta DMG.
- GitHub Release package and Release Notes are prepared.
- Current working tree debug self-test passed on 2026-07-19.
- Current working tree unsigned release DMG build passed on 2026-07-19.
- `build_release.sh` now produces an unsigned/ad-hoc GitHub beta DMG and warns that Gatekeeper warning is expected.
- `build_app.sh` completed successfully on 2026-07-19.
- `build_dmg.sh` completed successfully on 2026-07-19.
- DMG SHA-256 checksum generated: `f956eb31915ea8c69431c93542e6a34797d3e081c4f493872faa254c79664c99`.
- README now includes GitHub beta installation, unsigned Gatekeeper warning, Architecture, Lyrics Quality, and Known Issues.
- Release Notes created at `RELEASE_NOTES_0.3.0-beta.md`.
- Release commit created: `f60d927`.
- Fresh clone from release commit completed.
- Fresh clone `build_app.sh` completed successfully.
- Fresh clone self-test passed.
- Fresh clone `build_dmg.sh` completed successfully.
- Fresh clone DMG verification passed.
- Minimum screenshots added to `docs/assets/screenshots/`.
- DMG install simulation completed from mounted DMG to a temporary Applications folder.
- Copied app launched successfully from the simulated install path.
- Repository safety audit completed with no API keys, tokens, private keys, or credentials found.
- GitHub release requirement audit completed.
- Final release publish checklist completed.
- Local Git tag created: `v0.3.0-beta`.

Not release-ready:
- Gatekeeper quarantine flow from an actual GitHub-downloaded DMG is not manually verified.
- Demo GIF is not present.
- Settings screenshot is acceptable for beta but should be recaptured cleaner for a polished showcase.

## Blocking Issues

Critical:
- No current P0 blocker.

High:
- Verify Gatekeeper `Control-click Open` / `Open Anyway` flow from the uploaded GitHub DMG.
- Verify first-launch Spotify Apple Events permission flow on a clean user account if Product Owner requires stricter QA.
- Add SHA-256 checksum to GitHub Release body.
- Configure GitHub remote before push/publish.

Medium:
- Recapture cleaner Settings screenshot before a polished public showcase.
- Normalize older public CHANGELOG headings after beta if desired.
- Decide whether README should continue to show the exact VPS benchmark coverage `63.6%`.
- Developer ID signing and Apple notarization are moved to a future Distribution Phase.

## Completed Tasks

- Created NotchMuse Release Candidate QA thread.
- Created GitHub Release Preparation thread.
- Created Lyrics Matching Architecture Review thread.
- Confirmed Release build, DMG generation, metadata, and single-instance behavior.
- Confirmed GitHub release documentation is mostly ready, with screenshots/GIFs missing.
- Confirmed Benchmark/App matcher roadmap belongs to Phase 2, not Phase 1.
- Created project control files and reports directories.
- Completed Release Sprint reports:
  - `reports/release/release-blocker-report.md`
  - `reports/github/github-release-package-report.md`
  - `reports/ux/user-journey-qa-report.md`
  - `reports/benchmark/lyrics-quality-dashboard.md`
- Completed Thread Architecture Audit.
- Created `THREAD_REGISTRY.md`.
- Renamed long-term threads into the `00_PM` through `06_DOCS` structure.
- Archived duplicate one-time audit threads.
- Completed Beta Release Execution Phase reports:
  - `reports/release/02-release-execution-report.md`
  - `reports/github/06-docs-release-package-report.md`
  - `reports/ux/04-ux-clean-journey-checklist.md`
  - `reports/benchmark/03-lab-lyrics-quality-snapshot.md`
- Completed GitHub Open Source Release Sprint reports:
  - `reports/github/06-docs-release-ready-report.md`
  - `reports/release/01-app-build-verification-report.md`
  - `reports/release/02-release-artifact-report.md`
  - `reports/benchmark/03-lab-quality-showcase-report.md`
- Completed Final Beta Release Preparation reports:
  - `reports/release/01-app-final-build-verification-report.md`
  - `reports/github/06-docs-final-package-report.md`
  - `reports/github/github-release-final-package.md`
  - `reports/release/02-release-final-artifact-report.md`
  - `reports/benchmark/03-lab-benchmark-disclosure-recommendation.md`
  - `reports/benchmark/03-lab-final-disclosure-recommendation.md`
- Completed Release Candidate Freeze reports:
  - `reports/release/01-app-final-build-verification-report.md`
  - `reports/github/final-documentation-ready-report.md`
  - `reports/ux/final-ux-release-report.md`
- Completed Final GitHub Beta Release Checklist reports:
  - `reports/release/repository-safety-report.md`
  - `reports/github/github-documentation-ready-report.md`
  - `reports/release/release-publish-checklist.md`

## In Progress Tasks

- GitHub Release upload preparation.
- Long-term thread coordination through `THREAD_REGISTRY.md`.

## Next Decisions

- Confirm unsigned GitHub beta release wording and macOS security warning.
- Decide whether first public beta can ship without Demo GIF.
- Decide where VPS Benchmark reports should be synced in `reports/benchmark/`.
- Decide whether Phase 2 starts only after GitHub beta is published.
- Decide screenshot language: English only, Simplified Chinese only, or both.
- Decide whether README should display `63.6%` VPS benchmark coverage or describe it as an internal quality benchmark.
- Confirm final GitHub tag `v0.3.0-beta` and build number `3` for remote publication.
- Decide whether SHA-256 checksum is required as separate asset or release body text only.
- Add GitHub remote URL.
