# QQ Lyrics and Layout Implementation Plan

### Task 1: QQ line lyrics

- Add `QQMusicLyricsSource` with anonymous search, strict candidate scoring,
  progressive query fallback, JSONP unwrap, Base64 decode, and LRC parsing.
- Add it to the existing concurrent sources and cache path.
- Add attribution and network disclosure.
- Verify three popular Chinese songs and the existing matrix.

### Task 2: Native two-lane overlay

- Replace fixed overlay geometry with safe left/right frames from the status
  item's screen.
- Add Left, Right, Both menu modes; default Both.
- Use system menu font and dynamic color.
- Replace character stepping with elapsed-time pixel scrolling.

### Task 3: Independent release QA

- Review each task separately.
- Run self-tests, TSan, live source tests, fixed song matrix, and screenshots.
- Verify all layout modes, safe-area containment, smooth movement, package size,
  signature, and launch survival before installing the final app.
