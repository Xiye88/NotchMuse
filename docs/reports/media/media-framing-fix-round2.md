# Media Framing Fix — Round 2

2026-10-04 · `codex/media-showcase-refresh` · local candidate, not pushed,
merged or deployed. Baseline for this round: `006a0e16803aff47a1d5a7dbcd648fcab9185595`.

## Acceptance status

**Framing/export work complete for the available footage. Literal
physical-notch acceptance remains blocked by source footage.**

The Product Owner rejected Round 1's lyric-only strips. This round preserves
the full original 1920×1080 frame (100%, exceeding the requested roughly 2/3)
and uses 16:9 throughout website and GitHub assets. It does not redesign the
site or modify the Hero copy, navigation, FAQ, download links, App, version,
release workflow or feed. The Display and Appearance PNGs are unchanged.

## Framing decisions

- **Status Bar:** Source B 36.50–43.50s, a stable wide interval. Apple/app menus,
  native lyric position in the menu bar, desktop, real windows and Dock are all
  retained. Earlier source intervals with baked-in tight zooms were replaced.
  The source's existing inset desktop presentation is preserved, not invented.
- **Notch / top → Dock:** Source A 8.00–16.50s, one continuous interval. Native
  Display Settings and its real notch preview remain visible while the actual
  overlay switches from top to above Dock. Dock is visible in every frame.
- **Appearance:** original color/background edit retained, now showing the
  whole desktop and Dock behind the bottom lyrics rather than isolated text.
- Website Hero tabs, mode cards and Appearance reuse these assets; EN/ZH
  READMEs retain the same three GIF paths. Posters come from the first decoded
  frame. Containers reserve 16:9; the inherited 155px image cap is overridden
  only for demo posters so reduced-motion mode does not shrink their context.

**Source limitation:** neither recording contains the physical MacBook display
cutout. The notch visible inside Settings is the app's own live preview, not
physical hardware. No hardware notch or app output was fabricated. A question
is pending in the current PM chat: use this truthful preview for this round,
or supply footage showing physical hardware. Do not claim physical-notch
acceptance until Product Owner direction or suitable footage arrives.

## Exports and sizes

Website MP4/WebM/posters: 1280×720; videos 30fps, no audio, H.264/VP9.
GitHub GIFs: 960×540, nominal 12fps, 128 colors with Bayer dithering;
centisecond GIF timing. All exports preserve 16:9 with no letterbox crop.
Notch 8.50s; Status Bar 7.00s; Appearance 6.00s.

| Demo | GIF | MP4 | WebM | WebP poster |
| --- | ---: | ---: | ---: | ---: |
| status-bar | 0.796 MB | 0.264 MB | 0.246 MB | 0.084 MB |
| notch | 0.975 MB | 0.385 MB | 0.246 MB | 0.085 MB |
| appearance | 1.061 MB | 0.645 MB | 0.266 MB | 0.084 MB |

All web videos/posters: **2.304 MB**. All three GIFs: **2.832 MB**, each <5 MB.
Exact metadata: [media-metadata.json](media-metadata.json).
Reproduction: [media script guide](../../../scripts/media/README.md).

## Validation

| Check | Result |
| --- | --- |
| Source and final GIF/MP4 frame inspection | PASS: whole desktop, top edge/menu bar and Dock retained |
| Final export dimensions, codecs, duration, no audio | PASS: FFprobe on all 12 assets |
| Final MP4/WebM/GIF full decode | PASS: FFmpeg decode to null |
| MP4 faststart | PASS: `moov` precedes `mdat` |
| GIF file sizes | PASS: every GIF below 5 MB |
| Website language + JS syntax | PASS |
| Existing showcase checks with framing assertions | PASS: 360/390/760/820/1440px; 16:9; no overflow; CLS <0.01; autoplay, tabs/keyboard, deferred sources, offscreen pause, reduced motion, MP4/poster fallbacks |
| Website and README asset references | PASS: all referenced local media exist |
| Local README preview | PASS: EN/ZH render the same three complete-desktop GIFs; local Markdown preview, not GitHub production rendering |
| Product and release boundary | PASS: no App, feed, download, version or release changes |
| Physical hardware notch | NOT MET: missing from supplied footage |
| Product Owner visual acceptance | PENDING |

Existing browser suite used installed Chromium 149; the in-app browser was
also inspected. This does not establish independent Safari/iOS validation.
The suite passed after the frame/dimension change; the final Notch edit then
changed only to a continuous 8.5s interval, and final media decode/frame inspection
was repeated. The prior branch CI PASS at `006a0e1` is historical; Round 2 has
not been pushed, so no new GitHub CI result exists. No App build was repeated.

## Local review

- Website: http://127.0.0.1:8765/
- Chinese README: http://127.0.0.1:8766/readme-zh.html
- English README: http://127.0.0.1:8766/readme-en.html
- Evidence: `/Users/carlos/Desktop/edit/notchmuse-showcase/round2/analysis/`
- Final frame strips: `status-bar-gif-sheet.jpg`, `notch-gif-sheet.jpg`,
  `appearance-gif-sheet.jpg`, and corresponding MP4 strips.

The Round 1 pause/continue-control P2 remains open; this framing-only correction
does not change showcase playback behavior. It must be resolved or explicitly
accepted before production promotion, independently of framing acceptance.

## Handoff

```text
Current status: Local full-desktop framing candidate; physical-notch decision pending.
Completed: Full-desktop MP4/WebM/GIF/posters, 16:9 containers, validation, PM sync.
Pending confirmation: Physical-notch footage/direction, visual acceptance, sync/deploy.
Key files: website/index.html; website/style.css; scripts/media/render_showcase.py;
docs/reports/media/media-framing-fix-round2.md; docs/project/PROJECT_STATUS.md.
Next step: Review candidate; resolve source limitation; address/accept prior pause P2.
Do not repeat: Page redesign, source imports, App builds, release/provider/matcher work.
```
