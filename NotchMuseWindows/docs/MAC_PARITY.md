# Reference parity tracking

Read-only reference: origin/codex/preview-startup-updates at 895bc4cc479a802f4785620fc2c10faeae152c81. No Mac sources, website sources, shared scripts or existing workflows were edited.

Implemented from reference and explicit Windows handoff:

- title/version identity, remaster years, conservative studio/video duration gates;
- collaborator extraction and main-artist subset score; contextual `and` splitting;
- complete checked-in reference alias map (including Chinese, Korean and Japanese mappings);
- Windows NLS traditional-to-simplified normalization with ambiguous 乾/幹 preservation;
- blank-player-album handling; release suffix and bilingual album equivalence;
- direct LRCLIB/NetEase/QQ/Kugou requests and LRCMux fallback;
- standard/multi-stamp/Enhanced LRC, YRC absolute words and KRC decryption/relative words;
- credits excluded from vocal anchors; repeated-line nearest-unused pairing and prefix boundaries;
- strict Tier-4 solo evidence; resolver solo evidence; overflow repair; independent timing checks;
- source deadlines, cancellation, event-driven track changes and bounded result cache.

Intentional requested differences:

- Studio ranking uses five seconds (Mac preliminary ranking permits eight, final selection permits five).
- No empty-album five-line/85-score Tier-4 shortcut; requested strict 12-line/96-score gate applies.
- At least five corroborating anchors even for short documents, as required by the Windows brief.

Remaining parity / qualification work (must not claim full E19 equivalence):

- Mac's complete independent clique selection and bound-outlier precedence are not yet ported; Windows currently rejects disagreements conservatively.
- LRCLIB full Korean/Japanese conflicting-script and metadata-internal recording rules require more fixture coverage.
- NetEase live exact-ID binding and recording ISRC are modeled, but SMTC does not normally supply these identities; no fabricated IDs are inferred.
- QQ smartbox/details auxiliary route and Kugou alternate-host retry are pending.
- Some rich translation formats and resolver identity-URL parsing are pending.
- Browser policies and all 36 player names are implemented; physical compatibility across those players has not been established.
- WPF process working set currently exceeds the required budget. No memory acceptance is claimed.

Source request success, engine acceptance, manual lyric accuracy, physical SMTC integration and power measurements are distinct checks.
