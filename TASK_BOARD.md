# NotchMuse Task Board

Last Updated: 2026-09-22

## Sprint

v0.8 Stability Fix Sprint. Development precedes QA; release is prohibited.

## Workspace Registry

Workspace numbers are unique. A completed workspace moves to `DONE`, then to
`ARCHIVED` when its result has been merged or handed off.

| Workspace | Status | Current responsibility |
| --- | --- | --- |
| `00_PM` | ACTIVE | Sprint coordination, integration, gates, and release decision |
| `01_APP` | ACTIVE | P0 NetEase restoration, Auto Detect, and playback stability |
| `02_RELEASE` | ARCHIVED | No release work during Stability Fix Sprint |
| `03_LAB` | ARCHIVED | Benchmark experiments; reopen only with a new evidence question |
| `04_UX` | ACTIVE | P1 Settings and Notch UX implementation |
| `05_MATCHER` | ARCHIVED | v0.7 evidence gate was NO-GO; Production Matcher remains frozen |
| `06_DOCS` | ARCHIVED | `00_PM` updates Handoff after each development phase |
| `07_QA` | ARCHIVED | Start only after P0 and P1 development complete |

## Sprint Work

| ID | Priority | Owner | Status | Deliverable / exit criteria |
| --- | --- | --- | --- | --- |
| `P0.1` | P0 | `00_PM` / `02_RELEASE` / `07_QA` | DONE | Only `/Applications/NotchMuse.app` build 15 remains installed/Spotlight-visible; old build 7/build 14 are in Trash; executable hash, one launch entry, helpers, preferences, and Auto Detect are verified |
| `P0-1` | P0 | `01_APP` | ACTIVE | Permanently retain Auto/Spotify/Apple Music/NetEase Settings options and restart persistence in the single installed build |
| `P0-2` | P0 | `01_APP` | ACTIVE | Select by real playback state, metadata/event freshness, and deterministic fallback; do not select merely because an app is open |
| `P0-3` | P0 | `01_APP` | ACTIVE | Stabilize NetEase metadata, lyrics, and timeline across play/pause/previous/next/seek/restart |
| `P1-1` | P1 | `04_UX` | ACTIVE | Finish background/hover/stopped behavior, arbitrary lyric color with presets, numeric inputs, and functional Custom Width |
| `QA-GATE` | P1 | `07_QA` | BLOCKED | Start only after `01_APP` and `04_UX` are merged and automated checks pass |

## Current Evidence

- P0 integration commits: `8864f52` (App) and `6ae46e0` (sprint docs) on
  `codex/netease-production-candidate`.
- Release and Debug builds plus self-tests: PASS.
- Local build `15` DMG SHA-256:
  `215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
- `codesign --verify --deep --strict` and `hdiutil verify`: PASS.
- Signing: ad-hoc, arm64, no Team ID; Gatekeeper assessment: rejected.
- GitHub push, tag, and Release: NOT STARTED.
- Installed app: one `/Applications/NotchMuse.app`, version `0.8.0` build `15`;
  Spotlight returns one result and Player Source is Auto Detect.
- Focused Auto Detect runtime: Spotify and Apple Music were closed, NetEase
  was the only running player, MediaRemote owner was `com.netease.163music`
  with `playing=true`, and NotchMuse visibly rendered its current lyric.

## Physical Worktrees

- PM/integration: `.worktrees/netease-production-candidate` (clean/current).
- QA: archived; its old clean worktree is being deregistered until the
  development gate opens.
- Legacy experiment root: repository root (dirty; retained until its uncommitted
  evidence is migrated or archived).
- Four clean duplicate worktrees were deregistered; their branches and Git
  history remain intact.

## Product Decisions

- Player selection options: Auto Detect (recommended), Spotify, Apple Music,
  and NetEase Cloud Music.
- When the player exits, the default is to hide lyrics and wait for recovery.
  The alternative keeps the final lyric visible and paused.
- Production Matcher, thresholds, ranking, and Provider priority remain frozen.
- Do not push, tag, or publish v0.8 without the final Product Owner approval.

## Future — Not In This Sprint

Plan `notchmuse.com` after v0.8. The public download surface will contain only
the DMG, checksum, `latest.json`, landing page, and release notes. Source code
will not be uploaded to the website. No website implementation is authorized
in this sprint.

## Archived Evidence

- v0.6.0 and v0.6.1 were published with Spotify and Apple Music support.
- v0.7 and v0.7.1 Matcher/metadata gates ended NO-GO.
- The prior NetEase candidate reached build 14 and produced a locally verified
  DMG, but it was not merged, pushed, tagged, or released.
