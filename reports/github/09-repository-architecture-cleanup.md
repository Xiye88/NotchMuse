# Repository Architecture Cleanup — Completion Report

Task: Complete the post-freeze repository organization and CI work on
`codex/repository-architecture-cleanup`.

Status: Complete; branch pushed and final CI run passed.

Priority: P1 (repository maintenance)

## Findings

- Grouped app sources under `App/`, `Players/`, `Lyrics/`, `UI/`, and `Support/`;
  `AppLocalization.swift` remains at the target root because its `#filePath`
  resource fallback depends on that location.
- Extracted pure lyric parsing and clock logic into `LyricsCore` with a focused
  Swift test target. Full app self-tests run in Debug. Release
  `--self-test` now checks the packaged localization and MediaRemote bridge
  resources only.
- Updated the workflow to `macos-15` for its Swift 6 toolchain, bilingual
  READMEs and engineering docs, report index/archive, and build 19 artifact
  metadata/checksums.
- Preserved the v0.8 runtime, provider/matcher behavior, and frozen build 18
  release-review status. No merge, tag, or public release was made.

## Verification

- Local Debug build and complete `--full-self-test`: passed.
- Local `./scripts/build_release.sh 0.8.0 19`: passed, including packaged
  resource smoke test, code-signature verification, DMG verification, and
  SHA-256 manifest validation.
- `swift test`, localization parity, vendored bridge integrity, Release/DMG
  packaging, artifact metadata/checksums, and whitespace checks: passed in CI
  run `36157019064`.
- Local artifact metadata: arm64, ad-hoc signed, not notarized. It is a
  repository validation artifact and is not a public release.

## Problems Found

- `actions/checkout@v4` emits a non-blocking Node.js 20 deprecation warning on
  the current macOS runner image.
- Developer ID signing and notarization remain release-review requirements.

## Recommended Actions

- Keep this branch separate until the Product Owner decides whether to merge.
- Handle signing/notarization in the release phase.

## Need PM Decision

- None for this completed repository task. Merge and publication remain outside
  this task's authorization.
