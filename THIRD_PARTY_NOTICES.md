# Third-Party Notices

NotchMuse independently implements public network request formats used by
QQ Music and Kugou Music. Protocol investigation and the KRC decoding format
referenced the following project:

- Lyricify Lyrics Helper
  - Copyright 2023 XY Wang, WXRIW
  - https://github.com/WXRIW/Lyricify-Lyrics-Helper
  - Reference commit: 8a847ad1176d3ac46af6cbe310d88cf062450273
  - Licensed under the Apache License 2.0

The Apache License 2.0 text is distributed in `LICENSES/Apache-2.0.txt`.
No binary dependency from that project is included in NotchMuse. Lyrics
and service content remain subject to their respective rights holders and
service terms.

NotchMuse bundles MediaRemote Adapter framework binaries and its Perl bridge
script to read the macOS Now Playing state for supported music players:

- mediaremote-adapter-framework
  - Copyright 2025 Jonas van den Berg and contributors
  - https://github.com/MxIris-LyricsX-Project/mediaremote-adapter-framework
  - Bundled commit: 6bbb7d30f9ddb209a583fa509b9ca145df97f502
  - Licensed under the BSD 3-Clause License

The complete BSD 3-Clause License text is distributed alongside the bundled
framework in `MediaRemoteBridge/LICENSE`. NotchMuse does not copy LyricsX
source code.
