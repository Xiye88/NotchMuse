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

## FAIL

- None observed in the executed scope.

## BLOCKED

- Direct Settings window click-through: the Computer Use accessibility surface does not enumerate this `LSUIElement` menu-only QA app, so the live color panel, preset clicks, numeric Enter handling, and five width buttons were not manually clicked. Their code paths and self-tests pass; runtime preference-driven rendering was verified where possible.
- Hover pointer entry/exit: global overlay cursor movement was not reliably addressable by the available app-bound UI automation. Default/persistence and implementation checks pass.
- Spotify and Apple Music live playback: both are installed but not running with an active authenticated playback session. No PASS is claimed.

## PENDING

- Sleep/Wake recovery.
- Network loss/recovery while fetching lyrics.
- Cross-provider Auto handoff under simultaneous live playback.

## Environment Restoration

- NetEase was left paused.
- The user preference domain was backed up before QA and restored afterward.
- `/Applications/NotchMuse.app` build 15 was not overwritten and was relaunched after QA.
