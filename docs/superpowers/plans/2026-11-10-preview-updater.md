# Preview startup and automatic updates — Implementation Plan

**Goal:** Implement owner-authorized local Preview updater features without public release changes.
**Architecture:** Reuse Sparkle2.10 background checks, signing, download/install and daily scheduler. Add only startup background check, explicit automatic-install policy and two user settings. Preview uses a signed loopback-only feed and Preview identity; never the public Stable feed.
**Tech Stack:** Swift6/AppKit, existing Sparkle2.10, shell packaging; no new dependencies.
**Authorization:** Owner explicitly requests direct implementation, default-enabled automatic updating, quiet no-update checks and periodic checking while app remains running. No new public release or source push authorized this turn.

## Decisions and constraints
- Startup: automatic/background check every actual process launch if automatic checking is enabled, regardless of last scheduled check. No “latest” or network-error modal for these checks. Manual Check for Updates retains its current feedback.
- Schedule: daily (86400 seconds), selected by PM for timely fixes. Reuse Sparkle's timer, no duplicate custom poller; handle busy sessions without concurrent checks. Sleep/wake must recover on the next due cycle.
- Separate automatic-download/install switch, default on for an unset preference, persist and respect explicit off. Automatic checks remain independently configurable; explain that downloads need checks. No runtime setter that re-enables a user's disabled preference each launch.
- Automatic mode must apply verified updates, not merely download and wait indefinitely; inspect Sparkle immediate install delegate. Show only useful new-update UI and preserve a usable old app on failures. Record restart behavior clearly.
- Keep Preview bundle ID app.notchmuse.mac.preview, use loopback only, never download a Stable app into Preview. Stable /Applications app and public feed/assets/site remain untouched. Build number must exceed70; candidate build71 unless lifecycle tool allocates higher.
- UI EN/ZH labels and explanatory copy, no lyric-system changes.

## Tasks
1. Add failing behavior checks for startup quiet/background path, first-run defaults, explicit-off persistence, periodic scheduling/configuration, busy-cycle handling and preview source isolation; use existing standalone Swift test pattern where XCTest unavailable. Observe RED before implementation.
2. Modify UpdateController and only necessary helper/policy, SettingsWindowController, localized resources and build_app plist. GREEN behavioral tests and existing update feedback tests; full swift test attempted and limitation recorded if CLT lacks XCTest.
3. Build local Preview candidate with loopback feed. Test fresh defaults and persistence; actual no-update startup and unreachable feed produce no dialog; newer signed Preview fixture triggers discovery and automatic install/relaunch with identical payload; corrupted payload rejected; auto-off retains new-update notice and manual flow. Compress clock for schedule tests through pure policy or harness, never production rapid polling. Restore any user preference test changes.
4. Independent code review, resolve material findings, build/install regular local Preview with lifecycle rollback and stable hash protection; UI verify, canonical handoff and evidence. No GitHub push/tag/public feed or website publication.

## Review focus
Startup plus built-in scheduler must not duplicate checks; preference changes during download must be respected; no-update/background error must remain quiet while manual feedback remains useful; default-on cannot overwrite explicit false; automatic installation/relaunch and Preview identity must be actual verified behaviors.

## Execution ledger
- Planning: current baseline505ba48, pre-existing local docs are the owner's notes rule/backlog and must be preserved.
