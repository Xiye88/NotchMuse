# NetEase Candidate Final Closure

**Final decision: GO — FROZEN / READY FOR RELEASE REVIEW**
Run date: 2026-09-25
Workspace: `/Users/carlos/.codex/worktrees/e929/歌词`

## Baseline and installed candidate

- `git fetch` completed. Startup `HEAD` and
  `codex/netease-production-candidate` both resolved to
  `dee834f533812aac3e1dcab83f5d62a008d6a906`. This worktree is detached at that
  commit.
- At kickoff, `/Applications/NotchMuse.app` was version `0.8.0` build `16`,
  arm64, ad-hoc signed with no Team ID. Executable SHA-256:
  `16606dd8756c0b33f5a173dc9a2d6a5b15aea0d46a72327f2e5359b18ea0ea38`. Its
  source Git SHA could not be recovered from the installed executable.
- Build `17` was installed and used for initial runtime checks, then replaced
  with build `18` after the seek refresh change. Build 16 and 17 bundles remain
  recoverable in `dist.noindex/local-backups/`.
- Current installed candidate: `0.8.0` build `18`; its code tree is recorded by
  Candidate Freeze commit `3fb6946602dd35308d201fe7d5e609e63ebcb42e`,
  whose audited parent baseline is
  `dee834f533812aac3e1dcab83f5d62a008d6a906`. The executable does not embed a
  Git revision. Executable SHA-256:
  `4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`.
- Candidate DMG: `dist.noindex/NotchMuse.dmg`; SHA-256:
  `4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`.
  App is arm64 and ad-hoc signed, no Team ID.

## Gate results

| Gate | Result | Evidence / remaining work |
| --- | --- | --- |
| Installed App identity | PASS | Build 18 version/build, executable hash, arm64 architecture, signature type, Team ID absence, and Candidate Freeze commit recorded above. |
| NetEase playback chain | PASS | Build 17 runtime evidence is historical. Product Owner confirms build 18 forward/back seek and final current/restart lyric GUI checks PASS. No latency value or step-level GUI details were supplied. |
| Auto Detect matrix | PASS | Product Owner confirms build 18 Auto Detect combinations, ownership/fallback behavior, and stale clearing PASS. No per-combination details were supplied. |
| Restart and helpers | PASS | Build 18 simultaneous restart recovered; exactly one app/watchdog/Perl stream remained. Product Owner confirms post-restart current lyrics GUI PASS. |
| Sleep/Wake and network recovery | PASS | Product Owner final GUI confirmation: PASS. Step-level details and elapsed times were not supplied. |
| Custom Color and Hide on Hover | PASS | Product Owner final GUI confirmation covers Notch Mode, custom color persistence, and Hide on Hover. No additional details supplied. |
| Debug/Release and package checks | PASS | Debug self-test and Release self-test pass. `git diff --check`, en/zh-Hans exact key parity (102 each), `codesign --verify --deep --strict`, and `hdiutil verify` pass. |
| 60-minute soak | PASS | Valid continuous-playback soak ran 2026-09-25 20:46:21–21:46:24 CST; `playing=true` at start, 15/30/60-minute checkpoints, and intervening bridge spot checks. Full samples: `/tmp/notchmuse-build18-soak.log`. At 60m: one app (PID 43342, 6.8% CPU / 38,928 KB RSS), one watchdog (PID 43357, 0.1% / 1,728 KB), one Perl stream (PID 43358, 0.0% / 19,008 KB). NetEase owner `com.netease.163music`, `被你改变的那部分我` / 梁森田, native ID `9DC79DE3-1328-429C-855C-4A01CC4F816E`, playing. No candidate crash, restart, helper loss, or orphan. Multiple natural track changes and advancing bridge position estimates were observed. The soak evaluated playback/helper stability; lyric and stale-render behavior was separately covered by the Product Owner GUI PASS. The paused 20:40 pre-sample is invalid and retained separately at `/tmp/notchmuse-build18-soak-paused-presample.log`. |

## Seek latency investigation

The owner measured approximately three seconds between dragging NetEase's seek
bar and lyric resynchronization on build 17, with correct final lyrics and no
stale text. The Product Owner confirms build 18 forward and backward seek passed
without a precise latency measurement; it is Manual PASS with no numeric claim.

Code flow: `MenuBarController` polls snapshots every second.
`NetEaseMusicAdapter` only runs a one-shot bridge position refresh once two
seconds have elapsed since its previous refresh. Same-track playback updates
are committed immediately by `NetEaseEventConverger`; the 300ms quiet interval
is for new track identity convergence and does not delay a same-track seek.
After the adapter returns the updated position, `MenuBarController` recalculates
the current line with `LyricClock` and does not fetch lyrics again because the
track identity is unchanged. The measured three seconds is consistent with the
two-second refresh threshold plus poll alignment and bridge response time.

Measured one-shot `get` process cost:

- 20 calls: median 23.4ms, P95 28.8ms, child CPU 0.320s.
- 30 calls: median 19.6ms, P95 30.2ms, child CPU 0.429s.
- At one refresh per second: 60 bridge `get` calls/minute and approximately
  0.86 CPU seconds/minute based on those samples. The persistent watchdog and
  stream helper count remains unchanged.

15-minute sample (21:01:24 CST): NotchMuse PID 43342 at 5.8% CPU / 36,464 KB RSS; watchdog PID 43357 at 0.0% / 1,712 KB; Perl stream PID 43358 at 0.0% / 19,200 KB. Exactly one of each. NetEase owner `com.netease.163music`, `Lonely` / Nana, native ID `224190D7-032E-4220-9E87-3196544CC388`, playing. No candidate crash, helper loss/orphan, or restart observed through this sample; event updates have shown multiple natural song changes. Lyrics/stale remain visually unverified.

30-minute sample (21:16:24 CST): NotchMuse PID 43342 at 5.5% CPU / 42,864 KB RSS; watchdog PID 43357 at 0.0% / 1,728 KB; Perl stream PID 43358 at 0.0% / 19,104 KB. Exactly one of each. NetEase owner `com.netease.163music`, `呼吸有害` / 邓智伟, native ID `DBE02D7B-B22F-46A1-9D9B-92BECB5F0A05`, playing. No crash, helper loss/orphan, or restart observed. Bridge has returned multiple natural track updates during the active soak. Lyrics/stale remain visually unverified.

60-minute sample (21:46:24 CST): NotchMuse PID 43342 at 6.8% CPU / 38,928 KB RSS; watchdog PID 43357 at 0.1% / 1,728 KB; Perl stream PID 43358 at 0.0% / 19,008 KB. Exactly one of each; no crash, restart, helper loss, or orphan across the valid hour. NetEase owner `com.netease.163music`, `被你改变的那部分我` / 梁森田, native ID `9DC79DE3-1328-429C-855C-4A01CC4F816E`, playing. Multiple natural song changes and advancing `elapsedTimeNow` estimates observed. Lyrics/stale rendering were not observed during this background soak; the separate final GUI gate is PASS.

The regression test was first run against the original two-second interval and
failed on the new one-second refresh assertion. It also covers a large position
jump selecting the new lyric line, preserving track identity, and avoiding a
repeat lyric request. The implementation changes only the existing refresh
interval from two seconds to one second. Debug and Release self-tests pass on
build 18. The Product Owner's build 18 forward/back seek manual gate is PASS. A numeric
latency measurement remains unavailable.

## Final decision

**GO — FROZEN / READY FOR RELEASE REVIEW.** Build `0.8.0` build `18` is arm64
and ad-hoc signed with no Team ID. Executable SHA-256:
`4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`. DMG
SHA-256: `4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`.
`codesign --verify --deep --strict` and `hdiutil verify` pass. Known release
risks: ad-hoc signing/Gatekeeper rejection, no Developer ID/notarization/
stapling, and no clean-new-user distribution assessment. Public release is not
authorized by this freeze. No merge, push, tag, or release was performed.

## Candidate Freeze SHA

`3fb6946602dd35308d201fe7d5e609e63ebcb42e`
