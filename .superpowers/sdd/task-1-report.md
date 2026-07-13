Status: DONE_WITH_CONCERNS
Commit: a4372c95ccef8bd5c270e7d985e4dd228be6d6ae

Changed files:
- MenuBarLyrics/Sources/MenuBarLyrics/BrandStyle.swift
- MenuBarLyrics/Sources/MenuBarLyrics/MenuBarSafety.swift
- MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift
- MenuBarLyrics/Sources/MenuBarLyrics/OverlayLyricsWindow.swift
- MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift

RED verification:
- Applied only the new Task 1 checks to parent commit 6394a9d in a detached temporary worktree.
- Command: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`
- Result: exit 1; compile failed because `foregroundMenuMaxX` was not yet accepted.

GREEN verification:
- Command: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`
- Result: exit 0; `Self-tests passed`.

Concerns found during controller review:
- `BrandStyle` uses system pink/orange/yellow instead of the approved exact orange stops.
- Accessibility children that do not expose `AXHidden` currently abort the whole lookup instead of being treated conservatively as visible.

Task 1 Important fixes:

RED verification:
- Added self-tests for the exact brand RGB stops and AXHidden visibility policy.
- Command: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`
- Result: exit 1; compile failed because `BrandStyle.gradientColors` and `MenuBarSafety.isExplicitlyHidden` were not yet implemented.

GREEN verification:
- Command: `cd MenuBarLyrics && swift run MenuBarLyrics --self-test`
- Result: exit 0; `Self-tests passed`.

Commit:
- `git commit -m "fix: address Task 1 important review issues"`
