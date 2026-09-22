# NotchMuse Task Board

Last Updated: 2026-09-23

## Sprint

v0.8 Stability Fix Sprint. Development precedes QA; release is prohibited.

## Workspace Registry

Workspace numbers are unique. A completed workspace moves to `DONE`, then to
`ARCHIVED` when its result has been merged or handed off.

| Workspace | Status | Current responsibility |
| --- | --- | --- |
| `00_PM` | ACTIVE | Sprint coordination, integration, gates, and release decision |
| `01_APP` | ARCHIVED | P0 merged as `28d7a3b`; branch retained |
| `02_RELEASE` | ARCHIVED | No release work during Stability Fix Sprint |
| `03_LAB` | ARCHIVED | Benchmark experiments; reopen only with a new evidence question |
| `04_UX` | ARCHIVED | P1 merged as `46dc4f5`; branch retained |
| `05_MATCHER` | ARCHIVED | v0.7 evidence gate was NO-GO; Production Matcher remains frozen |
| `06_DOCS` | ARCHIVED | `00_PM` updates Handoff after each development phase |
| `07_QA` | ARCHIVED | Focused QA phases merged as `daff724` and `190fee6`; report retained |

## Sprint Work

| ID | Priority | Owner | Status | Deliverable / exit criteria |
| --- | --- | --- | --- | --- |
| `P0.1` | P0 | `00_PM` | DONE | Only `/Applications/NotchMuse.app` build 15 remains installed/Spotlight-visible; executable hash, one launch entry, helpers, preferences, and Auto Detect are verified |
| `P0-1` | P0 | `01_APP` | IMPLEMENTED | Auto/Spotify/Apple Music/NetEase Settings options and restart persistence have regression coverage |
| `P0-2` | P0 | `01_APP` | IMPLEMENTED | Auto selection uses playback state and freshness, preserves deterministic ownership, and does not select merely because an app is open |
| `P0-3` | P0 | `01_APP` | IMPLEMENTED | NetEase rejects stale asynchronous state, reused track identifiers, and expired provider data; real-player regression remains |
| `P1-1` | P1 | `04_UX` | IMPLEMENTED | Background/hover/stopped behavior, arbitrary lyric color with presets, numeric inputs, and functional Custom Width are implemented |
| `QA-GATE` | P1 | `07_QA` | PASS WITH BLOCKERS | Automated, three-player, Auto handoff, and Settings scope passed with 0 FAIL; color interaction, Hover, Sleep/Wake, and network remain blocked/pending |

## Current Evidence

- Stability integration commits: `28d7a3b` (App) and `46dc4f5` (UX) on
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
- Focused QA report: `reports/2026-09-23-v08-stability-focused-qa.md`.

## Physical Worktrees

- PM/integration: `.worktrees/netease-production-candidate` (clean/current).
- QA worktree was removed after its report merged; branch/history remain.
- APP and UX worktrees were cleanly removed after merge; their branches and
  commit history remain.
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
