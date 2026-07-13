# Multi-source Lyrics Implementation Plan

**Goal:** Raise multilingual timed-lyrics coverage and reduce first-result delay.

### Task 1: Candidate scoring

- Add a pure `TrackMatcher` for title, artist, duration, and version tags.
- Add regression checks for exact, feat, remaster, multi-artist, substring false
  matches, conflicting versions, duration boundaries, and best-candidate choice.
- Replace NetEase `first(where:)` with highest unambiguous score.

### Task 2: Concurrent sources and cache

- Add lrcmux strict line-level LRC source with a 5-second timeout.
- Run the three sources concurrently and return the first non-empty result.
- Add a 100-entry successful-result memory cache; refresh bypasses it.

### Task 3: Open-source readiness

- Add MIT license and accurate network/privacy/provider documentation.
- Keep the release dependency-free and below 1 MB.

### Task 4: Independent verification

- Run self-tests, production build, signing check, and fixed 20-song matrix.
- Require at least 18/20 hits, P50 below 2.5 seconds, and no known wrong match.
- Install the verified build to `/Applications/MenuBarLyrics.app`.
