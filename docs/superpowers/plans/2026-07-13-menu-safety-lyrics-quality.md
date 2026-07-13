# Menu Safety and Lyrics Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MenuBarLyrics collision-safe and easy to click, quantify lyric quality, and add the approved dark-orange gradient progress effect.

**Architecture:** Keep the native AppKit executable and existing source chain. Replace the floating settings panel with the existing `NSStatusItem`, pass an Accessibility-derived menu boundary into the existing lane geometry, and extend the existing lyric clock/overlay path with line progress. Keep the online matrix opt-in and the false-match checks offline.

**Tech Stack:** Swift 6, AppKit, ApplicationServices Accessibility API, Foundation, existing assert-style self-tests and shell scripts.

## Global Constraints

- Use the gradient `#E87924` -> `#C85A12` -> `#963A08` for both the music-note logo and active lyric progress.
- Keep lyric windows click-through and keep right-only mode free of Accessibility prompts.
- Add no dependency and no new lyric provider.
- Do not fabricate word timing from line-level LRC.
- Keep the latest app at `/Applications/MenuBarLyrics.app` and remove build copies after installation.

---

### Task 1: Native Status Item and Collision-Safe Left Lane

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/BrandStyle.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarSafety.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/OverlayLyricsWindow.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Produces: `BrandStyle.noteImage() -> NSImage`
- Produces: `MenuBarSafety.requestAccess()` and `MenuBarSafety.foregroundMenuMaxX() -> CGFloat?`
- Changes: `OverlayLaneGeometry.frames(..., foregroundMenuMaxX: CGFloat?)`

- [ ] **Step 1: Add failing geometry checks**

Add checks proving a foreground menu boundary moves `frames.left.minX` to at least eight points after the boundary, a boundary beyond the left safe area produces a zero-width left lane, and the right lane no longer reserves 24 points for the deleted floating button.

- [ ] **Step 2: Run the self-test and verify RED**

Run: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`

Expected: compile failure because `foregroundMenuMaxX` is not accepted yet, or a failed left-boundary check.

- [ ] **Step 3: Implement the minimum native layout change**

Implement `MenuBarSafety` with `AXIsProcessTrustedWithOptions` for an explicit prompt and `AXUIElementCopyAttributeValue` for the foreground application's menu-bar children. Return the largest visible menu-item `maxX`, or `nil` on any denied/missing Accessibility value.

Update geometry so the left boundary is:

```swift
let menuBoundary = max(conservativeMenuBoundary, foregroundMenuMaxX ?? conservativeMenuBoundary)
let leftMinX = min(leftArea.maxX, max(leftArea.minX, menuBoundary + inset))
```

Delete the overlay settings panel and its 24-point reservation. Use the existing `NSStatusItem` as the sole menu target. Prompt for Accessibility only when the active position is `.left` or `.both`.

Create the note image by drawing the three-stop `NSGradient`, masking it with the `music.note` SF Symbol, and setting `isTemplate = false`.

- [ ] **Step 4: Run self-tests and verify GREEN**

Run: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`

Expected: `Self-tests passed`.

- [ ] **Step 5: Commit**

```bash
git add MenuBarLyrics/Sources/MenuBarLyrics/{BrandStyle.swift,MenuBarSafety.swift,MenuBarController.swift,OverlayLyricsWindow.swift,SelfTests.swift}
git commit -m "fix: avoid menu collisions and use native status icon"
```

### Task 2: Smooth Gradient Lyric Progress

**Files:**
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/LyricClock.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/OverlayLyricsWindow.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Produces: `LyricMoment { text: String, progress: CGFloat }`
- Produces: `LyricClock.moment(at:in:) -> LyricMoment?`
- Changes: `OverlayLyricsWindow.show(text:progress:position:statusItem:scroll:)`

- [ ] **Step 1: Add failing lyric-progress checks**

For lines at 1, 3, and 7 seconds, assert no moment at 0.5, progress `0` at 1, progress `0.5` at 2, progress `0` at 3, and clamped progress `1` for the final line. Retain existing current-line checks.

- [ ] **Step 2: Run the self-test and verify RED**

Run: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`

Expected: compile failure because `LyricMoment` and `moment` do not exist.

- [ ] **Step 3: Implement lyric moment calculation**

Use the existing binary search once to locate the active index. Calculate progress as:

```swift
let progress = index + 1 < lines.count
    ? max(0, min(1, (position - line.time) / (lines[index + 1].time - line.time)))
    : 1
```

Keep `currentLine` as a compatibility wrapper around `moment`.

- [ ] **Step 4: Draw and animate the gradient**

Replace the lane's plain label with one small custom `NSView` that draws the normal label text, clips to `textWidth * progress`, then masks the shared three-stop gradient through the same glyphs. Preserve the existing line height, horizontal scrolling, clipping, and click-through windows.

In `MenuBarController`, retain the latest Spotify position and uptime. While playing, extrapolate the position between one-second Spotify polls and refresh at 30 Hz. Freeze the stored position while paused and stop the animation timer when Spotify is closed, unavailable, paused, or has no synchronized lyrics.

- [ ] **Step 5: Run self-tests and verify GREEN**

Run: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`

Expected: `Self-tests passed`.

- [ ] **Step 6: Commit**

```bash
git add MenuBarLyrics/Sources/MenuBarLyrics/{LyricClock.swift,MenuBarController.swift,OverlayLyricsWindow.swift,SelfTests.swift}
git commit -m "feat: animate lyric progress with orange gradient"
```

### Task 3: Measurable Lyrics Quality Matrix

**Files:**
- Create: `scripts/fixtures/live_tracks.tsv`
- Modify: `scripts/live_matrix.swift`
- Modify: `scripts/run_live_matrix.sh`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Consumes: the four existing lyrics source `syncedLyrics(for:)` methods.
- Produces: `/tmp/menubarlyrics-live-matrix.tsv` with `title`, `artist`, `source`, `line_count`, and `latency_ms` columns.

- [ ] **Step 1: Extend offline false-match fixtures**

Add deterministic rejects for same-title covers, mismatched Live/studio versions, duration outside 12 seconds, and unsafe Traditional/Simplified substitutions. Add accepted fixtures for the explicit `薛之謙`/`薛之谦` artist alias and existing valid multilingual tracks.

- [ ] **Step 2: Verify the fixture checks pass**

Run: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`

Expected: `Self-tests passed`.

- [ ] **Step 3: Add the 100-track dataset and report**

Store exactly 100 tab-separated representative tracks with title, artist, album, and duration. Parse the file with Foundation, run at most five tracks concurrently, and keep all four providers concurrent within each track. Record the first validated non-empty result and print coverage, source counts, median latency, and p95 latency.

The script must exit non-zero below 90 hits and leave the complete TSV report in `/tmp/menubarlyrics-live-matrix.tsv`.

- [ ] **Step 4: Run the live matrix**

Run: `./scripts/run_live_matrix.sh`

Expected: a 100-row report and either `Live matrix passed: N/100 songs matched` with `N >= 90`, or an evidence-backed failure that names every miss. Do not weaken matching to make the threshold pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/fixtures/live_tracks.tsv scripts/live_matrix.swift scripts/run_live_matrix.sh MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift
git commit -m "test: measure lyrics coverage across 100 tracks"
```

### Task 4: Documentation, Installation, and Final Verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: one signed app at `/Applications/MenuBarLyrics.app`.

- [ ] **Step 1: Update user-facing documentation**

Document the native orange status item, automatic left-menu avoidance and its optional Accessibility permission, line-level gradient semantics, the live quality command, and the fact that exact word animation requires word-timed lyrics.

- [ ] **Step 2: Build and self-test the release app**

Run: `./scripts/build_app.sh`

Expected: release build succeeds, `Self-tests passed`, and `dist/MenuBarLyrics.app` is ad-hoc signed.

- [ ] **Step 3: Replace the installed app and remove build copies**

Quit the existing process, replace `/Applications/MenuBarLyrics.app` with `dist/MenuBarLyrics.app`, launch it, then delete `dist/MenuBarLyrics.app`.

- [ ] **Step 4: Verify installation and runtime**

Run release self-tests again, `codesign --verify --deep --strict /Applications/MenuBarLyrics.app`, confirm one running installed process, confirm exactly one `MenuBarLyrics.app` under `/Applications` and the repository, and run `git diff --check`.

- [ ] **Step 5: Visual verification**

Verify right-only mode without an Accessibility prompt, native icon clickability near the input-method item, left/both collision behavior with a wide-menu foreground application, centered text, scrolling, and gradient progress on light and dark menu bars.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: explain menu safety and lyric quality checks"
```
