# NotchMuse Task Board

Last Updated: 2026-09-22

## Sprint

v0.8 Production Quality Sprint. The release is not published.

## Workspace Registry

Workspace numbers are unique. A completed workspace moves to `DONE`, then to
`ARCHIVED` when its result has been merged or handed off.

| Workspace | Status | Current responsibility |
| --- | --- | --- |
| `00_PM` | ACTIVE | Sprint coordination, integration, gates, and release decision |
| `01_APP` | ARCHIVED | P0 implementation merged as `8864f52` |
| `02_RELEASE` | ACTIVE | RC build, DMG, checksum, signing assessment, and release preparation |
| `03_LAB` | ARCHIVED | Benchmark experiments; reopen only with a new evidence question |
| `04_UX` | ACTIVE | Notch background and hover regression verification |
| `05_MATCHER` | ARCHIVED | v0.7 evidence gate was NO-GO; Production Matcher remains frozen |
| `06_DOCS` | ARCHIVED | Sprint reset merged as `6ae46e0` |
| `07_QA` | ACTIVE | Automated regression and real-player release gates |

## Sprint Work

| ID | Priority | Owner | Status | Deliverable / exit criteria |
| --- | --- | --- | --- | --- |
| `P0-1` | P0 | `01_APP` / `07_QA` | DONE | Auto Detect is the default; bundle detection, deterministic priority, owner switching, and stale-result guards have self-test coverage |
| `P0-2` | P0 | `01_APP` / `07_QA` | DONE | Settings exposes Auto, Spotify, Apple Music, and NetEase; enum, datasource, persistence, bundle IDs, and adapter factory are regression-tested |
| `P1-1` | P1 | `01_APP` / `07_QA` | QA PENDING | Playing/Paused/Stopped code is implemented; paused marquee stops, stopped hide/hold is configurable, and native identity changes clear old lyrics; real-player regression remains |
| `P1-2` | P1 | `04_UX` / `07_QA` | ACTIVE | Default lyric-only presentation; Background supports None/Black/Custom with None default; Hide lyrics on hover supports ON/OFF with ON default |
| `P2-1` | P2 | `02_RELEASE` / `07_QA` / `06_DOCS` | QA PENDING | Local `0.8.0` build `15` DMG is verified; real-player/lifecycle/clean-install gates and final approval remain before any public release |

## Current Evidence

- P0 integration commits: `8864f52` (App) and `6ae46e0` (sprint docs) on
  `codex/netease-production-candidate`.
- Release and Debug builds plus self-tests: PASS.
- Local build `15` DMG SHA-256:
  `215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
- `codesign --verify --deep --strict` and `hdiutil verify`: PASS.
- Signing: ad-hoc, arm64, no Team ID; Gatekeeper assessment: rejected.
- GitHub push, tag, and Release: NOT STARTED.

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
