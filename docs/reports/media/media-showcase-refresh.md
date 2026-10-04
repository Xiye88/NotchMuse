# NotchMuse Media Showcase Refresh

2026-10-04 · Marketing / Documentation / Website · ready for `00_PM` review.

**Historical Round 1 evidence.** Product Owner rejected the overly tight
framing. Current assets and framing evidence are documented in
[Round 2](media-framing-fix-round2.md); the sizes/crops below describe Round 1.

## Scope and result

Branch: `codex/media-showcase-refresh`, based on `origin/main` at `84bb0c1`.
Media commit: `9554338`; README commit: `d3940b9`; website/QA/handoff are in the
commit containing this report.

- Three real-recording micro demos, each as H.264 MP4, VP9 WebM, optimized GIF,
  and a WebP poster. Sources remain outside Git and untouched.
- Current Display and Appearance Settings PNGs from Source A. No obsolete
  Settings image was reused; General Settings is absent from the supplied inputs.
- EN/ZH README gallery with exactly three GIFs, one visible Settings screenshot
  and one collapsed Display screenshot. Installation, FAQ, support and download
  content are preserved byte for byte.
- Hero left copy, navigation, download links and overall sections retained.
  The nested Hero frames are replaced with a quiet real-recording crop, default
  Status Bar / optional Notch tabs, keyboard support and bilingual labels.
- Real Appearance playback is placed inside the existing modes section.
  Native videos only; no website GIFs or player framework.
- Default Hero poster is eager/high priority; all videos preload none, receive
  sources only when visible and motion is allowed, and pause offscreen.
  Unselected Notch is deferred. Video failures keep the poster. Reduced motion
  uses static posters without requesting video files, including after tab clicks.

## Source decisions and limitations

Source A is 1920×1080, 50.96s video (51.04s container), HEVC with AAC;
Source B is 1920×1080, 48.90s, H.264 with AAC. Source A has variable high frame
rate; exports are constant 30fps. All exported demos have exactly one video
stream and no audio stream.

Footage was inspected across the full recordings at two-second intervals, then
at one-second and quarter-second intervals around lyric positions/colors. Final
video and GIF frame strips were inspected, including beginnings, endings and
cuts. No artificial app rendering or lyric recoloring was used.

| Demo | Source ranges (seconds) | Result |
| --- | --- | --- |
| Notch | A 3.00–4.90, 9.10–11.00, 13.00–17.70 | Top lyrics → top live playback → above Dock; 8.50s |
| Status Bar | B 6.40–9.40, 9.70–10.70, 10.95–13.95 | Menu-bar playback / placement and natural lyric changes; 6.97s |
| Appearance | A 19.95–20.95, 17.00–18.00, 21.05–22.05, 18.05–19.55, 23.30–24.80 | Orange → blue progress → pink/red → gradient → background; 6.00s |

The physical MacBook notch is not present in Source A's captured desktop; the
actual overlay positions shown are top and above Dock. Both README languages
state which positions are recorded. Source B contains pre-existing zooms, so
segment crops retain the whole lyric instead of clipping it during those zooms.
The loops use deliberate editorial cuts between lyric/position states, not a
claim of continuous song playback across removed footage. Unsung lyric contrast
remains the app's actual recorded color. Final visual acceptance belongs to the
Product Owner; no manufactured hardware notch was added.

## File sizes

Decimal MB / KB, measured after final render. Exact bytes/codec/duration are in
[media-metadata.json](media-metadata.json).

| Demo | GIF | MP4 | WebM | Poster |
| --- | ---: | ---: | ---: | ---: |
| Status Bar | 2.407 MB | 134.483 KB | 47.980 KB | 7.852 KB |
| Notch | 4.674 MB | 193.190 KB | 106.654 KB | 9.828 KB |
| Appearance | 2.925 MB | 240.802 KB | 105.429 KB | 24.504 KB |

Web videos/posters together: about 0.87 MB. Only the default Status Bar WebM
(47.98 KB) is requested initially on a supporting browser. Each GIF is <5 MB,
1080px wide and nominal 15fps with optimized palette/dithering. GIF delays round
to centiseconds; GIF container duration can differ by a few hundredths of a second.
All new assets fit in normal Git; raw input recordings are not included.

## Validation

| Check | Result |
| --- | --- |
| ffprobe duration/resolution/30fps/H.264/VP9/no audio | PASS: all six web videos, 1080×240 |
| Complete FFmpeg decode | PASS: all MP4/WebM files |
| MP4 faststart (`moov` before `mdat`) | PASS |
| GIF readability, palette and sizes | PASS: manual frame strips + all <5 MB |
| Loop behavior | PASS: reviewed loop boundaries; actual browser loop observed |
| Existing `node website/test-language.cjs` | PASS: both languages, storage failures, unchanged v0.8.0 links |
| `node --check` on showcase code/test | PASS |
| Desktop/mobile 360, 390, 760, 820, 1440px | PASS: copy then demo on mobile, working tabs, no overflow |
| Default/Notch autoplay, muted, playsinline | PASS |
| Keyboard tabs and Chinese mode/appearance labels | PASS |
| Deferred sources, viewport pause | PASS |
| Reduced motion at initial load and live preference changes | PASS: no video requests in initial reduced-motion session |
| WebM decoding failure → MP4 fallback | PASS |
| All video requests fail → poster fallback | PASS |
| Layout shift | PASS: CLS <0.01 under tested viewports |
| Static website build/export | PASS: staged exact source copy, all local resource references resolve |
| README asset links / preserved installation, FAQ and support | PASS |
| `git diff --check` | PASS |
| App/runtime/version/build/feed/release boundary | PASS: unchanged |

The website is plain HTML/CSS/JS with no package manifest, compiler, bundler or
website lint command. “Build” means validating and staging the deployable static
files. App Swift/package/DMG builds were not run for this media-only task.
Browser tests used existing Playwright plus already-installed Chromium 149;
Safari/WebKit and other devices have not been independently tested.

Reproduce website checks with an existing Playwright installation:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory website
node website/test-language.cjs
node --check website/showcase.js
node website/test-showcase.cjs
```

Use `NODE_PATH` when Playwright is bundled outside the checkout;
`PLAYWRIGHT_EXECUTABLE_PATH` can select an existing browser;
`SHOWCASE_URL` defaults to `http://127.0.0.1:8765`;
`SHOWCASE_EVIDENCE` optionally saves verification screenshots.
Media reproduction is documented in `scripts/media/README.md`.

## Local visual evidence

Directory: `/Users/carlos/Desktop/edit/notchmuse-showcase/analysis/`

- `website-before-desktop.png`, `website-before-mobile.png`
- `website-after-desktop-status.png`, `website-after-desktop-notch.png`
- `website-after-mobile-status.png`, `website-after-mobile-notch.png`
- `website-after-desktop-chinese.png`, `website-after-reduced-motion.png`
- `website-after-appearance.png`
- `notch-gif-final.jpg`, `status-bar-gif-final.jpg`, `appearance-gif-final.jpg`
- Corresponding `*-mp4-final.jpg` strips, full source sheets and detail samples.

Static export: `/Users/carlos/Desktop/edit/notchmuse-showcase/site-export/`.
Local review server: `http://127.0.0.1:8765`. These screenshots/export are local
review evidence and are not part of production assets.

## Handoff

```text
Current status: Implementation and validation complete; ready for PM review.
Completed: Silent media, current Settings crops, EN/ZH README, Hero tabs,
Appearance playback, responsive/motion/loading/fallback tests, static export.
Pending confirmation: Product Owner visual acceptance; PM merge/deployment.
Key files: website/index.html, website/showcase.js, website/style.css,
README.md, README.zh-CN.md, scripts/media/render_showcase.py,
docs/reports/media/media-metadata.json.
Next step: 00_PM review → Product Owner visual acceptance → merge/deploy.
Do not repeat: App builds, v0.8.0 release work, source transcription,
provider/matcher/player changes, physical-notch fabrication.
```

Canonical status/board/registry/handoff received only this task's focused state
updates. The master handoff remains unchanged. `00_PM` should decide whether any
further canonical synchronization is needed after acceptance or deployment.
