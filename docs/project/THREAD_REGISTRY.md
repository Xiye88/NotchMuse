# NotchMuse Thread Registry

Last reviewed: 2026-10-17. [Historical registry](../archive/THREAD_REGISTRY-through-v0.8.0.md) preserves old workspace IDs and checkpoints.

| Workspace | State | Current meaning |
| --- | --- | --- |
| `00_PM` | ACTIVE | Current PM `01a104b8-1eb0-7320-8706-29eece12ab9f` adopted the master handoff and completed authorized Media Showcase push/merge/deploy closure. Former PM `019f741e-4308-7360-82f8-4e5c0d1c9224` is ready for archival. |
| `01_APP` | DONE | Accepted Build 47 runtime frozen. |
| `02_RELEASE` | DONE | Release, feed, website, and Stable installation verified. |
| `03_LAB` | DONE | Evidence retained; no long-running test task. |
| `04_UX` | DONE | Current website visuals accepted by Product Owner; media/settings gallery refreshed. |
| `05_MATCHER` | DONE | Production matching and provider priority frozen. |
| `06_DOCS` | DONE | Round 2 `8f4fb37` on feature/main; EN/ZH public media verified; production `20261004-media-8f4fb37` deployed. Round 1 execution chat `01a10527-c5ab-7070-9b96-015eaa91bfdf`; current PM closed the task without duplicate workspaces. |
| `07_QA` | DONE | Feature/promoted main CI PASS; public README media, website bytes, real Hero playback and unchanged official feed verified. |

Menu Bar Space: `origin/codex/menu-bar-space` at `62b47067a601fb48a6292efdfcee10e8c92d4036`; experimental, paused, archived, not merged or released. Reuse numbered workspaces; do not create duplicate PM threads.

## Website publication — 2026-10-17

Responsibility `06_DOCS`, existing SEO chat `01a116ce-e921-70c3-ad28-40baf9e371ed`: **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**. Authorized source `983729a4c9e69a748c5772dcdbefc772b2f582c1` was pushed directly atop main; source CI PASS. Five distinct topics in English and Chinese (10 new URLs), home guide cards and12 sitemap URLs are live in `/opt/notchmuse-site/releases/20261017-seo-983729a`. All44 origin files match; public pages on apex/www match source. Three video transfer timeouts passed complete-hash rechecks. Local preview remains open; in-app public navigation failed with a connection error and is not counted as visual verification. Official appcast/notes preserved byte-for-byte; public App remains v0.8.0 Build47. No confirmation remains for this task. [Closure and evidence](../reports/website/seo-pages-production-2026-10-17.md).
