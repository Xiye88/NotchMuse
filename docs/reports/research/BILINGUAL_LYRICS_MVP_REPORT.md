# Bilingual lyrics MVP — data layer result

日期：2026-11-12

## Scope

The MVP keeps the original lyric line as the source of truth and adds an optional `translation` string to `LyricLine`. Existing providers, matcher identity gates, provider ordering, playback timing, and caches remain unchanged. A line without a translation continues to render exactly as before.

NetEase parses the existing `yrc`/`lrc` payload first and treats `tlyric` as optional enrichment from the same response. Original YRC timestamps remain authoritative. Translation timestamps are normalized through their own LRC offset, then matched to original line starts within 450 ms. Matching is bidirectionally unique: a translation is attached only when exactly one original line and exactly one translation line are nearest in the tolerance window. This handles missing or extra translation lines and refuses duplicate or crowded timestamps rather than guessing by array index. Invalid translation JSON or malformed translation lines are ignored while valid original lyrics remain available.

`LyricLine.shifted(by:)`, `TimedLyricDocument.normalizedLines`, candidate selection timing repairs, and in-memory candidate caching preserve the optional translation. Track identity and cache keys remain unchanged, so translations cannot cross song, player, or native-track boundaries.

## Fixed fixture evidence

`test_bilingual_lyrics.sh` runs a standalone Swift harness without starting the app or SwiftPM. It covers missing and malformed translation, different line counts, normalized offsets, near-time tolerance, YRC priority, duplicate and ambiguous starts, whitespace-only lines, shifted/normalized documents, candidate propagation, same-recording cache reuse, and song/player identity cache separation.

Red before implementation: 8 bilingual assertions failed (`/private/tmp/notchmuse-bilingual-red.log`).

Green after implementation: **23 checks PASS** (`/private/tmp/notchmuse-bilingual-green.log`). These are fixed synthetic fixtures and demonstrate data contracts; they do not measure real-song bilingual coverage.

## UI handoff

The UI can read `LyricLine.translation` from `TimedLyricDocument.lines` or `normalizedLines`. The field is `nil` when no unambiguous translation is available. The data layer deliberately does not decide layout, bilingual line visibility, language preference, or fallback typography.

## Limits

Only NetEase's same-response `tlyric` is enriched in this MVP. Other providers and separate translation requests are unchanged. Timestamp alignment is conservative and can leave a translation blank when provider timestamps are too close or inconsistent. No new channel, network dependency, matcher rule, or public release behavior is introduced by this data layer.

## UI MVP update

The local candidate now carries the current line's optional translation through `LyricMoment` into `MenuBarController` and `OverlayLyricsWindow`. The bilingual switch is off by default. When enabled, only Notch/Free modes render original text above Chinese; Status Bar remains single-line. Translation text has smaller secondary styling, no fabricated word highlight, and missing translation falls back to the original line. Notch height calculations account for bilingual content; FreeLyricsInteraction, saved anchors, lock and click-through paths were reused.

`swift build --package-path MenuBarLyrics -c release` passed after wiring the clock and UI. The fixed data harness remains 23 PASS. A full AppKit UI test executable was not run because the standalone test needs the package's LyricsCore module; visual Preview acceptance is pending and no Preview was rebuilt or installed for this Track.
