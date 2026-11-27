# NotchMuse 800-song lyrics benchmark

**Scope.** Preview 0.8.3, branch `codex/preview-startup-updates`, initial checkout `18070b2`. One full pass covers 5,880 selections: seven player metadata profiles × (800 vocal recordings + 40 instrumental controls).

## Reproduction

```sh
python3 scripts/build_800_fixtures.py
./scripts/run_800_benchmark.sh --concurrency 4 \
  --http-cache /tmp/notchmuse-800-http \
  --rows /tmp/notchmuse-800-rows.jsonl \
  --report /tmp/notchmuse-800-summary.md
```

The fixtures retain Apple track IDs, storefronts and millisecond-resolution audio durations. [Apple iTunes Search result fields](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/UnderstandingSearchResults.html). Apple Music and Spotify use their production AppleScript parsers. NetEase, QQ Music, Soda Music, Kugou Music and YouTube Music use production MediaRemote event-to-track adapters with representative fixture payloads. Provider discovery and decisions run through the production providers, `LyricsClient` and `LyricsSelection`. The Apple catalog cannot supply native Spotify URIs or a live-authorized NetEase recording ID. YouTube labels, packed titles and channel strings are deterministic transformations of the named catalog recordings. They use the original audio duration.

The CLI saves an individual record for every evaluation. A vocal selection counts a returned timed-lyrics document. A control counts as a false positive if any timed lyrics are returned. Vocal selections need further recording and timing audit to establish correctness. The HTTP transport shares identical in-flight and completed requests, spaces starts per hostname by 250 ms and observes rate-limit backoff. The optional cache reuses successful payloads and 404 responses across runs, while uncached queries contact the upstream provider.

## Baseline

The full baseline completed 5,880 evaluations with four workers on the unedited app matcher.

| Fixture | Vocals | Guards | SHA-256 |
|---|---:|---:|---|
| Studio catalog | 800 | 40 | `4a12fc2c5af8e33260f9a1841606a0a544ddf49ae59d8ab28b5cab2e513136ad` |
| YouTube Music | 800 | 40 | `371b2ccf8b682ead3acfb702b49a7d1ce38126965d827db84347545a05907f97` |

Vocal cohorts include Mandopop (144), Cantopop market (100), mainland online pop (64), viral and soundtrack seeds (16), Western pop (104), rock (85), R&B and hip-hop (85), J-pop and anime (102) and K-pop (100). These are catalog cohorts, and region is not a track-level language label. Instrumental controls use selected piano, score, ambient and post-rock albums. Ten examples include `River Flows In You`, `Nuvole Bianche`, `On the Nature of Daylight (Piano Version)`, `Merry-Go-Round of Life`, `So Long, Lonesome`, `Near Light`, `Some`, `Lizard Point`, `Kiss the Rain` and `Divenire`.

| Platform | Vocal selections | Guard false positives | Vocal miss breakdown |
|---|---:|---:|---|
| Apple Music | 764/800 (95.5%) | 22/40 | provider_empty=15, timeline_conflict=13, content_ambiguity=4, resolver_metadata_unverified=2, timeline_out_of_recording=2 |
| Spotify | 757/800 (94.6%) | 1/40 | timeline_conflict=18, provider_empty=16, content_ambiguity=5, resolver_metadata_unverified=2, timeline_out_of_recording=2 |
| NetEase Cloud Music | 763/800 (95.4%) | 23/40 | provider_empty=14, timeline_conflict=14, content_ambiguity=5, resolver_metadata_unverified=2, timeline_out_of_recording=2 |
| QQ Music | 765/800 (95.6%) | 19/40 | provider_empty=19, timeline_conflict=9, content_ambiguity=5, resolver_metadata_unverified=1, timeline_out_of_recording=1 |
| Soda Music | 763/800 (95.4%) | 15/40 | provider_empty=19, timeline_conflict=9, content_ambiguity=5, resolver_metadata_unverified=2, timeline_out_of_recording=2 |
| Kugou Music | 765/800 (95.6%) | 3/40 | provider_empty=26, content_ambiguity=3, adapter_dropped=2, timeline_conflict=2, identity_ambiguous=1, resolver_metadata_unverified=1 |
| YouTube Music | 764/800 (95.5%) | 8/40 | provider_empty=18, timeline_conflict=7, content_ambiguity=5, identity_ambiguous=3, adapter_dropped=1, resolver_metadata_unverified=1, version_mismatch=1 |

Transport cache/join hits: 53899. Disk hits: 157. Requests: api.lrcmux.dev=2655, api.lrcmux.dev HTTP 404=685, api.lrcmux.dev HTTP 429=706, api.lrcmux.dev HTTP 503=1, api.qishui.com=862, c.y.qq.com=2568, lrclib.net=883, lyrics.kugou.com=1481, mobilecdn.kugou.com=861, music.163.com=1360, u.y.qq.com=926

## Before vs. after

| Player metadata profile | Baseline vocals | Final vocals | Change | Baseline guard FP | Final guard FP |
|---|---:|---:|---:|---:|---:|
| Apple Music | 764/800 (95.50%) | 769/800 (96.12%) | +5 | 22/40 | 0/40 |
| Spotify | 757/800 (94.62%) | 762/800 (95.25%) | +5 | 1/40 | 0/40 |
| NetEase Cloud Music | 763/800 (95.38%) | 769/800 (96.12%) | +6 | 23/40 | 0/40 |
| QQ Music | 765/800 (95.62%) | 770/800 (96.25%) | +5 | 19/40 | 0/40 |
| Soda Music | 763/800 (95.38%) | 754/800 (94.25%) | -9 | 15/40 | 0/40 |
| Kugou Music | 765/800 (95.62%) | 732/800 (91.50%) | -33 | 3/40 | 0/40 |
| YouTube Music | 764/800 (95.50%) | 743/800 (92.88%) | -21 | 8/40 | 0/40 |
| **Total** | 5,341/5,600 (95.38%) | 5,299/5,600 (94.62%) | -42 | 91/280 | 0/280 |

Each phase evaluated the same 5,880 platform/recording pairs. A returned timed document counts as a vocal selection. The 40 guard recordings appear on every profile, so the pooled guard count does not represent 280 independent recordings.

The final run gained 56 vocal selections and dropped 98. Among the dropped selections, 54 had unverified resolver metadata and 33 lacked independent support for a user upload. The biggest net reductions were on Kugou Music and YouTube Music, where the fixture profiles omit more album metadata.

## Key algorithm changes for Windows synchronization

- **Preserve negative recording evidence.** NetEase’s `pureMusic` flag enters selection with source recording metadata and an empty timeline, including the live-authorized Exact-ID path. An instrumental can veto generic lyrics with exact identity or matching artist, title, version, release and duration evidence. The generic veto with an empty album requires an exact matcher score and duration within one second. A stronger verified vocal identity takes precedence. Standalone notices such as `纯音乐，请欣赏` never render or count as vocal anchors.
- **Verify user uploads.** Kugou `product_from: ugc` needs text and timestamp agreement from an independent direct provider. `River Flows In You` and `Time Forgets...` exposed plausible metadata paired with user-uploaded text. Albumless solo resolver fallback also requires a source track ID. Baseline LRCMux false positives included `Nuvole Bianche` and `Una Mattina`.
- **Keep recording variants during video cleanup.** Confirm artist prefixes against known metadata and preserve dashed titles, soundtrack subtitles and live-video labels. Albumless studio requests reject candidates from explicitly marked concert releases. Existing duration caps and timeline-conflict vetoes apply, including the regression case for a +40-second video.
- **Normalize catalog-backed aliases and billing.** Chinese provider queries remove narrow Chinese soundtrack billing and tokenize `&` for Han-script collaborations. Identity comparison accepts the same Traditional and Simplified soundtrack forms. `乾淨` maps to `干净` while `乾` elsewhere stays distinct. Girls’ Generation, SNSD and 소녀시대 share the provider name `少女时代`. Different language versions and artists still require separate evidence.

## Selected case checks

| Recording and profile | Baseline | After |
|---|---|---|
| 像晴天像雨天(電視劇《難哄》心動曲) · NetEase Cloud Music | provider_empty | NetEase (电视剧《难哄》影视原声带·只喜欢你Love Moments) |
| 乾淨的房間 · Apple Music | provider_empty | Kugou (要去什么地方) |
| 你,好不好?(TVBS連續劇【遺憾拼圖】片尾曲) · YouTube Music | provider_empty | LRCLIB (愛，教會我們的事) |
| 烏 - Raven · YouTube Music | provider_empty | Kugou (烏 - Raven) |
| 残酷な夜に輝け - Shine in the Cruel Night · YouTube Music | provider_empty | Kugou (残酷な夜に輝け - Shine in the Cruel Night) |
| Gee · Apple Music | resolver_metadata_unverified | LRCMux (Gee - The First Mini Album) |
| Mr.Mr. · Apple Music | provider_empty | LRCMux (Girls' Generation 4th Mini Album 'Mr. Mr.') |
| 少女的祈禱 · YouTube Music | LRCMux (楊千嬅萬紫千紅演唱會) | Kugou (Play It Loud Kiss Music Soft) |

## Remaining miss breakdown

| Profile | Primary reasons across missed vocals |
|---|---|
| Apple Music | timeline_conflict 12, provider_empty 10, content_ambiguity 5, unverified_user_contribution 3, timeline_out_of_recording 1 |
| Spotify | timeline_conflict 18, provider_empty 10, content_ambiguity 5, unverified_user_contribution 4, timeline_out_of_recording 1 |
| NetEase Cloud Music | timeline_conflict 12, provider_empty 10, content_ambiguity 5, unverified_user_contribution 3, timeline_out_of_recording 1 |
| QQ Music | provider_empty 11, timeline_conflict 7, resolver_metadata_unverified 5, content_ambiguity 4, unverified_user_contribution 3 |
| Soda Music | provider_empty 12, resolver_metadata_unverified 10, timeline_conflict 10, unverified_user_contribution 8, content_ambiguity 5, timeline_out_of_recording 1 |
| Kugou Music | resolver_metadata_unverified 31, provider_empty 13, unverified_user_contribution 11, content_ambiguity 5, timeline_conflict 3, adapter_dropped 2, duration_risk 2, identity_ambiguous 1 |
| YouTube Music | resolver_metadata_unverified 22, provider_empty 11, content_ambiguity 6, timeline_conflict 6, unverified_user_contribution 6, identity_ambiguous 3, version_mismatch 2, adapter_dropped 1 |
| **Total** | provider_empty 77, resolver_metadata_unverified 68, timeline_conflict 68, unverified_user_contribution 38, content_ambiguity 35, identity_ambiguous 4, timeline_out_of_recording 4, adapter_dropped 3, duration_risk 2, version_mismatch 2 |

`provider_empty` means no selectable candidate emerged. It includes provider-side ranking rejections, provider failures alongside empty responses and missing timed lyrics. Timeline and content conflicts continue to block unverified choices. For `Genie` and `Good Evening`, public search exposed nearby language releases and alternate-script titles. Broad transliteration would merge ambiguous versions, so title aliases still need verified recording-level pairs.

## Transport and verification

Final run transport cache/join hits: 55063. Disk hits: 10591. Requests: api.lrcmux.dev=145, api.lrcmux.dev HTTP 404=43, c.y.qq.com=44, lyrics.kugou.com=29, mobilecdn.kugou.com=27, music.163.com=36, u.y.qq.com=13

Both runs contacted live providers for cache misses. The final pass reused successful payloads and 404s to limit traffic. The baseline recorded 706 LRCMux HTTP 429 responses. The runner now applies a minimum 60-second rate-limit backoff. Changes in underlying responses and deadlines can contribute to changes in raw vocal selections. The Soda endpoint sent an empty HTTP 200 body in the spot check, and the benchmark logged provider errors. The Soda player profile receives lyrics from the other sources when the Soda provider returns no candidate.

- `swift build --disable-sandbox` passed.
- `NotchMuse --full-self-test` passed. Settings window focus was skipped because the runner had no display.
- Lyrics selection, provider candidates and recall recovery passed. Update policy passed 44 checks and three plist configurations.
- Additional lyric timing, bilingual and diagnostics checks passed. The optional redacted real YRC fixture was absent.
- The extra Spotify identity recovery suite scored 30/31 on both the baseline HEAD and the candidate. Its HTTP 500 assertion expects no retry, while the existing transport marks 500 transient.

Gemini can inspect `/tmp/notchmuse-sprint-baseline.jsonl` and `/tmp/notchmuse-sprint-after.jsonl`. Each row records the provider candidate metadata, timestamp digest and outcome. Native player playback, audio-to-timeline alignment and live identity enrichment require separate acceptance. The work is uncommitted on `codex/preview-startup-updates` for Preview Build 109.
