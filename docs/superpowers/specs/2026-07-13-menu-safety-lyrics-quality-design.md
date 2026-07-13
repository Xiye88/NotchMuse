# Menu Safety and Lyrics Quality Design

## Goal

Make the menu-bar app easier to operate, prevent left-side lyrics from covering the foreground app's menus, measure lyric coverage and matching quality, and add a restrained lyric progress animation.

## Scope

### Native status item

- Remove the separate floating settings button.
- Use the existing `NSStatusItem` as the only settings button so macOS owns its layout and click target.
- Render the music-note symbol with the dark-orange brand gradient `#E87924` -> `#C85A12` -> `#963A08`, preserving contrast on light and dark menu bars.
- Keep the existing menu and left/right/both selection behavior.

### Left-side avoidance

- When left-side lyrics are selected, use macOS Accessibility to read the foreground application's menu-item frames and start the lyric lane after the final visible menu item.
- Request Accessibility access only when left-side or both-side lyrics need it, not when the app starts in right-only mode.
- If access is unavailable, retain a conservative fixed boundary and never reduce the existing right-side lane.
- Preserve click-through behavior for lyric text.

### Lyrics quality benchmark

- Expand the opt-in live matrix to 100 representative Chinese, English, Japanese, and Korean Spotify tracks.
- Report per-track result, winning source, lyric line count, and response time.
- Print aggregate coverage and latency summaries.
- Keep false-match checks deterministic and offline by extending existing parser fixtures with known same-title, live, cover, duration, script, and simplified/traditional metadata conflicts.
- Release target: at least 90% synchronized-lyric coverage in the live matrix and zero accepted false-match fixtures.
- Do not add another lyric provider until the matrix identifies a measurable coverage gap that an evaluated provider closes.

### Lyric progress color

- Keep the current line-level LRC model.
- Draw each active line in the normal menu-bar color with the same dark-orange gradient clipped from left to right according to elapsed time between the current line and the next line.
- Reset progress on pause, seek, track change, or lyric refresh.
- Use a lightweight display timer only while Spotify is playing and lyrics are visible.
- Exact word-level highlighting is out of scope until a provider supplies verified word timestamps such as TTML spans.

## Data Flow

1. Spotify polling supplies track metadata, playback state, and position.
2. Existing lyric sources validate candidates through `TrackMatcher` and return synchronized lines.
3. `LyricClock` supplies the active line and line progress.
4. `MenuBarController` sends text and progress to the overlay.
5. The overlay lays out safe left/right lanes and clips the orange active layer to the current progress.

## Verification

- Add self-checks for dynamic left boundaries, fallback boundaries, and progress calculation.
- Verify the native status item opens the menu without a floating hit target.
- Run release self-tests and the 100-track live matrix.
- Inspect light and dark menu bars with left, right, and both layouts.
- Confirm only the latest `/Applications/MenuBarLyrics.app` remains installed.

## Deliberate Deferrals

- No new lyric provider without benchmark evidence.
- No custom settings window or color picker.
- No fabricated per-word timing from line-level lyrics.
- A distributable application icon and GitHub release automation belong to the later open-source packaging phase.
