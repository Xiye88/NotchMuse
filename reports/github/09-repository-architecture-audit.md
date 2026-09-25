# Repository Architecture Audit

Task: Audit repository architecture before v0.8 Candidate Freeze

Status: Historical baseline audit; its deferred source organization was later
completed after the Candidate Freeze SHA was supplied. See
[Repository Architecture Cleanup — Completion Report](09-repository-architecture-cleanup.md).

Priority: P1 (architecture readiness)

## Current

- Audited baseline: branch target `codex/netease-production-candidate`,
  `dee834f533812aac3e1dcab83f5d62a008d6a906`; fetched remote tip and local HEAD
  resolve identically. Initial worktree was clean and detached.
- Installed `/Applications/NotchMuse.app` and `dist.noindex` artifacts are
  v0.8.0 build 16. Root status documents that still name build 14/15 are stale
  and must be synchronized only after the final runtime gate.
- Swift package is `MenuBarLyrics/Package.swift`, Swift tools 6.0, macOS 14+.
  One executable product/target, with implicit source discovery from
  `Sources/MenuBarLyrics/`; there is no library or formal test target.
- 26 Swift source files are flat under `Sources/MenuBarLyrics/` (278,585 bytes
  total). `SelfTests.swift` is 84,698 bytes and compiled into the production
  executable. `main.swift` dispatches `--self-test` to `SelfTests.run()` before
  app startup. The small packaged self-test is valuable as release smoke, but
  the entire suite's placement couples tests to the app target.
- UI ownership is concentrated: `MenuBarController.swift` (21 KB) handles
  player/source coordination and Status Bar UI; `SettingsWindowController.swift`
  (29 KB) and `OverlayLyricsWindow.swift` (28 KB) hold large UI surfaces.
  `MusicPlayerAdapter.swift` (10.7 KB) contains shared models, protocol,
  Spotify adapter, and selection logic. This is a maintenance concern, not a
  reason to relocate code before freeze.
- Product naming differs by layer: Swift package/target/folder are
  `NotchMuse` / `MenuBarLyrics`; user-facing name and bundle are `NotchMuse`;
  historical docs also say MenuBarLyrics. Avoid a global rename.
- `Vendor/MediaRemoteBridge` is approximately 440 KB: a 292 KB framework
  binary, 124 KB test client, Perl source and metadata. `VERSION.json` pins
  upstream commit `6bbb7d30f9ddb209a583fa509b9ca145df97f502`, BSD-3-Clause, and
  SHA-256 for all three artifacts. `build_app.sh` verifies hashes and archs;
  package step copies and signs them. No manifest covers resources generally.
- Assets are ~17 MB under `docs/assets`, mainly two MP4 demos (11 MB and 3.7
  MB), plus GIF previews and screenshots. These are documentation/demo assets,
  not runtime resources; keep them out of the app bundle.
- Scripts overlap by composition rather than exact duplication:
  `build_release.sh` cleans then calls `build_dmg.sh`; `build_dmg.sh` calls
  `build_app.sh`; `build_app.sh` builds and runs self-test, copies/signs the
  bridge, and verifies bundle contents. `run_app.sh` builds when absent;
  `deploy_local_candidate.sh` builds then replaces the installed app and is
  explicitly machine-mutating. `run_live_matrix.sh` compiles a selected source
  set separately from SwiftPM. `build_mediaremote_bridge.sh` rebuilds pinned
  source but replaces vendored binary files, so it is maintainer-only.
- Root docs include project/status/handoff/roadmap/task/changelog, old release
  notes, support and contributor material; engineering evidence already uses
  `reports/{app,benchmark,github,matcher,release,ux}`. `docs/README.md` still
  describes Spotify-only ownership and v0.5 matcher state; English and Chinese
  READMEs still present v0.6.1, Spotify/Apple Music only, despite current
  candidate support for Auto Detect/NetEase. Existing README correctly
  discloses no notarization, arm64 scope, third-party providers, privacy and
  no account/telemetry. No Homebrew installation path is described.

## Problems Found

### P0

- None found in repository structure that warrants a pre-freeze runtime edit.

### P1

- 84.7 KB of self-test implementation is production target input; failures use
  process exit and tests are not discoverable through `swift test`.
- No CI workflow existed. Local scripts include destructive/machine-specific
  install and cleanup behavior and must not be run as generic CI steps.
- README and developer architecture documentation lag the current candidate;
  release/readme descriptions could mislead about supported players.

### P2

- Flat source layout makes subsystem boundaries implicit and complicates
  ownership/search, although SwiftPM's single target still compiles all files.
- Package/target name `MenuBarLyrics` no longer matches the product brand.
- Two large UI controllers and the shared player file combine multiple roles.
- Demo MP4s dominate repository asset size. They are reviewable user-facing
  evidence and should not be deleted without replacing their value.
- Build logic is layered through nested scripts, but this is currently
  deliberate and provides a single verified release path. Do not duplicate
  bundle/vendor checks in another release builder.

## Proposed Architecture

Keep a single executable target for v0.8. After Freeze, split source files
into descriptive folders (App, Players, Lyrics, UI, Support) without changing
SwiftPM module/target identity or behavior. Move files in small, build-verified
batches, retaining historic filenames until imports/references and packaging
are proven. Extract the UI controllers only when a focused change gives clear
ownership. Keep `MusicPlayerAdapter` as the frozen abstraction boundary; do
not rewrite adapters or provider selection in an architecture-only migration.

## Test

- Near term: retain `--self-test` as a deliberately small packaged smoke
  contract, but move test-only assertions into a formal `MenuBarLyricsTests`
  target in incremental post-freeze work. Keep only a tiny release smoke in
  production if it verifies packaged resources and launch-independent wiring.
- Preferred first migration: create a SwiftPM library target containing
  testable non-UI logic and let the executable depend on it, then add
  `Tests/MenuBarLyricsTests`. This is a package/module boundary change and is
  explicitly deferred until a Freeze SHA exists; a test target importing the
  executable directly may not be a valid SwiftPM design.
- Preserve current assertions and behavior during transfer; the self-test and
  `swift test` should overlap temporarily, then delete duplicated assertions
  once parity is demonstrated. No mass source movement in this phase.

## CI

Added `.github/workflows/ci.yml`, an additive macOS 14 workflow. It checks
shell syntax (zsh/bash/sh), Perl syntax, English/Chinese localization key
parity, pinned Vendor SHA-256 values, the existing Release/DMG build path
(including packaged `--self-test` and signing/DMG verification), and clean diff
checks. It does not install or launch the app, use secrets, run live lyrics,
change runtime files, publish artifacts, tag, or release. Workflow execution
on GitHub remains pending. Locally, Release build and packaged `--self-test`
passed; shell/Perl syntax, 102-key localization parity, all three Vendor hashes,
YAML parsing, and `git diff --check` passed. The complete DMG release wrapper was
not run because it clears `dist.noindex` before building.

## Docs

- README v0.8 proposal (English and Chinese in the same update): state Auto
  Detect as default; enumerate Spotify, Apple Music and NetEase Cloud Music;
  retain explicit selection; explain the MediaRemote bridge is bundled (no
  separate Homebrew install/dependency); disclose that NetEase support relies
  on macOS private MediaRemote APIs and may break across macOS/player updates;
  preserve correct ad-hoc/no Developer ID/not notarized warning, Apple Silicon
  and macOS minimum, permission, privacy and provider caveats. Update download
  links only after a release exists. Do not claim v0.8 is released now.
- Keep project coordination in root PM docs while active; proposed longer-term
  organization: `docs/project/` for architecture/decisions, `docs/releases/`
  for current user-facing release notes/checklists, and `docs/archive/` for
  superseded plans and historical evidence. Keep `reports/` as immutable-ish
  execution evidence and add an index mapping reports by date, owner and phase.
  Migration should use `git mv`; do not delete or rewrite historical evidence.
- Update `docs/README.md` architecture summary and versioned state only after
  architecture changes. Keep historical specs/plans with clear archived labels.

## Migration Risks

- SwiftPM file moves can alter implicit target discovery, resource lookup, or
  shell-script hard-coded paths. Move batches must run Debug/Release builds,
  self-test, packaging and bundle resource checks.
- Extracting assertions from executable code can expose AppKit/main-actor and
  internal visibility constraints; avoid `@testable` assumptions until target
  boundaries compile.
- Renaming the package/target may affect `swift run` invocations and all shell
  scripts. No global rename before explicit migration inventory.
- Vendor update/rebuild can change binary ABI, architecture slices, signatures,
  private API assumptions and license attribution; require new hashes and
  focused runtime lifecycle QA.
- CI runner macOS/Xcode versions can drift from release builder; pin/select an
  approved runner and record Xcode/Swift versions before using CI as release
  evidence. The current workflow is a build gate, not a distribution workflow.

## Move-Stay-Archive

- Move after Freeze only: source files into descriptive directories, formal
  test-only assertions, and project/release docs into indexed homes.
- Stay: app entry point, runtime adapter/bridge, lyrics runtime and providers,
  matcher, UI controller behavior, SwiftPM target identity, bundled bridge,
  README/release evidence, benchmark datasets, and existing dated reports.
- Archive by `git mv` only: superseded planning docs/release material after
  validating inbound links and retaining evidence. No deletion now.

## Order

1. Receive Candidate Freeze SHA from `00_PM`; fetch and verify it.
2. Create `codex/repository-architecture-cleanup` from that exact SHA.
3. Add/validate CI and establish frozen baseline results.
4. Move test assertions to formal tests in a bounded package/module change.
5. Move source files in small groups, keeping package target identity and
   runtime stable.
6. Update bilingual README and developer docs to match a verified release.
7. Add docs/reports indexes and archive superseded docs with links intact.
8. Re-run all build, package, localization, vendor and runtime evidence before
   requesting review. No merge/push/release in this assignment.

## Pre-v0.8 Do Not Change

Do not change `NetEaseMusicAdapter`, `MediaRemoteBridge`, Auto Detect runtime,
Lyrics runtime, Production Matcher, Provider priority/thresholds; do not move
Swift files at scale, alter Package targets/modules, or globally rename.
Also do not rebuild/replace Vendor binaries, mutate local app installation,
merge, push, tag, or publish. Current report/workflow/doc work stays outside
those boundaries.

## Need PM Decision

- Supply the exact Candidate Freeze SHA when the Stability/Release gate allows
  architecture cleanup to start. Until then, only audit/documentation and
  additive CI work are authorized.
- No additional design decision is needed for this audit phase.
