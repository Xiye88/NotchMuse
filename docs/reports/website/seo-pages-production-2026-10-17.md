# Website topic pages — production closure

2026-10-17, Asia/Shanghai. **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**.

## Authorization and scope

Product Owner explicitly approved direct GitHub synchronization and public website publication and requested preview. Existing responsibility06_DOCS and SEO chat01a116ce-e921-70c3-ad28-40baf9e371ed are reused. Five topics each have English and Chinese pages (10 new URLs). Homepages gain guide discovery; sitemap includes12 URLs. The previous deployed bilingual/analytics baseline7784fcd is reconciled into main because it was not previously synchronized.

- Published source: `983729a4c9e69a748c5772dcdbefc772b2f582c1`.
- Direct fast-forward push: `cb79f3528b768f725a37aac87cc113ffab4ba403` → `983729a`.
- Source [GitHub CI](https://github.com/Xiye88/NotchMuse/actions/runs/39041051655): **PASS**. The existing CI builds/tests its checkout; it does not publish an App release.
- Scope verified:43 changed paths, all under website/, docs/project/ and docs/reports/website/. The unrelated Preview ancestry was excluded using a website-only patch atop current main. All46 website source/test files match the already-tested implementation workspace byte-for-byte.
- No App source, installed App, version/build, tag, release asset, official feed or download destination changed. Public App stays v0.8.0 / Build47.

## Preview and page map

The chat browser shows a local preview of `/zh/#guides`; its five cards open the individual pages. Local desktop/mobile screenshots are retained in the implementation evidence. Attempted in-app browser navigation to the public Spotify page failed with ERR_CONNECTION_CLOSED; it was not represented as a successful live visual check. Public GET verification below independently succeeded.

| Topic | English | Chinese |
| --- | --- | --- |
| Spotify | https://notchmuse.com/spotify-lyrics-mac/ | https://notchmuse.com/zh/spotify-lyrics-mac/ |
| Menu bar | https://notchmuse.com/menu-bar-lyrics/ | https://notchmuse.com/zh/menu-bar-lyrics/ |
| Apple Music | https://notchmuse.com/apple-music-desktop-lyrics-mac/ | https://notchmuse.com/zh/apple-music-desktop-lyrics-mac/ |
| Notch/Dock | https://notchmuse.com/macbook-notch-lyrics/ | https://notchmuse.com/zh/macbook-notch-lyrics/ |
| LyricsX | https://notchmuse.com/lyricsx-alternative/ | https://notchmuse.com/zh/lyricsx-alternative/ |

Apple Music footage is explicitly labeled as recorded using Spotify. LyricsX is an attributed public-documentation comparison; no head-to-head installation or performance benchmark is claimed. [Implementation and local verification](seo-scenario-pages-2026-10-17.md).

## Deployment and rollback

- New release directory: `/opt/notchmuse-site/releases/20261017-seo-983729a`.
- Previous directory retained: `/opt/notchmuse-site/releases/20261004-seo-7784fcd`.
- Server backup: `/opt/notchmuse-site/site_server.before-seo-983729a.py`.
- Static archive SHA256: `278c8459c48a4c608ad8010308dbf02db64c5da77c71c0a68fda73054a467098`.
-42 static source files deployed; test scripts excluded. Existing appcast and release notes copied byte-for-byte to the new directory. All44 origin files verified by GET and SHA256 after service restart. Website and Cloudflare Tunnel services active.
- Existing server cache policy extended to guide directories/HTML and guides.css. CSP retained. No CDN or analytics account configuration was changed.
- Rollback: restore the server backup to `/opt/notchmuse-site/site_server.py`, restart `notchmuse-site.service`, then verify origin and public root/feed. Previous assets and directory remain available.

## Public verification and limitations

-58 public URL checks cover42 static source files, two protected release files, and all12 pages plus sitemap/guides.css on www. The12 page URLs on both hosts return200 with exact source HTML bytes. Metadata, canonical/language links and source text therefore match the locally verified candidate.
-55 initial GET/hash checks passed. Three unchanged videos timed out mid-transfer on this network; follow-up requests with a verification query returned200 and exact expected complete hashes. Initial failures are retained, not overwritten. An initial Python urllib probe returned403; a server-side urllib follow-up also returned403. Curl GET verification succeeded. This is not a successful public browser playback assertion.
- Protected appcast SHA256: `750fda31ab87c78fe41b494b5119e0343c3413bc8e16b2df74f6127179b44580`.
- Protected NotchMuse.md SHA256: `770f3a527c1c85fb45c80faa5a16a9657a9270883c4a86df1af17c6b6f8e7e04`.
- Four local suites passed (language, analytics, guides and showcase); see recorded evidence. No paid SEO API call, live GA test event, App download, search-engine indexing/ranking claim or analytics backend change was made during this publication.

Evidence: [public GET/hash results](seo-pages-2026-10-17-evidence/public-verification.json), [deployment receipt](seo-pages-2026-10-17-evidence/deployment-result.json), [source manifest](seo-pages-2026-10-17-evidence/source-manifest.json), [CI receipt](seo-pages-2026-10-17-evidence/github-ci.json).

```text
Current status: GitHub main synchronized; five EN/ZH topics publicly deployed and HTTP verified.
Completed: Website-only main promotion; CI PASS; release-directory deployment;44 origin hashes;58 public targets including media rechecks; protected feed/notes preserved; local preview and evidence.
Pending confirmation: None. Optional visual feedback may follow from Product Owner.
Key files: website/; docs/reports/website/seo-pages-production-2026-10-17.md; seo-pages-2026-10-17-evidence/.
Next step: Product Owner may review the open local preview or public page links. Future search performance needs actual GSC observations; no scheduled task was created.
Do not repeat: Deployment, paid research, media regeneration, App promotion/release/feed changes, analytics configuration or claims of indexing/ranking success.
```
