# QQ lyrics and menu bar layout design

## Goal

Improve common-song coverage and make lyrics look native while using both safe
areas around a MacBook notch.

## Lyrics

Add QQ Music as a fourth concurrent source. Use the anonymous desktop search
request and the web line-LRC endpoint documented by the Apache-2.0
`WXRIW/Lyricify-Lyrics-Helper` project. Search title plus artist first, then title
only if no candidate passes the existing strict matcher. Fetch only line-level
Base64 LRC by song MID; do not port QRC decryption or add dependencies.

QQ is experimental and may throttle anonymous requests. A failure must not
affect LRCLIB, NetEase, or lrcmux. README and third-party notices must attribute
the protocol reference and disclose the network destination.

## Display

Use `NSFont.menuBarFont(ofSize: 0)` and dynamic label color. Add Left, Right,
and Both menu choices, defaulting to Both. Use the status item's screen and the
screen's auxiliary top areas instead of fixed coordinates.

Both mode uses two transparent clipped windows as one logical viewport. Long
text continues from the left lane into the right lane without drawing under the
notch. Short text that fits one lane is centered in the wider lane.

Measure text in points and animate at 28 points per second with 0.9-second end
pauses. Reset animation when the lyric changes. The app must not request
Accessibility permission.

## Acceptance

- QQ search and line LRC work for three fixed Chinese popular songs.
- Existing multilingual 20-song matrix does not regress.
- Font visually matches menu bar commands.
- Left, Right, and Both stay inside safe menu bar regions.
- Long text moves smoothly by elapsed time; short text does not move.
- App remains below 1 MB with no third-party binary dependency.
