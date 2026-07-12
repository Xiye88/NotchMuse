# Lyrics fallback design

## Goal

When LRCLIB has no synced lyrics for the current Spotify track, automatically
fall back to NetEase Cloud Music without changing playback.

## Design

`LyricsClient` queries LRCLIB first. If it returns no timed lines or fails, it
searches NetEase using the Spotify title and artist, selects the closest result
by normalized title, artist, and duration, then fetches that song's LRC. A
candidate more than 12 seconds away or with mismatched title/artist is rejected
to avoid showing lyrics for the wrong recording.

QQ Music is excluded because its current unauthenticated search endpoint did
not return usable data and newer endpoints depend on private signing or login
state. It can be added later as another fallback if a stable authorized API is
available.

## Verification

Self-tests cover candidate matching and fallback behavior. A live request for a
known Chinese song verifies that NetEase search and LRC retrieval still work.
