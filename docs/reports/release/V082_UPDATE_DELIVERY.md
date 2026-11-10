# v0.8.2 / Build70 — old-user update delivery

Date: 2026-11-10. Owner explicitly requested immediate update delivery and authorized the existing origin; this supersedes the earlier manual-only preparation checkpoint.

## Root cause and change

Stable Build47 and Build61 already embed Sparkle2.10.0, the same bundle identity, official feed URL and EdDSA public key. The official feed still advertised47 after GitHub and website downloads moved to70. Updated `https://notchmuse.com/appcast.xml` to70 with the exact already-public frozen DMG, original Keychain signing account, archive signature and signed XML. Published versioned bilingual updater notes first. No app code, build, tag or frozen release asset changed.

- DMG: `https://github.com/Xiye88/NotchMuse/releases/download/v0.8.2/NotchMuse.dmg`
- Length: 7,270,643 bytes.
- DMG SHA256: `f0aef83093c7bd0845816f4a52986d8cd3dee1d9c2381145e53c6fdd8226540c`.
- Feed SHA256: `e957c05f037b3950faf4d9fd64679e4c5a2a3f6519e1e767f20b34f0d218035a`.
- Notes: `https://notchmuse.com/releases/v0.8.2/NotchMuse.md`, SHA256 `cef41f3347c48e8f11abb4d42c37d1dc2c04bce01290f597ac7c2b65a03960ed`.

## Verification

| Check | Result |
| --- | --- |
| Frozen DMG with public key embedded in actual old app | PASS; independent CryptoKit verification; single-byte corruption rejected |
| Signed feed verification by official Sparkle tool | PASS |
| Original47 complete physical temporary copy →70 | PASS: staged loopback feed, actual public GitHub download, installer and automatic relaunch; 118 bundle files/links exactly match frozen70 |
| Original61 complete physical temporary copy →70 | PASS: official public feed, visible bilingual notes, actual download, install/relaunch; 118 entries exactly match |
| Updated70 checking public feed again | PASS: visible “0.8.2 Build70 is latest” |
| Automatic scheduled check, no Check for Updates action | PASS: original61, test last-check timestamp made due, checks enabled; didFindValidUpdate70 at15:45:47; visible Later/Install/Skip window. Reminder was behind Settings until that window closed. |
| Origin/apex/www feed and notes | PASS: four public responses match staged bytes; no feed cache problem |
| Installed Stable61 / Preview69 | Unchanged; only temporary app copies updated |
| Preferences | Exact original dictionary restored and compared after testing; same-ID copies share preferences, so this is not separate-account isolation |

The initial staged test showed a release-notes404 before notes deployment; installation succeeded. The public61 test subsequently displayed the complete notes correctly. First sandboxed generator attempt could not mount DMG/read Keychain; normal authorized host execution generated and verified successfully. No private key was exported.

## Public completion

Implementation/source commit `42b3d4af42726c4b99f7e2fcdff1f31e09c93e8b` is synchronized to main and the existing release branch. [Main CI passed](https://github.com/Xiye88/NotchMuse/actions/runs/42778260377). Origin has46 exact current source files plus3 retained historical note files;12 public apex/www checks (EN/ZH pages, current release notes, feed and updater notes) match source bytes and preserve CSP. The GitHub Release body now explains in-app updating; its frozen DMG digest and length remain unchanged. The original feed and changed pages/notes are backed up outside the served root. Temporary HTTP service is stopped; installed Stable61/Preview69 and exact original Stable preferences remain preserved.

## Delivery behavior and limits

Compatible old Stable users who keep automatic checks enabled discover70 when their running app next checks online, then confirm installation. This is scheduled checking with consented in-app download/install/relaunch, not a server force-install or immediate delivery guarantee to every user. Manual Check for Updates works independently. Preview stays separate. Beta3 and earlier contain no updater and require one manual install. Offline apps and disabled checks cannot be reached by this feed.

Ad-hoc signing and lack of Apple notarization remain unchanged. Clean-Mac installation and simulated installer failure/rollback are not claimed as tested by this work. Previous release packages and original feed are retained for operational rollback.

## Prevent recurrence

`prepare_appcast.sh` accepts frozen APP/DMG/NOTES/OUTPUT inputs, uses the current notes layout, generates versioned notes URLs, signs/verifies XML and checks expected build/version and asset URLs. Release procedure requires public feed verification before calling delivery complete. Source push alone does not deploy the origin. Updated README, current source release notes, GitHub Release body and EN/ZH website FAQ explain actual update behavior. Frozen uploaded release-note assets remain as the original publication checkpoint; the Release body and live notes provide the current delivery status. The repaired script also passed a real frozen-input generation/sign/verify run, in addition to shell syntax and simulated path tests.

Local evidence: `release-v082-20261110/sparkle-v082/` in the PM evidence directory: `build47-install-e2e.json`, `build61-public-install-e2e.json`, `automatic-check-e2e.json`, `origin-feed-promotion.json`, `public-feed-verification.json`. Preference backups are local only and excluded from Git.

```text
Current status: Official signed feed70 LIVE; old-user discovery/install/relaunch and automatic notice verified.
Completed: Original47→70; public61→70; automatic61 notice; exact118-entry comparisons; public feed/notes hashes; original preferences restored.
Pending confirmation: None for this owner-authorized delivery repair.
Key files: docs/releases/v0.8.2/appcast.xml; docs/releases/v0.8.2/NotchMuse.md; scripts/prepare_appcast.sh.
Next step: Keep future regular releases coupled to verified feed promotion; collect real old-user feedback.
Do not repeat: App rebuild/asset replacement, DNS changes, test-account requests, bilingual development or a forced-install claim.
```
