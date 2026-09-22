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
| `01_APP` | ACTIVE | Player auto detection, state handling, and Settings regression |
| `02_RELEASE` | ACTIVE | RC build, DMG, checksum, signing assessment, and release preparation |
| `03_LAB` | ARCHIVED | Benchmark experiments; reopen only with a new evidence question |
| `04_UX` | ACTIVE | Notch background and hover regression verification |
| `05_MATCHER` | ARCHIVED | v0.7 evidence gate was NO-GO; Production Matcher remains frozen |
| `06_DOCS` | ACTIVE | Sprint status, roadmap, task board, and release documentation |
| `07_QA` | ACTIVE | Automated regression and real-player release gates |

## Active Work

| ID | Priority | Owner | Status | Deliverable / exit criteria |
| --- | --- | --- | --- | --- |
| `P0-1` | P0 | `01_APP` / `07_QA` | ACTIVE | Player setting defaults to Auto Detect; detects active Spotify (`com.spotify.client`), Apple Music (`com.apple.Music`), or NetEase (`com.netease.163music`); deterministic switching and stale-lyric clearing are tested |
| `P0-2` | P0 | `01_APP` / `07_QA` | ACTIVE | Restore Spotify, Apple Music, and NetEase in Settings; verify `PlayerSource`, `SettingsWindowController`, adapter registration, datasource, persistence, and add a regression test |
| `P1-1` | P1 | `01_APP` / `07_QA` | ACTIVE | Playing shows and scrolls; Paused holds and stops scrolling; Stopped follows the selected hide/hold policy; track changes clear old lyrics before loading new lyrics |
| `P1-2` | P1 | `04_UX` / `07_QA` | ACTIVE | Default lyric-only presentation; Background supports None/Black/Custom with None default; Hide lyrics on hover supports ON/OFF with ON default |
| `P2-1` | P2 | `02_RELEASE` / `07_QA` / `06_DOCS` | ACTIVE | Produce and verify the v0.8 RC DMG and checksum; report actual signing state; update release notes and status documents; obtain final approval before any public release |

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
