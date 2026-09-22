# NotchMuse v0.8 Stability Focused QA

Date: 2026-09-23 (Asia/Shanghai)

Commit: `46dc4f51f7702186c6b3214fdd064a01f908e570`

QA app: `0.8.0 (9007)`, isolated under `07_QA/dist.noindex`

## Result

Focused stability gate: **PASS with environment blockers**. No product-code changes, installation overwrite, DMG, push, tag, or release occurred.

## PASS

- Debug build and executable self-tests: exit 0, `Self-tests passed`.
- Release build and executable self-tests: exit 0, `Self-tests passed`.
- Self-test suite contains 311 checks, including Auto freshness/ownership, NetEase convergence and stale updates, player preference persistence, stop behavior, numeric input, and all width modes.
- English and Simplified Chinese `.strings`: all four files pass `plutil -lint`.
- `git diff --check`: clean before this QA report.
- Isolated app packaging, ad-hoc signing, embedded bridge syntax/architecture/test: PASS.
- Real NetEase (`com.netease.163music`) with Player Source set to Auto:
  - paused `山北` -> play (`playing=true`, rate 1);
  - natural track transition to `沙漠船长`;
  - manual next to `餐桌笔记` with new title and content ID;
  - manual previous back to `沙漠船长`;
  - seek to 53.9 / 220.25 seconds, with the displayed lyric changing to the corresponding line;
  - pause (`playing=false`, rate 0), default Hide policy removed the lyric;
  - QA app restart retained Auto ownership and current NetEase metadata.
- Keep policy retained the last paused lyric after restart; Hide policy hid it.
- Notch runtime screenshots confirmed Background None, Black, and archived custom pink; Custom width 360 was bounded correctly. A securely archived custom cyan lyric color was persisted and decoded successfully.
- Static/runtime checks confirm Auto, Spotify, Apple Music, and NetEase choices; all PlayerSource values round-trip through preferences. Defaults remain Auto, Background None, Hide on Hover on, and Hide on stop.

## Second-Phase Incremental PASS

- Apple Music real playback: `以父之名` by `周杰伦` reported `com.apple.Music`, `playing=true`, rate 1; Auto displayed its synced lyrics.
- Spotify real playback: Taylor Swift playback reported `com.spotify.client`, `playing=true`, rate 1; Auto changed the visible lyric to the Spotify track.
- Cross-provider Auto handoff: while Apple Music and Spotify were both playing, the more recent Spotify activity won; pausing Spotify while Apple Music continued caused Auto to return to Apple Music within the next polling interval. Screenshots and independent AppleScript playback state agreed with the visible lyrics.
- The isolated QA app's status menu was exposed through macOS Accessibility and opened `NotchMuse 设置` successfully.
- The Player popup visibly contained Auto Detect, Spotify, Apple Music, and 网易云音乐. Selecting Apple Music and returning to Auto updated the control correctly.
- Numeric Enter handling was exercised in the live Settings window: font size 18 updated its slider, animation speed 1.5 updated its slider, opacity 80 updated its slider to 0.8, and custom width 420 updated its slider.
- All five width controls were exercised: Auto, Compact, Standard, Wide, and Custom each became selected; Custom revealed its slider and editable value field.

## FAIL

- None observed in the executed scope.

## BLOCKED

- Live color panel and preset click-through were not completed before the second-phase stop boundary. Secure custom-color persistence, rendering, preset code paths, and self-tests passed, but no claim is made for live color-panel interaction.
- Hover pointer entry/exit: global overlay cursor movement was not reliably addressable by the available app-bound UI automation. Default/persistence and implementation checks pass.

## PENDING

- Sleep/Wake recovery.
- Network loss/recovery while fetching lyrics.

## Environment Restoration

- NetEase was left paused.
- The user preference domain was backed up before each QA phase and restored afterward.
- Spotify and Apple Music were returned to their pre-test not-running state.
- `/Applications/NotchMuse.app` build 15 was not overwritten and was relaunched after QA.
