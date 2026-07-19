# NotchMuse Task Board

Last Updated: 2026-07-18

## TODO

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Developer ID signed build | Release | P0 | Required for public beta |
| Apple notarization and stapling | Release | P0 | Required before Gatekeeper verification |
| Clean install QA from final DMG | Release QA | P0 | Use clean user/test machine |
| Gatekeeper verification | Release QA | P0 | Run after notarization |
| Capture Status Bar screenshot | GitHub Release | P1 | README/GitHub asset |
| Capture Notch Mode screenshot | GitHub Release | P1 | README/GitHub asset |
| Capture Settings screenshot | GitHub Release | P1 | README/GitHub asset |
| Prepare GitHub Release notes | GitHub Release | P1 | Based on `CHANGELOG.md` |
| Import latest VPS Benchmark report | Benchmark | P1 | Save under `reports/benchmark/` |

## IN PROGRESS

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Phase 1 Beta Release Freeze | PM | P0 | No new features |
| Project Control System setup | PM | P0 | Initial files created |

## BLOCKED

| Task | Owner | Priority | Blocker |
| --- | --- | --- | --- |
| Public GitHub Beta Release | PM/Release | P0 | Developer ID signing and notarization not complete |
| Final clean first-launch approval | Release QA | P0 | Requires final signed/notarized DMG |

## DONE

| Task | Owner | Priority | Result |
| --- | --- | --- | --- |
| Release Candidate QA audit | Release QA | P0 | Functionally close; blocked by signing/notarization |
| GitHub release package audit | GitHub Release | P1 | Docs mostly ready; screenshots/GIFs missing |
| Matcher architecture review | Matcher | P1 | Phase 2 roadmap defined; no Phase 1 app changes |
| Create reports directory structure | PM | P0 | `reports/release`, `ux`, `benchmark`, `matcher`, `github` |
