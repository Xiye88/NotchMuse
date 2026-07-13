# Multi-source lyrics design

## Goal

Show synced lyrics quickly and accurately for as many Spotify tracks as
possible while keeping the native macOS app dependency-free and below 1 MB.

## Baseline

The current LRCLIB -> NetEase chain matched 17 of 20 representative Chinese,
English, Japanese, and Korean tracks. Median first result was about 4 seconds.
Failures were caused by title/artist aliases and version ambiguity.

## Design

1. Replace first-match substring logic with a pure Swift score using normalized
   title, artist set, duration, and version tags. Reject ambiguous or conflicting
   live/remix/acoustic/instrumental versions.
2. Query LRCLIB, NetEase, and lrcmux concurrently. Return the first non-empty,
   parsed result. Each request has a short timeout and no retries.
3. Cache up to 100 successful results in memory for the process lifetime. Do not
   cache failures or write song metadata to disk.
4. Keep all code on Foundation/AppKit with no third-party packages. Document
   every network destination and mark non-official providers as experimental.

## Acceptance

- At least 18/20 timed-lyric hits on the fixed multilingual matrix.
- Median first result below 2.5 seconds on the test network.
- No known wrong-version or substring false match in matcher regression cases.
- App bundle remains below 1 MB with zero third-party dependencies.
