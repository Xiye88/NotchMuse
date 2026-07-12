# Lyrics Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fall back to synced NetEase lyrics when LRCLIB has none.

**Architecture:** Keep `LyricsClient` as the single entry point. Add one native URLSession-backed NetEase source and deterministic candidate matching; no dependencies or server.

**Tech Stack:** Swift, Foundation, URLSession, existing self-test runner.

## Global Constraints

- Reject mismatched titles/artists and candidates over 12 seconds from Spotify duration.
- Do not add QQ Music until it has a stable authorized API.

---

### Task 1: NetEase fallback

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/NetEaseLyricsSource.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/LyricsClient.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Consumes: `SpotifyTrack`, `LyricLine`, `LyricParser.parse(_:)`
- Produces: `NetEaseLyricsSource.syncedLyrics(for:) async throws -> [LyricLine]`

- [ ] **Step 1: Write the failing self-test**

Add assertions that exact title/artist/duration candidates match, wrong artists fail, and a candidate 13 seconds away fails.

- [ ] **Step 2: Verify RED**

Run `swift run MenuBarLyrics --self-test`; expect compilation failure because `NetEaseLyricsSource` does not exist.

- [ ] **Step 3: Implement minimal source and fallback**

POST title and artist to `https://music.163.com/api/search/get/web`, decode the first valid candidate, GET `https://music.163.com/api/song/lyric?id=<id>&lv=-1`, parse `lrc.lyric`, and call it only when LRCLIB fails or returns no lines.

- [ ] **Step 4: Verify GREEN and live behavior**

Run `swift run MenuBarLyrics --self-test`, then request `成都` by `赵雷`; expect non-empty timed lines.

- [ ] **Step 5: Build and install**

Run `./scripts/build_app.sh`, replace `/Applications/MenuBarLyrics.app`, launch it, and verify the process remains running.
