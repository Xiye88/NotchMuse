# Native player lyrics feasibility

Status: **DEFERRED** for v0.8.0. This is a documentation-only probe, not an implemented fallback.

## Scope and evidence

The question is whether NotchMuse can reuse lyrics already held or displayed by the *currently playing desktop app* after all existing lyrics providers return no result. This review used only repository source and public vendor/platform documentation. It did not inspect installed player apps or caches, query accessibility trees, capture traffic, use credentials, or modify production code. Thus absence of an API below means **not established by this probe**, not proof that no such interface exists.

In the current code, `LyricsClient.swift` queries LRCLIB, NetEase, LRCMux, QQ, Kugou, and Soda sources and accepts the first nonempty result. `SpotifyReader.swift` and `AppleMusicAdapter.swift` read track/playback metadata with AppleScript. `MediaRemoteBridge.swift` / `MediaRemotePlayerAdapter.swift` supply metadata for NetEase, QQ, and Soda; `MediaRemoteEvent` has no lyric field. The similarly named `*LyricsSource.swift` files are network provider lookups, not reads from the corresponding desktop player's lyric display. A native fallback must come **after** every existing source returns empty, without changing provider priority or treating a network failure as a confirmed no-match.

## Player assessment

| Player | Evidence | Result |
| --- | --- | --- |
| NetEase Cloud Music | The local adapter receives MediaRemote title, artist, album, duration, position, and identifiers, but no lyric text. No supported desktop-player lyric IPC or stable cache contract was established from official documentation. | Deferred; a player cache or private endpoint would need separate stability and permission evidence. |
| QQ Music | Same metadata-only MediaRemote route. [Tencent's documented `describeLyric` method](https://cloud.tencent.com/document/product/1081/67456) belongs to its IoT H5 SDK and, except for designated unauthenticated methods, requires QQ Music authorization. It is not a local desktop-player interface. | Deferred; do not repurpose an IoT integration or collect account credentials. |
| Soda Music | Same metadata-only MediaRemote route. No documented desktop-player lyric IPC or cache contract was established. | Deferred. |
| Apple Music | The adapter's AppleScript reads current-track metadata and persistent ID, not lyrics. [MusicKit's `Song.hasLyrics`](https://developer.apple.com/documentation/musickit/song/haslyrics) indicates availability, not lyric content; [MusicKit](https://developer.apple.com/documentation/musickit) requires authorization for music data and documents catalog/playback integration rather than a feed of the Music app's displayed timed lyrics. | Deferred; local-library lyric metadata, if available for particular files, would not establish a general synced-lyrics fallback for streamed tracks. |
| Spotify | The adapter reads playback metadata via AppleScript. The [Spotify track API](https://developer.spotify.com/documentation/web-api/reference/get-track) documents `has_lyrics` as an availability flag, not lyric text; the [Web API](https://developer.spotify.com/documentation/web-api) requires authorization and is not a local player lyric interface. | Deferred. |

macOS [Accessibility attributes](https://developer.apple.com/documentation/applicationservices/carbon_accessibility/attributes) can expose values where an app supplies them, but that says nothing about the five players' lyric trees, timestamps, offscreen text, or stability. Because this probe explicitly excludes UI scraping and did not inspect those trees, Accessibility is **unverified**, not an approved route.

## Decision and revisit criteria

No reviewed route demonstrates a stable, simple, authorized way to obtain the active player's synchronized lyrics. Native lyrics must not block v0.8.0. Keep the existing provider chain unchanged and show the existing no-lyrics state when it has no match.

Revisit only if a player publishes a usable lyric interface or an explicitly permitted, stable local contract is demonstrated with representative tracks and player versions. Before implementation, verify timing/translation format, track identity, permission and redistribution terms, behavior when the player has no lyrics, and how the fallback is invoked **only after** all current providers have no result. Stop again if the route requires TLS MITM, certificate bypass, app injection, DRM bypass, token/cookie capture, extensive binary reverse engineering, or a brittle private protocol.
