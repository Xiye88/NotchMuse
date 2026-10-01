# Menu Bar Space Handoff

Status: **EXPERIMENTAL / PAUSED** (2026-10-01)

- Branch: `codex/menu-bar-space`. This branch is a remote source backup, not a release candidate approval. Do not merge into `main`, tag, or publish v0.9.
- Scope saved: three horizontal Visible / Hidden / Always Hidden icon strips with hover names and drag/drop; menu bar item movement, reveal behavior, reset, icon selection, and saved zones. No player, Matcher, or Provider Priority changes were made for this work.
- Local evidence: a trusted GUI probe moved real menu bar items between all three zones. Short two-item probes checked Hidden reveal, Always Hidden isolation, return to Visible, reset, and restart persistence. Debug/full self-tests, Release/packaged self-test, signature verification, and `git diff --check` passed before pause. No long soak test was run.
- Installed artifact: `/Applications/NotchMuse Menu Bar Space Candidate.app`, version `0.9.0-menu-bar-space-candidate`, build 39, executable SHA-256 `19e4279cbded8f32c905060a204792044ce6f45c3f23a8709e8b68adfc41ec0f`. This ad-hoc build is **not READY**. Build 38 was backed up under `dist.noindex/menu-bar-space-final/installed-build38-backup.app` in this worktree.
- Open blocker: installed build 39 did not create its three space controls, despite the Accessibility switch appearing on. Two launches produced only the ordinary status item. The installed app has not passed its own GUI drag or lyrics-space acceptance. There is no valid local code-signing identity; the ad-hoc permission entry may need to be re-added for the exact installed build. This remains an unconfirmed diagnosis.
- Resume only on a new Product Owner instruction. First resolve the installed build's effective Accessibility authorization, then run a short installed GUI and lyrics-space check. Review macOS 14/15 behavior before calling the feature ready. Preserve this branch and worktree until the remote backup is verified.
