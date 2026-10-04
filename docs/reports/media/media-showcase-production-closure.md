# Media Showcase — Production Closure

2026-10-04, Asia/Shanghai. **ACCEPTED / MERGED / DEPLOYED / VERIFIED**.

## Authorization and source

Product Owner accepted the current website visuals and explicitly requested
push, final preflight, main merge/push, production deployment and public checks.
No media was regenerated and no page design was changed in this closure.
Current footage lacks a physical display cutout; the real Settings preview and
top/Dock positions remain as accepted. The prior pause-control P2 is deferred
under acceptance of this version, not represented as fixed.

- Media source: `8f4fb378e54c658246757a336810394d332efbd3`.
- Feature branch: `codex/media-showcase-refresh`, pushed to that source.
- Main: fast-forward merged from `84bb0c18d79e6d5e7c0ae2964d64479b13371bac`
  to the same source and pushed; no force push or conflict resolution.
- [Feature CI](https://github.com/Xiye88/NotchMuse/actions/runs/37180680782): PASS.
- [Promoted main CI](https://github.com/Xiye88/NotchMuse/actions/runs/37180798209): PASS.
- Final documentation closure is a subsequent main commit; website bytes remain
  identical to the deployed source. Resolve its SHA through Git history.

## Final preflight and GitHub verification

- Patch whitespace, language behavior/translation parity and showcase JS syntax:
  PASS. Prior framing/media/browser evidence remains in [Round 2](media-framing-fix-round2.md).
- App tree, CI/build scripts and CHANGELOG unchanged from prior main; website
  v0.8.0 download URLs unchanged. No App release, version bump, DMG/feed change.
- Both feature and public main EN/ZH READMEs were actually opened in the in-app
  browser. Display Settings disclosures expanded; all six classes below loaded
  with nonzero natural dimensions. Raw public bytes matched local main exactly.

| Asset | Repository path | Result |
| --- | --- | --- |
| Hero poster | `website/assets/media/notch-poster.webp` | PASS, 1280×720 |
| Status Bar GIF | `docs/assets/demos/github/status-bar-demo.gif` | PASS, 960×540 |
| Notch GIF | `docs/assets/demos/github/notch-demo.gif` | PASS, 960×540 |
| Appearance GIF | `docs/assets/demos/github/appearance-demo.gif` | PASS, 960×540 |
| Appearance Settings | `docs/assets/screenshots/appearance-settings.png` | PASS, 1040×762 |
| Display Settings | `docs/assets/screenshots/display-settings.png` | PASS, 1040×762 |

## Production deployment and verification

Hosting is the existing VPS Python static service `notchmuse-site.service`
behind Cloudflare Tunnel `notchmuse-cloudflared.service`; main push does not
automatically deploy the website. Deployment used exact `git archive` bytes
from the promoted main source, with only HTML/CSS/JS/assets staged.

- Active directory: `/opt/notchmuse-site/releases/20261004-media-8f4fb37`.
- Previous directory `/opt/notchmuse-site/releases/20261004-v080` retained.
- Server configuration backup: `/opt/notchmuse-site/site_server.before-media-8f4fb37.py`.
- Archive SHA-256: `ca1834d9d254697c8e4516b0618aeb74b0b97a1a64b1cadbbd65322fe94ddf02`.
- Both origin services active; origin HTML, feed and notes verified after restart.
- Public apex/www HTML, CSS, showcase JS, six videos and three WebP posters:
  HTTPS success and byte-for-byte identical to main.
- In-app browser at https://notchmuse.com/ verified Status Bar and Notch Hero
  videos actively playing at 1280×720, with full desktop/Dock context, plus
  English/Chinese switching and unchanged v0.8.0 download destination.
- Official appcast SHA-256 unchanged:
  `750fda31ab87c78fe41b494b5119e0343c3413bc8e16b2df74f6127179b44580`.
- Published `NotchMuse.md` SHA-256 unchanged:
  `770f3a527c1c85fb45c80faa5a16a9657a9270883c4a86df1af17c6b6f8e7e04`.
- v0.8.0 remains a regular, non-draft release; tag, downloadable App and
  installed Stable/Preview were not changed by this task.

Local verification artifact directory:
`/Users/carlos/Desktop/edit/notchmuse-showcase/round2/production/`.
Contains `public-verification.json`, before-deployment feed/notes, exact archive,
and `notchmuse-production-status.jpg` / `notchmuse-production-notch.jpg`.

PROJECT_STATUS, TASK_BOARD, THREAD_REGISTRY, PROJECT_HANDOFF and master handoff
are synchronized to completed state. No pending Product Owner confirmation.
Stop; do not reopen media creation, website design or App release work.
