# Five website topic pages — implementation and verification

Date: 2026-10-17. Responsibility: `06_DOCS`, existing SEO chat; no new numbered chat or delegation. Branch: `codex/seo-scenario-pages`. Workspace: `/Users/carlos/.codex/worktrees/notchmuse-seo-pages/歌词`.

## Scope and homepage decision

The Product Owner approved all five topics because production cost is low. These are distinct use cases, not five keyword replacements of the same landing page. No new paid keyword queries were needed. The candidate preserves the current homepage design, title, H1, demos, FAQ, installation instructions and consent behavior. Homepage changes are a five-card guide section, a footer link and loading the shared guide stylesheet in EN/ZH.

The homepage already covers product identity, five players, recordings, two display modes, appearance, setup, requirements, privacy, updates and FAQ. The previous generic suggestion to “complete the homepage” was not a specific defect. This round adds discoverability for the new content.

## Published-site baseline

GitHub main remains older than the deployed website source. The candidate starts at `7784fcd` (the existing deployed website implementation), not an App Preview integration branch. Before editing, live `/`, `/zh/`, `/style.css`, `/analytics.js`, `/showcase.js` and `/sitemap.xml` matched this baseline byte-for-byte via public HTTP reads. The worktree was created from origin/main, then switched to the isolated feature branch at this verified baseline. No other chat's worktree was modified.

This ancestry contains earlier local App work. Any later GitHub synchronization must isolate the website changes and reconcile the already-deployed website baseline; do not merge the complete feature ancestry into main as an App promotion. No App source, installation, version/build, stable feed, DMG or public release was changed in this round. Public product facts remain v0.8.0 / Build47.

## Delivered paths and distinct jobs

Each topic has an English URL and a paired `/zh/` URL (10 new URLs; 12 sitemap entries including both homepages).

| Topic | English path | Job |
| --- | --- | --- |
| Spotify overlay | `/spotify-lyrics-mac/` | Native Spotify lyrics vs external display, setup, player permissions, placement, missing-match diagnosis. |
| Menu bar | `/menu-bar-lyrics/` | Cross-player Status Bar setup, left/right layout and permissions, space/readability. |
| Apple Music | `/apple-music-desktop-lyrics-mac/` | Native lyrics and MiniPlayer first, choice table, connection/setup, independent lyric coverage. |
| Notch/Dock | `/macbook-notch-lyrics/` | Top/Dock/menu bar positions, layout/appearance setup, hardware scope, focused lyric use case. |
| LyricsX alternative | `/lyricsx-alternative/` | Attributed documentation comparison, suitable users, file-workflow caveats, reversible trial steps, source links. |

All pages have a unique title, description and H1; self-canonical; paired EN/ZH/x-default links; OG/Twitter metadata; static BreadcrumbList JSON-LD; visible breadcrumb; sources; related-topic links; and three existing consent-gated download placements. Content is HTML, not injected by client JS. Shared `guides.css` extends the existing dark/orange visual language. Existing assets, `analytics.js` and `showcase.js` are reused unchanged.

## Factual boundaries

- Spotify's own Lyrics button is explained before the external overlay. NotchMuse supports the desktop player here; browser playback is not promised.
- Apple Music already offers native lyrics, MiniPlayer and an on-top setting. This page does not present a floating window as a capability missing from Apple. Menu labels can vary by OS.
- Existing video footage was recorded with Spotify. Apple Music's page and every reused recording identify that provenance; no Apple Music-specific recording or new physical-notch footage is claimed.
- LyricsX comparison is explicitly authored by the NotchMuse team and based on public docs checked October17,2026. No head-to-head installation/performance/reliability test was run. It does not call LyricsX broken, abandoned, incompatible or inferior. Unconfirmed NotchMuse file import/seek features are not marked as established support.
- No traffic, install, ranking or keyword-volume guarantee. The prior research's exact-long-tail demand gaps remain.

Sources checked:

- https://notchmuse.com/ and public source README
- https://support.spotify.com/us/article/lyrics/
- https://support.apple.com/guide/music/view-and-enter-lyrics-musf438ffc97/mac
- https://support.apple.com/guide/music/use-music-miniplayer-mus71d7dcfce/mac
- https://github.com/ddddxxx/LyricsX#readme and linked project documentation
- https://github.com/ddddxxx/LyricsX/releases/latest (resolved to v1.6.3; no release-age inference is used)

## Verification

Local static server: port8891, bound to127.0.0.1, serving `website/` only. Browser tests use the existing system Chrome in an isolated headless profile via Playwright. Google requests and DMG navigations are intercepted; no real GA events or App downloads are sent during these tests.

- `website/test-language.cjs`: PASS. Original EN/ZH home title/H1/copy/FAQ, canonical/hreflang/social tags/assets and three DMG placements preserved. Sitemap assertion accepts the added pages while retaining root-language ordering and uniqueness.
- `website/test-analytics.cjs`: PASS. Initial refusal/no-consent, consent, three download placements, withdrawal/cookie clearing, cross-tab consent, blocked storage, no-JS behavior for both homepages.
- `website/test-guides.cjs`: PASS. All five topics in EN/ZH; metadata, paired language navigation, downloads, analytics refusal/consent and language-specific events; 360/768/1440px without overflow or clipped header controls; posters and reduced-motion behavior; source HTML content without JS; all12 sitemap URLs; unique metadata; every internal path/fragment exists.
- `website/test-showcase.cjs`: PASS on isolated rerun. Original mode/keyboard switching, autoplay/looping, live motion preference, mobile layouts, media fallbacks and poster behavior. Initial concurrent run timed out at the dynamic motion-preference assertion; it was preserved in `test-showcase.initial-concurrent.log`. No showcase script change was made.
- `git diff --check`: PASS.
- Desktop IAB preview and EN desktop/ZH mobile screenshots inspected. Ten screenshots retained in [evidence](seo-pages-2026-10-17-evidence/). Small-screen header hiding inherited from homepage styles was corrected locally in the guide stylesheet; existing base CSS was left intact. Resize tests wait for two animation frames before measuring layout.

Logs are in the evidence directory. Final guide/showcase logs transcribe the successful command outputs from this chat; the other logs were written by the test runner.

## Approved publication — 2026-10-17

The Product Owner explicitly approved direct GitHub synchronization and website publication, and requested a visual preview. The Chinese Spotify page is open in the chat browser. The website-only patch was applied to a fresh checkout of origin/main at cb79f3528b768f725a37aac87cc113ffab4ba403; the candidate's unrelated Preview ancestry is excluded. The already deployed bilingual/analytics baseline is included because it had not previously reached main. The local patch remains in the original implementation workspace; it is not a site asset.

Publication and public verification are in [production closure](seo-pages-production-2026-10-17.md).
